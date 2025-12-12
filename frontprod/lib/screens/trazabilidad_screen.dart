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
  
  // Controllers principales
  final _cantidadProducidaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _codigoColaboradorLoteController = TextEditingController();
  
  // Datos de la tarea
  Map<String, dynamic>? _tarea;
  
  // ========================================================================
  // LISTAS DE TODAS LAS MATERIAS PRIMAS Y COLABORADORES DISPONIBLES
  // ========================================================================
  List<Map<String, dynamic>> _todasMateriasPrimasDisponibles = [];
  List<Map<String, dynamic>> _todosColaboradores = [];

  // ========================================================================
  // MATERIAS PRIMAS SELECCIONADAS (pueden agregarse/eliminarse)
  // ========================================================================
  List<String> _materiasPrimasSeleccionadas = []; // Lista de códigos
  
  // Gestión de colaboradores seleccionados
  List<Map<String, dynamic>> _colaboradoresSeleccionados = [];
  
  // ========================================================================
  // DATOS Y CONTROLLERS POR MATERIA PRIMA
  // ========================================================================
  Map<String, Map<String, dynamic>> _datosMateriasPrimas = {};
  Map<String, TextEditingController> _loteControllers = {};
  Map<String, TextEditingController> _consumoControllers = {};
  Map<String, TextEditingController> _reprocesoControllers = {};
  Map<String, TextEditingController> _mermaControllers = {};
  
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
    _codigoColaboradorLoteController.dispose();
    
    _loteControllers.values.forEach((c) => c.dispose());
    _consumoControllers.values.forEach((c) => c.dispose());
    _reprocesoControllers.values.forEach((c) => c.dispose());
    _mermaControllers.values.forEach((c) => c.dispose());
    
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tareaData = await _apiService.getTareaDetalle(widget.tareaId);
      final todosColabs = await _apiService.getColaboradores();
      
      // ========================================================================
      // CARGAR TODAS LAS MATERIAS PRIMAS DISPONIBLES EN EL SISTEMA
      // ========================================================================
      final todasMPData = await _apiService.getMateriasPrimas(); // Necesitas crear este método
      
      setState(() {
        _tarea = tareaData;
        
        // Guardar TODAS las materias primas disponibles
        _todasMateriasPrimasDisponibles = List<Map<String, dynamic>>.from(
          todasMPData.map((mp) => {
            'codigo': mp['codigo'],
            'nombre': mp['nombre'],
            'unidad_medida': mp['unidad_medida'] ?? 'kg',
            'requiere_lote': mp['requiere_lote'] ?? false,
          })
        );

        // Colaboradores
        final colaboradoresAsignados = tareaData['colaboradores_asignados'] 
          ?? tareaData['colaboradores'] 
          ?? [];

        _colaboradoresSeleccionados = List<Map<String, dynamic>>.from(
          colaboradoresAsignados.map((c) {
            final codigo = c['codigo'];
            final codigoInt = codigo is int ? codigo : int.parse(codigo.toString());
            
            return {
              'codigo': codigoInt,
              'nombre': c['nombre'],
              'apellido': c['apellido'],
            };
          })
        );
      
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
        
        // ========================================================================
        // INICIALIZAR CON MATERIAS PRIMAS DE LA RECETA (pero editables)
        // ========================================================================
        final materiasPrimasReceta = tareaData['producto_detalle']['materias_primas'] ?? [];
        
        for (var mp in materiasPrimasReceta) {
          final codigo = mp['codigo'].toString();
          _agregarMateriaPrimaInterna(
            codigo: codigo,
            nombre: mp['nombre'],
            unidadMedida: mp['unidad_medida'] ?? 'kg',
            requiereLote: mp['requiere_lote'],
          );
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
  // AGREGAR MATERIA PRIMA (método interno)
  // ========================================================================
  void _agregarMateriaPrimaInterna({
    required String codigo,
    required String nombre,
    required String unidadMedida,
    required bool requiereLote,
  }) {
    // Evitar duplicados
    if (_materiasPrimasSeleccionadas.contains(codigo)) {
      return;
    }
    
    _materiasPrimasSeleccionadas.add(codigo);
    
    // Crear controllers
    _loteControllers[codigo] = TextEditingController();
    _consumoControllers[codigo] = TextEditingController();
    _reprocesoControllers[codigo] = TextEditingController(text: '0');
    _mermaControllers[codigo] = TextEditingController(text: '0');
    
    // Guardar datos
    _datosMateriasPrimas[codigo] = {
      'materia_prima_id': codigo,
      'nombre': nombre,
      'unidad_medida': unidadMedida,
      'requiere_lote': requiereLote,
    };
  }

  // ========================================================================
  // AGREGAR MATERIA PRIMA (desde diálogo)
  // ========================================================================
  Future<void> _agregarMateriaPrima() async {
    // Filtrar materias primas que ya están seleccionadas
    final mpDisponibles = _todasMateriasPrimasDisponibles.where((mp) {
      return !_materiasPrimasSeleccionadas.contains(mp['codigo']);
    }).toList();
    
    if (mpDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay más materias primas disponibles para agregar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final mpSeleccionada = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogSeleccionarMateriaPrima(
        materiasPrimas: mpDisponibles,
      ),
    );
    
    if (mpSeleccionada != null) {
      setState(() {
        _agregarMateriaPrimaInterna(
          codigo: mpSeleccionada['codigo'],
          nombre: mpSeleccionada['nombre'],
          unidadMedida: mpSeleccionada['unidad_medida'],
          requiereLote: mpSeleccionada['requiere_lote'],
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mpSeleccionada['nombre']} agregada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ========================================================================
  // ELIMINAR MATERIA PRIMA
  // ========================================================================
  void _eliminarMateriaPrima(String codigo) {
    final mp = _datosMateriasPrimas[codigo];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Eliminar Materia Prima'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar "${mp!['nombre']}"?\n\n'
          'Se perderán todos los datos ingresados para esta materia prima.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Eliminar de la lista
                _materiasPrimasSeleccionadas.remove(codigo);
                
                // Limpiar datos y controllers
                _datosMateriasPrimas.remove(codigo);
                _loteControllers[codigo]?.dispose();
                _consumoControllers[codigo]?.dispose();
                _reprocesoControllers[codigo]?.dispose();
                _mermaControllers[codigo]?.dispose();
                
                _loteControllers.remove(codigo);
                _consumoControllers.remove(codigo);
                _reprocesoControllers.remove(codigo);
                _mermaControllers.remove(codigo);
              });
              
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Materia prima eliminada'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // GESTIÓN DE COLABORADORES (sin cambios)
  // ========================================================================
  
  void _eliminarColaborador(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Colaborador'),
        content: Text('¿Estás seguro?'),
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _agregarColaborador() async {
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
    }
  }

  // ========================================================================
  // FOTO
  // ========================================================================
  
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

  // ========================================================================
  // GUARDAR TRAZABILIDAD
  // ========================================================================
  
  Future<void> _guardarTrazabilidad() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar colaboradores
    if (_colaboradoresSeleccionados.isEmpty) {
      _mostrarError('Debe haber al menos un colaborador');
      return;
    }

    // Validar que haya al menos una materia prima
    if (_materiasPrimasSeleccionadas.isEmpty) {
      _mostrarError('Debe haber al menos una materia prima registrada');
      return;
    }

    // Validar código para lote
    if (_codigoColaboradorLoteController.text.trim().isEmpty) {
      _mostrarError('Ingresa el código del colaborador para el lote');
      return;
    }

    // Validar foto
    if (_fotoEtiqueta == null) {
      _mostrarError('Debes tomar una foto de las etiquetas');
      return;
    }

    // ========================================================================
    // CONSTRUIR DATOS DE MATERIAS PRIMAS CON REPROCESOS Y MERMAS
    // ========================================================================
    List<Map<String, dynamic>> materiasPrimasData = [];
    
    for (String codigo in _materiasPrimasSeleccionadas) {
      final mp = _datosMateriasPrimas[codigo]!;
      
      final consumo = _consumoControllers[codigo]!.text.trim();
      
      // Validar que tenga cantidad
      if (consumo.isEmpty || consumo == '0') {
        _mostrarError('Completa la cantidad de ${mp['nombre']}');
        return;
      }

      // Validar lote si lo requiere
      if (mp['requiere_lote'] == true) {
        final lote = _loteControllers[codigo]!.text.trim();
        if (lote.isEmpty) {
          _mostrarError('${mp['nombre']} requiere lote');
          return;
        }
      }

      // Construir datos de esta materia prima
      Map<String, dynamic> mpData = {
        'materia_prima_id': codigo,
        'lote': _loteControllers[codigo]!.text.trim(),
        'cantidad_usada': double.parse(consumo),
        'unidad_medida': mp['unidad_medida'],
      };

      // Agregar reprocesos si tiene
      final reprocesoText = _reprocesoControllers[codigo]!.text.trim();
      if (reprocesoText.isNotEmpty && reprocesoText != '0') {
        final cantidad = double.tryParse(reprocesoText);
        if (cantidad != null && cantidad > 0) {
          mpData['reprocesos'] = [
            {
              'cantidad': cantidad,
              'causas': 'error_operador',
            }
          ];
        }
      }

      // Agregar mermas si tiene
      final mermaText = _mermaControllers[codigo]!.text.trim();
      if (mermaText.isNotEmpty && mermaText != '0') {
        final cantidad = double.tryParse(mermaText);
        if (cantidad != null && cantidad > 0) {
          mpData['mermas'] = [
            {
              'cantidad': cantidad,
              'causas': 'desperdicio_corte',
            }
          ];
        }
      }

      materiasPrimasData.add(mpData);
    }

    // Mostrar confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Trazabilidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Guardar la trazabilidad con:'),
            SizedBox(height: 12),
            Text('• Cantidad: ${_cantidadProducidaController.text} unidades'),
            Text('• Colaboradores: ${_colaboradoresSeleccionados.length}'),
            Text('• Materias primas: ${materiasPrimasData.length}'),
            Text('• Foto: Adjuntada'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      List<int> colaboradoresCodigos = _colaboradoresSeleccionados
          .map((c) => c['codigo'] as int)
          .toList();

      await _apiService.crearTrazabilidad(
        hojaProcesosId: widget.hojaProcesosId,
        cantidadProducida: int.parse(_cantidadProducidaController.text),
        materiasPrimas: materiasPrimasData,
        colaboradoresCodigos: colaboradoresCodigos,
        observaciones: _observacionesController.text.isEmpty 
            ? null 
            : _observacionesController.text,
        fotoEtiquetas: _fotoEtiqueta,
        nombreArchivoFoto: _nombreArchivoFoto,
        codigoColaboradorLote: _codigoColaboradorLoteController.text.trim(),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('¡Éxito!'),
            ],
          ),
          content: Text('Trazabilidad guardada correctamente'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text('Finalizar'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ========================================================================
  // BUILD UI
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
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
              SizedBox(height: 16),
              Text('Error al cargar'),
              SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Registro Trazabilidad'),
        backgroundColor: Colors.indigo,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildEncabezado(),
            SizedBox(height: 24),
            _buildTablaColaboradores(),
            SizedBox(height: 24),
            _buildTablaMateriales(), // 🔥 ACTUALIZADA
            SizedBox(height: 24),
            _buildSeccionFoto(),
            SizedBox(height: 24),
            _buildCodigoLote(),
            SizedBox(height: 24),
            _buildObservaciones(),
            SizedBox(height: 32),
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
                  backgroundColor: Colors.green,
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

  // ========================================================================
  // WIDGETS DE SECCIONES (Encabezado sin cambios)
  // ========================================================================

  Widget _buildEncabezado() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'REGISTRO TRAZABILIDAD',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('F. ELAB.', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_tarea!['fecha'] ?? ''),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JULIANO:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Auto'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TURNO:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_tarea!['turno_detalle']['nombre'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text('LOTE:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('(Se generará al guardar)'),
            
            Divider(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        _tarea!['producto_detalle']['codigo'],
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(
                        _tarea!['producto_detalle']['nombre'],
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UdM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('UN'),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_tarea!['meta_produccion'].toString()),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REAL *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextFormField(
                        controller: _cantidadProducidaController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablaColaboradores() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COLABORADORES',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.person_add, color: Colors.blue),
                  onPressed: _agregarColaborador,
                  tooltip: 'Agregar',
                ),
              ],
            ),
            Divider(),
            
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('NOMBRE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ..._colaboradoresSeleccionados.asMap().entries.map((entry) {
                  final index = entry.key;
                  final colab = entry.value;
                  return TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(colab['codigo'].toString()),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${colab['nombre']} ${colab['apellido']}'),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _eliminarColaborador(index),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                ...List.generate(4 - _colaboradoresSeleccionados.length, (i) {
                  return TableRow(
                    children: [
                      Padding(padding: EdgeInsets.all(8), child: Text('')),
                      Padding(padding: EdgeInsets.all(8), child: Text('')),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // 🔥 TABLA DE MATERIALES CON BOTÓN AGREGAR Y ELIMINAR
  // ========================================================================
  
  Widget _buildTablaMateriales() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MATERIALES',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.add_box, color: Colors.green),
                  onPressed: _agregarMateriaPrima,
                  tooltip: 'Agregar Materia Prima',
                ),
              ],
            ),
            Divider(),
            
            // Mensaje si no hay materias primas
            if (_materiasPrimasSeleccionadas.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No hay materias primas registradas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _agregarMateriaPrima,
                        icon: Icon(Icons.add),
                        label: Text('Agregar Primera Materia Prima'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: Colors.black, width: 1),
                  defaultColumnWidth: IntrinsicColumnWidth(),
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        _buildHeaderCell(''),
                        _buildHeaderCell('CÓDIGO'),
                        _buildHeaderCell('DESCRIPCIÓN'),
                        _buildHeaderCell('UdM'),
                        _buildHeaderCell('LOTE'),
                        _buildHeaderCell('CONSUMO'),
                        _buildHeaderCell('REPROCESO'),
                        _buildHeaderCell('MERMA'),
                      ],
                    ),
                    // Filas de materias primas
                    ..._materiasPrimasSeleccionadas.map((codigo) {
                      final mp = _datosMateriasPrimas[codigo]!;
                      
                      return TableRow(
                        children: [
                          // 🔥 COLUMNA DE ELIMINAR
                          _buildDataCell(
                            IconButton(
                              icon: Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _eliminarMateriaPrima(codigo),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              tooltip: 'Eliminar',
                            ),
                          ),
                          _buildDataCell(Text(codigo)),
                          _buildDataCell(Text(mp['nombre'])),
                          _buildDataCell(Text(mp['unidad_medida'])),
                          _buildDataCell(
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: _loteControllers[codigo],
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          _buildDataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _consumoControllers[codigo],
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          _buildDataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _reprocesoControllers[codigo],
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          _buildDataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _mermaControllers[codigo],
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(Widget child) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: child,
    );
  }

  // Resto de widgets sin cambios...
  
  Widget _buildSeccionFoto() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOTO DE ETIQUETAS *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Divider(),
            
            if (_fotoEtiqueta == null)
              Column(
                children: [
                  Text('Debes tomar una foto de las etiquetas'),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Cámara'),
                        ),
                      ),
                      SizedBox(width: 8),
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.refresh),
                          label: Text('Cambiar'),
                        ),
                      ),
                      SizedBox(width: 8),
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

  Widget _buildCodigoLote() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CÓDIGO COLABORADOR LOTE *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Divider(),
            TextFormField(
              controller: _codigoColaboradorLoteController,
              decoration: InputDecoration(
                labelText: 'Código del colaborador a cargo',
                hintText: 'Ej: 96',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Requerido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservaciones() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OBSERVACIONES',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Divider(),
            TextFormField(
              controller: _observacionesController,
              decoration: InputDecoration(
                hintText: 'Observaciones adicionales...',
                border: OutlineInputBorder(),
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
// DIÁLOGOS
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
          final codigoStr = colab['codigo'].toString();
          
          return codigoStr.contains(query) || nombreCompleto.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seleccionar Colaborador'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: _colaboradoresFiltrados.isEmpty
                  ? Center(child: Text('No se encontraron colaboradores'))
                  : ListView.builder(
                      itemCount: _colaboradoresFiltrados.length,
                      itemBuilder: (context, index) {
                        final colab = _colaboradoresFiltrados[index];
                        return ListTile(
                          title: Text('${colab['nombre']} ${colab['apellido']}'),
                          subtitle: Text('Código: ${colab['codigo']}'),
                          onTap: () => Navigator.pop(context, colab),
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
// 🔥 NUEVO DIÁLOGO: Seleccionar Materia Prima
// ============================================================================

class _DialogSeleccionarMateriaPrima extends StatefulWidget {
  final List<Map<String, dynamic>> materiasPrimas;

  const _DialogSeleccionarMateriaPrima({
    required this.materiasPrimas,
  });

  @override
  State<_DialogSeleccionarMateriaPrima> createState() => 
      _DialogSeleccionarMateriaPrimaState();
}

class _DialogSeleccionarMateriaPrimaState 
    extends State<_DialogSeleccionarMateriaPrima> {
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _materiasFiltradas = [];

  @override
  void initState() {
    super.initState();
    _materiasFiltradas = widget.materiasPrimas;
    _searchController.addListener(_filtrarMaterias);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarMaterias() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _materiasFiltradas = widget.materiasPrimas;
      } else {
        _materiasFiltradas = widget.materiasPrimas.where((mp) {
          final codigo = mp['codigo'].toString().toLowerCase();
          final nombre = mp['nombre'].toString().toLowerCase();
          
          return codigo.contains(query) || nombre.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_box, color: Colors.green),
          SizedBox(width: 8),
          Text('Agregar Materia Prima'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: _materiasFiltradas.isEmpty
                  ? Center(child: Text('No se encontraron materias primas'))
                  : ListView.builder(
                      itemCount: _materiasFiltradas.length,
                      itemBuilder: (context, index) {
                        final mp = _materiasFiltradas[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.inventory_2, color: Colors.blue),
                            title: Text(mp['nombre']),
                            subtitle: Text('${mp['codigo']} - ${mp['unidad_medida']}'),
                            trailing: Icon(Icons.add_circle, color: Colors.green),
                            onTap: () => Navigator.pop(context, mp),
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