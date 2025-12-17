from django.db import migrations
from datetime import time 


def cargar_turnos(apps, schema_editor):
    Turno = apps.get_model('produccion', 'Turno')

    turnos_a_cargar = [
        {
            'nombre': 'AM',
            'hora_inicio': time(6, 15, 0),
            'hora_fin': time(13, 35, 0),
        },
        {
            'nombre': 'Jornada',
            'hora_inicio': time(8, 0, 0),
            'hora_fin': time(17, 30, 0),
        },
        {
            'nombre': 'PM',
            'hora_inicio': time(13, 25, 0),
            'hora_fin': time(22, 5, 0),
        },
    ]

    for turno_data in turnos_a_cargar:
        Turno.objects.get_or_create(
            nombre=turno_data['nombre'],
            defaults={
                'hora_inicio': turno_data['hora_inicio'],
                'hora_fin': turno_data['hora_fin'],
                'activo': True
            }
        )


def revertir_turnos(apps, schema_editor):
    """
    Elimina los turnos cargados si se revierte la migración.
    """
    Turno = apps.get_model('produccion', 'Turno')

    nombres_turnos = ['AM', 'Jornada', 'PM']

    Turno.objects.filter(nombre__in=nombres_turnos).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('produccion', '0004_cargar_lineas'),
    ]

    operations = [
        migrations.RunPython(cargar_turnos, revertir_turnos),
    ]