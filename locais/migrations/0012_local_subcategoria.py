from django.db import migrations, models

RULES = [
    ("restaurante", "restaurante", {"amenity": "restaurant"}),
    ("lanchonete", "restaurante", {"amenity": "fast_food"}),
    ("cafeteria", "cafeteria", {"amenity": "cafe"}),
    ("supermercado", "supermercado", {"shop": "supermarket"}),
    ("conveniencia", "supermercado", {"shop": "convenience"}),
    ("farmacia", "farmacia", {"amenity": "pharmacy"}),
    ("hospital", "saude", {"amenity": "hospital"}),
    ("clinica", "saude", {"amenity": "clinic"}),
    ("consultorio", "saude", {"amenity": "doctors"}),
    ("escola", "educacao", {"amenity": "school"}),
    ("universidade", "educacao", {"amenity": "university"}),
    ("roupas", "loja", {"shop": "clothes"}),
    ("centro_comercial", "loja", {"shop": "mall"}),
    ("parque", "parque", {"leisure": "park"}),
    ("playground", "parque", {"leisure": "playground"}),
    ("banco", "banco", {"amenity": "bank"}),
    ("prefeitura", "publico", {"amenity": "townhall"}),
    ("orgao_governamental", "publico", {"office": "government"}),
    ("biblioteca", "outros", {"amenity": "library"}),
    ("cinema", "outros", {"amenity": "cinema"}),
    ("teatro", "outros", {"amenity": "theatre"}),
    ("centro_comunitario", "outros", {"amenity": "community_centre"}),
]


def backfill(apps, schema_editor):
    Local = apps.get_model("locais", "Local")
    Entry = apps.get_model("locais", "CatalogEntry")
    Scope = apps.get_model("locais", "CatalogScope")
    alias = schema_editor.connection.alias
    editions = Entry.objects.using(alias).filter(
        batch_id__in=Scope.objects.using(alias).values("active_batch_id"), source_status="available"
    )
    by_id, by_osm = {}, {}
    for entry in editions.select_related("poi").iterator():
        candidates = [
            (key, parent) for key, parent, tags in RULES if all(entry.tags.get(k) == v for k, v in tags.items())
        ]
        child = candidates[0] if len(candidates) == 1 else None
        if entry.poi.local_id:
            by_id.setdefault(entry.poi.local_id, set()).add(child)
        by_osm.setdefault(entry.poi.external_id, set()).add(child)
    for local in Local.objects.using(alias).all().iterator():
        candidates = by_id.get(local.pk, set()) | by_osm.get(local.osm_id, set())
        if len(candidates) == 1:
            value = candidates.pop()
            if value and value[1] == local.categoria:
                Local.objects.using(alias).filter(pk=local.pk).update(subcategoria=value[0])


class Migration(migrations.Migration):
    dependencies = [("locais", "0011_municipal_catalog")]
    operations = [
        migrations.AddField(
            model_name="local",
            name="subcategoria",
            field=models.CharField(blank=True, default="", max_length=32, db_index=True),
        ),
        migrations.RunPython(backfill, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="local",
            constraint=models.CheckConstraint(
                condition=models.Q(subcategoria="")
                | (
                    models.Q(categoria="restaurante", subcategoria="restaurante")
                    | models.Q(categoria="restaurante", subcategoria="lanchonete")
                    | models.Q(categoria="cafeteria", subcategoria="cafeteria")
                    | models.Q(categoria="supermercado", subcategoria="supermercado")
                    | models.Q(categoria="supermercado", subcategoria="conveniencia")
                    | models.Q(categoria="farmacia", subcategoria="farmacia")
                    | models.Q(categoria="saude", subcategoria="hospital")
                    | models.Q(categoria="saude", subcategoria="clinica")
                    | models.Q(categoria="saude", subcategoria="consultorio")
                    | models.Q(categoria="educacao", subcategoria="escola")
                    | models.Q(categoria="educacao", subcategoria="universidade")
                    | models.Q(categoria="loja", subcategoria="roupas")
                    | models.Q(categoria="loja", subcategoria="centro_comercial")
                    | models.Q(categoria="parque", subcategoria="parque")
                    | models.Q(categoria="parque", subcategoria="playground")
                    | models.Q(categoria="banco", subcategoria="banco")
                    | models.Q(categoria="publico", subcategoria="prefeitura")
                    | models.Q(categoria="publico", subcategoria="orgao_governamental")
                    | models.Q(categoria="outros", subcategoria="biblioteca")
                    | models.Q(categoria="outros", subcategoria="cinema")
                    | models.Q(categoria="outros", subcategoria="teatro")
                    | models.Q(categoria="outros", subcategoria="centro_comunitario")
                ),
                name="local_category_child_pair",
            ),
        ),
    ]
