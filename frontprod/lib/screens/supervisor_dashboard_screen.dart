import 'package:flutter/material.dart';
import 'package:frontprod/services/api_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'crear_tarea_screen.dart';
import 'lista_tareas_screen.dart';
import 'colaboradores_screen.dart';
import 'firma_supervisor_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;
  int _refreshKey = 0; // Key para forzar rebuild de la lista

  void _refreshLista() {
    setState(() {
      _refreshKey++; // Incrementar para forzar rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final usuario = authService.usuario;

    final screens = [
      ListaTareasScreen(key: ValueKey(_refreshKey)),
      ColaboradoresScreen(key: ValueKey(_refreshKey)),
      FirmaSupervisorScreen(key: ValueKey(_refreshKey)),
      const Center(child: Text('Reportes (Próximamente)')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chocolatería Entrelagos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
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
                    usuario?['nombre_completo'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    usuario?['rol_display'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrearTareaScreen(),
                  ),
                );
                
                // Si se creó una tarea, recargar la lista
                if (resultado == true) {
                  _refreshLista();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva Tarea'),
            )
          : null,
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      // Cerrar sesión (eliminar token)
      await _apiService.logout();
      
      if (!mounted) return;
      
      // Volver al HomeScreen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}