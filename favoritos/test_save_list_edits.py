from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from locais.models import Local

from .models import EstadoPessoalLocal, ItemLista, ListaPessoal


class SaveListEditsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model().objects
        cls.owner = users.create_user("dono-teste", email="owner@example.test")
        cls.other = users.create_user("outra-conta", email="other@example.test")
        cls.local = Local.objects.create(nome="Biblioteca", endereco="Rua Teste", distancia=0)
        cls.initial = {"nome": "Passeios", "descricao": "", "icone": "map-pin", "cor": "blue"}
        cls.changes = {"nome": "Leituras", "descricao": "Livros", "icone": "book-open", "cor": "teal"}
        cls.list_ = ListaPessoal.objects.create(user=cls.owner, **cls.initial)
        cls.foreign = ListaPessoal.objects.create(user=cls.other, **cls.initial)
        cls.favorite = ListaPessoal.objects.create(user=cls.owner, nome="Favoritos", sistema=True)
        ItemLista.objects.create(lista=cls.list_, local=cls.local)
        EstadoPessoalLocal.objects.create(user=cls.owner, local=cls.local, status="want", nota="Minha nota")

    def setUp(self):
        self.api = APIClient()
        self.api.force_authenticate(self.owner)

    def save_edit(self, *, pk=None, expected=None, data=None, new_lists=None):
        return self.api.post("/api/favoritos/listas/aplicar/", {
            "local": self.local.pk, "listas": [self.list_.pk], "novas": new_lists or [],
            "status": "want", "nota": "Minha nota",
            "esperado": {"listas": [self.list_.pk], "status": "want", "nota": "Minha nota"},
            "edicoes": [{
                "id": pk or self.list_.pk, "esperado": expected or self.initial, "dados": data or self.changes,
            }],
        }, format="json")

    def test_metadata_only_edit_persists_without_changing_membership(self):
        self.assertEqual(self.save_edit().status_code, 200)
        response = self.api.get(f"/api/favoritos/listas/{self.list_.pk}/").json()
        for field, value in self.changes.items():
            self.assertEqual(response[field], value)
        self.assertEqual(response["quantidade"], 1)
        self.assertEqual(EstadoPessoalLocal.objects.get(user=self.owner, local=self.local).nota, "Minha nota")
        layer = self.api.get(f"/api/favoritos/listas/camada/?locais={self.local.pk}").json()["results"][0]
        self.assertEqual((layer["icone"], layer["cor"]), ("book-open", "teal"))

    def test_stale_foreign_and_system_edits_are_rejected(self):
        self.assertEqual(self.save_edit(expected={**self.initial, "nome": "Obsoleto"}).status_code, 409)
        self.assertEqual(self.save_edit(pk=self.foreign.pk).status_code, 404)
        self.assertEqual(self.save_edit(pk=self.favorite.pk).status_code, 400)
        self.list_.refresh_from_db()
        self.assertEqual(self.list_.nome, "Passeios")

    def test_invalid_new_list_rolls_back_metadata_edit(self):
        self.assertEqual(self.save_edit(new_lists=[{**self.changes, "icone": "inexistente"}]).status_code, 400)
        self.list_.refresh_from_db()
        self.assertEqual(self.list_.nome, "Passeios")
