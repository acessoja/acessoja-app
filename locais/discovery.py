"""Opt-in pagination, after evidence filters and deterministic global ordering."""

import math

from rest_framework.pagination import PageNumberPagination

from .services.matching import distance_m, normalize

OPTIONS = {"paginated", "page", "page_size", "ordering", "origin_lat", "origin_lon", "bbox"}


def valid_coordinates(lat, lon):
    return (
        isinstance(lat, (int, float))
        and not isinstance(lat, bool)
        and isinstance(lon, (int, float))
        and not isinstance(lon, bool)
        and math.isfinite(lat)
        and math.isfinite(lon)
        and abs(lat) <= 90
        and abs(lon) <= 180
    )


class DiscoveryOptions:
    def __init__(self, params):
        self.paginated = params.get("paginated", "false")
        if self.paginated not in ("true", "false"):
            raise ValueError("paginated: use true ou false.")
        self.paginated = self.paginated == "true"
        self.page_size = self.positive(params.get("page_size", "20"), 50)
        self.positive(params.get("page", "1"), None)
        self.ordering = params.get("ordering", "name" if self.paginated else "legacy")
        if self.ordering not in ("name", "proximity", "rating") and not (
            self.ordering == "legacy" and "ordering" not in params
        ):
            raise ValueError("ordering: use name, proximity ou rating.")
        self.origin = None
        if "origin_lat" in params or "origin_lon" in params:
            try:
                self.origin = (float(params["origin_lat"]), float(params["origin_lon"]))
            except (ValueError, KeyError, TypeError):
                raise ValueError("Origem exige latitude e longitude válidas.") from None
            if not valid_coordinates(*self.origin):
                raise ValueError("Origem inválida.")
        if self.ordering == "proximity" and self.origin is None:
            raise ValueError("Proximidade exige origem explícita.")
        self.bbox = None
        if "bbox" in params:
            try:
                self.bbox = tuple(float(x) for x in params["bbox"].split(","))
                south, west, north, east = self.bbox
            except (ValueError, TypeError):
                raise ValueError("bbox: sul,oeste,norte,leste.") from None
            if not valid_coordinates(south, west) or not valid_coordinates(north, east) or south > north:
                raise ValueError("Área inválida.")

    @staticmethod
    def positive(value, maximum):
        if not isinstance(value, str) or not value.isdecimal() or not 1 <= int(value):
            raise ValueError("Página e tamanho devem ser inteiros positivos.")
        result = int(value)
        if maximum is not None and result > maximum:
            raise ValueError("Tamanho máximo: 50.")
        return result

    def contains(self, local):
        if self.bbox is None:
            return True
        if not valid_coordinates(local.latitude, local.longitude):
            return False
        south, west, north, east = self.bbox
        return south <= local.latitude <= north and (
            west <= local.longitude <= east if west <= east else local.longitude >= west or local.longitude <= east
        )

    def order(self, rows, context):
        request = context.get("request")
        user = getattr(request, "user", None)
        own = user.pk if user and user.is_authenticated else None

        def key(local):
            tail = (normalize(local.nome), local.pk)
            if self.ordering == "proximity":
                meters = (
                    distance_m(*self.origin, local.latitude, local.longitude)
                    if valid_coordinates(local.latitude, local.longitude)
                    else math.inf
                )
                return (meters, *tail)
            if self.ordering == "rating":
                stats = context["visible_review_stats"][(local.pk, own)]
                return (-(stats["average"] or 0), -stats["count"], *tail)
            return (local.pk,) if self.ordering == "legacy" else tail

        return sorted(rows, key=key)

    def response(self, rows, request, serializer):
        if not self.paginated:
            from rest_framework.response import Response

            return Response(serializer(rows))
        paginator = PageNumberPagination()
        paginator.page_size = self.page_size
        page = paginator.paginate_queryset(rows, request)
        return paginator.get_paginated_response(serializer(page))
