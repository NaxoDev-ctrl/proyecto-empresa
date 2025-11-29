import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/api_service.dart';

class TrazabilidadScreen extends StatefulWidget {
  final int tareaId;
  final int hojaProcesosId;

  const TrazabilidadScreen({
    super.key,
    required this.tareaId,
    required this.hojaProcesosId,
  });

  @override
  State<TrazabilidadScreen> createState() => _TrazabilidadScreenState();
}

class _TrazabilidadScreenState extends State<TrazabilidadScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _cantidadProducidaController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  // Datos de la tarea
  Map<String, dynamic>? _tarea;
  List<dynamic> _materiasPrimas = [];

  // Gestión de colaboradores
  List<Map<String, dynamic>> _colaboradoresOriginales = [];
  List<Map<String, dynamic>> _colaboradoresSeleccionados = [];
  List<Map<String, dynamic>> _todosColaboradores = [];
  
  // Datos del formulario
  Map<int, Map<String, dynamic>> _lotesMP = {}; // {materiaprima_id: {lote, cantidad, unidad}}
  List<Map<String, dynamic>> _reprocesos = [];
  List<Map<String, dynamic>> _mermas = [];
  Uint8List? _fotoEtiqueta;
  String? _nombreArchivoFoto;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadProducidaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cargar tarea con producto y receta
      final tareaData = await _apiService.getTareaDetalle(widget.tareaId);

      final todosColabs = await _apiService.getColaboradores();
      
      setState(() {
        _tarea = tareaData;
        _materiasPrimas = tareaData['producto_detalle']['materias_primas'] ?? [];

        final colaboradoresAsignados = tareaData['colaboradores_asignados'] 
          ?? tareaData['colaboradores']
          ?? tareaData['asignados']
          ?? [];

        // Inicializar colaboradores
        _colaboradoresOriginales = List<Map<String, dynamic>>.from(
          colaboradoresAsignados.map((c) {
            // Extraer codigo y garantizar que sea int
            final codigo = c['codigo'];
            final codigoInt = codigo is int ? codigo : int.parse(codigo.toString());
            
            print('   📝 Procesando: ${c['nombre']} ${c['apellido']} (codigo: $codigoInt, tipo: ${codigoInt.runtimeType})');
            
            return {
              'codigo': codigoInt,
              'nombre': c['nombre'],
              'apellido': c['apellido'],
            };
          })
        );

        // Prellenar con los colaboradores originales
        _colaboradoresSeleccionados = List<Map<String, dynamic>>.from(_colaboradoresOriginales);
      
        // Guardar todos los colaboradores disponibles
        _todosColaboradores = List<Map<String, dynamic>>.from(
          todosColabs.map((c) {
            final codigo = c['codigo'];
            final codigoInt = codigo is int ? codigo : int.parse(codigo.toString());
            
            return {
              'codigo': codigoInt,
              'nombre': c['nombre'],
              'apellido': c['apellido'],
            };
          })
        );
            
        // Inicializar mapa de lotes
        for (var mp in _materiasPrimas) {
          _lotesMP[mp['codigo'].hashCode] = {
            'materia_prima_id': mp['codigo'],
            'lote': '',
            'cantidad_usada': '',
            'unidad_medida': 'kg',
            'requiere_lote': mp['requiere_lote'],
            'nombre': mp['nombre'],
          };
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // ========================================================================
  // NUEVOS MÉTODOS: Gestión de colaboradores
  // ========================================================================

  void _eliminarColaborador(int index) {
    final colab = _colaboradoresSeleccionados[index];
    final nombreCompleto = '${colab['nombre']} ${colab['apellido']}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Eliminar Colaborador'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar a este colaborador?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.grey[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreCompleto,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Código: ${colab['codigo']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _colaboradoresSeleccionados.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Colaborador eliminado'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _agregarColaborador() async {
    // Filtrar colaboradores que ya están seleccionados
    final colaboradoresDisponibles = _todosColaboradores.where((colab) {
      return !_colaboradoresSeleccionados.any(
        (sel) => sel['codigo'] == colab['codigo']
      );
    }).toList();
    
    if (colaboradoresDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay más colaboradores disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final colaboradorSeleccionado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogSeleccionarColaborador(
        colaboradores: colaboradoresDisponibles,
      ),
    );
    
    if (colaboradorSeleccionado != null) {
      setState(() {
        _colaboradoresSeleccionados.add(colaboradorSeleccionado);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Colaborador ${colaboradorSeleccionado['nombre']} ${colaboradorSeleccionado['apellido']} agregado'
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fotoEtiqueta = bytes;
          _nombreArchivoFoto = image.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _seleccionarFotoGaleria() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fotoEtiqueta = bytes;
          _nombreArchivoFoto = image.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _agregarReproceso() {
    showDialog(
      context: context,
      builder: (context) => _DialogReproceso(
        onAgregar: (reproceso) {
          setState(() {
            _reprocesos.add(reproceso);
          });
        },
      ),
    );
  }

  void _agregarMerma() {
    showDialog(
      context: context,
      builder: (context) => _DialogMerma(
        onAgregar: (merma) {
          setState(() {
            _mermas.add(merma);
          });
        },
      ),
    );
  }

  Future<void> _guardarTrazabilidad() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ========================================================================
    // VALIDACIÓN: Verificar que haya al menos un colaborador
    // ========================================================================
    if (_colaboradoresSeleccionados.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text('Sin Colaboradores'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debe haber al menos un colaborador asignado a la trazabilidad.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Agrega al menos un colaborador que haya trabajado en esta producción',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _agregarColaborador();
              },
              icon: Icon(Icons.person_add),
              label: Text('Agregar Colaborador'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      );
      return;
    }

    // ========================================================================
    // VALIDACIÓN: Verificar que todas las materias primas tengan cantidad
    // ========================================================================
    int mpSinCantidad = 0;
    int mpSinLote = 0;
    String? primeraMPSinCantidad;
    String? primeraMPSinLote;

    for (var entry in _lotesMP.entries) {
      final mp = entry.value;
      final nombreMP = mp['nombre'] ?? mp['materia_prima_id'];

      // Verificar cantidad
      if (mp['cantidad_usada'].toString().isEmpty || 
          mp['cantidad_usada'].toString() == '0' ||
          mp['cantidad_usada'].toString() == '0.0') {
        mpSinCantidad++;
        if (primeraMPSinCantidad == null) {
          primeraMPSinCantidad = nombreMP;
        }
      }

      // Verificar lote si lo requiere
      if (mp['requiere_lote'] == true && 
          (mp['lote'] == null || mp['lote'].toString().trim().isEmpty)) {
        mpSinLote++;
        if (primeraMPSinLote == null) {
          primeraMPSinLote = nombreMP;
        }
      }
    }

    // Mostrar error si faltan cantidades
    if (mpSinCantidad > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Faltan Cantidades')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debes ingresar la cantidad usada de TODAS las materias primas.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Materias primas sin cantidad: $mpSinCantidad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    if (primeraMPSinCantidad != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Ejemplo: $primeraMPSinCantidad',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ No se puede continuar sin completar todas las cantidades.',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Mostrar error si faltan lotes
    if (mpSinLote > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Faltan Lotes')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Algunas materias primas requieren lote OBLIGATORIAMENTE.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Materias primas sin lote: $mpSinLote',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    if (primeraMPSinLote != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Ejemplo: $primeraMPSinLote',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Busca el lote en el empaque de la materia prima.',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // ========================================================================
    // VALIDACIÓN: Verificar foto
    // ========================================================================
    if (_fotoEtiqueta == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.blue, size: 32),
              SizedBox(width: 12),
              Text('Falta Foto'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debes tomar una foto de las etiquetas utilizadas en la producción.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La foto es obligatoria para la trazabilidad',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _tomarFoto();
              },
              icon: Icon(Icons.camera_alt),
              label: Text('Tomar Foto Ahora'),
            ),
          ],
        ),
      );
      return;
    }

    // ========================================================================
    // CONFIRMACIÓN FINAL CON RESUMEN
    // ========================================================================
    int mpConDatos = 0;
    _lotesMP.forEach((key, value) {
      if (value['cantidad_usada'].toString().isNotEmpty && 
          value['cantidad_usada'].toString() != '0' &&
          value['cantidad_usada'].toString() != '0.0') {
        mpConDatos++;
      }
    });

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Confirmar Trazabilidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de guardar la trazabilidad?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildResumenItem(
              Icons.production_quantity_limits,
              'Cantidad producida',
              '${_cantidadProducidaController.text} unidades',
              Colors.green,
            ),
            Divider(),
            _buildResumenItem(
              Icons.people,
              'Colaboradores',
              '${_colaboradoresSeleccionados.length}',
              Colors.indigo,
            ),
            Divider(),
            _buildResumenItem(
              Icons.inventory_2,
              'Materias primas',
              '$mpConDatos registradas',
              Colors.blue,
            ),
            if (_reprocesos.isNotEmpty) ...[
              Divider(),
              _buildResumenItem(
                Icons.replay,
                'Reprocesos',
                '${_reprocesos.length}',
                Colors.orange,
              ),
            ],
            if (_mermas.isNotEmpty) ...[
              Divider(),
              _buildResumenItem(
                Icons.delete_outline,
                'Mermas',
                '${_mermas.length}',
                Colors.red,
              ),
            ],
            Divider(),
            _buildResumenItem(
              Icons.photo_camera,
              'Foto de etiquetas',
              'Adjuntada ✓',
              Colors.purple,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.check_circle),
            label: Text('Confirmar y Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Preparar datos de materias primas
      List<Map<String, dynamic>> materiasPrimasData = [];
      
      _lotesMP.forEach((key, value) {
        if (value['cantidad_usada'].toString().isNotEmpty) {
          materiasPrimasData.add({
            'materia_prima_id': value['materia_prima_id'],
            'lote': value['lote'].isEmpty ? null : value['lote'],
            'cantidad_usada': double.parse(value['cantidad_usada']),
            'unidad_medida': value['unidad_medida'],
          });
        }
      });

      // Preparar IDs de colaboradores
      List<int> colaboradoresCodigos = [];

      for (var colab in _colaboradoresSeleccionados) {
        final codigo = colab['codigo'];
        int codigoInt;
        
        if (codigo is int) {
          codigoInt = codigo;
        } else if (codigo is String) {
          codigoInt = int.parse(codigo);
        } else {
          throw Exception('Código de colaborador inválido: $codigo (tipo: ${codigo.runtimeType})');
        }
        
        colaboradoresCodigos.add(codigoInt);
      }

      // Crear trazabilidad
      final trazabilidadData = await _apiService.crearTrazabilidad(
        hojaProcesosId: widget.hojaProcesosId,
        cantidadProducida: int.parse(_cantidadProducidaController.text),
        materiasPrimas: materiasPrimasData,
        colaboradoresCodigos: colaboradoresCodigos,
        reprocesos: _reprocesos.isNotEmpty ? _reprocesos : null,
        mermas: _mermas.isNotEmpty ? _mermas : null,
        observaciones: _observacionesController.text.isEmpty 
            ? null 
            : _observacionesController.text,
        fotoEtiquetas: _fotoEtiqueta, 
        nombreArchivoFoto: _nombreArchivoFoto,
      );

      if (!mounted) return;

      // Mostrar éxito
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Text('¡Trazabilidad Guardada!'),
            ],
          ),
          content: Text(
            'La trazabilidad se ha guardado correctamente.\n\n'
            'Ahora será revisada por el supervisor y control de calidad.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.popUntil(context, (route) => route.isFirst); // Volver al inicio
              },
              child: Text('Finalizar'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Widget helper para el resumen
  Widget _buildResumenItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Cargando trazabilidad...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al cargar'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Trazabilidad'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            final confirmar = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('⚠️ Advertencia'),
                content: Text(
                  'Si sales ahora, perderás todos los datos ingresados.\n\n'
                  '¿Estás seguro?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('Salir sin guardar'),
                  ),
                ],
              ),
            );

            if (confirmar == true && mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Info del producto
            _buildProductoInfo(),
            const SizedBox(height: 24),

            // Cantidad producida
            _buildCantidadProducida(),
            const SizedBox(height: 24),

            // Sección de colaboradores
            _buildColaboradores(),
            const SizedBox(height: 24),

            // Materias primas
            _buildMateriasPrimas(),
            const SizedBox(height: 24),

            // Reprocesos
            _buildReprocesos(),
            const SizedBox(height: 24),

            // Mermas
            _buildMermas(),
            const SizedBox(height: 24),

            // Foto de etiquetas
            _buildFotoEtiquetas(),
            const SizedBox(height: 24),

            // Observaciones
            _buildObservaciones(),
            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _guardarTrazabilidad,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.save, size: 28),
                label: Text(
                  _isSaving ? 'GUARDANDO...' : 'GUARDAR TRAZABILIDAD',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRODUCTO',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tarea!['producto_detalle']['nombre'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Código: ${_tarea!['producto_detalle']['codigo']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('Meta: ${_tarea!['meta_produccion']} unidades'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCantidadProducida() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CANTIDAD PRODUCIDA *',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cantidadProducidaController,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: 'unidades',
                prefixIcon: Icon(Icons.production_quantity_limits),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa la cantidad producida';
                }
                if (int.tryParse(value) == null) {
                  return 'Ingresa un número válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColaboradores() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'COLABORADORES',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: _agregarColaborador,
                  icon: Icon(Icons.person_add, size: 18),
                  label: Text('Agregar'),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Indica quiénes trabajaron realmente en esta producción',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_colaboradoresSeleccionados.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.person_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No hay colaboradores asignados',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _agregarColaborador,
                        icon: Icon(Icons.person_add),
                        label: Text('Agregar Colaborador'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._colaboradoresSeleccionados.asMap().entries.map((entry) {
                final index = entry.key;
                final colab = entry.value;
                final nombreCompleto = '${colab['nombre']} ${colab['apellido']}';
                
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        colab['nombre'].toString()[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      nombreCompleto,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Código: ${colab['codigo']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarColaborador(index),
                      tooltip: 'Eliminar',
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriasPrimas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MATERIAS PRIMAS',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (_materiasPrimas.isEmpty)
              Center(
                child: Text(
                  'No hay materias primas definidas',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._materiasPrimas.map((mp) {
                final key = mp['codigo'].hashCode;
                return _buildMateriaPrimaItem(mp, key);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriaPrimaItem(Map<String, dynamic> mp, int key) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mp['nombre'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (mp['requiere_lote'])
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Requiere Lote',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Código: ${mp['codigo']}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (mp['requiere_lote'])
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Lote',
                hintText: 'Ej: LOT12345',
                isDense: true,
              ),
              onChanged: (value) {
                _lotesMP[key]!['lote'] = value;
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _lotesMP[key]!['cantidad_usada'] = value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _lotesMP[key]!['unidad_medida'],
                  decoration: InputDecoration(
                    labelText: 'Unidad',
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'unidades', child: Text('unidades')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _lotesMP[key]!['unidad_medida'] = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReprocesos() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'REPROCESOS (Opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _agregarReproceso,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
              ],
            ),
            if (_reprocesos.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay reprocesos registrados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._reprocesos.asMap().entries.map((entry) {
                final index = entry.key;
                final reproceso = entry.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${reproceso['cantidad_kg']} kg'),
                  subtitle: Text(reproceso['descripcion']),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _reprocesos.removeAt(index);
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMermas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MERMAS (Opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _agregarMerma,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
              ],
            ),
            if (_mermas.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay mermas registradas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._mermas.asMap().entries.map((entry) {
                final index = entry.key;
                final merma = entry.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${merma['cantidad_kg']} kg'),
                  subtitle: Text(merma['descripcion']),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _mermas.removeAt(index);
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFotoEtiquetas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOTO DE ETIQUETAS *',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (_fotoEtiqueta == null)
              Column(
                children: [
                  Text(
                    'Debes tomar una foto de las etiquetas utilizadas',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Tomar Foto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _seleccionarFotoGaleria,
                          icon: Icon(Icons.photo_library),
                          label: Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _fotoEtiqueta!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.refresh),
                          label: Text('Tomar otra'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _fotoEtiqueta = null;
                            });
                          },
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text('Eliminar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservaciones() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OBSERVACIONES (Opcional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacionesController,
              decoration: InputDecoration(
                hintText: 'Escribe observaciones adicionales...',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG: Seleccionar Colaborador
// ============================================================================
class _DialogSeleccionarColaborador extends StatefulWidget {
  final List<Map<String, dynamic>> colaboradores;

  const _DialogSeleccionarColaborador({
    required this.colaboradores,
  });

  @override
  State<_DialogSeleccionarColaborador> createState() => 
      _DialogSeleccionarColaboradorState();
}

class _DialogSeleccionarColaboradorState 
    extends State<_DialogSeleccionarColaborador> {
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _colaboradoresFiltrados = [];

  @override
  void initState() {
    super.initState();
    _colaboradoresFiltrados = widget.colaboradores;
    _searchController.addListener(_filtrarColaboradores);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarColaboradores() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _colaboradoresFiltrados = widget.colaboradores;
      } else {
        _colaboradoresFiltrados = widget.colaboradores.where((colab) {
          final nombreCompleto = 
              '${colab['nombre']} ${colab['apellido']}'.toLowerCase();
          
          // ✅ Convertir codigo a String para búsqueda
          final codigoStr = colab['codigo'].toString();
          
          return codigoStr.contains(query) || nombreCompleto.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Seleccionar Colaborador')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Campo de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              autofocus: false,
            ),
            const SizedBox(height: 16),
            
            // Contador de resultados
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_colaboradoresFiltrados.length} resultado(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            
            // Lista de colaboradores filtrados
            Expanded(
              child: _colaboradoresFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No se encontraron colaboradores',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Intenta con otro término de búsqueda',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _colaboradoresFiltrados.length,
                      itemBuilder: (context, index) {
                        final colab = _colaboradoresFiltrados[index];
                        final nombreCompleto = 
                            '${colab['nombre']} ${colab['apellido']}';
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Text(
                                colab['nombre'].toString()[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              nombreCompleto,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text('Código: ${colab['codigo']}'),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () => Navigator.pop(context, colab),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOG: Agregar Reproceso
// ============================================================================
class _DialogReproceso extends StatefulWidget {
  final Function(Map<String, dynamic>) onAgregar;

  const _DialogReproceso({required this.onAgregar});

  @override
  State<_DialogReproceso> createState() => _DialogReprocesoState();
}

class _DialogReprocesoState extends State<_DialogReproceso> {
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _cantidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar Reproceso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _cantidadController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descripcionController,
            decoration: InputDecoration(
              labelText: 'Descripción',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_cantidadController.text.isEmpty || 
                _descripcionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Completa todos los campos')),
              );
              return;
            }

            widget.onAgregar({
              'cantidad_kg': double.parse(_cantidadController.text),
              'descripcion': _descripcionController.text,
            });

            Navigator.pop(context);
          },
          child: Text('Agregar'),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOG: Agregar Merma
// ============================================================================
class _DialogMerma extends StatefulWidget {
  final Function(Map<String, dynamic>) onAgregar;

  const _DialogMerma({required this.onAgregar});

  @override
  State<_DialogMerma> createState() => _DialogMermaState();
}

class _DialogMermaState extends State<_DialogMerma> {
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _cantidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar Merma'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _cantidadController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descripcionController,
            decoration: InputDecoration(
              labelText: 'Descripción',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_cantidadController.text.isEmpty || 
                _descripcionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Completa todos los campos')),
              );
              return;
            }

            widget.onAgregar({
              'cantidad_kg': double.parse(_cantidadController.text),
              'descripcion': _descripcionController.text,
            });

            Navigator.pop(context);
          },
          child: Text('Agregar'),
        ),
      ],
    );
  }
}