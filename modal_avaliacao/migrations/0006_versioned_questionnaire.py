from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("modal_avaliacao", "0005_modalavaliacao_survey_completed")]
    operations = [
        migrations.AddField(
            model_name="modalavaliacao", name="questionnaire_version",
            field=models.PositiveSmallIntegerField(default=1, choices=[(1, "Legado"), (2, "Recursos")]),
        ),
        migrations.AddField(model_name="modalavaliacao", name="answers", field=models.JSONField(default=dict, blank=True)),
        migrations.AddField(
            model_name="modalavaliacao", name="answer_dates", field=models.JSONField(default=dict, blank=True),
        ),
        *[
            migrations.AlterField(
                model_name="modalavaliacao", name=f"pergunta_{i}",
                field=models.CharField(
                    blank=True, max_length=20,
                    choices=[("Sim", "Sim"), ("Não", "Não"), ("Não sei", "Não sei"), ("Não se aplica", "Não se aplica")],
                ),
            )
            for i in range(1, 5)
        ],
    ]
