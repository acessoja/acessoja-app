import unicodedata

from django.db import transaction
from django.utils.decorators import method_decorator
from django.views.decorators.cache import never_cache
from django.views.decorators.vary import vary_on_headers
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from acessoja.api_schema import ErroSerializer
from locais.models import Local
from .models import Favorito
from .serializers import FavoriteCreateSerializer, FavoriteSerializer, FavoriteStatesSerializer, favorite_context


def search_key(value):
    value = " ".join(value.split()).casefold()
    return "".join(c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c))


class FavoritePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50

    def get_paginated_response(self, data):
        response = super().get_paginated_response(data)
        response.data["total"] = self.total_favorites
        return response

    def get_paginated_response_schema(self, schema):
        result = super().get_paginated_response_schema(schema)
        result["properties"]["total"] = {"type": "integer", "minimum": 0}
        result["required"].append("total")
        return result


@method_decorator(never_cache, name="dispatch")
@method_decorator(vary_on_headers("Authorization", "Cookie"), name="dispatch")
@extend_schema(tags=["Favoritos"])
class FavoritoViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = FavoriteSerializer
    pagination_class = FavoritePagination
    lookup_value_regex = "[1-9][0-9]*"

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Favorito.objects.none()
        return Favorito.objects.filter(user=self.request.user).select_related("local").order_by("-criado_em", "-id")

    def _query(self, allowed):
        if set(self.request.query_params) - set(allowed):
            raise ValidationError("Parâmetro não permitido; o proprietário é definido pela sessão.")

    def _serialize(self, rows, *, many=False):
        rows = list(rows) if many else [rows]
        context = favorite_context([row.local for row in rows], self.get_serializer_context())
        return FavoriteSerializer(rows if many else rows[0], many=many, context=context).data

    @extend_schema(
        summary="Consultar os próprios favoritos",
        description="Busca por nome/endereço somente nos favoritos da sessão. count é o resultado da busca; "
                    "total é o total privado da conta. Páginas de 20, máximo 50, data decrescente e ID como desempate.",
        parameters=[OpenApiParameter("q", str), OpenApiParameter("page_size", int)],
    )
    def list(self, request, *args, **kwargs):
        self._query({"page", "page_size", "q"})
        if len(request.query_params.get("q", "")) > 180:
            raise ValidationError({"q": "Use até 180 caracteres."})
        if "page_size" in request.query_params:
            raw = request.query_params["page_size"]
            if not raw.isascii() or not raw.isdigit() or int(raw) < 1:
                raise ValidationError({"page_size": "Informe um inteiro positivo."})
        qs = self.get_queryset()
        total = qs.count()
        query = search_key(request.query_params.get("q", ""))
        if query:
            # Portable accent-insensitive matching without a PostgreSQL extension or
            # stale duplicated name fields. Scan only this owner's lightweight rows.
            matched = [pk for pk, name, address in qs.values_list("pk", "local__nome", "local__endereco").iterator()
                       if query in search_key(f"{name} {address}")]
            qs = qs.filter(pk__in=matched)
        page = self.paginate_queryset(qs)
        self.paginator.total_favorites = total
        return self.get_paginated_response(self._serialize(page, many=True))

    @extend_schema(summary="Consultar um favorito próprio")
    def retrieve(self, request, *args, **kwargs):
        self._query(set())
        return Response(self._serialize(self.get_object()))

    @extend_schema(
        summary="Adicionar um favorito privado sem duplicação",
        request=FavoriteCreateSerializer,
        responses={200: FavoriteSerializer, 201: FavoriteSerializer, 400: ErroSerializer, 401: ErroSerializer},
    )
    def create(self, request, *args, **kwargs):
        self._query(set())
        serializer = FavoriteCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            try:
                local = Local.objects.select_for_update().get(pk=serializer.validated_data["local"].pk)
            except Local.DoesNotExist:
                raise NotFound("Local não encontrado.") from None
            favorite, created = Favorito.objects.get_or_create(user=request.user, local=local)
        return Response(self._serialize(favorite), status=201 if created else 200)

    @extend_schema(
        summary="Remover somente a relação de favorito",
        description="204 também quando a relação já não existe ou não pertence à sessão, sem revelar outra conta.",
        request=None, responses={204: None, 401: ErroSerializer},
    )
    def destroy(self, request, *args, **kwargs):
        self._query(set())
        if request.data:
            raise ValidationError("A remoção não aceita proprietário ou dados no corpo.")
        self.get_queryset().filter(pk=kwargs["pk"]).delete()
        return Response(status=204)

    @extend_schema(
        summary="Consultar em lote o estado privado de locais visíveis",
        parameters=[OpenApiParameter("locais", str, required=True,
                                     description="Até 100 IDs internos separados por vírgula.")],
        responses={200: FavoriteStatesSerializer, 400: ErroSerializer, 401: ErroSerializer},
    )
    @action(detail=False, methods=["get"], pagination_class=None)
    def estado(self, request):
        self._query({"locais"})
        raw = request.query_params.get("locais", "").split(",")
        if not 1 <= len(raw) <= 100 or any(
            not s.isascii() or not s.isdigit() or int(s) < 1 for s in raw
        ):
            raise ValidationError({"locais": "Informe de 1 a 100 IDs internos positivos."})
        ids = list(dict.fromkeys(int(s) for s in raw))
        existing = set(Local.objects.filter(pk__in=ids).values_list("pk", flat=True))
        saved = dict(Favorito.objects.filter(user=request.user, local_id__in=ids).values_list("local_id", "pk"))
        return Response({"results": [{"local": pk, "id": saved.get(pk), "exists": pk in existing} for pk in ids]})
