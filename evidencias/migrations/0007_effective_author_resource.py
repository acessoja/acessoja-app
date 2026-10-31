from datetime import datetime, timezone
from django.db import migrations, models


def choose_latest(apps, schema_editor):
    Evidence = apps.get_model("evidencias", "ResourceEvidence")
    rows = (
        Evidence.objects.using(schema_editor.connection.alias)
        .filter(
            source="user",
            owner__isnull=False,
            local__isnull=False,
            kind__in=["review", "observation"],
        )
        .select_related("current_revision")
    )
    heads = {}
    minimum = datetime.min.replace(tzinfo=timezone.utc)
    for row in rows.iterator(chunk_size=500):
        key = row.owner_id, row.local_id, row.resource
        stamp = (row.current_revision.received_at if row.current_revision_id else None) or minimum, str(row.pk)
        if key not in heads or stamp > heads[key][0]:
            heads[key] = stamp, row.pk
    # Include tombstones and invalid revisions in precedence, never invent dates.
    rows.update(superseded=True)
    Evidence.objects.using(schema_editor.connection.alias).filter(pk__in=[item[1] for item in heads.values()]).update(
        superseded=False
    )


class Migration(migrations.Migration):
    dependencies = [("evidencias", "0006_resourceevidence_superseded_evidenceoperation")]
    operations = [
        migrations.RunPython(choose_latest, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="resourceevidence",
            constraint=models.UniqueConstraint(
                fields=["owner", "local", "resource"],
                name="one_effective_author_resource",
                condition=models.Q(
                    superseded=False,
                    owner__isnull=False,
                    local__isnull=False,
                    kind__in=["review", "observation"],
                    source="user",
                ),
            ),
        ),
    ]
