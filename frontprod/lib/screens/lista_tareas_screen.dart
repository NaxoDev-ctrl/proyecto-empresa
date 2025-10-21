import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tarea.dart';
import '../providers/filtro_provider.dart';
import 'detalle_tarea_screen.dart';

class ListaTareasScreen extends StatefulWidget {
  final VoidCallback? onRefreshNeeded;
  
  const ListaTareasScreen({
    super.key,
    this.onRefreshNeeded,
  });

  @override
  State<ListaTareasScreen> createState() => _ListaTareasScreenState();
}

class _ListaTareasScreenState extends State<ListaTareasScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ApiService _apiService = ApiService();
  List<Tarea> _tareas = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Cargar fecha guardada del provider
    final filtroProvider = Provider.of<FiltroProvider>(context, listen: false);
    _selectedDate = filtroProvider.selectedDate;
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fecha = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await _apiService.getTareas(fecha: fecha);
      
      if (mounted) {
        setState(() {
          _tareas = data.map((json) => Tarea.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2080),
    );

    if (picked != null && picked != _selectedDate) {
      // Guardar en provider
      final filtroProvider = Provider.of<FiltroProvider>(context, listen: false);
      await filtroProvider.setSelectedDate(picked);
      
      setState(() {
        _selectedDate = picked;
      });
      _cargarTareas();
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
    super.build(context); // Necesario para AutomaticKeepAliveClientMixin
    return Column(
      children: [
        // Filtro de fecha
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              const Icon(Icons.calendar_today),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _seleccionarFecha,
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Cambiar'),
              ),
            ],
          ),
        ),

        // Lista de tareas
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando tareas...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar tareas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarTareas,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay tareas para esta fecha',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una nueva tarea usando el botón +',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTareas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tareas.length,
        itemBuilder: (context, index) {
          final tarea = _tareas[index];
          return _buildTareaCard(tarea);
        },
      ),
    );
  }

  Widget _buildTareaCard(Tarea tarea) {
    final isFinalized = tarea.estado != 'pendiente';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isFinalized
            ? null
            : () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleTareaScreen(tareaId: tarea.id),
                  ),
                );
                
                // Si se eliminó o editó la tarea, recargar la lista
                if (resultado == true) {
                  _cargarTareas();
                }
              },
        child: Opacity(
          opacity: isFinalized ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con estado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(tarea.estado).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getEstadoColor(tarea.estado),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tarea.estadoDisplay,
                        style: TextStyle(
                          color: _getEstadoColor(tarea.estado),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      tarea.turnoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Producto
                Text(
                  tarea.productoNombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: ${tarea.productoCodigo}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // Información adicional
                Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      tarea.lineaNombre,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.flag, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Meta: ${tarea.metaProduccion} unidades',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      tarea.supervisorNombre,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}