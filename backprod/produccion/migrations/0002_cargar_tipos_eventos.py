# Generated manually

from django.db import migrations


def cargar_tipos_eventos(apps, schema_editor):
    """
    Carga los 11 tipos de eventos predefinidos.
    """
    TipoEvento = apps.get_model('produccion', 'TipoEvento')
    
    tipos_eventos = [
        {
            'nombre': 'Setup Inicial',
            'codigo': 'SETUP_INICIAL',
            'descripcion': 'Preparación inicial de la línea antes de comenzar la producción',
            'orden': 1
        },
        {
            'nombre': 'Templado',
            'codigo': 'TEMPLADO',
            'descripcion': 'Proceso de templado del chocolate',
            'orden': 2
        },
        {
            'nombre': 'Falta de Materia Prima',
            'codigo': 'FALTA_MATERIA_PRIMA',
            'descripcion': 'Detención por falta de materia prima',
            'orden': 3
        },
        {
            'nombre': 'Cambio y Limpieza',
            'codigo': 'CAMBIO_LIMPIEZA',
            'descripcion': 'Tiempo dedicado a cambio de producto y limpieza de línea',
            'orden': 4
        },
        {
            'nombre': 'Falla Máquina',
            'codigo': 'FALLA_MAQUINA',
            'descripcion': 'Detención por falla o avería de máquina',
            'orden': 5
        },
        {
            'nombre': 'Producción',
            'codigo': 'PRODUCCION',
            'descripcion': 'Tiempo efectivo de producción',
            'orden': 6
        },
        {
            'nombre': 'Factores Externos',
            'codigo': 'FACTORES_EXTERNOS',
            'descripcion': 'Detención por factores externos (corte de luz, etc.)',
            'orden': 7
        },
        {
            'nombre': 'Falta Personal',
            'codigo': 'FALTA_PERSONAL',
            'descripcion': 'Detención por falta de personal',
            'orden': 8
        },
        {
            'nombre': 'Colación',
            'codigo': 'COLACION',
            'descripcion': 'Tiempo de colación del personal',
            'orden': 9
        },
        {
            'nombre': 'Setup Final',
            'codigo': 'SETUP_FINAL',
            'descripcion': 'Cierre y limpieza final de la línea',
            'orden': 10
        },
        {
            'nombre': 'Otro',
            'codigo': 'OTRO',
            'descripcion': 'Otros eventos no contemplados en las categorías anteriores',
            'orden': 11
        },
    ]
    
    for tipo_data in tipos_eventos:
        TipoEvento.objects.get_or_create(
            codigo=tipo_data['codigo'],
            defaults={
                'nombre': tipo_data['nombre'],
                'descripcion': tipo_data['descripcion'],
                'orden': tipo_data['orden'],
                'activo': True
            }
        )


def revertir_tipos_eventos(apps, schema_editor):
    """
    Elimina los tipos de eventos si se revierte la migración.
    """
    TipoEvento = apps.get_model('produccion', 'TipoEvento')
    
    codigos = [
        'SETUP_INICIAL', 'TEMPLADO', 'FALTA_MATERIA_PRIMA',
        'CAMBIO_LIMPIEZA', 'FALLA_MAQUINA', 'PRODUCCION',
        'FACTORES_EXTERNOS', 'FALTA_PERSONAL', 'COLACION',
        'SETUP_FINAL', 'OTRO'
    ]
    
    TipoEvento.objects.filter(codigo__in=codigos).delete()
    


class Migration(migrations.Migration):

    dependencies = [
        ('produccion', '0001_initial'),  # Ajusta esto al nombre de tu última migración
    ]

    operations = [
        migrations.RunPython(cargar_tipos_eventos, revertir_tipos_eventos),
    ]