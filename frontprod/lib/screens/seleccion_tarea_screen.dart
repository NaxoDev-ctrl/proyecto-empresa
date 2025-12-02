import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/linea.dart';
import '../models/tarea.dart';
import 'hoja_procesos_screen.dart';

class SeleccionTareaScreen extends StatefulWidget {
  final Linea linea;

  const SeleccionTareaScreen({
    super.key,
    required this.linea,
  });

  @override
  State<SeleccionTareaScreen> createState() => _SeleccionTareaScreenState();
}

class _SeleccionTareaScreenState extends State<SeleccionTareaScreen> {
  final ApiService _apiService = ApiService();
  List<Tarea> _tareas = [];
  bool _isLoading = true;
  String? _error;

  final Color _primaryColor = const Color(0xFF891D43);
  final Color _onPrimaryColor = const Color(0xFFFFD9C6);

  final Map<String, ({Color base, Color border, Color text, Color border_turno, Color text_turno, Color text_producto})> _turnoSkin = {
    'AM': (
      base: const Color.fromARGB(255, 255, 249, 221),
      border: const Color(0xFF4CAF50), 
      text: const Color(0xFF4CAF50),
      border_turno: const Color.fromARGB(255, 255, 222, 89),
      text_turno: const Color.fromARGB(255, 255, 255, 255),
      text_producto: const Color.fromARGB(255, 0, 89, 79),
    ),
    'PM': (
      base: const Color.fromARGB(255, 255, 215, 179),
      border: const Color(0xFF4CAF50), 
      text: const Color(0xFF4CAF50),
      border_turno: const Color.fromARGB(255, 204, 78, 0),
      text_turno: const Color.fromARGB(255, 255, 255, 255),
      text_producto: const Color.fromARGB(255, 140, 28, 66),
    ),
    'Noche': (
      base: const Color(0xFFE3F2FD), 
      border: const Color(0xFF2196F3),
      text: const Color(0xFF0D47A1),
      border_turno: const Color(0xFF891D43),
      text_turno: const Color(0xFF2196F3),
      text_producto: const Color.fromARGB(255, 0, 0, 0),
    ),
    // Agrega más turnos aquí si es necesario (ej: 'Extra', 'Fines de Semana')
    // 'Extra': (base: const Color(0xFFFBEFF5), border: const Color(0xFF891D43), text: const Color(0xFF891D43)),
  };

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'es_CL'; 
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await _apiService.getTareas(
        fecha: fecha,
        lineaId: widget.linea.id,
      );

      setState(() {
        _tareas = data
            .map((json) => Tarea.fromJson(json))
            .where((t) => t.estado == 'pendiente')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _iniciarTarea(Tarea tarea) async {
    // Confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Iniciar Producción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Deseas iniciar la producción de:'),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea.productoNombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Turno: ${tarea.turnoNombre}'),
                  Text('Meta: ${tarea.metaProduccion} unidades'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Se iniciará el registro de tiempos de producción.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Iniciar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Iniciando producción...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Iniciar tarea
      await _apiService.iniciarTarea(tarea.id);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      // Navegar a hoja de procesos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HojaProcesosScreen(tareaId: tarea.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar tarea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange.shade700;
      case 'en_curso':
        return Colors.blue.shade700;
      case 'finalizada':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeaderFijo(context),
            
            // Contenido deslizable
            SliverFillRemaining(
              hasScrollBody: true,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildContent(),
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

  Widget _buildHeaderFijo(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _primaryColor,
      elevation: 0,
      toolbarHeight: 120, 
      
      // Botón de atrás (izquierda)
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: CircleAvatar(
            backgroundColor: _onPrimaryColor, // Color crema
            radius: 22,
            child: Icon(
              Icons.arrow_back,
              color: _primaryColor, // Color guinda
              size: 35,
            ),
          ),
        ),
      ),
      
      // Título Central
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.linea.nombre} - TAREAS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onPrimaryColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          _buildDateHeader(),
        ],
      ),
      centerTitle: true,
      
      // Logo (derecha)
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Image.asset(
              'assets/images/logo_entrelagosE.png',
              fit: BoxFit.contain,
              color: _onPrimaryColor, // Lo tintamos del color crema
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.emoji_events, // Placeholder
                color: _onPrimaryColor,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 20, color: _onPrimaryColor),
          const SizedBox(width: 8),
          Text(
            DateFormat('EEEE, d MMMM', 'es_CL').format(DateTime.now()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _onPrimaryColor,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Cargando tareas...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar tareas'),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarTareas,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
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
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay tareas pendientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'para ${widget.linea.nombre} hoy',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _cargarTareas,
              icon: Icon(Icons.refresh),
              label: Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTareas,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _tareas.length,
        itemBuilder: (context, index) {
          final tarea = _tareas[index];
          return _buildTareaCard(tarea);
        },
      ),
    );
  }

  Widget _buildTareaCard(Tarea tarea) {
    // 1. Obtener la configuración de estilo basada en el nombre del turno
    final turnoStyle = _turnoSkin[tarea.turnoNombre] ?? _turnoSkin['AM']!;
    
    // Color específico del estado
    final estadoColor = _getEstadoColor(tarea.estado);
    
    // Formato de número para la meta
    final formatter = NumberFormat('#,##0', 'es_CL');
    final metaDisplay = '${formatter.format(tarea.metaProduccion)} unidades'; // Asumo unidades

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: turnoStyle.base, // Color de fondo dinámico
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _iniciarTarea(tarea),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Turno y Estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono de Turno (Círculo con hora)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: turnoStyle.border_turno,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tarea.turnoNombre,
                      style: TextStyle(
                        color: turnoStyle.text_turno,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Etiqueta de Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: estadoColor, width: 1.5),
                    ),
                    child: Text(
                      tarea.estadoDisplay,
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Producto y Código
              Text(
                '${tarea.productoCodigo} - ${tarea.productoNombre}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: turnoStyle.text_producto,
                ),
              ),
              const SizedBox(height: 4),


              // Meta (Rectángulo con borde y relleno verde)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white, // Fondo blanco para que destaque
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: turnoStyle.border, width: 3), // Borde basado en el turno
                  boxShadow: [
                    BoxShadow(
                      color: turnoStyle.border.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_sharp, color: turnoStyle.text, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Meta: ',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Expanded(
                      child: Text(
                        metaDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: turnoStyle.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón de iniciar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _iniciarTarea(tarea),
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'INICIAR PRODUCCIÓN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor, // Color guinda para el botón
                    foregroundColor: _onPrimaryColor, // Texto crema
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}