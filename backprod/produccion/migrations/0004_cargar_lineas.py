from django.db import migrations

def cargar_lineas(apps, schema_editor):
    # Obtenemos el modelo Linea del historial de la app 'produccion'
    Linea = apps.get_model('produccion', 'Linea')

    lineas_a_cargar = [
        {'nombre': 'L1', 'descripcion': 'Linea bombones, huevos, lingotes'},
        {'nombre': 'L2', 'descripcion': 'Linea figuras'},
        {'nombre': 'L3', 'descripcion': 'Linea banado cuchufli, bombones, alfajores'},
        {'nombre': 'L4', 'descripcion': 'Linea banado alfajores, mazapan, cuchufli'},
        {'nombre': 'OS', 'descripcion': 'Linea industrial bombones'},
        {'nombre': 'RELL', 'descripcion': 'Linea rellenos'},
        {'nombre': 'ART1', 'descripcion': 'Linea artesanias'},
        {'nombre': 'ART2', 'descripcion': 'Linea artesanias 2'},
        {'nombre': 'SAPAL', 'descripcion': 'Linea de envoltura'},
        {'nombre': 'FLOW', 'descripcion': 'Linea flowpack'},
        {'nombre': 'HOR', 'descripcion': 'Linea horneo'},
        {'nombre': 'CORTE', 'descripcion': 'Linea de cortado de rellenos'},
        {'nombre': 'MABAS', 'descripcion': 'Linea de fabricacion mazapan'},
        {'nombre': 'MAFIG', 'descripcion': 'Linea de figuras mazapan'},
        {'nombre': 'TERM', 'descripcion': 'Salas de terminacion'},
    ]

    for linea_data in lineas_a_cargar:
        Linea.objects.get_or_create(
            nombre=linea_data['nombre'],
            defaults={
                'descripcion': linea_data['descripcion'],
                'activa': True
            }
        )

def revertir_lineas(apps, schema_editor):
    """
    Elimina las líneas cargadas si se decide revertir esta migración específica.
    """
    Linea = apps.get_model('produccion', 'Linea')
    
    nombres_a_borrar = [
        'L1', 'L2', 'L3', 'L4', 'OS', 'RELL', 'ART1', 'ART2', 
        'SAPAL', 'FLOW', 'HOR', 'CORTE', 'MABAS', 'MAFIG', 'TERM'
    ]
    
    Linea.objects.filter(nombre__in=nombres_a_borrar).delete()

class Migration(migrations.Migration):

    dependencies = [
        ('produccion', '0003_cargar_tipos_eventos'),
    ]

    operations = [
        migrations.RunPython(cargar_lineas, revertir_lineas),
    ]