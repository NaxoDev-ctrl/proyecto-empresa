from django.db import migrations
from datetime import time # Necesario para definir objetos time para los TimeField


def cargar_turnos(apps, schema_editor):
    """
    Carga los turnos de trabajo predefinidos (AM, Jornada, PM).
    """
    # Obtenemos el modelo Turno de la aplicación 'produccion'
    Turno = apps.get_model('produccion', 'Turno')

    # Datos a cargar: usamos objetos time de datetime para los campos TimeField
    turnos_a_cargar = [
        {
            'nombre': 'AM',
            'hora_inicio': time(6, 15, 0),  # 06:15:00
            'hora_fin': time(13, 35, 0),  # 13:35:00
        },
        {
            'nombre': 'Jornada',
            'hora_inicio': time(8, 0, 0),   # 08:00:00
            'hora_fin': time(17, 30, 0),  # 17:30:00
        },
        {
            'nombre': 'PM',
            'hora_inicio': time(13, 25, 0), # 13:25:00
            'hora_fin': time(22, 5, 0),   # 22:05:00
        },
    ]

    for turno_data in turnos_a_cargar:
        # Usamos get_or_create para asegurar que solo se creen si no existen,
        # utilizando el campo 'nombre' como clave única.
        Turno.objects.get_or_create(
            nombre=turno_data['nombre'],
            defaults={
                'hora_inicio': turno_data['hora_inicio'],
                'hora_fin': turno_data['hora_fin'],
                'activo': True # Por defecto están activos
            }
        )


def revertir_turnos(apps, schema_editor):
    """
    Elimina los turnos cargados si se revierte la migración.
    """
    Turno = apps.get_model('produccion', 'Turno')

    # Lista de nombres de los turnos a eliminar
    nombres_turnos = ['AM', 'Jornada', 'PM']

    # Eliminamos todos los turnos que coincidan con estos nombres
    Turno.objects.filter(nombre__in=nombres_turnos).delete()


class Migration(migrations.Migration):

    dependencies = [
        # Asegúrate de que esta dependencia apunte a la migración anterior de tu app
        ('produccion', '0006_alter_colaborador_codigo'),
    ]

    operations = [
        # Ejecutamos las funciones para cargar y revertir los datos
        migrations.RunPython(cargar_turnos, revertir_turnos),
    ]