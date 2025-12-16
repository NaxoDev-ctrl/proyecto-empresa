// ============================================================================
// PANTALLA: Lista de Trazabilidades para Control de Calidad
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'detalle_trazabilidad_supervisor_screen.dart';

const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);

class FirmaControlCalidadScreen extends StatefulWidget {
  const FirmaControlCalidadScreen({Key? key}) : super(key: key);

  @override
  State<FirmaControlCalidadScreen> createState() => _FirmaControlCalidadScreenState();
}

class _FirmaControlCalidadScreenState extends State<FirmaControlCalidadScreen> {
  // ========== ESTADO ==========
  bool _isLoading = false;
  List<Map<String, dynamic>> _trazabilidades = [];
  String? _error;

  // ========== FILTROS (IGUALES A SUPERVISOR) ==========
  DateTime? _fechaSeleccionada;
  String? _julianoFiltro;
  int? _turnoSeleccionado;
  int? _lineaSeleccionada;
  String? _productoSeleccionado;
  String? _productoNombreSeleccionado;

  final TextEditingController _julianoController = TextEditingController();

  // ========== DATOS PARA DROPDOWNS ==========
  List<Map<String, dynamic>> _turnos = [];
  List<Map<String, dynamic>> _lineas = [];
  List<Map<String, dynamic>> _productos = [];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _julianoController.dispose();
    super.dispose();
  }

  // ========== INICIALIZAR ==========
  Future<void> _inicializar() async {
    await _cargarTurnos();
    await _cargarLineas();
    await _cargarProductos();
    await _cargarTrazabilidades();
  }

  // ========== CARGAR TURNOS ==========
  Future<void> _cargarTurnos() async {
    try {
      final response = await _apiService.getTurnos();
      setState(() {
        _turnos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error al cargar turnos: $e');
    }
  }

  // ========== CARGAR LÍNEAS ==========
  Future<void> _cargarLineas() async {
    try {
      final response = await _apiService.getLineas();
      setState(() {
        _lineas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error al cargar líneas: $e');
    }
  }

  // ========== CARGAR PRODUCTOS ==========
  Future<void> _cargarProductos() async {
    try {
      final response = await _apiService.getProductos();
      setState(() {
        _productos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error al cargar productos: $e');
    }
  }

  // ========== CARGAR TRAZABILIDADES CON FILTROS ==========
  Future<void> _cargarTrazabilidades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<String, String> queryParams = {};

      if (_fechaSeleccionada != null) {
        queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada!);
      }

      if (_julianoFiltro != null && _julianoFiltro!.isNotEmpty) {
        queryParams['juliano'] = _julianoFiltro!;
      }

      if (_turnoSeleccionado != null) {
        queryParams['turno'] = _turnoSeleccionado.toString();
      }

      if (_lineaSeleccionada != null) {
        queryParams['linea'] = _lineaSeleccionada.toString();
      }

      if (_productoSeleccionado != null) {
        queryParams['producto'] = _productoSeleccionado!;
      }

      final response = await _apiService.getTrazabilidades(queryParams: queryParams);

      setState(() {
        _trazabilidades = List<Map<String, dynamic>>.from(response);
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = 'Error al cargar trazabilidades: $e, $stackTrace';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== LIMPIAR FILTROS ==========
  void _limpiarFiltros() {
    setState(() {
      _fechaSeleccionada = null;
      _julianoFiltro = null;
      _turnoSeleccionado = null;
      _lineaSeleccionada = null;
      _productoSeleccionado = null;
      _productoNombreSeleccionado = null;
      _julianoController.clear();
    });
    _cargarTrazabilidades();
  }

  // ========== MOSTRAR SELECTOR DE PRODUCTO ==========
  Future<void> _mostrarSelectorProducto() async {
    final resultado = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _DialogoSelectorProducto(productos: _productos),
    );

    if (resultado == null) {
      setState(() {
        _productoSeleccionado = null;
        _productoNombreSeleccionado = null;
      });
      _cargarTrazabilidades();
    } else {
      setState(() {
        _productoSeleccionado = resultado['codigo'];
        _productoNombreSeleccionado = resultado['nombre'];
      });
      _cargarTrazabilidades();
    }
  }

  // ========== UI: SELECTOR DE FECHA ==========
  Widget _buildSelectorFecha() {
    return InkWell(
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: _fechaSeleccionada ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2080),
        );

        if (fecha != null) {
          setState(() {
            _fechaSeleccionada = fecha;
          });
          _cargarTrazabilidades();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fechaSeleccionada == null
                  ? 'Seleccionar fecha'
                  : DateFormat('dd/MM/yyyy', 'es').format(_fechaSeleccionada!),
              style: TextStyle(
                color: _fechaSeleccionada == null ? Colors.grey[600] : Colors.black87,
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // ========== UI: SELECTOR DE JULIANO ==========
  Widget _buildSelectorJuliano() {
    return TextField(
      controller: _julianoController,
      decoration: InputDecoration(
        labelText: 'Día Juliano (001-366)',
        hintText: 'Ej: 345, 001, 200',
        prefixIcon: const Icon(Icons.calendar_month),
        suffixIcon: _julianoFiltro != null && _julianoFiltro!.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() {
                    _julianoFiltro = null;
                    _julianoController.clear();
                  });
                  _cargarTrazabilidades();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        helperText: 'Ingrese el día juliano del año (1-366)',
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      keyboardType: TextInputType.number,
      maxLength: 3,
      onChanged: (value) {
        if (value.isEmpty) {
          setState(() {
            _julianoFiltro = null;
          });
          _cargarTrazabilidades();
          return;
        }
        
        final numero = int.tryParse(value);
        if (numero != null && numero >= 1 && numero <= 366) {
          setState(() {
            _julianoFiltro = value;
          });
          _cargarTrazabilidades();
        }
      },
    );
  }

  // ========== UI: DROPDOWN TURNO ==========
  Widget _buildDropdownTurno() {
    return DropdownButtonFormField<int?>(
      value: _turnoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Turno',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos los turnos'),
        ),
        ..._turnos.map((turno) {
          return DropdownMenuItem<int?>(
            value: turno['id'] as int?,
            child: Text(turno['nombre'] ?? ''),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _turnoSeleccionado = value;
        });
        _cargarTrazabilidades();
      },
    );
  }

  // ========== UI: DROPDOWN LÍNEA ==========
  Widget _buildDropdownLinea() {
    return DropdownButtonFormField<int?>(
      value: _lineaSeleccionada,
      decoration: InputDecoration(
        labelText: 'Línea',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todas las líneas'),
        ),
        ..._lineas.map((linea) {
          return DropdownMenuItem<int?>(
            value: linea['id'] as int?,
            child: Text(linea['nombre'] ?? ''),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _lineaSeleccionada = value;
        });
        _cargarTrazabilidades();
      },
    );
  }

  // ========== UI: SELECTOR DE PRODUCTO ==========
  Widget _buildSelectorProducto() {
    return InkWell(
      onTap: _mostrarSelectorProducto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _productoSeleccionado == null
                    ? 'Todos los productos'
                    : '$_productoSeleccionado - $_productoNombreSeleccionado',
                style: TextStyle(
                  color: _productoSeleccionado == null ? Colors.grey[600] : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_productoSeleccionado != null)
                  IconButton(
                    icon: Icon(Icons.clear, size: 20, color: Colors.grey[600]),
                    onPressed: () {
                      setState(() {
                        _productoSeleccionado = null;
                        _productoNombreSeleccionado = null;
                      });
                      _cargarTrazabilidades();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                Icon(Icons.search, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== UI: SECCIÓN DE FILTROS ==========
  Widget _buildSeccionFiltros() {
    final hayFiltrosActivos = _fechaSeleccionada != null ||
        _julianoFiltro != null ||
        _turnoSeleccionado != null ||
        _lineaSeleccionada != null ||
        _productoSeleccionado != null;

    return Card(
      color: const Color.fromARGB(255, 224, 245, 214),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColorDark,
                  ),
                ),
                if (hayFiltrosActivos)
                  TextButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: const Icon(Icons.clear_all, size: 18, color: primaryColorDark),
                    label: const Text('Limpiar', style: TextStyle(color: primaryColorDark)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSelectorFecha(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectorJuliano(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdownTurno(),
            const SizedBox(height: 12),
            _buildDropdownLinea(),
            const SizedBox(height: 12),
            _buildSelectorProducto(),
          ],
        ),
      ),
    );
  }

  // ========== UI: TARJETA DE TRAZABILIDAD ==========
  Widget _buildTarjetaTrazabilidad(Map<String, dynamic> trazabilidad) {
    try {
      final hojaProcesos = trazabilidad['hoja_procesos'];
      
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

      final lote = trazabilidad['lote']?.toString() ?? '';
      final firmas = trazabilidad['firmas'] as List<dynamic>? ?? [];

      final tieneFirmaSupervisor = firmas.any(
        (firma) => firma is Map && firma['tipo_firma'] == 'supervisor',
      );

      final firmaSupervisor = tieneFirmaSupervisor
          ? firmas.firstWhere((firma) => firma is Map && firma['tipo_firma'] == 'supervisor')
          : null;

      final tieneFirmaCalidad = firmas.any(
        (firma) => firma is Map && firma['tipo_firma'] == 'control_calidad',
      );

      final firmaCalidad = tieneFirmaCalidad
          ? firmas.firstWhere((firma) => firma is Map && firma['tipo_firma'] == 'control_calidad')
          : null;

      // Extraer nombres de firmantes
      String? nombreFirmaSupervisor;
      String? nombreFirmaCalidad;

      if (firmaSupervisor != null && firmaSupervisor is Map) {
        nombreFirmaSupervisor = firmaSupervisor['usuario_nombre']?.toString();
      }

      if (firmaCalidad != null && firmaCalidad is Map) {
        nombreFirmaCalidad = firmaCalidad['usuario_nombre']?.toString();
      }

      // Formatear fecha de elaboración
      String fechaElaboracion = '';
      try {
        final fechaCreacion = DateTime.parse(trazabilidad['fecha_creacion']);
        fechaElaboracion = DateFormat('dd/MM/yy').format(fechaCreacion);
      } catch (e) {
        fechaElaboracion = 'N/A';
      }

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            final resultado = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetalleTrazabilidadSupervisorScreen(
                  trazabilidadId: trazabilidad['id'],
                ),
              ),
            );

            _cargarTrazabilidades();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ========== COLUMNA IZQUIERDA: Información ==========
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fecha
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Color.fromARGB(255, 137, 29, 67),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              fechaElaboracion,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Producto
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inventory,
                              size: 18,
                              color: Color.fromARGB(255, 137, 29, 67),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${producto['codigo']} - ${producto['nombre']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Lote
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.qr_code,
                              size: 18,
                              color: Color.fromARGB(255, 137, 29, 67),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lote,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Línea
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.conveyor_belt,
                              size: 18,
                              color: Color.fromARGB(255, 137, 29, 67),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              linea['nombre']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
              
                // ========== COLUMNA DERECHA: Firmas ==========
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ========== FILA: Firma Producción + Cuadro ==========
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Firma producción',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 150,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: tieneFirmaSupervisor 
                                    ? Colors.green 
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tieneFirmaSupervisor
                                    ? 'Firmado por\n${nombreFirmaSupervisor ?? 'Supervisor'}'
                                    : 'Pendiente',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        
                        const Divider(height: 20, color: Color.fromARGB(255, 136, 136, 136)),
                        
                        // ========== FILA: Firma Calidad + Cuadro ==========
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Firma calidad',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 150,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: tieneFirmaCalidad 
                                    ? _getColorEstado(trazabilidad['estado']?.toString())
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tieneFirmaCalidad
                                    ? '${_getTextoEstado(trazabilidad['estado']?.toString())} por\n${nombreFirmaCalidad ?? 'Control Calidad'}'
                                    : 'Pendiente',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 9),
                        
                        // Texto "Ver detalle"
                        Text(
                          'Ver detalle',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error al construir tarjeta de trazabilidad: $e');
      return const SizedBox.shrink();
    }
  }

  // ========== UI: LISTA DE TRAZABILIDADES ==========
  Widget _buildListaTrazabilidades() {
    if (_trazabilidades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No se encontraron trazabilidades',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${_trazabilidades.length} trazabilidad(es) encontrada(s)',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _trazabilidades.length,
            itemBuilder: (context, index) {
              return _buildTarjetaTrazabilidad(_trazabilidades[index]);
            },
          ),
        ),
      ],
    );
  }

  // ========== MÉTODOS AUXILIARES PARA ESTADOS ==========
  
  /// Obtiene el color según el estado de la trazabilidad
  Color _getColorEstado(String? estado) {
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
  
  /// Obtiene el texto según el estado de la trazabilidad
  String _getTextoEstado(String? estado) {
    switch (estado) {
      case 'liberado':
        return 'Liberado';
      case 'retenido':
        return 'Retenido';
      case 'en_revision':
        return 'En revisión';
      default:
        return 'En revisión';
    }
  }

  // ========== BUILD PRINCIPAL ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _cargarTrazabilidades,
        child: Column(
          children: [
            _buildSeccionFiltros(),
            Expanded(
              child: _isLoading
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
                                  onPressed: _cargarTrazabilidades,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildListaTrazabilidades(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIÁLOGO: Selector de Producto con Búsqueda (IDÉNTICO A SUPERVISOR)
// ============================================================================
class _DialogoSelectorProducto extends StatefulWidget {
  final List<Map<String, dynamic>> productos;

  const _DialogoSelectorProducto({required this.productos});

  @override
  State<_DialogoSelectorProducto> createState() => _DialogoSelectorProductoState();
}

class _DialogoSelectorProductoState extends State<_DialogoSelectorProducto> {
  final TextEditingController _busquedaController = TextEditingController();
  List<Map<String, dynamic>> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _productosFiltrados = widget.productos;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _filtrarProductos(String query) {
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = widget.productos;
      } else {
        final queryLower = query.toLowerCase();
        _productosFiltrados = widget.productos.where((producto) {
          final codigo = (producto['codigo'] ?? '').toString().toLowerCase();
          final nombre = (producto['nombre'] ?? '').toString().toLowerCase();
          return codigo.contains(queryLower) || nombre.contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Seleccionar Producto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                          _filtrarProductos('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filtrarProductos,
            ),
            const SizedBox(height: 16),

            ListTile(
              title: const Text(
                'Todos los productos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.select_all),
              onTap: () {
                Navigator.pop(context, null);
              },
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _productosFiltrados.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron productos',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        final codigo = producto['codigo']?.toString() ?? '';
                        final nombre = producto['nombre']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              codigo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            subtitle: Text(
                              nombre,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                            onTap: () {
                              Navigator.pop(context, {
                                'codigo': codigo,
                                'nombre': nombre,
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}