import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'trazabilidad_screen.dart';

class HojaProcesosScreen extends StatefulWidget {
  final int tareaId;

  const HojaProcesosScreen({
    super.key,
    required this.tareaId,
  });

  @override
  State<HojaProcesosScreen> createState() => _HojaProcesosScreenState();
}

class _HojaProcesosScreenState extends State<HojaProcesosScreen> {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _tarea;
  Map<String, dynamic>? _hojaProcesos;
  List<dynamic> _eventos = [];
  List<dynamic> _tiposEventos = [];
  //List<dynamic> _maquinas = [];
  
  bool _isLoading = true;
  bool _isCreatingEvent = false;
  String? _error;
  
  // Para el cronómetro
  Timer? _timer;
  Duration _tiempoTranscurrido = Duration.zero;
  DateTime? _inicioProduccion;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _inicializar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cargar tarea
      final tareaData = await _apiService.getTareaDetalle(widget.tareaId);
      
      // Cargar tipos de eventos
      final tiposEventosData = await _apiService.getTiposEventos();
      
      // Cargar máquinas
      //final maquinasData = await _apiService.getMaquinas();

      setState(() {
        _tarea = tareaData;
        _tiposEventos = tiposEventosData;
        //_maquinas = maquinasData;
      });

      // Verificar si ya existe hoja de procesos
      await _verificarOCrearHojaProcesos();

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verificarOCrearHojaProcesos() async {
    try {
      // Intentar obtener hoja de procesos existente
      final hojaData = await _apiService.getHojaProcesosPorTarea(widget.tareaId);
      
      setState(() {
        _hojaProcesos = hojaData;
        _inicioProduccion = DateTime.parse(hojaData['fecha_inicio']);
      });

      // Cargar eventos existentes
      await _cargarEventos();

      // Iniciar cronómetro
      _iniciarCronometro();

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      // Si no existe, crear una nueva
      await _crearHojaProcesos();
    }
  }

