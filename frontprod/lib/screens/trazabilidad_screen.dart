import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  
  // Valores calculados en tiempo real
  String _loteGenerado = '(Ingresa código del colaborador)';
  String _julianoGenerado = '---';
  
  // Datos de la tarea
  Map<String, dynamic>? _tarea;
  final Map<String, Map<String, dynamic>?> _reprocesosData = {}; 
  final Map<String, Map<String, dynamic>?> _mermasData = {}; 
  
  // ========================================================================
  // LISTAS DE TODAS LAS MATERIAS PRIMAS Y COLABORADORES DISPONIBLES
  // ========================================================================
  List<Map<String, dynamic>> _todasMateriasPrimasDisponibles = [];
  List<Map<String, dynamic>> _todosColaboradores = [];

  // ========================================================================
  // MATERIAS PRIMAS SELECCIONADAS (pueden agregarse/eliminarse)
  // ========================================================================
  final List<String> _materiasPrimasSeleccionadas = []; // Lista de códigos
  
  // Gestión de colaboradores seleccionados
  List<Map<String, dynamic>> _colaboradoresSeleccionados = [];
  
  // ========================================================================
  // DATOS Y CONTROLLERS POR MATERIA PRIMA
  // ========================================================================
  final Map<String, Map<String, dynamic>> _datosMateriasPrimas = {};
  final Map<String, TextEditingController> _loteControllers = {};
  final Map<String, TextEditingController> _consumoControllers = {};
  final Map<String, TextEditingController> _reprocesoControllers = {};
  final Map<String, TextEditingController> _mermaControllers = {};
  
  Uint8List? _fotoEtiqueta;
  String? _nombreArchivoFoto;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    
    // Listener para regenerar lote cuando cambie el código del colaborador
    _codigoColaboradorLoteController.addListener(_generarLote);
  }

  @override
  void dispose() {
    _cantidadProducidaController.dispose();
    _observacionesController.dispose();
    _codigoColaboradorLoteController.dispose();
    for (var controller in _loteControllers.values) {
      controller.dispose();
    }

    for (var controller in _consumoControllers.values) {
      controller.dispose();
    }
    for (var controller in _reprocesoControllers.values) {
      controller.dispose();
    }
    for (var controller in _mermaControllers.values) {
      controller.dispose();
    }
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
          final mpCompleta = _todasMateriasPrimasDisponibles.firstWhere(
            (mpCatalogo) => mpCatalogo['codigo'] == codigo,
            orElse: () => {
              'codigo': codigo,
              'nombre': mp['nombre'],
              'unidad_medida': mp['unidad_medida'] ?? 'kg',
              'requiere_lote': mp['requiere_lote'] ?? false,
            },
          );

          _agregarMateriaPrimaInterna(
            codigo: codigo,
            nombre: mpCompleta['nombre'],
            unidadMedida: mpCompleta['unidad_medida'],
            requiereLote: mpCompleta['requiere_lote'],
          );
        }
        
        _isLoading = false;
        
        // ========================================================================
        // CALCULAR JULIANO DESPUÉS DE CARGAR LA TAREA
        // ========================================================================
        _calcularJuliano();
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
    
    _reprocesosData[codigo] = null;
    _mermasData[codigo] = null; 
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
      
      if (!mounted) return; 
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

                _reprocesosData.remove(codigo);
                _mermasData.remove(codigo);
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

  Future<void> _ingresarReproceso(String codigoMP, String nombreMP) async {
    final reprocesoActual = _reprocesosData[codigoMP];
    final mp = _datosMateriasPrimas[codigoMP]!;
    
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogIngresarReproceso(
        nombreMateriaPrima: nombreMP,
        unidadMedida: mp['unidad_medida'],
        cantidadInicial: reprocesoActual?['cantidad']?.toString(),
        causaInicial: reprocesoActual?['causas'],
      ),
    );
    
    if (resultado != null) {
      setState(() {
        if (resultado['cantidad'] == 0.0) {
          // Si la cantidad es 0, eliminar el reproceso
          _reprocesosData[codigoMP] = null;
          _reprocesoControllers[codigoMP]!.text = '0';
        } else {
          _reprocesosData[codigoMP] = resultado;
          _reprocesoControllers[codigoMP]!.text = resultado['cantidad'].toString();
        }
      });
    }
  }

  Future<void> _ingresarMerma(String codigoMP, String nombreMP) async {
    final mermaActual = _mermasData[codigoMP];
    final mp = _datosMateriasPrimas[codigoMP]!;
    
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogIngresarMerma(
        nombreMateriaPrima: nombreMP,
        unidadMedida: mp['unidad_medida'],
        cantidadInicial: mermaActual?['cantidad']?.toString(),
        causaInicial: mermaActual?['causas'],
      ),
    );
    
    if (resultado != null) {
      setState(() {
        if (resultado['cantidad'] == 0.0) {
          // Si la cantidad es 0, eliminar la merma
          _mermasData[codigoMP] = null;
          _mermaControllers[codigoMP]!.text = '0';
        } else {
          _mermasData[codigoMP] = resultado;
          _mermaControllers[codigoMP]!.text = resultado['cantidad'].toString();
        }
      });
    }
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
    // Validar límite máximo
    if (_colaboradoresSeleccionados.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pueden agregar más de 20 colaboradores'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
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
      
      // Mostrar contador actualizado
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${colaboradorSeleccionado['nombre']} agregado (${_colaboradoresSeleccionados.length}/20)',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
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
      if (!mounted) return; 
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
        if (!mounted) return; 
        setState(() {
          _fotoEtiqueta = bytes;
          _nombreArchivoFoto = image.name;
        });
      }
    } catch (e) {
      if (!mounted) return; 
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

      final reprocesoData = _reprocesosData[codigo];
      if (reprocesoData != null && reprocesoData['cantidad'] > 0) {
        mpData['reprocesos'] = [
          {
            'cantidad': reprocesoData['cantidad'],
            'causas': reprocesoData['causas'],
          }
        ];
      }

      final mermaData = _mermasData[codigo];
      if (mermaData != null && mermaData['cantidad'] > 0) {
        mpData['mermas'] = [
          {
            'cantidad': mermaData['cantidad'],
            'causas': mermaData['causas'],
          }
        ];
      }

      materiasPrimasData.add(mpData);

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
  // CÁLCULOS EN TIEMPO REAL: JULIANO Y LOTE
  // ========================================================================
  
  /// Calcular día juliano (1-366) basado en la fecha de la tarea
  void _calcularJuliano() {
    if (_tarea == null) {
      return;
    }
    
    try {
      final fechaStr = _tarea!['fecha_elaboracion_real'] ?? _tarea!['fecha'];

      final partes = fechaStr.split('-');
      if (partes.length != 3) {
        throw Exception('Formato de fecha inválido: $fechaStr');
      }
      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final anio = int.parse(partes[2]);
          
      final fechaTarea = DateTime(anio, mes, dia);
      
      final primerDiaAnio = DateTime(fechaTarea.year, 1, 1);
      final diferencia = fechaTarea.difference(primerDiaAnio).inDays + 1;
      
      setState(() {
        _julianoGenerado = diferencia.toString().padLeft(3, '0');
      });
    } catch (e) {
      setState(() {
        _julianoGenerado = '---';
      });
    }
  }
  
  /// Generar lote en tiempo real: CÓDIGO_PRODUCTO-JULIANO-CÓDIGO_OPERADOR
  void _generarLote() {
    final codigoColab = _codigoColaboradorLoteController.text.trim();
    if (_tarea == null || codigoColab.isEmpty) {
      setState(() {
        _loteGenerado = '(Ingresa código del colaborador)';
      });
      return;
    }
    
    try {
      // Obtener código del producto
      final codigoProducto = _tarea!['producto_detalle']['codigo'] ?? 'XXXXX';
      final loteCompleto = '$codigoProducto-$_julianoGenerado-$codigoColab';
      
      setState(() {
        _loteGenerado = loteCompleto;
      });
      
    } catch (e) {
      setState(() {
        _loteGenerado = '(Error al generar)';
      });
    }
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
        toolbarHeight: 120,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                'assets/images/logo_entrelagosE.png',
                fit: BoxFit.contain,
                color: const Color(0xFFFFD9C6),
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.emoji_events,
                  color: const Color(0xFFFFD9C6),
                  size: 35,
                ),
              ),
            ),
          ),
        ],
        title: 
          Text('REGISTRO DE TRAZABILIDAD', 
            style: 
            TextStyle(
              fontWeight: FontWeight.w900,
              color: Color.fromRGBO(255, 217, 198, 1),
              fontSize: 28,
            ),
          ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 255, 217, 198),
              radius: 22,
              child: IconButton(
                padding: const EdgeInsets.only(left: 2.0),
                icon: Icon(Icons.arrow_back),
                color: Color.fromARGB(255, 137, 29, 67),
                iconSize: 35,
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Advertencia'),
                      content: Text(
                        'Si sales ahora, la trazabilidad quedará pendiente.\n\n'
                        '¿Estás seguro de salir?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Salir'),
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
          ),
        ),
        backgroundColor: Color.fromARGB(255, 137, 29, 67),
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
            _buildTablaMateriales(),
            SizedBox(height: 24),
            _buildSeccionFoto(),
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
                    : Icon(Icons.save, size: 28, color: Colors.white),
                label: Text(
                  _isSaving ? 'GUARDANDO...' : 'GUARDAR TRAZABILIDAD',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('F. ELAB.', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_tarea!['fecha_elaboracion_real'] ?? _tarea!['fecha'] ?? ''),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JULIANO:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _tarea!['juliano_fecha_tarea']?.toString() ?? 'N/A'),
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
            
            // ========================================================================
            // LOTE Y CÓDIGO DEL COLABORADOR JUNTOS
            // ========================================================================
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_2, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'LOTE GENERADO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Mostrar lote generado
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _loteGenerado.contains('(') 
                          ? Colors.grey.shade200 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _loteGenerado.contains('(') 
                            ? Colors.grey 
                            : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _loteGenerado,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _loteGenerado.contains('(') 
                            ? Colors.grey.shade600 
                            : Colors.blue.shade900,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Campo para código del colaborador
                  Row(
                    children: [
                      Icon(Icons.badge, size: 20, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Código del Colaborador *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _codigoColaboradorLoteController,
                    decoration: InputDecoration(
                      hintText: 'Ej: 96',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      prefixIcon: Icon(Icons.person, color: Colors.blue),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido para generar el lote';
                      }
                      return null;
                    },
                  ),
                  
                  if (_loteGenerado.contains('('))
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 14, color: Colors.orange),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ingresa el código para generar el lote',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
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
                      Text('UdM:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_tarea!['producto_detalle']['unidad_medida_display'] ?? 'UN'),
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
                Row(
                  children: [
                    Text(
                      'COLABORADORES',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _colaboradoresSeleccionados.length >= 20 
                            ? Colors.red.shade100 
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_colaboradoresSeleccionados.length}/20',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _colaboradoresSeleccionados.length >= 20 
                              ? Colors.red.shade900 
                              : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.person_add, color: Colors.blue),
                  onPressed: _colaboradoresSeleccionados.length >= 20 
                      ? null 
                      : _agregarColaborador,
                  tooltip: _colaboradoresSeleccionados.length >= 20 
                      ? 'Límite alcanzado (20 máx.)' 
                      : 'Agregar',
                ),
              ],
            ),
            Divider(),
            
            if (_colaboradoresSeleccionados.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No hay colaboradores asignados',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _agregarColaborador,
                        icon: Icon(Icons.add),
                        label: Text('Agregar Colaborador'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Table(
                border: TableBorder.all(color: Colors.black, width: 1),
                columnWidths: {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FixedColumnWidth(50),
                },
                children: [
                  // Header
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
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Filas dinámicas con todos los colaboradores
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
                          child: Text('${colab['nombre']} ${colab['apellido']}'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(4),
                          child: IconButton(
                            icon: Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _eliminarColaborador(index),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            tooltip: 'Eliminar',
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            
            // Mensaje de advertencia si se acerca al límite
            if (_colaboradoresSeleccionados.length >= 15 && _colaboradoresSeleccionados.length < 20)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Acercándose al límite: ${20 - _colaboradoresSeleccionados.length} espacios restantes',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Mensaje de límite alcanzado
            if (_colaboradoresSeleccionados.length >= 20)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Límite máximo alcanzado (20 colaboradores)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // TABLA DE MATERIALES CON BOTÓN AGREGAR Y ELIMINAR
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
                      final tieneReproceso = _reprocesosData[codigo] != null;
                      final tieneMerma = _mermasData[codigo] != null;
                      
                      return TableRow(
                        children: [
                          // COLUMNA DE ELIMINAR
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
                            InkWell(
                              onTap: () => _ingresarReproceso(codigo, mp['nombre']),
                              child: Container(
                                width: 80,
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: tieneReproceso 
                                      ? Colors.orange.shade50 
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: tieneReproceso 
                                        ? Colors.orange 
                                        : Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _reprocesoControllers[codigo]!.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tieneReproceso 
                                              ? Colors.orange.shade900 
                                              : Colors.black87,
                                          fontWeight: tieneReproceso 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildDataCell(
                            InkWell(
                              onTap: () => _ingresarMerma(codigo, mp['nombre']),
                              child: Container(
                                width: 80,
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: tieneMerma 
                                      ? Colors.red.shade50 
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: tieneMerma 
                                        ? Colors.red 
                                        : Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _mermaControllers[codigo]!.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tieneMerma 
                                              ? Colors.red.shade900 
                                              : Colors.black87,
                                          fontWeight: tieneMerma 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ],
                                ),
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
                      height: 600,
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
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color.fromARGB(255, 217, 244, 205),
                              child: Text(
                                colab['codigo'].toString().length >= 3
                                ? colab['codigo'].toString().substring(0, 3)
                                : colab['codigo'].toString(),
                                style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text('${colab['nombre']} ${colab['apellido']}'),
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
// Seleccionar Materia Prima
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

class _DialogIngresarReproceso extends StatefulWidget {
  final String nombreMateriaPrima;
  final String? cantidadInicial;
  final String? causaInicial;
  final String unidadMedida;

  const _DialogIngresarReproceso({
    required this.nombreMateriaPrima,
    required this.unidadMedida,
    this.cantidadInicial,
    this.causaInicial,
  });

  @override
  State<_DialogIngresarReproceso> createState() => _DialogIngresarReprocesoState();
}

class _DialogIngresarReprocesoState extends State<_DialogIngresarReproceso> {
  final _cantidadController = TextEditingController();
  final _otraCausaController = TextEditingController();
  String _causaSeleccionada = 'error_operador';
  
  // Lista de causas de reproceso (del modelo Django)
  final List<Map<String, String>> _causasReproceso = [
    {'value': 'escasez_de_banado', 'label': 'Escasez de Bañado'},
    {'value': 'poca_vida_util', 'label': 'Poca Vida Útil'},
    {'value': 'deformacion', 'label': 'Deformación'},
    {'value': 'peso_erroneo', 'label': 'Peso Erróneo'},
    {'value': 'mal_templado', 'label': 'Mal Templado'},
    {'value': 'otro', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();
    _cantidadController.text = widget.cantidadInicial ?? '0';
    _causaSeleccionada = widget.causaInicial ?? 'escasez_de_banado';

    if (_causaSeleccionada.startsWith('otro:')) {
      final partes = _causaSeleccionada.split(':');
      if (partes.length > 1) {
        _causaSeleccionada = 'otro';
        _otraCausaController.text = partes.sublist(1).join(':');
      }
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _otraCausaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.recycling, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reproceso',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre de la materia prima
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.orange.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.nombreMateriaPrima,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Campo de cantidad
            Text(
              'Cantidad de Reproceso',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _cantidadController,
              decoration: InputDecoration(
                hintText: 'Ej: 5.5',
                suffixText: widget.unidadMedida,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Selector de causa
            Text(
              'Causa del Reproceso',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _causaSeleccionada,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber),
              ),
              items: _causasReproceso.map((causa) {
                return DropdownMenuItem<String>(
                  value: causa['value'],
                  child: Text(causa['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _causaSeleccionada = value!;
                });
              },
            ),

            if (_causaSeleccionada == 'otro') ...[
              SizedBox(height: 12),
              Text(
                'Especifica la otra causa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _otraCausaController,
                decoration: InputDecoration(
                  hintText: 'Escribe la causa...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                maxLength: 200,
                maxLines: 2,
              ),
            ],
            
            SizedBox(height: 12),
            
            // Info adicional
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ingresa 0 para eliminar el reproceso',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
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
        ElevatedButton.icon(
          onPressed: () {
            final cantidad = double.tryParse(_cantidadController.text.trim()) ?? 0.0;

            if (_causaSeleccionada == 'otro' && _otraCausaController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Por favor especifica la otra causa'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            
            String causaFinal = _causaSeleccionada;
            if (_causaSeleccionada == 'otro') {
              causaFinal = 'otro:${_otraCausaController.text.trim()}';
            }
            
            Navigator.pop(context, {
              'cantidad': cantidad,
              'causas': causaFinal,
            });
          },
          icon: Icon(Icons.check),
          label: Text('Guardar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _DialogIngresarMerma extends StatefulWidget {
  final String nombreMateriaPrima;
  final String? cantidadInicial;
  final String? causaInicial;
  final String unidadMedida;

  const _DialogIngresarMerma({
    required this.nombreMateriaPrima,
    required this.unidadMedida,
    this.cantidadInicial,
    this.causaInicial,
  });

  @override
  State<_DialogIngresarMerma> createState() => _DialogIngresarMermaState();
}

class _DialogIngresarMermaState extends State<_DialogIngresarMerma> {
  final _cantidadController = TextEditingController();
  final _otraCausaController = TextEditingController();
  String _causaSeleccionada = 'desperdicio_corte';
  
  // Lista de causas de merma (del modelo Django)
  final List<Map<String, String>> _causasMerma = [
    {'value': 'cayo_al_suelo', 'label': 'Cayó al Suelo'},
    {'value': 'por_hongos', 'label': 'Por Hongos'},
    {'value': 'caducidad', 'label': 'Caducidad'},
    {'value': 'grasa_maquina', 'label': 'Grasa Máquina'},
    {'value': 'exposicion', 'label': 'Exposición'},
    {'value': 'otro', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();
    _cantidadController.text = widget.cantidadInicial ?? '0';
    _causaSeleccionada = widget.causaInicial ?? 'cayo_al_suelo';

    if (_causaSeleccionada.startsWith('otro:')) {
      final partes = _causaSeleccionada.split(':');
      if (partes.length > 1) {
        _causaSeleccionada = 'otro';
        _otraCausaController.text = partes.sublist(1).join(':');
      }
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _otraCausaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Merma',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre de la materia prima
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.red.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.nombreMateriaPrima,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Campo de cantidad
            Text(
              'Cantidad de Merma',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _cantidadController,
              decoration: InputDecoration(
                hintText: 'Ej: 2.3',
                suffixText: widget.unidadMedida,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Selector de causa
            Text(
              'Causa de la Merma',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _causaSeleccionada,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber),
              ),
              items: _causasMerma.map((causa) {
                return DropdownMenuItem<String>(
                  value: causa['value'],
                  child: Text(causa['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _causaSeleccionada = value!;
                });
              },
            ),

            if (_causaSeleccionada == 'otro') ...[
              SizedBox(height: 12),
              Text(
                'Especifica la otra causa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _otraCausaController,
                decoration: InputDecoration(
                  hintText: 'Escribe la causa...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                maxLength: 200,
                maxLines: 2,
              ),
            ],
            
            SizedBox(height: 12),
            
            // Info adicional
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ingresa 0 para eliminar la merma',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
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
        ElevatedButton.icon(
          onPressed: () {
            final cantidad = double.tryParse(_cantidadController.text.trim()) ?? 0.0;

            if (_causaSeleccionada == 'otro' && _otraCausaController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Por favor especifica la otra causa'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            String causaFinal = _causaSeleccionada;
            if (_causaSeleccionada == 'otro') {
              causaFinal = 'otro:${_otraCausaController.text.trim()}';
            }
            
            Navigator.pop(context, {
              'cantidad': cantidad,
              'causas': causaFinal,
            });
          },
          icon: Icon(Icons.check),
          label: Text('Guardar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
        ),
      ],
    );
  }
}