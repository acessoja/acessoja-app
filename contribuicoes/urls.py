from django.urls import path
from .views import AchievementView, ActivityView, CommunityView, DiscoveryView, ImpactView, MyReviewsView

urlpatterns = [
    path("meu-impacto/", ImpactView.as_view()),
    path("minhas-avaliacoes/", MyReviewsView.as_view()),
    path("conquistas/", AchievementView.as_view()),
    path("atividade/", ActivityView.as_view()),
    path("comunidade/", CommunityView.as_view()),
    path("locais-para-avaliar/", DiscoveryView.as_view()),
]
