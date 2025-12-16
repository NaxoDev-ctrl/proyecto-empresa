import 'package:flutter/material.dart';
import 'package:frontprod/services/api_service.dart';
import 'lista_tareas_screen.dart';
import 'colaboradores_screen.dart';
import 'firma_supervisor_screen.dart';
import 'home_screen.dart';

const Color primaryColorDark = Color.fromARGB(255, 26, 110, 92);

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;
  final int _refreshKey = 0;

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

    final screens = [
      ListaTareasScreen(key: ValueKey(_refreshKey)),
      ColaboradoresScreen(key: ValueKey(_refreshKey)),
      FirmaSupervisorScreen(key: ValueKey(_refreshKey)),
      const Center(child: Text('Reportes (Próximamente)')),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
              'EQUIPO PRODUCCION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
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
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Colaboradores',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Trazabilidad',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }

  /// Cerrar sesión con confirmación
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
      await _apiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }
}