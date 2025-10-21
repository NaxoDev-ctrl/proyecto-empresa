import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'editar_tarea_screen.dart';

class DetalleTareaScreen extends StatefulWidget {
  final int tareaId;

  const DetalleTareaScreen({
    super.key,
    required this.tareaId,
  });

  @override
  State<DetalleTareaScreen> createState() => _DetalleTareaScreenState();
}

class _DetalleTareaScreenState extends State<DetalleTareaScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _tarea;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getTareaDetalle(widget.tareaId);
      setState(() {
        _tarea = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarTarea() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta tarea?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _apiService.eliminarTarea(widget.tareaId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea eliminada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retornar true para actualizar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editarTarea() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tarea'),
        content: const Text(
          '¿Deseas editar esta tarea?\n\n'
          'Los cambios se guardarán inmediatamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Editar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarTareaScreen(tarea: _tarea!),
      ),
    );

    if (resultado == true) {
      _cargarDetalle(); // Recargar detalles
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'en_curso':
        return Colors.blue;
      case 'finalizada':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Tarea'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
        actions: [
          // Solo mostrar acciones si la tarea está pendiente
          if (_tarea != null && _tarea!['estado'] == 'pendiente') ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: _editarTarea,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar',
              onPressed: _eliminarTarea,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar detalle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDetalle,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_tarea == null) {
      return const Center(child: Text('No se encontró la tarea'));
    }

    return RefreshIndicator(
      onRefresh: _cargarDetalle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEstadoCard(),
          const SizedBox(height: 16),
          _buildInfoGeneralCard(),
          const SizedBox(height: 16),
          _buildProductoCard(),
          const SizedBox(height: 16),
          _buildColaboradoresCard(),
          if (_tarea!['observaciones'] != null && _tarea!['observaciones'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildObservacionesCard(),
          ],
          const SizedBox(height: 16),
          _buildAuditoriaCard(),
        ],
      ),
    );
  }

  Widget _buildEstadoCard() {
    final estado = _tarea!['estado'];
    final estadoDisplay = _tarea!['estado_display'];
    final color = _getEstadoColor(estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    estadoDisplay,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGeneralCard() {
    final lineaDetalle = _tarea!['linea_detalle'];
    final turnoDetalle = _tarea!['turno_detalle'];
    final supervisorDetalle = _tarea!['supervisor_detalle'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(
              Icons.calendar_today,
              'Fecha',
              DateFormat('EEEE, d MMMM yyyy').format(
                DateTime.parse(_tarea!['fecha']),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.straighten,
              'Línea',
              lineaDetalle['nombre'],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.access_time,
              'Turno',
              turnoDetalle['nombre_display'],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.person,
              'Supervisor',
              supervisorDetalle['nombre_completo'],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.flag,
              'Meta de Producción',
              '${_tarea!['meta_produccion']} unidades',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoCard() {
    final productoDetalle = _tarea!['producto_detalle'];
    final materiasPrimas = productoDetalle['materias_primas'] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Producto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(
              Icons.inventory,
              'Código',
              productoDetalle['codigo'],
            ),
            const SizedBox(height: 12),
            Text(
              productoDetalle['nombre'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (materiasPrimas.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Materias Primas:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...materiasPrimas.map((mp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${mp['codigo']} - ${mp['nombre']}'),
                      ),
                      if (mp['requiere_lote'])
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Lote',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColaboradoresCard() {
    final colaboradores = _tarea!['colaboradores'] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colaboradores Asignados (${colaboradores.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...colaboradores.map((colaborador) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    colaborador['codigo'].substring(0, 2).toUpperCase(),
                  ),
                ),
                title: Text(colaborador['nombre_completo']),
                subtitle: Text('Código: ${colaborador['codigo']}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacionesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Observaciones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Text(_tarea!['observaciones']),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditoriaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auditoría',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(
              Icons.add_circle_outline,
              'Creada',
              _formatDateTime(_tarea!['fecha_creacion']),
            ),
            if (_tarea!['fecha_inicio'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.play_circle_outline,
                'Iniciada',
                _formatDateTime(_tarea!['fecha_inicio']),
              ),
            ],
            if (_tarea!['fecha_finalizacion'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.check_circle_outline,
                'Finalizada',
                _formatDateTime(_tarea!['fecha_finalizacion']),
              ),
            ],
            if (_tarea!['duracion_minutos'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.timer,
                'Duración',
                '${_tarea!['duracion_minutos']} minutos',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
    } catch (e) {
      return dateTimeStr;
    }
  }
}