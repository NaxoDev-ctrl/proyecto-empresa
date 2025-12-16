import 'package:flutter/material.dart';
import 'package:frontprod/screens/lista_tareas_screen.dart';
import 'package:frontprod/services/api_service.dart';
import 'firma_control_calidad_screen.dart';
import 'home_screen.dart';

const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);

class ControlCalidadDashboard extends StatefulWidget {
  const ControlCalidadDashboard({super.key});

  @override
  State<ControlCalidadDashboard> createState() => _ControlCalidadDashboardState();
}

class _ControlCalidadDashboardState extends State<ControlCalidadDashboard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _usuario;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    try {
      final usuario = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
        
        // Si falla, cerrar sesión y volver al home
        await _apiService.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: primaryColorDark,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColorDark,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: SizedBox(
            child: Image.asset(
              'assets/images/logo_entrelagosE_verde.png',
              fit: BoxFit.contain,
              height: 90,
              width: 90,
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CONTROL DE CALIDAD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,

        actions: [
          // Información del usuario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _usuario?['nombre_completo'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _usuario?['rol_display'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(255, 217, 244, 205),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botón de logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      
      body: const FirmaControlCalidadScreen(), // ✅ Directamente la pantalla principal
    );
  }
  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: primaryColorDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColorLight,
            ),
            child: const Text('Cerrar Sesión', style: TextStyle(color: primaryColorDark)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      // Cerrar sesión (eliminar token)
      await _apiService.logout();
      
      if (!mounted) return;
      
      // Volver al HomeScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // Eliminar todas las rutas anteriores
      );
    }
  }
}