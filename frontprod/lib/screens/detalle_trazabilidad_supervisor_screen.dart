// ============================================================================
// PANTALLA: Detalle de Trazabilidad para Supervisor - VERSIÓN CORREGIDA
// ============================================================================
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'detalle_hoja_procesos_screen.dart';


const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);
class DetalleTrazabilidadSupervisorScreen extends StatefulWidget {
  final int trazabilidadId;

  const DetalleTrazabilidadSupervisorScreen({
    Key? key,
    required this.trazabilidadId,
  }) : super(key: key);

  @override
  State<DetalleTrazabilidadSupervisorScreen> createState() =>
      _DetalleTrazabilidadSupervisorScreenState();
}

class _DetalleTrazabilidadSupervisorScreenState extends State<DetalleTrazabilidadSupervisorScreen> {
  // ========== ESTADO ==========
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _trazabilidad;
  String? _error;
  bool _modoEdicion = false;
  Map<String, dynamic>? _usuario;

  double _convertirADouble(dynamic valor) {
  if (valor == null) return 0.0;
  if (valor is double) return valor;
  if (valor is int) return valor.toDouble();
  if (valor is String) return double.tryParse(valor) ?? 0.0;
  return 0.0;
}

  // ========== DATOS ORIGINALES (para revertir cambios) ==========
  Map<String, Map<String, dynamic>> _materiasPrimasOriginales = {};
  List<Map<String, dynamic>> _reprocesosOriginales = [];
  List<Map<String, dynamic>> _mermasOriginales = [];
  List<Map<String, dynamic>> _colaboradoresOriginales = [];
  String _cantidadProducidaOriginal = '';
  String _observacionesOriginal = '';

  // ========== DATOS PARA EDICIÓN ==========
  final TextEditingController _cantidadProducidaController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _codigoColaboradorLoteController = TextEditingController();
  

  Uint8List? _fotoEtiqueta;
  String? _nombreArchivoFoto;
  String? _fotoEtiquetasUrl;
  
  final List<String> _materiasPrimasSeleccionadas = [];
  final Map<String, Map<String, dynamic>> _datosMateriasPrimas = {};
  final Map<String, TextEditingController> _loteControllers = {};
  final Map<String, TextEditingController> _consumoControllers = {};
  final Map<String, List<Map<String, dynamic>>> _reprocesosData = {}; 
  final Map<String, List<Map<String, dynamic>>> _mermasData = {};
  final Map<String, TextEditingController> _reprocesoControllers = {};
  final Map<String, TextEditingController> _mermaControllers = {};
  
  List<Map<String, dynamic>> _colaboradoresSeleccionados = [];
  List<Map<String, dynamic>> _todosColaboradores = [];
  
