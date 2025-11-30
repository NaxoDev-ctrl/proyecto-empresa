// ============================================================================
// PANTALLA: Lista de Firmas de Supervisor
// Muestra trazabilidades con filtros múltiples y permite navegar a detalle
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
  int? _productoSeleccionado;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Construir query params según filtros activos
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
        queryParams['producto'] = _productoSeleccionado.toString();
      }

      final response = await _apiService.getTrazabilidades(queryParams: queryParams);

      setState(() {
        _trazabilidades = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar trazabilidades: $e';
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
      _turnoSeleccionado = null;
      _lineaSeleccionada = null;
      _productoSeleccionado = null;
    });
    _cargarTrazabilidades();
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
          locale: const Locale('es', 'ES'),
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
    return DropdownButtonFormField<int>(
      value: _turnoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Turno',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Todos los turnos'),
        ),
        ..._turnos.map((turno) {
          return DropdownMenuItem<int>(
            value: turno['id'],
            child: Text(turno['nombre']),
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
    return DropdownButtonFormField<int>(
      value: _lineaSeleccionada,
      decoration: InputDecoration(
        labelText: 'Línea',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Todas las líneas'),
        ),
        ..._lineas.map((linea) {
          return DropdownMenuItem<int>(
            value: linea['id'],
            child: Text(linea['nombre']),
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

  // ========== UI: DROPDOWN PRODUCTO ==========
  Widget _buildDropdownProducto() {
    return DropdownButtonFormField<int>(
      value: _productoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Producto',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Todos los productos'),
        ),
        ..._productos.map((producto) {
          return DropdownMenuItem<int>(
            value: producto['id'],
            child: Text(producto['nombre']),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _productoSeleccionado = value;
        });
        _cargarTrazabilidades();
      },
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
            _buildDropdownProducto(),
          ],
        ),
      ),
    );
  }

  // ========== UI: TARJETA DE TRAZABILIDAD ==========
  Widget _buildTarjetaTrazabilidad(Map<String, dynamic> trazabilidad) {
    final hojaProcesos = trazabilidad['hoja_procesos'] as Map<String, dynamic>;
    final tarea = hojaProcesos['tarea'] as Map<String, dynamic>;
    final producto = tarea['producto'] as Map<String, dynamic>;
    final linea = tarea['linea'] as Map<String, dynamic>;
    final turno = tarea['turno'] as Map<String, dynamic>;
    final firmas = trazabilidad['firmas'] as List<dynamic>? ?? [];

    final tieneFirmaSupervisor = firmas.any(
      (firma) => firma['tipo_firma'] == 'supervisor',
    );

    final firmaSupervisor = tieneFirmaSupervisor
        ? firmas.firstWhere((firma) => firma['tipo_firma'] == 'supervisor')
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

          // Si hubo cambios (firma), recargar lista
          if (resultado == true) {
            _cargarTrazabilidades();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: Producto y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto['nombre'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Código: ${producto['codigo']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                          tieneFirmaSupervisor ? 'Firmada' : 'Sin firmar',
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
              const SizedBox(height: 12),

              // Información de la tarea
              Row(
                children: [
                  Icon(Icons.factory, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    linea['nombre'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    turno['nombre'],
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

              // Información de firma (si existe)
              if (tieneFirmaSupervisor && firmaSupervisor != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.edit_note, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Firmada por ${firmaSupervisor['usuario_nombre']} el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(firmaSupervisor['fecha_firma']))}',
                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ],

              // Indicador de navegación
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

  // ========== BUILD PRINCIPAL ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmas de Supervisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarTrazabilidades,
            tooltip: 'Actualizar',
          ),
        ],
      ),
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