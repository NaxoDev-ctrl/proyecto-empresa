from django.db import migrations


def cargar_lineas(apps, schema_editor):
    """
    Carga las líneas de producción L1, L2, L3 y L4.
    """
    # Obtenemos el modelo Linea de la aplicación 'produccion'
    Linea = apps.get_model('produccion', 'Linea')

    # Datos a cargar
    lineas_a_cargar = [
        {
            'nombre': 'L1',
            'descripcion': 'Línea de producción principal 1 para productos sólidos.',
        },
        {
            'nombre': 'L2',
            'descripcion': 'Línea de producción 2, enfocada en productos con relleno.',
        },
        {
            'nombre': 'L3',
            'descripcion': 'Línea de producción 3, utilizada para productos estacionales.',
        },
        {
            'nombre': 'L4',
            'descripcion': 'Línea de producción 4, utilizada como respaldo o para prototipos.',
        },
    ]

    for linea_data in lineas_a_cargar:
        # Usamos get_or_create para asegurar que solo se creen si no existen,
        # utilizando el campo 'nombre' como clave única.
        Linea.objects.get_or_create(
            nombre=linea_data['nombre'],
            defaults={
                'descripcion': linea_data['descripcion'],
                'activa': True  # Por defecto, todas las líneas están activas
            }
        )


def revertir_lineas(apps, schema_editor):
    """
    Elimina las líneas cargadas si se revierte la migración.
    """
    Linea = apps.get_model('produccion', 'Linea')

    # Lista de nombres de las líneas a eliminar
    nombres_lineas = ['L1', 'L2', 'L3', 'L4']

    # Eliminamos todas las líneas que coincidan con estos nombres
    Linea.objects.filter(nombre__in=nombres_lineas).delete()


class Migration(migrations.Migration):

    dependencies = [
        # Asegúrate de que esta dependencia apunte a la migración anterior
        ('produccion', '0007_cargar_turnos'),
    ]

    operations = [
        # Ejecutamos las funciones para cargar y revertir los datos
        migrations.RunPython(cargar_lineas, revertir_lineas),
    ]