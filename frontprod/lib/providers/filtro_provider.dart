import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FiltroProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  
  DateTime get selectedDate => _selectedDate;
  
  FiltroProvider() {
    _cargarFechaGuardada();
  }
  
  Future<void> _cargarFechaGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fechaStr = prefs.getString('ultima_fecha_tareas');
      
      if (fechaStr != null) {
        _selectedDate = DateTime.parse(fechaStr);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al cargar fecha guardada: $e');
    }
  }
  
  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = date;
    
    // Guardar en SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultima_fecha_tareas', date.toIso8601String());
    } catch (e) {
      debugPrint('Error al guardar fecha: $e');
    }
    
    notifyListeners();
  }
  
  String getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);
  }
}