from django.urls import path
from . import views

urlpatterns = [
    path("evidencias/", views.EvidenceListView.as_view(), name="evidence-list"),
    path("evidencias/<uuid:evidence_id>/", views.EvidenceDetailView.as_view(), name="evidence-detail"),
    path(
        "evidencias/<uuid:evidence_id>/confirmar/",
        views.EvidenceConfirmView.as_view(),
        name="evidence-confirm",
    ),
    path(
        "evidencias/<uuid:evidence_id>/alterar/", views.EvidenceChangeView.as_view(), name="evidence-change"
    ),
    path(
        "evidencias/<uuid:evidence_id>/historico/",
        views.EvidenceHistoryView.as_view(),
        name="evidence-history",
    ),
    path(
        "evidencias/avaliacoes/<int:review_id>/historico/",
        views.ReviewHistoryView.as_view(),
        name="review-history",
    ),
    path("denuncias/", views.ReportListCreateView.as_view(), name="own-reports"),
    path("denuncias/<uuid:protocol>/", views.OwnReportDetailView.as_view(), name="own-report-detail"),
    path("revisoes-solicitadas/", views.OwnRevisionRequestsView.as_view(), name="own-revision-requests"),
]