  List<Map<String, dynamic>> _todasMateriasPrimasDisponibles = [];

  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _tarea;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _codigoColaboradorLoteController.addListener(_actualizarLoteEnPantalla);
  }

  @override
  void _actualizarLoteEnPantalla() {
  if (_tarea == null || _trazabilidad == null) return;
  
  // No actualizar si no estamos en modo edición
  if (!_modoEdicion) return;
  
  final producto = _tarea!['producto_detalle'] ?? _tarea!['producto'];
  if (producto == null) return;
  
  final codigoProducto = producto['codigo'];
  final juliano = _trazabilidad!['juliano'];
  final codigoColaborador = _codigoColaboradorLoteController.text.trim();
  
  // Generar nuevo lote
  final nuevoLote = '$codigoProducto-$juliano-$codigoColaborador';
  
  setState(() {
  });
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

  // ========== CARGAR USUARIO Y TRAZABILIDAD ==========
  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1️⃣ Cargar usuario actual
      final usuario = await _apiService.getCurrentUser();
      
      // 2️⃣ Cargar trazabilidad
      await _cargarTrazabilidadInternal();

      setState(() {
        _usuario = usuario;
      });

      print('✅ Usuario cargado: ${usuario['username']} - Rol: ${usuario['rol']}');
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  // ========== CARGAR TRAZABILIDAD ==========
  Future<void> _cargarTrazabilidadInternal() async {
    try {
      final data = await _apiService.getTrazabilidadDetalle(widget.trazabilidadId);
      
      final todosColabs = await _apiService.getColaboradores();
      final todasMPData = await _apiService.getMateriasPrimas();

      setState(() {
        _trazabilidad = data;
        _tarea = data['hoja_procesos_detalle']?['tarea'];

        final lote = data['lote']?.toString() ?? '';
        if (lote.isNotEmpty) {
          final partes = lote.split('-');
          if (partes.length >= 3) {
            _codigoColaboradorLoteController.text = partes[2];
          }
        }
      
        _cantidadProducidaOriginal = (data['cantidad_producida']?? 0).toString();
        _observacionesOriginal = data['observaciones'] ?? '';
        
        _cantidadProducidaController.text = _cantidadProducidaOriginal;
        _observacionesController.text = _observacionesOriginal;
        
        _todasMateriasPrimasDisponibles = List<Map<String, dynamic>>.from(
          todasMPData.map((mp) => {
            'codigo': mp['codigo'],
            'nombre': mp['nombre'],
            'unidad_medida': mp['unidad_medida'] ?? 'kg',
            'requiere_lote': mp['requiere_lote'] ?? false,
          })
        );
        _materiasPrimasSeleccionadas.clear();
        _materiasPrimasOriginales.clear();
        _datosMateriasPrimas.clear();

        _loteControllers.values.forEach((c) => c.dispose());
        _consumoControllers.values.forEach((c) => c.dispose());
        _reprocesoControllers.values.forEach((c) => c.dispose());
        _mermaControllers.values.forEach((c) => c.dispose());
        
        _loteControllers.clear();
        _consumoControllers.clear();
        _reprocesoControllers.clear();
        _mermaControllers.clear();
        _reprocesosData.clear();
        _mermasData.clear();

        final mpUsadas = data['materias_primas_usadas'] as List? ?? [];
        
        for (var mp in mpUsadas) {
          final mpDetalle = mp['materia_prima_detalle'] ?? mp['materia_prima'];
          if (mpDetalle == null) continue;
          
          final codigo = (mpDetalle['codigo'] ?? '').toString();

          _materiasPrimasSeleccionadas.add(codigo);
          
          _loteControllers[codigo] = TextEditingController(
            text: (mp['lote'] ?? '').toString()
          );
          _consumoControllers[codigo] = TextEditingController(
            text: (mp['cantidad_usada'] ?? 0).toString()
          );
          
          final reprocesos = mp['reprocesos'] as List? ?? [];
          _reprocesosData[codigo] = reprocesos.map((r) => {
            'cantidad': _convertirADouble(r['cantidad']),
            'causas': r['causas'].toString(),
          }).toList();

          final totalReproceso = _reprocesosData[codigo]!.isEmpty 
              ? 0.0 
              : _reprocesosData[codigo]!.fold(0.0, (sum, r) => sum + (r['cantidad'] as double));
          _reprocesoControllers[codigo] = TextEditingController(
            text: totalReproceso.toString()
          );

          final mermas = mp['mermas'] as List? ?? [];
          _mermasData[codigo] = mermas.map((m) => {
            'cantidad': _convertirADouble(m['cantidad']),
            'causas': m['causas'].toString(),
          }).toList();

          final totalMerma = _mermasData[codigo]!.isEmpty 
              ? 0.0 
              : _mermasData[codigo]!.fold(0.0, (sum, m) => sum + (m['cantidad'] as double));
          _mermaControllers[codigo] = TextEditingController(
            text: totalMerma.toString()
          );

          _datosMateriasPrimas[codigo] = {
            'materia_prima_id': codigo,
            'nombre': (mpDetalle['nombre'] ?? 'Sin nombre').toString(),
            'unidad_medida': (mpDetalle['unidad_medida'] ?? mp['unidad_medida'] ?? 'kg').toString(),
            'requiere_lote': mpDetalle['requiere_lote'] ?? false,
          };
          
          _materiasPrimasOriginales[codigo] = Map<String, dynamic>.from(
            _datosMateriasPrimas[codigo]!
          );
        }

        final colaboradoresReales = data['colaboradores_reales'] as List? ?? [];

        _colaboradoresOriginales = colaboradoresReales.map<Map<String, dynamic>>((c) {
          final colaborador = c is Map && c.containsKey('colaborador') 
              ? c['colaborador'] 
              : c;
          
          if (colaborador == null || colaborador is! Map) {
            return <String, dynamic>{};
          }
          
          final codigo = colaborador['codigo'];
          final codigoInt = codigo is int ? codigo : int.tryParse(codigo.toString()) ?? 0;

          return {
            'codigo': codigoInt,
            'nombre': colaborador['nombre']?.toString() ?? '',
            'apellido': colaborador['apellido']?.toString() ?? '',
          };
        }).where((c) => c.isNotEmpty).toList();
        
        _colaboradoresSeleccionados = _colaboradoresOriginales.map(
          (c) => Map<String, dynamic>.from(c)
        ).toList();
        
        _todosColaboradores = todosColabs.map<Map<String, dynamic>>((c) {
          final codigo = c['codigo'];
          final codigoInt = codigo is int ? codigo : int.tryParse(codigo.toString()) ?? 0;
          
          return {
            'codigo': codigoInt,
            'nombre': (c['nombre'] ?? '').toString(),
            'apellido': (c['apellido'] ?? '').toString(),
          };
        }).toList();
        
        if (data['foto_etiquetas'] != null && 
            data['foto_etiquetas'].toString().isNotEmpty) {
            _fotoEtiquetasUrl = data['foto_etiquetas'].toString();
        }
      });

    } catch (e) {
      setState(() {
        _error = 'Error al cargar trazabilidad: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== VERIFICAR ROL DEL USUARIO ==========
  bool get _esSupervisor => _usuario?['rol'] == 'supervisor';
  bool get _esControlCalidad => _usuario?['rol'] == 'control_calidad';

  // ========== VERIFICAR FIRMAS ==========
  bool get _tieneFirmaSupervisor {
    final firmas = _trazabilidad?['firmas'] as List<dynamic>? ?? [];
    return firmas.any((firma) => firma is Map && firma['tipo_firma'] == 'supervisor');
  }

  bool get _tieneFirmaCalidad {
    final firmas = _trazabilidad?['firmas'] as List<dynamic>? ?? [];
    return firmas.any((firma) => firma is Map && firma['tipo_firma'] == 'control_calidad');
  }

  // ========== OBTENER ESTADO ACTUAL ==========
  String get _estadoActual => _trazabilidad?['estado']?.toString() ?? 'en_revision';

  // ========== COLOR SEGÚN ESTADO ==========
  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'liberado':
        return Colors.green;
      case 'retenido':
        return Colors.red;
      case 'en_revision':
      default:
        return Colors.blue;
    }
  }

  // ========== TEXTO SEGÚN ESTADO ==========
  String _getTextoEstado(String estado) {
    switch (estado) {
      case 'liberado':
        return 'LIBERADO';
      case 'retenido':
        return 'RETENIDO';
      case 'en_revision':
      default:
        return 'EN REVISIÓN';
    }
  }

  // ========== ICONO SEGÚN ESTADO ==========
  IconData _getIconoEstado(String estado) {
    switch (estado) {
      case 'liberado':
        return Icons.check_circle;
      case 'retenido':
        return Icons.cancel;
      case 'en_revision':
      default:
        return Icons.pending;
    }
  }

  // ========== WIDGET: ESTADO DESTACADO ==========
  Widget _buildEstadoDestacado() {
    final estado = _estadoActual;
    final color = _getColorEstado(estado);
    final texto = _getTextoEstado(estado);
    final icono = _getIconoEstado(estado);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            size: 48,
            color: color,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado Actual',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 24,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Mostrar motivo de retención si existe
                if (estado == 'retenido' && _trazabilidad?['motivo_retencion'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motivo: ${_trazabilidad!['motivo_retencion']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== CANCELAR EDICIÓN (REVERTIR CAMBIOS) ==========
  void _cancelarEdicion() {
    setState(() {
      _cantidadProducidaController.text = _cantidadProducidaOriginal;
      _observacionesController.text = _observacionesOriginal;

      _colaboradoresSeleccionados = _colaboradoresOriginales.map(
        (c) => Map<String, dynamic>.from(c)
      ).toList();

      _modoEdicion = false;
    });

    _cargarDatos();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ========== GUARDAR CAMBIOS ==========
  Future<void> _guardarCambios() async {
    // Validar cantidad producida
    final cantidadProducida = int.tryParse(_cantidadProducidaController.text);
    if (cantidadProducida == null || cantidadProducida <= 0) {
      _mostrarError('La cantidad producida debe ser un número válido mayor a 0');
      return;
    }

    // Validar que haya al menos un colaborador
    if (_colaboradoresSeleccionados.isEmpty) {
      _mostrarError('Debe haber al menos un colaborador asignado');
      return;
    }

    // ========================================================================
    // VALIDAR FOTO OBLIGATORIA
    // ========================================================================
    if (_fotoEtiqueta == null && _fotoEtiquetasUrl == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text('Falta Foto de Etiquetas'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La foto de etiquetas es OBLIGATORIA para guardar la trazabilidad.',
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
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Debes tomar una foto antes de guardar',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      );
      return;
    }

    // Validar materias primas
    for (var codigo in _materiasPrimasSeleccionadas) {
      final mp = _datosMateriasPrimas[codigo]!;
      final cantidadStr = _consumoControllers[codigo]!.text.trim();
      if (cantidadStr.isEmpty || double.tryParse(cantidadStr) == null) {
        _mostrarError('Completa todas las cantidades de materias primas');
        return;
      }
      
      if (mp['requiere_lote'] == true) {
        final lote = _loteControllers[codigo]!.text.trim();
        if (lote.isEmpty) {
          _mostrarError('${mp['nombre']} requiere lote');
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      List<Map<String, dynamic>> materiasPrimasData = [];
      
      for (String codigo in _materiasPrimasSeleccionadas) {
        final mp = _datosMateriasPrimas[codigo]!;
        final lote = _loteControllers[codigo]!.text.trim();
        
        Map<String, dynamic> mpData = {
          'materia_prima_id': codigo,
          'lote': lote.isEmpty ? null : lote,
          'cantidad_usada': double.parse(_consumoControllers[codigo]!.text),
          'unidad_medida': mp['unidad_medida'],
        };

        final reprocesos = _reprocesosData[codigo] ?? [];
        if (reprocesos.isNotEmpty) {
          mpData['reprocesos'] = reprocesos.map((r) => {
            'cantidad': r['cantidad'],
            'causas': r['causas'],
          }).toList();
        }

        final mermas = _mermasData[codigo] ?? [];
        if (mermas.isNotEmpty) {
          mpData['mermas'] = mermas.map((m) => {
            'cantidad': m['cantidad'],
            'causas': m['causas'],
          }).toList();
        }
        materiasPrimasData.add(mpData);
      }

      final datos = {
        'cantidad_producida': cantidadProducida,
        'observaciones': _observacionesController.text.trim(),
        'materias_primas': materiasPrimasData,
        'colaboradores_codigos': _colaboradoresSeleccionados
            .map((c) => c['codigo'] as int)
            .toList(),
        'codigo_colaborador_lote': _codigoColaboradorLoteController.text.trim(),
      };

      List<int>? fotoBytesParaEnviar;
      String? nombreArchivoParaEnviar;

      if (_fotoEtiqueta != null) {
        fotoBytesParaEnviar = _fotoEtiqueta;
        nombreArchivoParaEnviar = _nombreArchivoFoto ?? 
            'etiqueta_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (_fotoEtiquetasUrl != null) {
        fotoBytesParaEnviar = null;
        nombreArchivoParaEnviar = null;
      }

      await _apiService.updateTrazabilidad(
        widget.trazabilidadId,
        datos,
        fotoBytes: fotoBytesParaEnviar,
        nombreArchivo: nombreArchivoParaEnviar,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _modoEdicion = false;
        });

        await _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al guardar: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  // ========== AGREGAR/ELIMINAR REPROCESO ==========
  Future<void> _ingresarReproceso(String codigoMP, String nombreMP) async {
    final reprocesosList = _reprocesosData[codigoMP] ?? [];
    final mp = _datosMateriasPrimas[codigoMP]!;
    
    // Tomar el primero si existe
    final reprocesoActual = reprocesosList.isNotEmpty ? reprocesosList[0] : null;
    
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
          _reprocesosData[codigoMP] = [];
          _reprocesoControllers[codigoMP]!.text = '0';
        } else {
          _reprocesosData[codigoMP] = [resultado];
          _reprocesoControllers[codigoMP]!.text = resultado['cantidad'].toString();
        }
      });
    }
  }

  // ========== AGREGAR/ELIMINAR MERMA ==========
  Future<void> _ingresarMerma(String codigoMP, String nombreMP) async {
    final mermasList = _mermasData[codigoMP] ?? [];
    final mp = _datosMateriasPrimas[codigoMP]!;
    
    // Tomar el primero si existe
    final mermaActual = mermasList.isNotEmpty ? mermasList[0] : null;
    
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
          _mermasData[codigoMP] = [];
          _mermaControllers[codigoMP]!.text = '0';
        } else {
          _mermasData[codigoMP] = [resultado];
          _mermaControllers[codigoMP]!.text = resultado['cantidad'].toString();
        }
      });
    }
  }

  Future<void> _agregarMateriaPrima() async {
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
        final codigo = mpSeleccionada['codigo'];
        _materiasPrimasSeleccionadas.add(codigo);
        
        _loteControllers[codigo] = TextEditingController();
        _consumoControllers[codigo] = TextEditingController();
        _reprocesoControllers[codigo] = TextEditingController(text: '0');
        _mermaControllers[codigo] = TextEditingController(text: '0');
        
        _reprocesosData[codigo] = [];
        _mermasData[codigo] = [];
        
        _datosMateriasPrimas[codigo] = {
          'materia_prima_id': codigo,
          'nombre': mpSeleccionada['nombre'],
          'unidad_medida': mpSeleccionada['unidad_medida'],
          'requiere_lote': mpSeleccionada['requiere_lote'],
        };
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mpSeleccionada['nombre']} agregada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

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
                _materiasPrimasSeleccionadas.remove(codigo);
                
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

  Future<void> _agregarColaborador() async {
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
      _mostrarError('No hay más colaboradores disponibles');
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

  void _eliminarColaborador(int index) {
    setState(() {
      _colaboradoresSeleccionados.removeAt(index);
    });
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

  // ========== FIRMAR TRAZABILIDAD ==========
  Future<void> _firmarTrazabilidad() async {
    // Verificar que el usuario pueda firmar
    if (_esSupervisor && _tieneFirmaSupervisor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya firmaste esta trazabilidad'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_esControlCalidad && !_tieneFirmaSupervisor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El supervisor debe firmar primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_esControlCalidad && _tieneFirmaCalidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya firmaste esta trazabilidad'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirmar acción
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Firma'),
        content: Text(
          _esSupervisor 
              ? '¿Confirmas que la información es correcta y deseas firmar esta trazabilidad?'
              : '¿Confirmas que has revisado la trazabilidad y deseas firmarla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Firmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _apiService.firmarTrazabilidad(widget.trazabilidadId);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trazabilidad firmada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Recargar datos
      await _cargarDatos();
      
      // No cerrar la pantalla, mantener al usuario aquí
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al firmar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========== CAMBIAR ESTADO DE TRAZABILIDAD ==========
  Future<void> _cambiarEstado(String nuevoEstado) async {
    // Solo Control de Calidad puede cambiar estado
    if (!_esControlCalidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo Control de Calidad puede cambiar el estado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Si es retener, pedir motivo
    String? motivoRetencion;
    if (nuevoEstado == 'retenido') {
      motivoRetencion = await _mostrarDialogoMotivoRetencion();
      if (motivoRetencion == null || motivoRetencion.isEmpty) {
        return; // Usuario canceló o no ingresó motivo
      }
    }

    // Confirmar acción
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nuevoEstado == 'liberado' ? 'Liberar Producto' : 'Retener Producto'),
        content: Text(
          nuevoEstado == 'liberado'
              ? '¿Confirmas que deseas LIBERAR este producto?'
              : '¿Confirmas que deseas RETENER este producto?\n\nMotivo: $motivoRetencion',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'liberado' ? Colors.green : Colors.red,
            ),
            child: Text(nuevoEstado == 'liberado' ? 'Liberar' : 'Retener'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _apiService.cambiarEstadoTrazabilidad(
        trazabilidadId: widget.trazabilidadId,
        estado: nuevoEstado,
        motivoRetencion: motivoRetencion,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'liberado' 
                ? 'Producto liberado exitosamente' 
                : 'Producto retenido exitosamente',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Recargar datos
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========== DIÁLOGO: MOTIVO DE RETENCIÓN ==========
  Future<String?> _mostrarDialogoMotivoRetencion() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo de Retención'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Describe detalladamente el motivo por el cual se retiene este producto:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Ejemplo: Producto con defectos visibles en el chocolate, se observa blanqueamiento en más del 30% de las unidades...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debes ingresar un motivo'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Retener'),
          ),
        ],
      ),
    );
  }

  // ========== UI: INFORMACIÓN DE LA TAREA ==========
 Widget _buildEncabezado() {
  final firmas = _trazabilidad!['firmas'] as List? ?? [];
  final tieneFirmaSupervisor = firmas.any(
    (f) => f is Map && f['tipo_firma'] == 'supervisor',
  );
  if (_tarea == null) return SizedBox.shrink();
  
  final producto = _tarea!['producto_detalle'] ?? _tarea!['producto'];
  final linea = _tarea!['linea_detalle'] ?? _tarea!['linea'];
  final turno = _tarea!['turno_detalle'] ?? _tarea!['turno'];
  
  if (producto == null || linea == null || turno == null) {
    return SizedBox.shrink();
  }
  
  final juliano = _trazabilidad!['juliano'];
  final lote = _trazabilidad!['lote'];
  String fechaElaboracion = 'N/A';
  try {
    final fechaElabRaw = _tarea!['fecha_elaboracion_real'] ?? _tarea!['fecha'];
    if (fechaElabRaw != null) {
      DateTime fechaDateTime;
      
      // Parsear según formato recibido
      if (fechaElabRaw.toString().contains('-') && fechaElabRaw.toString().length == 10) {
        // Formato: YYYY-MM-DD (desde el backend)
        fechaDateTime = DateTime.parse(fechaElabRaw.toString());
      } else if (fechaElabRaw.toString().contains('-') && fechaElabRaw.toString().contains('T')) {
        // Formato ISO completo: YYYY-MM-DDTHH:MM:SS
        fechaDateTime = DateTime.parse(fechaElabRaw.toString());
      } else {
        // Intentar parseo directo
        fechaDateTime = DateTime.parse(fechaElabRaw.toString());
      }
      
      // Formatear a DD/MM/YYYY
      fechaElaboracion = DateFormat('dd/MM/yyyy').format(fechaDateTime);
    }
  } catch (e) {
    print('❌ Error al formatear fecha de elaboración: $e');
    print('   Fecha raw: ${_tarea!['fecha_elaboracion_real'] ?? _tarea!['fecha']}');
    fechaElaboracion = _tarea!['fecha_elaboracion_real']?.toString() ?? 
                      _tarea!['fecha']?.toString() ?? 
                      'N/A';
  }

  return Card(
    elevation: 4,
    margin: EdgeInsets.all(16),
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
                    Text('F. ELAB.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(fechaElaboracion ?? ''),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JULIANO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(juliano?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TURNO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(turno['nombre'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
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
                
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Text(
                    _modoEdicion && tieneFirmaSupervisor == false
                        ? '${producto['codigo']}-$juliano-${_codigoColaboradorLoteController.text.trim()}'
                        : (lote?.toString() ?? 'Sin lote'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                if (_modoEdicion && !tieneFirmaSupervisor) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 20, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Código del Colaborador',
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
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                // Manejo robusto: puede ser int o Map
                final hojaProcesos = _trazabilidad!['hoja_procesos'];
                final int hojaProcesosId;
                
                if (hojaProcesos is int) {
                  // Si es un entero directo
                  hojaProcesosId = hojaProcesos;
                } else if (hojaProcesos is Map) {
                  // Si es un objeto con id
                  hojaProcesosId = hojaProcesos['id'] as int;
                } else {
                  // Fallback (no debería llegar aquí)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo obtener ID de hoja de procesos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleHojaProcesosSupervisorScreen(
                      hojaProcesosId: hojaProcesosId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Ver Hoja de Procesos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: BorderSide(color: primaryColorDark, width: 2),
                foregroundColor: primaryColorDark,
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
                    Text('CODIGO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(producto['codigo'] ?? '', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(producto['nombre'] ?? '', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UdM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(_tarea!['unidad_medida_display'] ?? _tarea!['unidad_medida'] ?? 'UN'),
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
                    Text(_tarea!['meta_produccion']?.toString() ?? '0'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (_modoEdicion)
                      TextFormField(
                        controller: _cantidadProducidaController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      )
                    else
                      Text(_trazabilidad!['cantidad_producida']?.toString() ?? '0'),
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
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (_modoEdicion && !tieneFirmaSupervisor)
                  IconButton(
                    icon: Icon(Icons.person_add, color: Colors.blue),
                    onPressed: _colaboradoresSeleccionados.length >= 20 
                        ? null 
                        : _agregarColaborador,
                    tooltip: _colaboradoresSeleccionados.length >= 20 
                        ? 'Límite alcanzado (20 max.)' 
                        : 'Agregar',
                  ),
              ],
            ),
            Divider(),
            
            if (_colaboradoresSeleccionados.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay colaboradores asignados'),
                ),
              )
            else
              Table(
                border: TableBorder.all(color: Colors.black, width: 1),
                columnWidths: {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  if (_modoEdicion && !tieneFirmaSupervisor) 2: FixedColumnWidth(50),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('CODIGO', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('NOMBRE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_modoEdicion && !tieneFirmaSupervisor)
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          child: Text('${colab['nombre']} ${colab['apellido']}'),
                        ),
                        if (_modoEdicion && !tieneFirmaSupervisor)
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
          ],
        ),
      ),
    );
  }

  Widget _buildTablaMateriales() {
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (_modoEdicion && !tieneFirmaSupervisor)
                  IconButton(
                    icon: Icon(Icons.add_box, color: Colors.green),
                    onPressed: _agregarMateriaPrima,
                    tooltip: 'Agregar Materia Prima',
                  ),
              ],
            ),
            Divider(),
            
            if (_materiasPrimasSeleccionadas.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay materias primas registradas'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: Colors.black, width: 1),
                  defaultColumnWidth: IntrinsicColumnWidth(),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        if (_modoEdicion && !tieneFirmaSupervisor) _buildHeaderCell(''),
                        _buildHeaderCell('CODIGO'),
                        _buildHeaderCell('DESCRIPCION'),
                        _buildHeaderCell('UdM'),
                        _buildHeaderCell('LOTE'),
                        _buildHeaderCell('CONSUMO'),
                        _buildHeaderCell('REPROCESO'),
                        _buildHeaderCell('MERMA'),
                      ],
                    ),
                    ..._materiasPrimasSeleccionadas.map((codigo) {
                      final mp = _datosMateriasPrimas[codigo]!;
                      final tieneReproceso = (_reprocesosData[codigo] ?? []).isNotEmpty;
                      final tieneMerma = (_mermasData[codigo] ?? []).isNotEmpty;
                      
                      return TableRow(
                        children: [
                          if (_modoEdicion && !tieneFirmaSupervisor)
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
                              child: _modoEdicion && !tieneFirmaSupervisor
                                  ? TextFormField(
                                      controller: _loteControllers[codigo],
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      style: TextStyle(fontSize: 12),
                                    )
                                  : Text(_loteControllers[codigo]!.text),
                            ),
                          ),
                          _buildDataCell(
                            SizedBox(
                              width: 80,
                              child: _modoEdicion && !tieneFirmaSupervisor
                                  ? TextFormField(
                                      controller: _consumoControllers[codigo],
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(fontSize: 12),
                                    )
                                  : Text(_consumoControllers[codigo]!.text),
                            ),
                          ),
                          _buildDataCell(
                            _modoEdicion && !tieneFirmaSupervisor
                                ? InkWell(
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
                                  )
                                : Text(_reprocesoControllers[codigo]!.text),
                          ),
                          _buildDataCell(
                            _modoEdicion && !tieneFirmaSupervisor
                                ? InkWell(
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
                                  )
                                : Text(_mermaControllers[codigo]!.text),
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
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );
    
    final bool hayFoto = _fotoEtiqueta != null || _fotoEtiquetasUrl != null;
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOTO DE ETIQUETAS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Divider(),
            
            if (!hayFoto)
              Column(
                children: [
                  Text('Debes tomar una foto de las etiquetas utilizadas'),
                  SizedBox(height: 16),
                  if (_modoEdicion && !tieneFirmaSupervisor)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tomarFoto,
                            icon: Icon(Icons.camera_alt),
                            label: Text('Tomar Foto'),
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
                    child: _fotoEtiqueta != null
                        ? Image.memory(
                            _fotoEtiqueta!,
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _fotoEtiquetasUrl!,
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 400,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 400,
                                color: Colors.grey[300],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, size: 48, color: Colors.red),
                                    SizedBox(height: 8),
                                    Text(
                                      'Error al cargar imagen',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  SizedBox(height: 12),
                  
                  if (_modoEdicion && !tieneFirmaSupervisor)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tomarFoto,
                            icon: Icon(Icons.refresh),
                            label: Text('Cambiar Foto'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _fotoEtiqueta = null;
                                _fotoEtiquetasUrl = null;
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
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Foto de etiquetas guardada',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
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

  Widget _buildObservaciones() {
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            
            if (_modoEdicion && !tieneFirmaSupervisor)
              TextFormField(
                controller: _observacionesController,
                decoration: InputDecoration(
                  hintText: 'Observaciones adicionales...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              )
            else
              Text(
                _trazabilidad!['observaciones'] ?? 'Sin observaciones',
                style: TextStyle(
                  color: _trazabilidad!['observaciones'] != null
                      ? Colors.black87
                      : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionFirmas() {
    final firmas = _trazabilidad!['firmas'] as List? ?? [];

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FIRMAS Y ESTADO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),

            // ========== ESTADO DESTACADO ==========
            _buildEstadoDestacado(),

            const SizedBox(height: 16),

            // ========== LISTA DE FIRMAS ==========
            Text(
              'Historial de Firmas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (firmas.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Sin firmas registradas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...firmas.map((firma) {
                if (firma == null || firma is! Map<String, dynamic>) {
                  return SizedBox.shrink();
                }

                final esSupervisor = firma['tipo_firma'] == 'supervisor';
                
                String usuarioNombre = 'Usuario desconocido';
                if (firma['usuario_detalle'] != null && firma['usuario_detalle'] is Map) {
                  final usuarioDetalle = firma['usuario_detalle'] as Map;
                  usuarioNombre = (usuarioDetalle['nombre_completo'] ?? 
                                  usuarioDetalle['username'] ?? 
                                  'Usuario desconocido').toString();
                } else if (firma['usuario_nombre'] != null) {
                  usuarioNombre = firma['usuario_nombre'].toString();
                }
                final fechaFirma = firma['fecha_firma'];
                
                String fechaFormateada = 'Fecha no disponible';
                if (fechaFirma != null) {
                  try {
                    final dateTime = DateTime.parse(fechaFirma.toString());
                    fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
                  } catch (e) {
                    fechaFormateada = fechaFirma.toString();
                  }
                }

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esSupervisor ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: esSupervisor ? Colors.green[200]! : Colors.blue[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: esSupervisor ? Colors.green : Colors.blue,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esSupervisor ? 'Supervisor' : 'Control de Calidad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esSupervisor ? Colors.green[700] : Colors.blue[700],
                              ),
                            ),
                            Text(
                              usuarioNombre,
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              fechaFormateada,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),
            Divider(),

            // ========== BOTONES DE ACCIÓN ==========
            _buildBotonesAccion(),
          ],
        ),
      ),
    );
  }

  // ========== BOTONES DE ACCIÓN SEGÚN ROL ==========
  Widget _buildBotonesAccion() {
    // ========== SUPERVISOR ==========
    if (_esSupervisor) {
      // Si ya firmó, solo mostrar botón de editar (si no está en modo edición)
      if (_tieneFirmaSupervisor) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ya firmaste esta trazabilidad. No puedes modificarla.',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // No ha firmado: mostrar botón según modo
      if (_modoEdicion) {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _guardarCambios,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? 'Guardando...' : 'Guardar Cambios',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.all(16),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Los cambios no se guardarán hasta que presiones "Guardar Cambios".',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      } else {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _firmarTrazabilidad,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.edit_note, color: Colors.white),
                label: Text(
                  _isSaving ? 'Firmando...' : 'Firmar Trazabilidad',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.all(16),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Una vez firmada, no podrás modificar esta trazabilidad.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }
    }

    // ========== CONTROL DE CALIDAD ==========
    if (_esControlCalidad) {
      // Verificar si supervisor firmó primero
      if (!_tieneFirmaSupervisor) {
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.pending, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El supervisor debe firmar primero antes de que puedas revisar esta trazabilidad.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Supervisor ya firmó: mostrar controles de Control de Calidad
      return Column(
        children: [
          // Botón de Firmar (si no ha firmado)
          if (!_tieneFirmaCalidad) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _firmarTrazabilidad,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.verified, color: Colors.white),
                label: Text(
                  _isSaving ? 'Firmando...' : 'Firmar Revisión',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Firma la revisión para confirmar que revisaste la trazabilidad.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Divider(),
            const SizedBox(height: 8),
          ],

          // Botones de Cambiar Estado (siempre disponibles para Control de Calidad)
          Text(
            'Cambiar Estado del Producto',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              // Botón LIBERAR
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _estadoActual == 'liberado' 
                      ? null 
                      : () => _cambiarEstado('liberado'),
                  icon: Icon(
                    Icons.check_circle,
                    color: _estadoActual == 'liberado' 
                        ? Colors.grey 
                        : Colors.green,
                  ),
                  label: Text(
                    _estadoActual == 'liberado' ? 'Liberado' : 'Liberar',
                    style: TextStyle(
                      color: _estadoActual == 'liberado' 
                          ? Colors.grey 
                          : Colors.green,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _estadoActual == 'liberado' 
                          ? Colors.grey 
                          : Colors.green,
                      width: 2,
                    ),
                    backgroundColor: _estadoActual == 'liberado' 
                        ? Colors.grey.shade100 
                        : Colors.green.shade50,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Botón RETENER
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _estadoActual == 'retenido' 
                      ? null 
                      : () => _cambiarEstado('retenido'),
                  icon: Icon(
                    Icons.cancel,
                    color: _estadoActual == 'retenido' 
                        ? Colors.grey 
                        : Colors.red,
                  ),
                  label: Text(
                    _estadoActual == 'retenido' ? 'Retenido' : 'Retener',
                    style: TextStyle(
                      color: _estadoActual == 'retenido' 
                          ? Colors.grey 
                          : Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _estadoActual == 'retenido' 
                          ? Colors.grey 
                          : Colors.red,
                      width: 2,
                    ),
                    backgroundColor: _estadoActual == 'retenido' 
                        ? Colors.grey.shade100 
                        : Colors.red.shade50,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'Puedes cambiar el estado en cualquier momento, incluso después de firmar.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // ========== USUARIO SIN ROL VÁLIDO ==========
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        'No tienes permisos para realizar acciones en esta trazabilidad.',
        style: TextStyle(color: Colors.grey[700]),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ========== BUILD PRINCIPAL ==========
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
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarDatos,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70, 
        title: Text('Detalle de Trazabilidad',
          style: TextStyle(
            fontSize: 28,
          ),
        ),
        actions: [
          if (_esSupervisor && !_tieneFirmaSupervisor)
            IconButton(
              icon: Icon(_modoEdicion ? Icons.close : Icons.edit),
              onPressed: () {
                if (_modoEdicion) {
                  _cancelarEdicion();
                } else {
                  setState(() {
                    _modoEdicion = true;
                  });
                }
              },
              tooltip: _modoEdicion ? 'Cancelar edición' : 'Editar',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
        backgroundColor: primaryColorDark,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEncabezado(),
              _buildTablaColaboradores(),
              _buildTablaMateriales(),
              _buildSeccionFoto(),
              _buildObservaciones(),
              _buildSeccionFirmas(),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSeleccionarColaborador extends StatefulWidget {
  final List<Map<String, dynamic>> colaboradores;

  const _DialogSeleccionarColaborador({required this.colaboradores});

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
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: _colaboradoresFiltrados.isEmpty
                  ? Center(
                      child: Text('No se encontraron colaboradores'),
                    )
                  : ListView.builder(
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
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(nombreCompleto),
                            subtitle: Text('Código: ${colab['codigo']}'),
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
  String _causaSeleccionada = 'escasez_de_banado';
  
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
  String _causaSeleccionada = 'cayo_al_suelo';
  
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