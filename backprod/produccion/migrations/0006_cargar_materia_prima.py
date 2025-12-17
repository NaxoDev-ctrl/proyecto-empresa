from django.db import migrations

def cargar_materias_primas(apps, schema_editor):
    # Obtenemos el modelo MateriaPrima del historial de la app 'produccion'
    MateriaPrima = apps.get_model('produccion', 'MateriaPrima')

    # Lista de datos a cargar basada en tu requerimiento
    # Formato: (codigo, nombre, unidad_medida, requiere_lote)
    materias_primas_data = [
        ('CJA0001', 'CAJA ALFAJORES 273 X 215 X 230 PADRON 40', 'UN', False),
        ('CJA0007', 'CAJA CONEJO N2 390 X 280 X 160', 'UN', False),
        ('CJA0008', 'CAJA CONEJO N4 390 X 280 X 300', 'UN', False),
        ('CJA0010', 'CAJA PERRO 220 X 180 X 210', 'UN', False),
        ('CJA0012', 'CAJA 1K 175 X 122 X 100', 'UN', False),
        ('CJA0014', 'CAJA 2.5 245 X 175 X 100', 'UN', False),
        ('CJA0017', 'CAJA MASTER EXPORTACION 415 X 210 X 230', 'UN', False),
        ('COB0010', 'COB. BLANCA BARRY CALLEBAUT', 'KG', True),
        ('COB0032', 'COB. BITTER 80% LUKER MAPALÉ', 'KG', True),
        ('COB0038', 'COB. LECHE 40% LUKER NOCHE', 'KG', True),
        ('COB0041', 'COB. S/A BITTER 58% LUKER CUMBRE', 'KG', True),
        ('COB0042', 'COB. S/A LECHE 37% LUKER MULATA', 'KG', True),
        ('COB0043', 'COB. S/A BLANCO LUKER COCORA', 'KG', True),
        ('COB0048', 'COB. BLANCA LUKER GLACIAR', 'KG', True),
        ('COB0049', 'COB. BITTER 60% LUKER MACONDO', 'KG', True),
        ('COB0051', 'COB. LECHE 35% LUKER LYRA', 'KG', True),
        ('LAC0055', 'MANJAR', 'KG', True),
        ('LAC0162', 'MANJAR SIN AZUCAR', 'KG', True),
        ('GAP0001', 'GALLETA HORNEADA CON AZUCAR', 'KG', True),
        ('GAP0002', 'GALLETA HORNEADA SIN AZUCAR', 'KG', True),
        ('REL0150', 'RELLENO TRUFA AL WHISKY', 'KG', True),
        ('REL0154', 'RELLENO TRUFA AL RON', 'KG', True),
        ('REL0205', 'RELLENO B. SHOT DE CAFE', 'KG', True),
        ('REL0206', 'RELLENO B. PIE DE LIMON', 'KG', True),
        ('REL0208', 'RELLENO B. ALFAJOR', 'KG', True),
        ('REL0211', 'RELLENO B. SELVA DE MANJAR', 'KG', True),
        ('REL0405', 'RELLENO VAINAS CUCHUFLI', 'KG', True),
        ('REL0411', 'RELLENO ALFAJOR NARANJA', 'KG', True),
        ('TKC0001', 'COBERTURA TANQUE LECHE', 'KG', True),
        ('TKC0002', 'COBERTURA TANQUE BITTER', 'KG', True),
        ('TKC0003', 'COBERTURA TANQUE BLANCA', 'KG', True),
        ('TKC0004', 'COBERTURA TANQUE BITTER S/A', 'KG', True),
        ('TKC0005', 'COBERTURA TANQUE LECHE S/A', 'KG', True),
        ('TKC0006', 'COBERTURA TANQUE BLANCA S/A', 'KG', True),
    ]

    for codigo, nombre, unidad, lote in materias_primas_data:
        MateriaPrima.objects.get_or_create(
            codigo=codigo,
            defaults={
                'nombre': nombre,
                'unidad_medida': unidad,
                'requiere_lote': lote,
                'activo': True
            }
        )

def revertir_materias_primas(apps, schema_editor):
    """
    Elimina los registros cargados por esta migración en caso de rollback.
    """
    MateriaPrima = apps.get_model('produccion', 'MateriaPrima')
    
    # Extraemos solo los códigos para el filtrado masivo
    codigos_a_borrar = [
        'CJA0001', 'CJA0007', 'CJA0008', 'CJA0010', 'CJA0012', 'CJA0014', 
        'CJA0017', 'COB0010', 'COB0032', 'COB0038', 'COB0041', 'COB0042', 
        'COB0043', 'COB0048', 'COB0049', 'COB0051', 'LAC0055', 'LAC0162', 
        'GAP0001', 'GAP0002', 'REL0150', 'REL0154', 'REL0205', 'REL0206', 
        'REL0208', 'REL0211', 'REL0405', 'REL0411', 'TKC0001', 'TKC0002', 
        'TKC0003', 'TKC0004', 'TKC0005', 'TKC0006'
    ]
    
    MateriaPrima.objects.filter(codigo__in=codigos_a_borrar).delete()

class Migration(migrations.Migration):

    dependencies = [
        ('produccion', '0005_cargar_turnos'),
    ]

    operations = [
        migrations.RunPython(cargar_materias_primas, revertir_materias_primas),
    ]