  Future<void> _crearHojaProcesos() async {
    try {
      // Crear hoja de procesos
      final hojaData = await _apiService.crearHojaProcesos(tareaId: widget.tareaId);
      
      setState(() {
        _hojaProcesos = hojaData;
        _inicioProduccion = DateTime.parse(hojaData['fecha_inicio']);
      });

      // Crear evento de Setup Inicial automáticamente
      final setupInicial = _tiposEventos.firstWhere(
        (t) => t['codigo'] == 'SETUP_INICIAL',
        orElse: () => _tiposEventos.first,
      );

      await _apiService.crearEventoProceso(
        hojaProcesosId: _hojaProcesos!['id'],
        tipoEventoId: setupInicial['id'],
        horaInicio: DateTime.now().toIso8601String(),
      );

      // Recargar eventos
      await _cargarEventos();

      // Iniciar cronómetro
      _iniciarCronometro();

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Error al crear hoja de procesos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarEventos() async {
    try {
      final eventosData = await _apiService.getEventosProceso(_hojaProcesos!['id']);
      setState(() {
        _eventos = eventosData;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar eventos: $e';
      });
    }
  }

  void _iniciarCronometro() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_inicioProduccion != null) {
        setState(() {
          _tiempoTranscurrido = DateTime.now().difference(_inicioProduccion!);
        });
      }
    });
  }

  Future<void> _agregarEvento() async {
    if (_isCreatingEvent) return;

    // Seleccionar tipo de evento
    final tipoEvento = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogSeleccionTipoEvento(
        tiposEventos: _tiposEventos,
      ),
    );

    if (tipoEvento == null) return;

    // Si hay un evento activo (sin hora_fin), finalizarlo primero
    final eventoActivo = _eventos.firstWhere(
      (e) => e['hora_fin'] == null,
      orElse: () => null,
    );

    setState(() {
      _isCreatingEvent = true;
    });

    try {
      if (eventoActivo != null) {
        await _apiService.finalizarEventoProceso(eventoActivo['id']);
      }

      // Crear nuevo evento
      await _apiService.crearEventoProceso(
        hojaProcesosId: _hojaProcesos!['id'],
        tipoEventoId: tipoEvento['id'],
        horaInicio: DateTime.now().toIso8601String(),
      );

      // Recargar eventos
      await _cargarEventos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evento "${tipoEvento['nombre']}" registrado'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar evento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCreatingEvent = false;
      });
    }
  }

  Future<void> _finalizarProduccion() async {
    // Confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Finalizar Producción'),
        content: Text(
          '¿Estás seguro de finalizar la producción?\n\n'
          'Se registrará el Setup Final y continuarás con la trazabilidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return; 

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
                Text('Finalizando producción...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Finalizar evento activo si existe
      final eventoActivo = _eventos.firstWhere(
        (e) => e['hora_fin'] == null,
        orElse: () => null,
      );

      if (eventoActivo != null) {
        await _apiService.finalizarEventoProceso(eventoActivo['id']);
      }

      // Crear evento de Setup Final
      final setupFinal = _tiposEventos.firstWhere(
        (t) => t['codigo'] == 'SETUP_FINAL',
        orElse: () => _tiposEventos.last,
      );

      final eventoFinal = await _apiService.crearEventoProceso(
        hojaProcesosId: _hojaProcesos!['id'],
        tipoEventoId: setupFinal['id'],
        horaInicio: DateTime.now().toIso8601String(),
        horaFin: DateTime.now().toIso8601String(),
      );

      await _apiService.finalizarHojaProcesos(_hojaProcesos!['id']);

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TrazabilidadScreen(
            tareaId: widget.tareaId,
            hojaProcesosId: _hojaProcesos!['id'],
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al finalizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Iniciando producción...'),
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
              const SizedBox(height: 16),
              Text('Error al cargar'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _inicializar,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(       
        toolbarHeight: 120,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                'assets/images/logo_entrelagosE.png',
                fit: BoxFit.contain,
                color: const Color(0xFFFFD9C6),
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.emoji_events,
                  color: const Color(0xFFFFD9C6),
                  size: 35,
                ),
              ),
            ),
          ),
        ],
        title: Text('PRODUCCIÓN EN CURSO',
          style: 
          TextStyle(
            fontWeight: FontWeight.w900,
            color: Color.fromRGBO(255, 217, 198, 1),
            fontSize: 28,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 255, 217, 198),
              radius: 22,
              child: IconButton(
                padding: const EdgeInsets.only(left: 2.0),
                icon: Icon(Icons.arrow_back),
                color: Color.fromARGB(255, 137, 29, 67),
                iconSize: 35,
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Advertencia'),
                      content: Text(
                        'Si sales ahora, la producción seguirá en curso.\n\n'
                        '¿Estás seguro de salir?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Salir'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 137, 29, 67),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildHeader(),
          ),

          const SizedBox(height: 10),

          _buildCronometro(),

          Expanded(
            child: _buildEventos(),
          ),

          _buildBotones(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Color.fromRGBO(255, 217, 198, 0.37),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tarea!['producto_detalle']['codigo'],
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _tarea!['producto_detalle']['nombre'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.conveyor_belt, size: 16),
              Text(_tarea!['linea_detalle']['nombre']),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16),
              const SizedBox(width: 4),
              Text(_tarea!['turno_detalle']['nombre_display']),
            ],
          ),
        ],
      ),
    );
  }
  

  Widget _buildCronometro() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
      ),
      child: Column(
        children: [
          Text(
            'TIEMPO TRANSCURRIDO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_tiempoTranscurrido),
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Inicio: ${DateFormat('HH:mm:ss').format(_inicioProduccion!)}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventos() {
    if (_eventos.isEmpty) {
      return Center(
        child: Text('No hay eventos registrados'),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _eventos.length,
      itemBuilder: (context, index) {
        final evento = _eventos[index];
        final isActivo = evento['hora_fin'] == null;
        
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          color: isActivo ? Colors.green.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActivo ? Colors.green : Colors.grey,
              child: Icon(
                isActivo ? Icons.play_arrow : Icons.check,
                color: Colors.white,
              ),
            ),
            title: Text(
              evento['tipo_evento_nombre'],
              style: TextStyle(
                fontWeight: isActivo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inicio: ${DateFormat('HH:mm:ss').format(DateTime.parse(evento['hora_inicio']))}',
                ),
                if (evento['hora_fin'] != null)
                  Text(
                    'Fin: ${DateFormat('HH:mm:ss').format(DateTime.parse(evento['hora_fin']))}',
                  ),
                if (evento['duracion_minutos'] != null)
                  Text(
                    'Duración: ${evento['duracion_minutos']} min',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            trailing: isActivo
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EN CURSO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildBotones() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isCreatingEvent ? null : _agregarEvento,
              icon: Icon(Icons.add_circle_outline, size: 28),
              label: Text(
                'REGISTRAR EVENTO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _finalizarProduccion,
              icon: Icon(Icons.stop_circle, size: 28),
              label: Text(
                'FINALIZAR PRODUCCIÓN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red, width: 2),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG: Selección de Tipo de Evento
// ============================================================================
class _DialogSeleccionTipoEvento extends StatelessWidget {
  final List<dynamic> tiposEventos;

  const _DialogSeleccionTipoEvento({
    required this.tiposEventos,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Selecciona el tipo de evento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tiposEventos.length,
                itemBuilder: (context, index) {
                  final tipo = tiposEventos[index];
                  
                  // No mostrar Setup Inicial ni Setup Final
                  if (tipo['codigo'] == 'SETUP_INICIAL' || 
                      tipo['codigo'] == 'SETUP_FINAL') {
                    return SizedBox.shrink();
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${tipo['orden']}'),
                    ),
                    title: Text(tipo['nombre']),
                    subtitle: tipo['descripcion'] != null
                        ? Text(
                            tipo['descripcion'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, tipo),
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