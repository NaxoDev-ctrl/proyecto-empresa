import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _usuario;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? get usuario => _usuario;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSupervisor => _usuario?['rol'] == 'supervisor';
  bool get isControlCalidad => _usuario?['rol'] == 'control_calidad';

  /// Inicializar - Verificar si hay token guardado
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        _apiService.setToken(token);
        await _loadCurrentUser();
      }
    } catch (e) {
      _error = 'Error al inicializar: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Llamar al API
      await _apiService.login(username, password);
      
      // Cargar información del usuario
      await _loadCurrentUser();
      
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      
      return false;
    }
  }

  /// Cargar información del usuario actual
  Future<void> _loadCurrentUser() async {
    try {
      final userData = await _apiService.getCurrentUser();
      _usuario = userData;
      _isAuthenticated = true;
    } catch (e) {
      _error = 'Error al cargar usuario: $e';
      _isAuthenticated = false;
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('refresh');

      // Limpiar token del API Service
      _apiService.clearToken();

      // Limpiar estado
      _usuario = null;
      _isAuthenticated = false;
      _error = null;
    } catch (e) {
      _error = 'Error al cerrar sesión: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}