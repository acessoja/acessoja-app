import uuid

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.contrib.staticfiles import finders
from django.test import Client, TestCase
from django.urls import reverse

from locais.models import Local
from midia.models import ImageAsset, ImageDecision, PhotoRevision, ReviewPhoto
from modal_avaliacao.models import ModalAvaliacao

from .models import ContentReport, ModerationDecision


class ModerationPresentationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model().objects
        cls.moderator = users.create_user("moderador-teste", email="mod@example.test", is_staff=True)
        cls.moderator.user_permissions.add(
            Permission.objects.get(content_type__app_label="evidencias", codename="moderate_content")
        )
        cls.staff = users.create_user("staff-teste", email="staff@example.test", is_staff=True)
        author = users.create_user("autor-teste", email="author@example.test")
        cls.local = Local.objects.create(nome="Biblioteca de teste", endereco="Rua Teste", distancia=0)
        cls.review = ModalAvaliacao.objects.create(user=author, local=cls.local, estrelas=4)
        asset = ImageAsset.objects.create(purpose="photo", owner=author, state="ready")
        cls.photo = ReviewPhoto.objects.create(review=cls.review, owner=author)
        revision = PhotoRevision.objects.create(
            photo=cls.photo, owner=author, asset=asset, description="Entrada da biblioteca"
        )
        cls.photo.current_revision = revision
        cls.photo.save(update_fields=["current_revision"])
        cls.report = ContentReport.objects.create(
            target_kind="review", target_key=f"review:{cls.review.pk}", target_revision=cls.review.content_revision,
            review_revision_id=cls.review.content_revision, reason="outdated", state="closed",
        )

    def test_default_admin_routes_use_new_templates_and_live_records(self):
        self.client.force_login(self.moderator)
        for name, args, caption in (
            ("index", [], "Fila de moderação"),
            ("evidencias_contentreport_changelist", [], "Biblioteca de teste"),
            ("midia_reviewphoto_changelist", [], "Biblioteca de teste"),
            ("evidence-report-decision", [self.report.pk], "Comparação das informações"),
            ("image-photo-decision", [self.photo.pk], "Entrada da biblioteca"),
            ("evidencias_moderationdecision_changelist", [], "Histórico de denúncias"),
            ("midia_imagedecision_changelist", [], "Histórico de fotos"),
        ):
            with self.subTest(route=name):
                response = self.client.get(reverse(f"admin:{name}", args=args))
                self.assertContains(response, caption)
                self.assertTemplateUsed(response, "admin/moderation/base.html")
        for model_name, pk, decision in (
            ("evidencias_contentreport", self.report.pk, "evidence-report-decision"),
            ("midia_reviewphoto", self.photo.pk, "image-photo-decision"),
        ):
            self.assertRedirects(self.client.get(
                reverse(f"admin:{model_name}_change", args=[pk])
            ), reverse(f"admin:{decision}", args=[pk]))
        self.assertIsNotNone(finders.find("evidencias/moderation.css"))
        self.assertEqual(ContentReport.objects.count(), 1)
        self.assertEqual(ReviewPhoto.objects.count(), 1)
        self.assertEqual(ModalAvaliacao.objects.count(), 1)

    def test_search_dashboard_counts_and_filters_match_live_data(self):
        self.client.force_login(self.moderator)
        dashboard = self.client.get(reverse("admin:index"))
        self.assertEqual({card["state"]: card["total"] for card in dashboard.context["state_cards"]}, {
            "pending": 0, "reviewing": 0, "revision_requested": 0, "closed": 1,
        })
        self.assertContains(self.client.get(
            reverse("admin:evidencias_contentreport_changelist"), {"q": "Biblioteca", "state__exact": "closed"}
        ), str(self.report.pk))
        self.assertNotContains(self.client.get(
            reverse("admin:evidencias_contentreport_changelist"), {"state__exact": "pending"}
        ), str(self.report.pk))

    def test_permissions_and_csrf_still_apply(self):
        route = reverse("admin:evidencias_contentreport_changelist")
        anonymous = self.client.get(route)
        self.assertEqual(anonymous.status_code, 302)
        self.assertTemplateUsed(self.client.get(anonymous.url), "admin/moderation/login.html")
        self.client.force_login(self.staff)
        self.assertNotContains(self.client.get(reverse("admin:index")), str(self.report.pk))
        self.assertEqual(self.client.get(route).status_code, 403)
        secure_client = Client(enforce_csrf_checks=True)
        secure_client.force_login(self.moderator)
        self.assertEqual(secure_client.post(
            reverse("admin:evidence-report-decision", args=[self.report.pk]), {}
        ).status_code, 403)
        self.assertEqual(ModerationDecision.objects.count(), 0)

    def test_decision_forms_keep_existing_services_and_history(self):
        self.client.force_login(self.moderator)
        self.report.state = "pending"
        self.report.save(update_fields=["state"])
        report_url = reverse("admin:evidence-report-decision", args=[self.report.pk])
        self.assertRedirects(self.client.post(report_url, {
            "action": "keep", "reason": "A análise confirmou o conteúdo da avaliação.",
            "expected_version": self.report.version, "expected_target_revision": self.report.target_revision,
            "operation_id": uuid.uuid4(),
        }), report_url)
        self.assertEqual(ModerationDecision.objects.filter(report=self.report).count(), 1)

        photo_url = reverse("admin:image-photo-decision", args=[self.photo.pk])
        revision = self.photo.current_revision
        self.assertRedirects(self.client.post(photo_url, {
            "action": "approve", "reason": "A imagem corresponde ao local indicado.",
            "revision_id": revision.pk, "expected_version": revision.moderation_version,
            "operation_id": uuid.uuid4(),
        }), photo_url)
        self.assertEqual(ImageDecision.objects.filter(revision=revision).count(), 1)
