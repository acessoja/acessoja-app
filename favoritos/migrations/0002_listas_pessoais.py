from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def migrate_favorites_to_default_list(apps, schema_editor):
    User = apps.get_model(settings.AUTH_USER_MODEL.split('.')[0], settings.AUTH_USER_MODEL.split('.')[1])
    Lista = apps.get_model("favoritos", "ListaPessoal")
    Item = apps.get_model("favoritos", "ItemLista")
    Favorito = apps.get_model("favoritos", "Favorito")
    for user in User.objects.all().iterator():
        lista = Lista.objects.create(user=user, nome="Favoritos", icone="favorite", cor="red", sistema=True)
        Item.objects.bulk_create(
            [Item(lista=lista, local_id=local_id) for local_id in Favorito.objects.filter(user_id=user.pk)
             .values_list("local_id", flat=True)],
            ignore_conflicts=True,
        )


class Migration(migrations.Migration):
    dependencies = [("favoritos", "0001_initial")]
    operations = [
        migrations.CreateModel(
            name="ListaPessoal",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("nome", models.CharField(max_length=80)),
                ("descricao", models.CharField(blank=True, max_length=240)),
                ("icone", models.CharField(choices=[("favorite", "Favoritos"), ("flag", "Quero visitar"), ("star", "Estrela"), ("restaurant", "Talheres"), ("shopping_bag", "Sacola"), ("luggage", "Mala"), ("home", "Casa"), ("menu_book", "Livro"), ("coffee", "Café"), ("park", "Árvore"), ("local_hospital", "Hospital"), ("music_note", "Música"), ("photo_camera", "Câmera"), ("place", "Marcador"), ("check", "Visitado")], default="favorite", max_length=24)),
                ("cor", models.CharField(choices=[("blue", "Azul"), ("teal", "Verde-azulado"), ("orange", "Laranja"), ("purple", "Roxo"), ("red", "Vermelho"), ("green", "Verde")], default="blue", max_length=16)),
                ("sistema", models.BooleanField(default=False)),
                ("visivel_mapa", models.BooleanField(default=True)),
                ("ordem", models.PositiveIntegerField(default=0)),
                ("criado_em", models.DateTimeField(auto_now_add=True)),
                ("atualizado_em", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="listas_pessoais", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["ordem", "nome", "id"], "constraints": [models.UniqueConstraint(fields=("user", "nome"), name="lista_pessoal_owner_name_unique")]},
        ),
        migrations.CreateModel(
            name="EstadoPessoalLocal",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("status", models.CharField(choices=[("unknown", "Não informado"), ("want", "Quero visitar"), ("visited", "Já visitei")], default="unknown", max_length=12)),
                ("nota", models.TextField(blank=True, max_length=1000)),
                ("atualizado_em", models.DateTimeField(auto_now=True)),
                ("local", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="estados_pessoais", to="locais.local")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="estados_locais", to=settings.AUTH_USER_MODEL)),
            ],
            options={"constraints": [models.UniqueConstraint(fields=("user", "local"), name="estado_pessoal_owner_local_unique")], "indexes": [models.Index(fields=["user", "status"], name="estado_pessoal_owner_status")]},
        ),
        migrations.CreateModel(
            name="ItemLista",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("criado_em", models.DateTimeField(auto_now_add=True)),
                ("lista", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="itens", to="favoritos.listapessoal")),
                ("local", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="itens_listas", to="locais.local")),
            ],
            options={"ordering": ["-criado_em", "-id"], "constraints": [models.UniqueConstraint(fields=("lista", "local"), name="item_lista_unique")]},
        ),
        migrations.RunPython(migrate_favorites_to_default_list, migrations.RunPython.noop),
    ]
