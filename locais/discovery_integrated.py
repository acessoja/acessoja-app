"""One bounded server-side discovery scope, canonicalized and ranked before paging.

No provider calls or writes here. Current authorized evidence is shared with the
place panel. Continuations contain only hashes and offsets, never resource IDs.
"""

import hashlib
import json
import math
from urllib.parse import urlencode

from django.conf import settings
from django.core import signing
from django.core.serializers.json import DjangoJSONEncoder
from django.db import connection, transaction
from django.db.models import Exists, OuterRef, Q
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils.decorators import method_decorator
from django.views.decorators.debug import sensitive_post_parameters

from acessoja.accessibility_catalog import CATALOG_VERSION, RESOURCE_IDS
from acessoja.api_schema import ErroSerializer
from evidencias.external import project_catalog_places
from evidencias.query_projection import annotate_quality
from .accessibility import matching_resources, parse_filters, presence_count
from .catalog_models import CatalogEntry, CatalogScope
from .catalog_serializers import CatalogQuerySerializer
from .discovery import DiscoveryOptions, OPTIONS
from .models import Local
from .serializers import LocalSerializer
from .services.accessibility import populate_accessibility_context
from .services.categories import CATEGORY_CATALOG, CATEGORY_VERSION, matches_category
from .services.catalog_query import catalog_place
from .services.catalog_rules import MUNICIPALITY
from .services.matching import normalize

PRIVATE = {"Cache-Control": "private, no-store", "Vary": "Authorization, Cookie"}
SALT = "discovery-continuation-v1"


def stable(value):
    # evaluated_at is a rendering clock, not an evidence/classification revision.
    if isinstance(value, dict):
        return {key: stable(item) for key, item in value.items() if key != "evaluated_at"}
    if isinstance(value, (list, tuple)):
        return [stable(item) for item in value]
    return value


def digest(value):
    return hashlib.sha256(
        json.dumps(
            stable(value), cls=DjangoJSONEncoder, sort_keys=True, ensure_ascii=False, separators=(",", ":")
        ).encode()
    ).hexdigest()


class PublicDiscoveryQuerySerializer(CatalogQuerySerializer):
    cursor = serializers.CharField(required=False, max_length=3000)

    def get_fields(self):
        fields = super().get_fields()
        fields.pop("page", None)
        fields.pop("catalog_version", None)
        return fields


class PersonalSnapshotSerializer(serializers.Serializer):
    resources = serializers.ListField(child=serializers.ChoiceField(choices=RESOURCE_IDS), max_length=100)
    mode = serializers.ChoiceField(choices=["prioritize", "all", "any"], default="prioritize")
    include_unknown = serializers.BooleanField(default=False)
    catalog_version = serializers.IntegerField(min_value=1)
    snapshot_revision = serializers.IntegerField(min_value=0, default=0)


class DiscoveryRequestSerializer(serializers.Serializer):
    criteria = serializers.DictField(child=serializers.CharField(), required=False, default=dict)
    personalization = PersonalSnapshotSerializer()
    cursor = serializers.CharField(required=False, max_length=3000)


class CategoryCatalogSerializer(serializers.Serializer):
    parents = serializers.ListField(child=serializers.DictField())
    version = serializers.IntegerField()
    conflict_policy = serializers.CharField()
    children = serializers.ListField(child=serializers.DictField())


class DiscoveryResponseSerializer(serializers.Serializer):
    count = serializers.IntegerField()
    count_exact = serializers.BooleanField()
    next = serializers.CharField(allow_null=True)
    previous = serializers.CharField(allow_null=True)
    version = serializers.CharField()
    scope = serializers.DictField()
    results = serializers.ListField(child=serializers.DictField())


def validate_personal(data):
    allowed = {"resources", "mode", "include_unknown", "catalog_version", "snapshot_revision"}
    if not isinstance(data, dict) or set(data) - allowed:
        raise ValueError
    resources = data.get("resources")
    if (
        not isinstance(resources, list)
        or len(resources) > 100
        or any(not isinstance(key, str) or key not in RESOURCE_IDS for key in resources)
    ):
        raise ValueError
    mode = data.get("mode", "prioritize")
    unknown = data.get("include_unknown", False)
    version = data.get("catalog_version")
    revision = data.get("snapshot_revision", 0)
    if mode not in ("prioritize", "all", "any") or type(unknown) is not bool:
        raise ValueError
    if type(version) is not int or version != CATALOG_VERSION or type(revision) is not int or revision < 0:
        raise ValueError
    if mode == "prioritize" and unknown:
        raise ValueError
    return {
        "resources": sorted(set(resources)),
        "mode": mode,
        "include_unknown": unknown,
        "catalog_version": version,
        "snapshot_revision": revision,
    }


