from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("modal_avaliacao", "0009_questionnaire_version_3")]

    operations = [
        migrations.AlterField(
            model_name="modalavaliacao",
            name="questionnaire_version",
            field=models.PositiveSmallIntegerField(
                choices=[(1, "Legado"), (2, "Recursos v2"), (3, "Questionário v3")],
                default=3,
            ),
        ),
    ]
