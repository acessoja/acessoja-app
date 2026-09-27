from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('locais', '0005_alter_local_imagem')]

    operations = [
        migrations.AddField(
            model_name='local', name='guia_visita',
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AlterField(
            model_name='local', name='aberto',
            field=models.BooleanField(blank=True, default=None, null=True),
        ),
    ]
