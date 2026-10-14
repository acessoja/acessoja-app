from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("usuarios", "0003_usuario_is_active_usuario_is_staff_and_more")]
    operations = [migrations.AddField(
        model_name="usuario", name="accessibility_preferences", field=models.JSONField(default=list, blank=True),
    )]
