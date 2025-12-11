import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/tarea.dart';
import '../providers/filtro_provider.dart';
import 'detalle_tarea_screen.dart';
import 'crear_tarea_screen.dart';

const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);
const Color primaryColorLight = Color.fromARGB(255, 217, 244, 205);

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

  final Map<String, ({Color base, Color borderTurno, Color textTurno, Color textProducto})> _turnoSkin = {
    'AM': (
      // Base: Amarillo pálido (similar a la imagen)
      base: const Color.fromARGB(255, 255, 249, 221), 
      // Turno Border/Background: Amarillo/Dorado
      borderTurno: const Color.fromARGB(255, 255, 222, 89),
      // Turno Text: Blanco
      textTurno: Colors.white,
      // Producto Text: Dark Teal (color corporativo)
      textProducto: const Color.fromARGB(255, 0, 89, 79),
    ),
    'PM': (
      // Base: Durazno pálido (similar a la imagen)
      base: const Color.fromARGB(255, 255, 215, 179),
      // Turno Border/Background: Naranja oscuro
      borderTurno: const Color.fromARGB(255, 204, 78, 0),
      // Turno Text: Blanco
      textTurno: Colors.white,
      // Producto Text: Granate/Vino
      textProducto: const Color.fromARGB(255, 140, 28, 66),
    ),
    'Noche': (
      // Base: Azul muy pálido (ejemplo)
      base: const Color(0xFFE3F2FD), 
      // Turno Border/Background: Rojo Oscuro
      borderTurno: const Color(0xFF891D43),
      // Turno Text: Azul
      textTurno: const Color(0xFF2196F3),
      // Producto Text: Negro
      textProducto: Colors.black,
    ),
  };

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'es_ES';
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColorDark, // Color del encabezado y botones
              onPrimary: Colors.white, // Color del texto en el encabezado
              onSurface: Colors.black, // Color de los textos en el calendario
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColorDark, // Color de los botones de acción
              ),
            ),
          ),
          child: child!,
        );
      },
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

  ({Color base, Color borderTurno, Color textTurno, Color textProducto}) _getTurnoSkin(String turnoCodigo) {
    // Si el código de turno no existe, usamos AM como valor predeterminado seguro
    return _turnoSkin[turnoCodigo] ?? _turnoSkin['AM']!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necesario para AutomaticKeepAliveClientMixin
    return Column(
      children: [
        _buildHeaderToolbar(),

        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeaderToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Color.fromARGB(255, 0, 58, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Botón Nueva Tarea (replicando el diseño de la imagen)
          _buildNewTaskButton(),

          const SizedBox(width: 8),

          // 2. Botón y selector de fecha
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: primaryColorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: _seleccionarFecha,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColorDark,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Filtrar Fecha a: ',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTaskButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CrearTareaScreen(),
          ),
        );
        // Si se creó una tarea, recargar la lista
        if (resultado == true) {
          _cargarTareas();
        }
      },
      icon: const Icon(Icons.add, size: 18,),
      label: const Text('Nueva Tarea', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        
        backgroundColor: primaryColorLight, // Fondo blanco
        foregroundColor: primaryColorDark, // Texto verde oscuro
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColorDark),
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
              color: primaryColorDark,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColorDark, // Botón de fondo verde
                foregroundColor: Colors.white,
              ),
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
              color: primaryColorDark.withOpacity(0.5), 
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
      color: primaryColorDark,
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
    final skin = _getTurnoSkin(tarea.turnoNombre);
    final isFinalized = tarea.estado != 'pendiente';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 2,
        ),
      ),
      elevation: 2,
      color: skin.base,
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

                // Si se actualizó la tarea, recargar la lista
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
                        color: skin.borderTurno,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: skin.borderTurno),
                      ),
                      child: Text(
                        tarea.turnoNombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: skin.textTurno,
                        ),
                      ),
                    ),
                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(tarea.estado).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
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
                  ],
                ),
                const SizedBox(height: 12),

                // Línea y Producto (Título)
                Text(
                  tarea.lineaNombre,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: skin.textProducto, // Título en color verde
                  ),
                ),
                
                // Código de Producto
                Text(
                  '${tarea.productoCodigo} - ${tarea.productoNombre}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: skin.textProducto, // Título en color verde
                  ),
                ),
                const SizedBox(height: 8),
                
                // Información adicional
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: primaryColorDark),
                    const SizedBox(width: 6),
                    Text(
                      'Producción: ${tarea.metaProduccion} unidades', // Usando meta como placeholder
                      style: const TextStyle(
                        color: primaryColorDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
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