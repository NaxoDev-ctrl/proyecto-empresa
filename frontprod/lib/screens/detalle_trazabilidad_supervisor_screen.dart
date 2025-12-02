// ============================================================================
// PANTALLA: Detalle de Trazabilidad para Supervisor - VERSIÓN CORREGIDA
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

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

class _DetalleTrazabilidadSupervisorScreenState
    extends State<DetalleTrazabilidadSupervisorScreen> {
  // ========== ESTADO ==========
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _trazabilidad;
  String? _error;
  bool _modoEdicion = false;

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

  Uint8List? _fotoEtiqueta;
  String? _nombreArchivoFoto;
  String? _fotoEtiquetasUrl;
  
  // Materias primas: Map<materia_prima_id, Map<lote, cantidad, unidad>>
  Map<String, Map<String, dynamic>> _materiasPrimasEditadas = {};
  
  // Reprocesos y mermas
  List<Map<String, dynamic>> _reprocesosEditados = [];
  List<Map<String, dynamic>> _mermasEditadas = [];
  
  // Colaboradores
  List<Map<String, dynamic>> _colaboradoresSeleccionados = [];
  List<Map<String, dynamic>> _todosColaboradores = [];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _cargarTrazabilidad();
  }

  @override
  void dispose() {
    _cantidadProducidaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // ========== CARGAR TRAZABILIDAD ==========
  Future<void> _cargarTrazabilidad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 Cargando trazabilidad ${widget.trazabilidadId}...');
      
      final data = await _apiService.getTrazabilidadDetalle(widget.trazabilidadId);
      print('📦 Datos recibidos: ${data.toString()}');
      
      // Cargar todos los colaboradores disponibles
      final todosColabs = await _apiService.getColaboradores();
      print('👥 Colaboradores disponibles: ${todosColabs.length}');

      setState(() {
        _trazabilidad = data;
        
        // ========== INICIALIZAR DATOS ORIGINALES ==========
        _cantidadProducidaOriginal = (data['cantidad_producida']?? 0).toString();
        _observacionesOriginal = data['observaciones'] ?? '';
        
        // Inicializar controllers
        _cantidadProducidaController.text = _cantidadProducidaOriginal;
        _observacionesController.text = _observacionesOriginal ?? '';
        
        // ========== MATERIAS PRIMAS ORIGINALES ==========
        _materiasPrimasOriginales.clear();
        _materiasPrimasEditadas.clear();
        
        final mpUsadas = data['materias_primas_usadas'] as List? ?? [];
        print('🧪 Materias primas usadas: ${mpUsadas.length}');
        
        for (var mp in mpUsadas) {
          final mpDetalle = mp['materia_prima_detalle'] ?? mp['materia_prima'];
          final codigo = mpDetalle['codigo'].toString();
          
          final mpData = {
            'id': mp['id'],
            'materia_prima_id': codigo,
            'nombre': mpDetalle['nombre'],
            'lote': mp['lote'] ?? '',
            'cantidad_usada': mp['cantidad_usada']?.toString() ?? '',
            'unidad_medida': mp['unidad_medida'] ?? 'kg',
            'requiere_lote': mpDetalle['requiere_lote'] ?? false,
          };
          
          _materiasPrimasOriginales[codigo] = Map<String, dynamic>.from(mpData);
          _materiasPrimasEditadas[codigo] = Map<String, dynamic>.from(mpData);
        }
        
        // ========== REPROCESOS ORIGINALES ==========
        final reprocesos = data['reprocesos'] as List? ?? [];
        print('♻️ Reprocesos: ${reprocesos.length}');
        
        _reprocesosOriginales = reprocesos.map((r) => Map<String, dynamic>.from(r)).toList();
        _reprocesosEditados = reprocesos.map((r) => Map<String, dynamic>.from(r)).toList();
        
        // ========== MERMAS ORIGINALES ==========
        final mermas = data['mermas'] as List? ?? [];
        print('🗑️ Mermas: ${mermas.length}');
        
        _mermasOriginales = mermas.map((m) => Map<String, dynamic>.from(m)).toList();
        _mermasEditadas = mermas.map((m) => Map<String, dynamic>.from(m)).toList();
        
        // ========== COLABORADORES ORIGINALES ==========
        final colaboradoresReales = data['colaboradores_reales'] as List? ?? [];
        print('👷 Colaboradores en trazabilidad: ${colaboradoresReales.length}');
        print('📋 Datos colaboradores: $colaboradoresReales');
        
        _colaboradoresOriginales = colaboradoresReales.map<Map<String, dynamic>>((c) {
          // Extraer datos del colaborador
          final colaborador = c is Map && c.containsKey('colaborador') 
              ? c['colaborador'] 
              : c;
          
          if (colaborador == null || colaborador is! Map) {
            print('⚠️ Colaborador inválido: $c');
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
        
        print('✅ Colaboradores cargados: $_colaboradoresSeleccionados');
        
        // Guardar todos los colaboradores disponibles
        _todosColaboradores = todosColabs.map<Map<String, dynamic>>((c) {
          final codigo = c['codigo'];
          final codigoInt = codigo is int ? codigo : int.tryParse(codigo.toString()) ?? 0;
          
          return {
            'codigo': codigoInt,
            'nombre': c['nombre']?.toString() ?? '',
            'apellido': c['apellido']?.toString() ?? '',
          };
        }).toList();
        
        print('✅ Total colaboradores disponibles: ${_todosColaboradores.length}');
        // ========== CARGAR FOTO DE ETIQUETAS ==========
        if (data['foto_etiquetas'] != null && 
            data['foto_etiquetas'].toString().isNotEmpty) {
          setState(() {
            _fotoEtiquetasUrl = data['foto_etiquetas'];
          });
          print('📷 Foto etiquetas cargada: $_fotoEtiquetasUrl');
        } else {
          print('⚠️ No hay foto de etiquetas guardada');
        }
      });

    } catch (e) {
      print('❌ ERROR al cargar trazabilidad: $e');
      setState(() {
        _error = 'Error al cargar trazabilidad: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== CANCELAR EDICIÓN (REVERTIR CAMBIOS) ==========
  void _cancelarEdicion() {
    setState(() {
      // Revertir controllers
      _cantidadProducidaController.text = _cantidadProducidaOriginal;
      _observacionesController.text = _observacionesOriginal;
      
      // Revertir materias primas
      _materiasPrimasEditadas.clear();
      for (var entry in _materiasPrimasOriginales.entries) {
        _materiasPrimasEditadas[entry.key] = Map<String, dynamic>.from(entry.value);
      }
      
      // Revertir reprocesos
      _reprocesosEditados = _reprocesosOriginales.map(
        (r) => Map<String, dynamic>.from(r)
      ).toList();
      
      // Revertir mermas
      _mermasEditadas = _mermasOriginales.map(
        (m) => Map<String, dynamic>.from(m)
      ).toList();
      
      // Revertir colaboradores
      _colaboradoresSeleccionados = _colaboradoresOriginales.map(
        (c) => Map<String, dynamic>.from(c)
      ).toList();
      
      // Salir del modo edición
      _modoEdicion = false;
    });
    
    print('↩️ Cambios revertidos');
  }

  // ========== GUARDAR CAMBIOS ==========
  Future<void> _guardarCambios() async {
    print('💾 Iniciando guardado de cambios...');
    
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
    for (var mp in _materiasPrimasEditadas.values) {
      final cantidadStr = mp['cantidad_usada'].toString().trim();
      if (cantidadStr.isEmpty || double.tryParse(cantidadStr) == null) {
        _mostrarError('Completa todas las cantidades de materias primas');
        return;
      }
      
      if (mp['requiere_lote'] == true) {
        final lote = mp['lote']?.toString().trim() ?? '';
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
      // Preparar datos para enviar
      final datos = {
        'cantidad_producida': cantidadProducida,
        'observaciones': _observacionesController.text.trim(),
        'materias_primas': _materiasPrimasEditadas.values.map((mp) {
          final lote = mp['lote']?.toString().trim() ?? '';
          return {
            'materia_prima_id': mp['materia_prima_id'],
            'lote': lote.isEmpty ? null : lote,
            'cantidad_usada': double.parse(mp['cantidad_usada'].toString()),
            'unidad_medida': mp['unidad_medida'],
          };
        }).toList(),
        'reprocesos_data': _reprocesosEditados.map((r) => {
          'cantidad_kg': r['cantidad_kg'] is double 
              ? r['cantidad_kg'] 
              : double.parse(r['cantidad_kg'].toString()),
          'descripcion': r['descripcion']?.toString() ?? '',
        }).toList(),
        'mermas_data': _mermasEditadas.map((m) => {
          'cantidad_kg': m['cantidad_kg'] is double 
              ? m['cantidad_kg'] 
              : double.parse(m['cantidad_kg'].toString()),
          'descripcion': m['descripcion']?.toString() ?? '',
        }).toList(),
        'colaboradores_codigos': _colaboradoresSeleccionados
            .map((c) => c['codigo'] as int)
            .toList(),
      };

      print('📤 Datos a enviar: $datos');

      // ========================================================================
      // SIEMPRE ENVIAR CON FOTO (nueva o existente)
      // ========================================================================
      List<int>? fotoBytesParaEnviar;
      String? nombreArchivoParaEnviar;

      if (_fotoEtiqueta != null) {
        // Hay foto NUEVA cargada en memoria
        print('📷 Enviando NUEVA foto...');
        fotoBytesParaEnviar = _fotoEtiqueta;
        nombreArchivoParaEnviar = _nombreArchivoFoto ?? 
            'etiqueta_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (_fotoEtiquetasUrl != null) {
        // Solo hay URL de foto existente - NO enviar foto (el backend la mantiene)
        print('📷 Manteniendo foto existente (URL: $_fotoEtiquetasUrl)');
        fotoBytesParaEnviar = null;
        nombreArchivoParaEnviar = null;
      }

      // Llamar al método unificado
      await _apiService.updateTrazabilidad(
        widget.trazabilidadId,
        datos,
        fotoBytes: fotoBytesParaEnviar,
        nombreArchivo: nombreArchivoParaEnviar,
      );

      print('✅ Cambios guardados exitosamente');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Salir del modo edición
        setState(() {
          _modoEdicion = false;
        });

        // Recargar datos del servidor
        await _cargarTrazabilidad();
      }
    } catch (e) {
      print('❌ ERROR al guardar: $e');
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
  void _agregarReproceso() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _DialogReproceso(),
    );
    
    if (resultado != null) {
      setState(() {
        _reprocesosEditados.add(resultado);
      });
      print('✅ Reproceso agregado: $resultado');
    }
  }

  void _eliminarReproceso(int index) {
    setState(() {
      _reprocesosEditados.removeAt(index);
    });
  }

  // ========== AGREGAR/ELIMINAR MERMA ==========
  void _agregarMerma() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _DialogMerma(),
    );
    
    if (resultado != null) {
      setState(() {
        _mermasEditadas.add(resultado);
      });
      print('✅ Merma agregada: $resultado');
    }
  }

  void _eliminarMerma(int index) {
    setState(() {
      _mermasEditadas.removeAt(index);
    });
  }

  // ========== AGREGAR/ELIMINAR COLABORADOR ==========
  Future<void> _agregarColaborador() async {
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Firma'),
        content: const Text(
          '¿Estás seguro de que deseas firmar esta trazabilidad?\n\n'
          'Una vez firmada, no podrás modificarla.',
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

    setState(() {
      _isSaving = true;
    });

    try {
      await _apiService.firmarTrazabilidad(widget.trazabilidadId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trazabilidad firmada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        await _cargarTrazabilidad();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al firmar: $e');
      }
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

  // ========== UI: INFORMACIÓN DE LA TAREA ==========
  Widget _buildSeccionTarea() {
    final hojaProcesos = _trazabilidad!['hoja_procesos_detalle'];
    if (hojaProcesos == null || hojaProcesos is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final tarea = hojaProcesos['tarea'];
    if (tarea == null || tarea is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final producto = tarea['producto'];
    final linea = tarea['linea'];
    final turno = tarea['turno'];

    if (producto == null || producto is! Map<String, dynamic> ||
        linea == null || linea is! Map<String, dynamic> ||
        turno == null || turno is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final fecha = tarea['fecha'];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Producto', producto['nombre']?.toString() ?? ''),
            _buildInfoRow('Código', producto['codigo']?.toString() ?? ''),
            _buildInfoRow('Línea', linea['nombre']?.toString() ?? ''),
            _buildInfoRow('Turno', turno['nombre']?.toString() ?? ''),
            _buildInfoRow(
              'Fecha', 
              fecha != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha)) : ''
            ),
            _buildInfoRow(
              'Fecha Creación',
              DateFormat('dd/MM/yyyy HH:mm').format(
                DateTime.parse(_trazabilidad!['fecha_creacion']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== UI: CANTIDAD PRODUCIDA Y OBSERVACIONES ==========
  Widget _buildSeccionProduccion() {
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Producción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (!tieneFirmaSupervisor)
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
                    tooltip: _modoEdicion ? 'Cancelar' : 'Editar',
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Cantidad Producida
            if (_modoEdicion)
              TextFormField(
                controller: _cantidadProducidaController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad Producida',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.production_quantity_limits),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              )
            else
              _buildInfoRow(
                'Cantidad Producida',
                '${_trazabilidad!['cantidad_producida']} unidades',
              ),

            const SizedBox(height: 16),

            // Observaciones
            if (_modoEdicion)
              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observaciones:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  // ========== UI: MATERIAS PRIMAS ==========
  Widget _buildSeccionMateriasPrimas() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Materias Primas Utilizadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            if (_materiasPrimasEditadas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay materias primas registradas'),
                ),
              )
            else
              ..._materiasPrimasEditadas.values.map((mp) {
                return _buildMateriaPrimaItem(mp);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriaPrimaItem(Map<String, dynamic> mp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: _modoEdicion ? Colors.blue.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mp['nombre'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          
          // Lote
          if (mp['requiere_lote']) ...[
            if (_modoEdicion)
              TextFormField(
                initialValue: mp['lote'],
                decoration: const InputDecoration(
                  labelText: 'Lote',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  mp['lote'] = value;
                },
              )
            else
              Text('Lote: ${mp['lote']}'),
            const SizedBox(height: 8),
          ],
          
          // Cantidad
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _modoEdicion
                    ? TextFormField(
                        initialValue: mp['cantidad_usada'].toString(),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          mp['cantidad_usada'] = value;
                        },
                      )
                    : Text('Cantidad: ${mp['cantidad_usada']} ${mp['unidad_medida']}'),
              ),
              if (_modoEdicion) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: mp['unidad_medida'],
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'unidades', child: Text('unidades')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        mp['unidad_medida'] = value!;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  // UI de seleccionar foto de etiquetas
  Widget _buildFotoEtiquetas() {
    // Determinar si hay foto (nueva o existente)
    final bool hayFoto = _fotoEtiqueta != null || _fotoEtiquetasUrl != null;
    
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
            
            if (!hayFoto)
              // NO HAY FOTO: Mostrar botones para agregar
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
              // HAY FOTO: Mostrar preview
              Column(
                children: [
                  // Preview de la imagen
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _fotoEtiqueta != null
                        ? Image.memory(
                            _fotoEtiqueta!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _fotoEtiquetasUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
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
                                height: 200,
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
                  const SizedBox(height: 12),
                  
                  // Botones de acción (solo en modo edición)
                  if (_modoEdicion)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tomarFoto,
                            icon: Icon(Icons.refresh),
                            label: Text('Cambiar Foto'),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    // Vista de solo lectura
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

  // ========== UI: COLABORADORES ==========
  Widget _buildSeccionColaboradores() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Colaboradores (${_colaboradoresSeleccionados.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (_modoEdicion)
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: _agregarColaborador,
                    tooltip: 'Agregar',
                  ),
              ],
            ),
            const Divider(),
            if (_colaboradoresSeleccionados.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay colaboradores asignados'),
                ),
              )
            else
              ..._colaboradoresSeleccionados.asMap().entries.map((entry) {
                final index = entry.key;
                final colab = entry.value;
                final nombreCompleto = '${colab['nombre']} ${colab['apellido']}';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: _modoEdicion ? Colors.indigo.shade50 : Colors.white,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        colab['nombre'].toString()[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Código: ${colab['codigo']}'),
                    trailing: _modoEdicion
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarColaborador(index),
                          )
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ========== UI: REPROCESOS ==========
  Widget _buildSeccionReprocesos() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.loop, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reprocesos (${_reprocesosEditados.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
                if (_modoEdicion)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _agregarReproceso,
                    tooltip: 'Agregar',
                  ),
              ],
            ),
            const Divider(),
            if (_reprocesosEditados.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay reprocesos registrados'),
                ),
              )
            else
              ..._reprocesosEditados.asMap().entries.map((entry) {
                final index = entry.key;
                final reproceso = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${reproceso['cantidad_kg']} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reproceso['descripcion'] ?? 'Sin descripción',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      if (_modoEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarReproceso(index),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ========== UI: MERMAS ==========
  Widget _buildSeccionMermas() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mermas (${_mermasEditadas.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                if (_modoEdicion)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _agregarMerma,
                    tooltip: 'Agregar',
                  ),
              ],
            ),
            const Divider(),
            if (_mermasEditadas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay mermas registradas'),
                ),
              )
            else
              ..._mermasEditadas.asMap().entries.map((entry) {
                final index = entry.key;
                final merma = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${merma['cantidad_kg']} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              merma['descripcion'] ?? 'Sin descripción',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      if (_modoEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarMerma(index),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ========== UI: FIRMAS ==========
  Widget _buildSeccionFirmas() {
    final firmas = _trazabilidad!['firmas'] as List;
    final tieneFirmaSupervisor = firmas.any((f) => f['tipo_firma'] == 'supervisor');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firmas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),

            if (firmas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Sin firmas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...firmas.map((firma) {
                final esSupervisor = firma['tipo_firma'] == 'supervisor';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(width: 12),
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
                              firma['usuario_nombre'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                DateTime.parse(firma['fecha_firma']),
                              ),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Botón de firma o guardar cambios
            if (!tieneFirmaSupervisor) ...[
              const SizedBox(height: 16),
              if (_modoEdicion)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _guardarCambios,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _firmarTrazabilidad,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.edit_note),
                    label: Text(_isSaving ? 'Firmando...' : 'Firmar Trazabilidad'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _modoEdicion 
                    ? 'Los cambios no se guardarán hasta que presiones "Guardar Cambios".'
                    : 'Una vez firmada, no podrás modificar esta trazabilidad.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== HELPER: FILA DE INFORMACIÓN ==========
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ========== BUILD PRINCIPAL ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Trazabilidad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarTrazabilidad,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarTrazabilidad,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarTrazabilidad,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSeccionTarea(),
                        _buildSeccionProduccion(),
                        _buildSeccionMateriasPrimas(),
                        _buildSeccionColaboradores(),
                        _buildSeccionReprocesos(),
                        _buildSeccionMermas(),
                        _buildFotoEtiquetas(),
                        _buildSeccionFirmas(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ============================================================================
// DIÁLOGOS (sin cambios)
// ============================================================================

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
      title: const Row(
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: _colaboradoresFiltrados.isEmpty
                  ? const Center(
                      child: Text('No se encontraron colaboradores'),
                    )
                  : ListView.builder(
                      itemCount: _colaboradoresFiltrados.length,
                      itemBuilder: (context, index) {
                        final colab = _colaboradoresFiltrados[index];
                        final nombreCompleto = 
                            '${colab['nombre']} ${colab['apellido']}';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Text(
                                colab['nombre'].toString()[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
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
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _DialogReproceso extends StatefulWidget {
  const _DialogReproceso();

  @override
  State<_DialogReproceso> createState() => _DialogReprocesoState();
}

class _DialogReprocesoState extends State<_DialogReproceso> {
  final _cantidadController = TextEditingController();
  final _otroController = TextEditingController();
  final List<String> _causasDisponibles = [
    'Producto fuera de especificación',
    'Error en proceso',
    'Problema de temperatura',
    'Contaminación cruzada',
    'Devolución de cliente',
    'Exceso de producción',
    'Otros',
  ];
  final Set<String> _causasSeleccionadas = {};

  @override
  void dispose() {
    _cantidadController.dispose();
    _otroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool otrosSeleccionado = _causasSeleccionadas.contains('Otros');
    
    return AlertDialog(
      title: const Text('Agregar Reproceso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cantidadController,
              decoration: const InputDecoration(
                labelText: 'Cantidad (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            const Text(
              'Causas del reproceso:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._causasDisponibles.map((causa) => CheckboxListTile(
              title: Text(causa),
              value: _causasSeleccionadas.contains(causa),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _causasSeleccionadas.add(causa);
                  } else {
                    _causasSeleccionadas.remove(causa);
                    // Si deselecciona "Otros", limpiar el campo
                    if (causa == 'Otros') {
                      _otroController.clear();
                    }
                  }
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
            // Campo de texto que aparece solo si "Otros" está seleccionado
            if (otrosSeleccionado) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otroController,
                decoration: const InputDecoration(
                  labelText: 'Especifique otra causa',
                  border: OutlineInputBorder(),
                  hintText: 'Describa la causa',
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final cantidad = double.tryParse(_cantidadController.text);
            if (cantidad == null || cantidad <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingrese una cantidad válida')),
              );
              return;
            }
            
            if (_causasSeleccionadas.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seleccione al menos una causa')),
              );
              return;
            }

            // Validar que si seleccionó "Otros", haya escrito algo
            if (otrosSeleccionado && _otroController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Especifique la otra causa')),
              );
              return;
            }

            // Construir la descripción
            final causas = _causasSeleccionadas.toList();
            
            // Si "Otros" está seleccionado, reemplazarlo con el texto ingresado
            if (otrosSeleccionado) {
              causas.remove('Otros');
              causas.add('Otros: ${_otroController.text.trim()}');
            }
            
            Navigator.pop(context, {
              'cantidad_kg': cantidad,
              'descripcion': causas.join(', '),
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _DialogMerma extends StatefulWidget {
  const _DialogMerma();

  @override
  State<_DialogMerma> createState() => _DialogMermaState();
}

class _DialogMermaState extends State<_DialogMerma> {
  final _cantidadController = TextEditingController();
  final _otroController = TextEditingController();
  final List<String> _causasDisponibles = [
    'Desperdicio de proceso',
    'Producto no conforme',
    'Limpieza de equipos',
    'Calibración de máquinas',
    'Cambio de formato',
    'Residuos de producción',
    'Otros',
  ];
  final Set<String> _causasSeleccionadas = {};

  @override
  void dispose() {
    _cantidadController.dispose();
    _otroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool otrosSeleccionado = _causasSeleccionadas.contains('Otros');
    
    return AlertDialog(
      title: const Text('Agregar Merma'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cantidadController,
              decoration: const InputDecoration(
                labelText: 'Cantidad (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            const Text(
              'Causas de la merma:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._causasDisponibles.map((causa) => CheckboxListTile(
              title: Text(causa),
              value: _causasSeleccionadas.contains(causa),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _causasSeleccionadas.add(causa);
                  } else {
                    _causasSeleccionadas.remove(causa);
                    // Si deselecciona "Otros", limpiar el campo
                    if (causa == 'Otros') {
                      _otroController.clear();
                    }
                  }
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
            // Campo de texto que aparece solo si "Otros" está seleccionado
            if (otrosSeleccionado) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otroController,
                decoration: const InputDecoration(
                  labelText: 'Especifique otra causa',
                  border: OutlineInputBorder(),
                  hintText: 'Describa la causa',
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final cantidad = double.tryParse(_cantidadController.text);
            if (cantidad == null || cantidad <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingrese una cantidad válida')),
              );
              return;
            }
            
            if (_causasSeleccionadas.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seleccione al menos una causa')),
              );
              return;
            }

            // Validar que si seleccionó "Otros", haya escrito algo
            if (otrosSeleccionado && _otroController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Especifique la otra causa')),
              );
              return;
            }

            // Construir la descripción
            final causas = _causasSeleccionadas.toList();
            
            // Si "Otros" está seleccionado, reemplazarlo con el texto ingresado
            if (otrosSeleccionado) {
              causas.remove('Otros');
              causas.add('Otros: ${_otroController.text.trim()}');
            }
            
            Navigator.pop(context, {
              'cantidad_kg': cantidad,
              'descripcion': causas.join(', '),
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}