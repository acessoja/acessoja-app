from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("locais", "0007_visitarecente_arrival_confirmed")]
    operations = [migrations.AddField(
        model_name="local", name="accessibility_information", field=models.JSONField(default=dict, blank=True),
    )]
