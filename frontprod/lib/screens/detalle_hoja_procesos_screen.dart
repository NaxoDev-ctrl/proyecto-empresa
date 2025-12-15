import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);

class DetalleHojaProcesosSupervisorScreen extends StatefulWidget {
  final int hojaProcesosId;

  const DetalleHojaProcesosSupervisorScreen({
    Key? key,
    required this.hojaProcesosId,
  }) : super(key: key);

  @override
  State<DetalleHojaProcesosSupervisorScreen> createState() =>
      _DetalleHojaProcesosSupervisorScreenState();
}

class _DetalleHojaProcesosSupervisorScreenState
    extends State<DetalleHojaProcesosSupervisorScreen> {
  
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _hojaProcesos;

  @override
  void initState() {
    super.initState();
    _cargarHojaProcesos();
  }

  Future<void> _cargarHojaProcesos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getHojaProcesosDetalle(widget.hojaProcesosId);
      
      setState(() {
        _hojaProcesos = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar hoja de procesos: $e';
        _isLoading = false;
      });
    }
  }

  String _formatearDuracion(int? minutos) {
    if (minutos == null) return 'En curso';
    
    if (minutos < 60) {
      return '$minutos min';
    }
    
    final horas = minutos ~/ 60;
    final mins = minutos % 60;
    
    if (mins == 0) {
      return '$horas h';
    }
    
    return '$horas h $mins min';
  }

  String _formatearHora(String? fechaHora) {
    if (fechaHora == null) return '-';
    
    try {
      final dateTime = DateTime.parse(fechaHora);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return '-';
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Text('Hoja de Procesos', style: TextStyle(fontSize: 28)),
          backgroundColor: primaryColorDark,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando hoja de procesos...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: primaryColorDark,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error al cargar'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarHojaProcesos,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final tarea = _hojaProcesos!['tarea_detalle'] ?? _hojaProcesos!['tarea'];
    final eventos = _hojaProcesos!['eventos'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text(
          'Hoja de Procesos',
          style: TextStyle(fontSize: 28),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHojaProcesos,
            tooltip: 'Actualizar',
          ),
        ],
        backgroundColor: primaryColorDark,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarHojaProcesos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEncabezado(tarea),
              const SizedBox(height: 16),
              _buildListaEventos(eventos),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildEncabezado(Map<String, dynamic> tarea) {
    final producto = tarea['producto_detalle'] ?? tarea['producto'];
    final linea = tarea['linea_detalle'] ?? tarea['linea'];
    final turno = tarea['turno_detalle'] ?? tarea['turno'];
    final fecha = tarea['fecha_elaboracion_real'] ?? tarea['fecha'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Icon(Icons.list_alt, color: primaryColorDark, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'INFORMACIÓN DE PRODUCCIÓN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Fecha, Línea, Turno
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FECHA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(fecha ?? '-'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LÍNEA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(linea?['nombre'] ?? '-'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TURNO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(turno?['nombre'] ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Producto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRODUCTO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Código',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              producto?['codigo'] ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nombre',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              producto?['nombre'] ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
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
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildListaEventos(List<dynamic> eventos) {
    if (eventos.isEmpty) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No hay eventos registrados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Icon(Icons.access_time, color: primaryColorDark),
                const SizedBox(width: 12),
                Text(
                  'EVENTOS REGISTRADOS (${eventos.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Lista de eventos
            ...eventos.asMap().entries.map((entry) {
              final index = entry.key;
              final evento = entry.value;
              final isLast = index == eventos.length - 1;
              
              return _buildEventoItem(evento, isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEventoItem(Map<String, dynamic> evento, bool isLast) {
    final tipoEvento = evento['tipo_evento_nombre'] ?? 'Sin nombre';
    final horaInicio = _formatearHora(evento['hora_inicio']);
    final horaFin = _formatearHora(evento['hora_fin']);
    final duracion = _formatearDuracion(evento['duracion_minutos']);
    final maquinas = evento['maquinas'] as List? ?? [];
    final observaciones = evento['observaciones']?.toString();
    
    final bool tieneHoraFin = evento['hora_fin'] != null;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tieneHoraFin ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: tieneHoraFin ? Colors.green.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre del evento
              Row(
                children: [
                  Icon(
                    tieneHoraFin ? Icons.check_circle : Icons.access_time_filled,
                    size: 20,
                    color: tieneHoraFin ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tipoEvento,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Horas
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inicio',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          horaInicio,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fin',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          horaFin,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tieneHoraFin ? Colors.black : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Duración',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          duracion,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tieneHoraFin ? Colors.black : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Máquinas (si hay)
              if (maquinas.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Máquinas:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: maquinas.map((maquina) {
                    return Chip(
                      label: Text(
                        maquina['nombre'] ?? maquina['codigo'] ?? 'Sin nombre',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.blue.shade100,
                      padding: const EdgeInsets.all(4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              
              // Observaciones (si hay)
              if (observaciones != null && observaciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Observaciones:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  observaciones,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        
        if (!isLast) const SizedBox(height: 12),
      ],
    );
  }
}