import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // IMPORTANTE: Cambia esta URL según tu configuración
  // Para emulador Android: 'http://10.0.2.2:8000'
  // Para emulador iOS: 'http://127.0.0.1:8000'
  // Para dispositivo físico: 'http://192.168.0.11:8000'
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  /// Establece el token de autenticación
  void setToken(String token) {
    _token = token;
  }

  /// Obtiene el token guardado
  String? getToken() {
    return _token;
  }

  /// Limpia el token (logout)
  void clearToken() {
    _token = null;
  }

  /// Headers por defecto para las peticiones
  Map<String, String> _getHeaders({bool needsAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (needsAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// Maneja errores de la API
  void _handleError(http.Response response) {
    try {
      final body = json.decode(response.body);
      
      if (response.statusCode == 400) {
        // Error de validación - extraer mensaje específico
        if (body is Map) {
          String mensaje = 'Error de validación: ';
          body.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              mensaje += '${value.join(", ")} ';
            } else {
              mensaje += '$value ';
            }
          });
          throw Exception(mensaje.trim());
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para realizar esta acción.');
      } else if (response.statusCode == 404) {
        throw Exception('Recurso no encontrado.');
      } else if (response.statusCode >= 500) {
        throw Exception('Error del servidor. Intenta nuevamente más tarde.');
      } else {
        throw Exception(body.toString());
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ========================================================================
  // AUTENTICACIÓN
  // ========================================================================

  /// Login - Obtener token JWT
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: _getHeaders(needsAuth: false),
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access'];

        // Guardar token en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access']);
        await prefs.setString('refresh', data['refresh']);

        return data;
      } else {
        _handleError(response);
        throw Exception('Error en login');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener información del usuario actual
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/me/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        _handleError(response);
        throw Exception('Error al obtener usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // LÍNEAS
  // ========================================================================

  /// Obtener todas las líneas activas
  Future<List<dynamic>> getLineas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lineas/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener líneas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // TURNOS
  // ========================================================================

  /// Obtener todos los turnos activos
  Future<List<dynamic>> getTurnos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/turnos/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener turnos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // COLABORADORES
  // ========================================================================

  /// Obtener todos los colaboradores activos
  Future<List<dynamic>> getColaboradores({String? search}) async {
    try {
      String url = '$baseUrl/colaboradores/';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener colaboradores');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Cargar colaboradores desde JSON
  Future<Map<String, dynamic>> cargarColaboradoresJson(
      List<Map<String, dynamic>> colaboradores) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/colaboradores/cargar_excel/'),
        headers: _getHeaders(),
        body: json.encode({
          'colaboradores': colaboradores,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        _handleError(response);
        throw Exception('Error al cargar colaboradores');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // PRODUCTOS
  // ========================================================================

  /// Obtener todos los productos activos
  Future<List<dynamic>> getProductos({String? search}) async {
    try {
      String url = '$baseUrl/productos/';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener productos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener detalle de un producto (con receta)
  Future<Map<String, dynamic>> getProductoDetalle(String codigo) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/productos/$codigo/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener producto');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // TAREAS
  // ========================================================================

  /// Obtener todas las tareas (con filtros opcionales)
  Future<List<dynamic>> getTareas({
    String? fecha,
    int? lineaId,
    int? turnoId,
    String? estado,
  }) async {
    try {
      String url = '$baseUrl/tareas/?';
      
      if (fecha != null) url += 'fecha=$fecha&';
      if (lineaId != null) url += 'linea=$lineaId&';
      if (turnoId != null) url += 'turno=$turnoId&';
      if (estado != null) url += 'estado=$estado&';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener tareas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener tareas del día actual
  Future<List<dynamic>> getTareasHoy() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tareas/hoy/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener tareas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener detalle de una tarea
  Future<Map<String, dynamic>> getTareaDetalle(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tareas/$id/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

        if (jsonResponse is Map<String, dynamic>) {
          return jsonResponse;
        }
        // Manejar caso inesperado si la API devuelve una lista o algo diferente
        throw Exception('Respuesta inesperada del servidor para la tarea $id');
      } else if (response.statusCode == 404) {
        // Manejo específico para No Encontrado
        throw Exception('Tarea con ID $id no encontrada.');

      } else {
        // Manejo de otros errores
        _handleError(response);
        throw Exception('Error al obtener tarea: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Crear una nueva tarea
  Future<Map<String, dynamic>> crearTarea({
    required String fecha,
    required int lineaId,
    required int turnoId,
    required String productoCodigo,
    required int metaProduccion,
    required int supervisorId,
    required List<int> colaboradoresIds,
    String? observaciones,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tareas/'),
        headers: _getHeaders(),
        body: json.encode({
          'fecha': fecha,
          'linea': lineaId,
          'turno': turnoId,
          'producto': productoCodigo,
          'meta_produccion': metaProduccion,
          'supervisor_asignador': supervisorId,
          'colaboradores_ids': colaboradoresIds,
          'observaciones': observaciones,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        _handleError(response);
        throw Exception('Error al crear tarea');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Actualizar una tarea existente
  Future<Map<String, dynamic>> actualizarTarea({
    required int id,
    required String fecha,
    required int lineaId,
    required int turnoId,
    required String productoCodigo,
    required int metaProduccion,
    required int supervisorId,
    required List<int> colaboradoresIds,
    String? observaciones,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tareas/$id/'),
        headers: _getHeaders(),
        body: json.encode({
          'fecha': fecha,
          'linea': lineaId,
          'turno': turnoId,
          'producto': productoCodigo,
          'meta_produccion': metaProduccion,
          'supervisor_asignador': supervisorId,
          'colaboradores_ids': colaboradoresIds,
          'observaciones': observaciones,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        _handleError(response);
        throw Exception('Error al actualizar tarea');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Eliminar una tarea
  Future<void> eliminarTarea(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tareas/$id/'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 204) {
        _handleError(response);
        throw Exception('Error al eliminar tarea');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Iniciar una tarea
  Future<Map<String, dynamic>> iniciarTarea(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tareas/$id/iniciar/'),
        headers: _getHeaders(needsAuth: false),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        return jsonResponse;
      } else {
        _handleError(response);
        throw Exception('Error al iniciar tarea');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Verificar bloqueo de una tarea
  Future<Map<String, dynamic>> verificarBloqueoTarea(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tareas/$id/verificar_bloqueo/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al verificar bloqueo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
  // ========================================================================
  // MÁQUINAS
  // ========================================================================

  /// Obtener todas las máquinas activas
  Future<List<dynamic>> getMaquinas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/maquinas/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener máquinas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // TIPOS DE EVENTOS
  // ========================================================================

  /// Obtener todos los tipos de eventos
  Future<List<dynamic>> getTiposEventos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tipos-eventos/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener tipos de eventos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // HOJA DE PROCESOS
  // ========================================================================

  /// Crear hoja de procesos
  Future<Map<String, dynamic>> crearHojaProcesos({
    required int tareaId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/hojas-procesos/'),
        headers: _getHeaders(),
        body: json.encode({
          'tarea': tareaId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al crear hoja de procesos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener hoja de procesos por tarea
  Future<Map<String, dynamic>> getHojaProcesosPorTarea(int tareaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hojas-procesos/por_tarea/?tarea_id=$tareaId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al obtener hoja de procesos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Finalizar hoja de procesos
  Future<Map<String, dynamic>> finalizarHojaProcesos(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/hojas-procesos/$id/finalizar/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al finalizar hoja de procesos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // EVENTOS DE PROCESO
  // ========================================================================

  /// Crear evento de proceso
  Future<Map<String, dynamic>> crearEventoProceso({
    required int hojaProcesosId,
    required int tipoEventoId,
    required String horaInicio,
    String? horaFin,
    String? observaciones,
    List<int>? maquinasIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/eventos-proceso/'),
        headers: _getHeaders(),
        body: json.encode({
          'hoja_procesos': hojaProcesosId,
          'tipo_evento': tipoEventoId,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'observaciones': observaciones,
          'maquinas_ids': maquinasIds ?? [],
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al crear evento');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Finalizar evento de proceso
  Future<Map<String, dynamic>> finalizarEventoProceso(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/eventos-proceso/$id/finalizar_evento/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al finalizar evento');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Listar eventos de una hoja de procesos
  Future<List<dynamic>> getEventosProceso(int hojaProcesosId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/eventos-proceso/?hoja_procesos=$hojaProcesosId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener eventos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // TRAZABILIDAD
  // ========================================================================

  /// Crear trazabilidad
  Future<Map<String, dynamic>> crearTrazabilidad({
    required int hojaProcesosId,
    required int cantidadProducida,
    required List<Map<String, dynamic>> materiasPrimas,
    List<Map<String, dynamic>>? reprocesos,
    List<Map<String, dynamic>>? mermas,
    String? observaciones,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trazabilidades/'),
        headers: _getHeaders(),
        body: json.encode({
          'hoja_procesos': hojaProcesosId,
          'cantidad_producida': cantidadProducida,
          'materias_primas': materiasPrimas,
          'reprocesos_data': reprocesos ?? [],
          'mermas_data': mermas ?? [],
          'observaciones': observaciones,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al crear trazabilidad');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener trazabilidades por fecha y turno
  Future<List<dynamic>> getTrazabilidadesPorFechaTurno({
    required String fecha,
    required int turnoId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trazabilidades/por_fecha_turno/?fecha=$fecha&turno=$turnoId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = jsonResponse is List ? jsonResponse : jsonResponse['results'];
        return data;
      } else {
        _handleError(response);
        throw Exception('Error al obtener trazabilidades');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener detalle de trazabilidad
  Future<Map<String, dynamic>> getTrazabilidadDetalle(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trazabilidades/$id/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al obtener trazabilidad');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Subir foto de etiqueta
  Future<Map<String, dynamic>> subirFotoEtiqueta(int trazabilidadId, List<int> imageBytes) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trazabilidades/$trazabilidadId/subir_foto_etiqueta/'),
      );


      // Agregar archivo
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          imageBytes,
          filename: 'etiqueta_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al subir foto');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ========================================================================
  // FIRMAS
  // ========================================================================

  /// Firmar trazabilidad
  Future<Map<String, dynamic>> firmarTrazabilidad(int trazabilidadId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/firmas-trazabilidad/firmar/'),
        headers: _getHeaders(),
        body: json.encode({
          'trazabilidad_id': trazabilidadId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al firmar trazabilidad');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Cambiar estado de trazabilidad (solo Control de Calidad)
  Future<Map<String, dynamic>> cambiarEstadoTrazabilidad({
    required int trazabilidadId,
    required String estado,
    String? motivoRetencion,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trazabilidades/$trazabilidadId/cambiar_estado/'),
        headers: _getHeaders(),
        body: json.encode({
          'estado': estado,
          'motivo_retencion': motivoRetencion,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        _handleError(response);
        throw Exception('Error al cambiar estado');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}