def canonical_documents(request, options, filters):
    """Bounded projection, constant query count; no all-catalog device transfer."""
    scope = CatalogScope.objects.select_related("active_batch").filter(pk=MUNICIPALITY).first()
    cap = max(1, min(getattr(settings, "DISCOVERY_MAX_CANDIDATES", 5000), 20000))
    locals_qs = Local.objects.order_by("pk")
    if filters["categories"]:
        locals_qs = locals_qs.filter(categoria__in=filters["categories"])
    if options.bbox:
        south, west, north, east = options.bbox
        locals_qs = locals_qs.filter(latitude__range=(south, north))
        locals_qs = (
            locals_qs.filter(longitude__range=(west, east))
            if west <= east
            else locals_qs.filter(Q(longitude__gte=west) | Q(longitude__lte=east))
        )
    locals_ = list(annotate_quality(locals_qs)[: cap + 1])
    truncated = len(locals_) > cap
    locals_ = locals_[:cap]
    context = populate_accessibility_context(locals_, {"request": request})
    internal = list(LocalSerializer(locals_, many=True, context=context).data)
    for row in internal:
        row["canonical_id"] = f'acessoja:{row["id_local"]}'
        own_id = request.user.pk if request.user.is_authenticated else None
        row["_discovery_rating"] = context["visible_review_stats"][(row["id_local"], own_id)]["average"]
    entries = CatalogEntry.objects.none()
    if scope and scope.active_batch_id and filters["sources"] != ["acessoja"]:
        entries = (
            CatalogEntry.objects.filter(
                batch_id=scope.active_batch_id, source_status="available", poi__local__isnull=True
            )
            .annotate(has_local=Exists(Local.objects.filter(osm_id=OuterRef("poi__external_id"))))
            .filter(has_local=False)
        )
        if filters["categories"]:
            entries = entries.filter(category__in=filters["categories"])
        for word in normalize(filters["search"]).split():
            entries = entries.filter(search_text__contains=word)
        if options.bbox:
            south, west, north, east = options.bbox
            entries = entries.filter(latitude__range=(south, north))
            entries = (
                entries.filter(longitude__range=(west, east))
                if west <= east
                else entries.filter(Q(longitude__gte=west) | Q(longitude__lte=east))
            )
        entries = list(
            annotate_quality(entries.order_by("poi_id"), catalog=True).select_related("poi", "batch", "observed_in")[
                : max(0, cap - len(internal)) + 1
            ]
        )
    else:
        entries = []
    truncated |= len(internal) + len(entries) > cap
    entries = entries[: max(0, cap - len(internal))]
    external = [catalog_place(entry) for entry in entries]
    project_catalog_places(entries, external)
    for row in external:
        row["canonical_id"] = row["external_id"]
    version = digest(
        {
            "documents": [*internal, *external],
            "catalog": CATEGORY_VERSION,
            "scope": [scope.revision, str(scope.active_batch_id)] if scope else None,
            "partial": truncated,
        }
    )
    coverage = bool(scope and scope.active_batch and scope.active_batch.complete)
    metadata = {
        "kind": "bounded_persistent_discovery",
        "municipality": MUNICIPALITY,
        "sources": {
            "acessoja": "available",
            "openstreetmap": (
                ("complete" if coverage else "partial") if scope and scope.active_batch_id else "unavailable"
            ),
        },
        "live_provider": "separate_regional_scope",
        "candidate_limit": cap,
        "limited": truncated,
        "coverage_complete": coverage and not truncated,
        "category_version": CATEGORY_VERSION,
        "resource_catalog_version": CATALOG_VERSION,
        "bbox": options.bbox,
    }
    return [*internal, *external], version, metadata


def rank_documents(rows, filters, options, personal):
    ranked = []
    priority = set(filters["resources"]) if filters["mode"] == "priorizar" else set()
    if personal and personal["mode"] == "prioritize":
        priority.update(personal["resources"])
    words = normalize(filters["search"]).split()
    for row in rows:
        if any(word not in normalize(row["nome"] + " " + row.get("endereco", "")) for word in words):
            continue
        if filters["sources"] and not set(row["origins"]) & set(filters["sources"]):
            continue
        if not matches_category(
            row["categoria"], row.get("subcategoria", ""), filters["categories"], filters["subcategories"]
        ):
            continue
        information = row["accessibility"]
        accepted, missing = matching_resources(
            information, filters["resources"], filters["include_unknown"], filters["combination"], filters["mode"]
        )
        if not accepted:
            continue
        if personal and personal["mode"] != "prioritize":
            accepted, _ = matching_resources(
                information,
                personal["resources"],
                personal["include_unknown"],
                "qualquer" if personal["mode"] == "any" else "todos",
            )
            if not accepted:
                continue
        row["missing_resources"] = missing
        # Derived response only; never added to a model or evidence record.
        row["resource_match"] = {"count": presence_count(information, priority), "total": len(priority)}
        ranked.append(row)

    def secondary(row):
        tail = (normalize(row["nome"]), row["canonical_id"])
        if options.ordering == "proximity":
            lat, lon = row.get("latitude"), row.get("longitude")
            distance = math.inf
            if lat is not None and lon is not None:
                a, b = options.origin
                h = (
                    math.sin(math.radians(lat - a) / 2) ** 2
                    + math.cos(math.radians(a)) * math.cos(math.radians(lat)) * math.sin(math.radians(lon - b) / 2) ** 2
                )
                distance = 12742000 * math.asin(min(1, math.sqrt(h)))
            return distance, *tail
        if options.ordering == "rating":
            return (
                -(row.get("_discovery_rating", row.get("media_estrelas")) or 0),
                -(row.get("quantidade_avaliacoes") or 0),
                *tail,
            )
        return tail

    ranked.sort(key=lambda row: (-row["resource_match"]["count"], *secondary(row)))
    return ranked


