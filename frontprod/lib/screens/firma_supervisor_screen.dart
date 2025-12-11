// ============================================================================
// PANTALLA: Lista de Firmas de Supervisor
// VERSIÓN MEJORADA - Con búsqueda de productos
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import 'detalle_trazabilidad_supervisor_screen.dart';

class FirmaSupervisorScreen extends StatefulWidget {
  const FirmaSupervisorScreen({Key? key}) : super(key: key);

  @override
  State<FirmaSupervisorScreen> createState() => _FirmaSupervisorScreenState();
}

class _FirmaSupervisorScreenState extends State<FirmaSupervisorScreen> {
  // ========== ESTADO ==========
  bool _isLoading = false;
  List<Map<String, dynamic>> _trazabilidades = [];
  String? _error;

  // ========== FILTROS ==========
  DateTime? _fechaSeleccionada;
  int? _turnoSeleccionado;
  int? _lineaSeleccionada;
  String? _productoSeleccionado;
  String? _productoNombreSeleccionado;  // <-- Para mostrar en UI

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
    print('\n🔵🔵🔵 INICIANDO _cargarTrazabilidades 🔵🔵🔵');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<String, String> queryParams = {};

      if (_fechaSeleccionada != null) {
        queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada!);
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

      print('🔵 Query params: $queryParams');

      final response = await _apiService.getTrazabilidades(queryParams: queryParams);

      print('🔵 RESPUESTA RECIBIDA:');
      print('🔵 Tipo: ${response.runtimeType}');
      print('🔵 Cantidad: ${response.length}');
      
      if (response.isNotEmpty) {
        print('🔵 Primera trazabilidad:');
        print(response[0]);
        print('🔵 Tipo de hoja_procesos: ${response[0]['hoja_procesos'].runtimeType}');
        if (response[0]['hoja_procesos'] is Map) {
          print('🔵 Tipo de tarea: ${response[0]['hoja_procesos']['tarea'].runtimeType}');
        }
      }

      setState(() {
        _trazabilidades = List<Map<String, dynamic>>.from(response);
        print('🔵 _trazabilidades tiene ${_trazabilidades.length} elementos');
      });
    } catch (e, stackTrace) {
      print('🔴 ERROR al cargar trazabilidades: $e');
      print('🔴 Stack trace: $stackTrace');
      setState(() {
        _error = 'Error al cargar trazabilidades: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('🔵🔵🔵 FIN _cargarTrazabilidades 🔵🔵🔵\n');
    }
  }

  // ========== LIMPIAR FILTROS ==========
  void _limpiarFiltros() {
    setState(() {
      _fechaSeleccionada = null;
      _turnoSeleccionado = null;
      _lineaSeleccionada = null;
      _productoSeleccionado = null;
      _productoNombreSeleccionado = null;
    });
    _cargarTrazabilidades();
  }

  // ========== MOSTRAR SELECTOR DE PRODUCTO CON BÚSQUEDA ==========
  Future<void> _mostrarSelectorProducto() async {
    final resultado = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _DialogoSelectorProducto(productos: _productos),
    );

    // Si resultado es null, significa "Todos los productos"
    if (resultado == null) {
      setState(() {
        _productoSeleccionado = null;
        _productoNombreSeleccionado = null;
      });
      _cargarTrazabilidades();
    } else {
      // Si resultado tiene datos, es un producto específico
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
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
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
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fechaSeleccionada == null
                  ? 'Seleccionar fecha'
                  : DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!),
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

  // ========== UI: SELECTOR DE PRODUCTO CON BÚSQUEDA ==========
  Widget _buildSelectorProducto() {
    return InkWell(
      onTap: _mostrarSelectorProducto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
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
        _turnoSeleccionado != null ||
        _lineaSeleccionada != null ||
        _productoSeleccionado != null;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (hayFiltrosActivos)
                  TextButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Limpiar'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSelectorFecha(),
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
      
      // Verificar que hoja_procesos sea un mapa
      if (hojaProcesos == null || hojaProcesos is! Map<String, dynamic>) {
        return const SizedBox.shrink();
      }

      final tarea = hojaProcesos['tarea'];
      
      // Verificar que tarea sea un mapa
      if (tarea == null || tarea is! Map<String, dynamic>) {
        return const SizedBox.shrink();
      }

      final producto = tarea['producto'];
      final linea = tarea['linea'];
      final turno = tarea['turno'];
      
      // Verificar que los objetos anidados sean mapas
      if (producto == null || producto is! Map<String, dynamic> ||
          linea == null || linea is! Map<String, dynamic> ||
          turno == null || turno is! Map<String, dynamic>) {
        return const SizedBox.shrink();
      }

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

      

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

            if (resultado == true) {
              _cargarTrazabilidades();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            producto['nombre']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Código: ${producto['codigo']?.toString() ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tieneFirmaSupervisor ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tieneFirmaSupervisor ? Icons.check_circle : Icons.pending,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tieneFirmaSupervisor ? 'Supervisor ✓' : 'Sin firmar',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tieneFirmaCalidad 
                                ? Colors.blue 
                                : (tieneFirmaSupervisor ? Colors.grey : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tieneFirmaCalidad ? Icons.verified : Icons.hourglass_empty,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tieneFirmaCalidad 
                                    ? 'Calidad ✓' 
                                    : (tieneFirmaSupervisor ? 'Pendiente' : 'N/A'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.factory, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      linea['nombre']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      turno['nombre']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Creada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(trazabilidad['fecha_creacion']))}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),

                if (tieneFirmaSupervisor || tieneFirmaCalidad) ...[
                  const Divider(height: 24),
                  
                  // Firma de Supervisor
                  if (tieneFirmaSupervisor && firmaSupervisor != null && firmaSupervisor is Map) ...[
                    Row(
                      children: [
                        Icon(Icons.edit_note, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Firmada por ${firmaSupervisor['usuario_nombre']?.toString() ?? ''} el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(firmaSupervisor['fecha_firma']))}',
                            style: TextStyle(fontSize: 11, color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Firma de Control de Calidad
                  if (tieneFirmaCalidad && firmaCalidad != null && firmaCalidad is Map) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Firmada por ${firmaCalidad['usuario_nombre']?.toString() ?? ''} el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(firmaCalidad['fecha_firma']))}',
                            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
      print('Datos de trazabilidad: $trazabilidad');
      return const SizedBox.shrink();
    }
  }

  // ========== UI: LISTA DE TRAZABILIDADES ==========
  Widget _buildListaTrazabilidades() {
    print('🟢 _buildListaTrazabilidades llamado con ${_trazabilidades.length} trazabilidades');
    
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
              print('🟢 Construyendo tarjeta $index');
              return _buildTarjetaTrazabilidad(_trazabilidades[index]);
            },
          ),
        ),
      ],
    );
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
// DIÁLOGO: Selector de Producto con Búsqueda
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
            // Título
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

            // Campo de búsqueda
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

            // Opción "Todos"
            ListTile(
              title: const Text(
                'Todos los productos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.select_all),
              onTap: () {
                Navigator.pop(context, null);  // ← Retornar null para "Todos"
              },
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),

            // Lista de productos filtrados
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
                              codigo,  // ← CÓDIGO ARRIBA EN GRANDE
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            subtitle: Text(
                              nombre,  // ← NOMBRE ABAJO MÁS PEQUEÑO
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