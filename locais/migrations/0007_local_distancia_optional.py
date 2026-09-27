from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('locais', '0006_local_guia_visita')]
    operations = [migrations.AlterField(
        model_name='local', name='distancia',
        field=models.FloatField(null=True, blank=True, default=None),
    )]
