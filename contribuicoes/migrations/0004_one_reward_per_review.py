from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("contribuicoes", "0003_report_reward"),
    ]

    operations = [
        migrations.RemoveConstraint(
            model_name="reportrewardattribution",
            name="one_report_reward_per_user_local_action",
        ),
        migrations.AddConstraint(
            model_name="reportrewardattribution",
            constraint=models.UniqueConstraint(
                fields=("review",),
                name="one_report_reward_per_review",
            ),
        ),
        migrations.AddConstraint(
            model_name="reportrewardattribution",
            constraint=models.UniqueConstraint(
                fields=("beneficiary", "local", "action"),
                name="one_report_reward_per_user_local_action",
            ),
        ),
    ]
