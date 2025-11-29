# Si codigo era CharField y lo cambias a IntegerField:
# produccion/migrations/XXXX_cambiar_codigo_a_int.py

from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [
        ('produccion', '0004_alter_trazabilidadcolaborador_options_and_more'),
    ]
    
    operations = [
        migrations.AlterField(
            model_name='colaborador',
            name='codigo',
            field=models.IntegerField(unique=True),
        ),
    ]