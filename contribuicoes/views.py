import math

from django.db.models import Count, Q
from drf_spectacular.utils import extend_schema
from rest_framework.generics import GenericAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from locais.models import Local
from locais.serializers import LocalSerializer
from modal_avaliacao.models import ModalAvaliacao
from modal_avaliacao.serializers import ModalAvaliacaoSerializer
from .models import PointActivity
from .serializers import (
    AchievementSerializer,
    ActivitySerializer,
    DiscoveryPlaceSerializer,
    DiscoveryQuerySerializer,
    ImpactSerializer,
)
from .services import achievement_data, impact


class ContributionPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class ContributionView(GenericAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = ContributionPagination

    def page(self, values):
        return self.get_paginated_response(self.paginate_queryset(values))


class ImpactView(ContributionView):
    serializer_class = ImpactSerializer

    @extend_schema(tags=["Contribuições"], responses={200: ImpactSerializer})
    def get(self, request):
        return Response(impact(request.user))


class AchievementView(ContributionView):
    serializer_class = AchievementSerializer
    pagination_class = None

    @extend_schema(tags=["Contribuições"], responses={200: AchievementSerializer(many=True)})
    def get(self, request):
        return Response(achievement_data(request.user))


class MyReviewsView(ContributionView):
    serializer_class = ModalAvaliacaoSerializer

    @extend_schema(tags=["Contribuições"], responses=ModalAvaliacaoSerializer(many=True))
    def get(self, request):
        reviews = ModalAvaliacao.objects.filter(user=request.user, is_current=True).select_related("user", "local")
        page = self.paginate_queryset(reviews.order_by("-data_resposta", "-pk"))
        return self.get_paginated_response(ModalAvaliacaoSerializer(page, many=True, context={"request": request}).data)


class CommunityView(MyReviewsView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["Contribuições"], responses=ModalAvaliacaoSerializer(many=True))
    def get(self, request):
        reviews = ModalAvaliacao.objects.filter(
            is_current=True, is_valid=True, user__perfil_publico=True, user__mostrar_avaliacoes=True
        ).select_related("user", "local")
        page = self.paginate_queryset(reviews.order_by("-data_resposta", "-pk"))
        return self.get_paginated_response(ModalAvaliacaoSerializer(page, many=True, context={"request": request}).data)


class ActivityView(ContributionView):
    serializer_class = ActivitySerializer

    @extend_schema(tags=["Contribuições"], responses=ActivitySerializer(many=True))
    def get(self, request):
        qs = PointActivity.objects.filter(event__user=request.user).select_related("event__local")
        rows = self.paginate_queryset(qs)
        return self.get_paginated_response(
            [
                {
                    "id": row.pk,
                    "delta": row.delta,
                    "action": row.event.action,
                    "created_at": row.created_at,
                    "evaluation_id": row.event.evaluation_id,
                    "local": {"id_local": row.event.local_id, "nome": row.event.local.nome},
                }
                for row in rows
            ]
        )


class DiscoveryView(ContributionView):
    serializer_class = DiscoveryPlaceSerializer

    @extend_schema(
        tags=["Contribuições"],
        parameters=[DiscoveryQuerySerializer],
        responses={200: DiscoveryPlaceSerializer(many=True)},
    )
    def get(self, request):
        params = DiscoveryQuerySerializer(data=request.query_params)
        params.is_valid(raise_exception=True)
        data = params.validated_data
        qs = Local.objects.annotate(
            review_total=Count("avaliacoes", filter=Q(avaliacoes__is_current=True, avaliacoes__is_valid=True))
        )
        if data.get("search"):
            qs = qs.filter(Q(nome__icontains=data["search"]) | Q(endereco__icontains=data["search"]))
        if data.get("categoria"):
            qs = qs.filter(categoria=data["categoria"])
        state = data.get("estado", "all")
        if state == "unreviewed":
            qs = qs.filter(review_total=0)
        if state == "visited":
            qs = qs.filter(visitas__user=request.user, visitas__arrival_confirmed=True).distinct()
        # Bound candidates and response. External places are fetched through the
        # existing proxy only on explicit discovery, then registered before review.
        if "latitude" in data:
            lat, lon = data["latitude"], data["longitude"]
            margin = data["raio"] / 111000
            lon_margin = margin / max(0.01, math.cos(math.radians(lat)))
            qs = qs.filter(
                latitude__range=(lat - margin, lat + margin), longitude__range=(lon - lon_margin, lon + lon_margin)
            )
        places = list(qs.order_by("review_total", "pk")[:500])

        def distance(place):
            lat1, lat2 = math.radians(data["latitude"]), math.radians(place.latitude)
            dlat, dlon = lat2 - lat1, math.radians(place.longitude - data["longitude"])
            a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
            return 6371000 * 2 * math.asin(min(1, math.sqrt(a)))

        if "latitude" in data:
            places = [p for p in places if distance(p) <= data["raio"]]
            places.sort(key=lambda p: (p.review_total, distance(p), p.pk))
        # Four survey answers need contributions; legacy false flags mean unknown.
        if state == "incomplete":
            places = [
                p
                for p in places
                if p.review_total == 0
                or p.avaliacoes.filter(is_current=True, is_valid=True)
                .filter(
                    Q(survey_completed=False)
                    | Q(pergunta_1="Não sei")
                    | Q(pergunta_2="Não sei")
                    | Q(pergunta_3="Não sei")
                    | Q(pergunta_4="Não sei")
                )
                .exists()
            ]
        page = self.paginate_queryset(places)
        rows = LocalSerializer(page, many=True).data
        if "latitude" in data:
            for place, row in zip(page, rows):
                row["distance_meters"] = round(distance(place))
        return self.get_paginated_response(rows)