@method_decorator(sensitive_post_parameters("__ALL__"), name="dispatch")
class IntegratedDiscoveryAPIView(APIView):
    permission_classes = [AllowAny]

    def get_permissions(self):
        return [IsAuthenticated()] if self.request.method == "POST" else [AllowAny()]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = PRIVATE["Cache-Control"]
        response["Vary"] = "Accept, Authorization, Cookie"
        return response

    @extend_schema(
        tags=["Descoberta"],
        summary="Descoberta pública consolidada; somente critérios manuais",
        parameters=[PublicDiscoveryQuerySerializer],
        responses={200: DiscoveryResponseSerializer, 400: ErroSerializer, 409: ErroSerializer},
    )
    def get(self, request):
        return self.discover(request)

    @extend_schema(
        tags=["Descoberta"],
        summary="Descoberta privada com snapshot explicitamente aplicado",
        request=DiscoveryRequestSerializer,
        responses={200: DiscoveryResponseSerializer, 400: ErroSerializer, 401: ErroSerializer, 409: ErroSerializer},
    )
    def post(self, request):
        return self.discover(request)

    def discover(self, request):
        try:
            personal = None
            if request.method == "POST":
                if (
                    request.query_params
                    or not isinstance(request.data, dict)
                    or set(request.data) - {"criteria", "personalization", "cursor"}
                ):
                    raise ValueError
                personal = validate_personal(request.data.get("personalization"))
                params = request.data.get("criteria", {})
                cursor = request.data.get("cursor")
                if not isinstance(params, dict) or any(not isinstance(v, str) for v in params.values()):
                    raise ValueError
            else:
                if any(len(values) != 1 for _, values in request.query_params.lists()):
                    raise ValueError
                params = request.query_params.dict()
                cursor = params.pop("cursor", None)
            if "page" in params or "catalog_version" in params:
                raise ValueError
            options = DiscoveryOptions({"paginated": "true", **params})
            filters = parse_filters({k: v for k, v in params.items() if k not in OPTIONS})
            if cursor is not None and (not isinstance(cursor, str) or len(cursor) > 3000):
                raise ValueError
            owner = digest(
                [
                    request.user.pk if request.user.is_authenticated else None,
                    str(request.auth or getattr(getattr(request, "session", None), "session_key", "") or ""),
                ]
            )
            query = digest([filters, options.ordering, options.origin, options.bbox, options.page_size, personal])
            claims = signing.loads(cursor, salt=SALT, max_age=900) if cursor else None
            if claims is not None and (
                not isinstance(claims, dict) or type(claims.get("offset")) is not int or claims["offset"] < 0
            ):
                raise ValueError
            if claims and (claims.get("owner") != owner or claims.get("query") != query):
                raise ValueError
        except signing.SignatureExpired:
            return Response(
                {"code": "discovery_changed", "detail": "A consulta expirou. Reinicie a busca."}, status=409
            )
        except (ValueError, TypeError, signing.BadSignature):
            raise ValidationError(
                {"code": "invalid_discovery", "detail": "Consulta inválida. Revise os critérios."}
            ) from None
        nested = connection.in_atomic_block
        with transaction.atomic():
            if connection.vendor == "postgresql" and not nested:
                # A real request reads every projection from one MVCC snapshot.
                with connection.cursor() as cursor_db:
                    cursor_db.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
            rows, version, metadata = canonical_documents(request, options, filters)
        if claims and claims.get("version") != version:
            return Response(
                {"code": "discovery_changed", "detail": "As informações mudaram. Reinicie a busca."}, status=409
            )
        ordered = rank_documents(rows, filters, options, personal)
        offset = claims["offset"] if claims else 0
        size = options.page_size

        def continuation(index):
            if index < 0 or index >= len(ordered):
                return None
            token = signing.dumps({"owner": owner, "query": query, "version": version, "offset": index}, salt=SALT)
            if request.method == "POST":
                return token
            return request.path + "?" + urlencode({**params, "cursor": token})

        return Response(
            {
                "count": len(ordered),
                "count_exact": not metadata["limited"],
                "next": continuation(offset + size),
                "previous": continuation(offset - size),
                "version": version,
                "scope": metadata,
                "results": [
                    {key: value for key, value in row.items() if key != "_discovery_rating"}
                    for row in ordered[offset:offset + size]
                ],
            }
        )


class CategoryCatalogAPIView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["Descoberta"], responses={200: CategoryCatalogSerializer})
    def get(self, request):
        return Response(CATEGORY_CATALOG)
