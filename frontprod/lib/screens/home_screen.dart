import 'package:flutter/material.dart';
import 'seleccion_linea_screen.dart';
import 'login_screen.dart';
import 'supervisor_dashboard_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_footer.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});


  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _verificandoSesion = false;

  /// Verificar si hay sesión activa antes de navegar
  Future<void> _irALogin(BuildContext context) async {
    setState(() {
      _verificandoSesion = true;
    });

    try {
      // Verificar si ya hay sesión activa
      final usuario = await _apiService.getCurrentUser();
        
      setState(() {
        _verificandoSesion = false;
      });

      if (!mounted) return;

      _navegarSegunRol(usuario['rol']);

      } catch (e) {
        setState(() {
          _verificandoSesion = false;
        });
      
        if (!mounted) return;

        final loginExitoso = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );

        if (loginExitoso == true && mounted) {
          await _verificarYNavegar();
        }
      }
    }

    Future<void> _verificarYNavegar() async {
      try {
        final usuario = await _apiService.getCurrentUser();
        if (!mounted) return;
        _navegarSegunRol(usuario['rol']);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
      
  void _navegarSegunRol(String rol) {
    switch (rol) {
      case 'supervisor':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupervisorDashboard(),
          ),
        );
        break;

      case 'control_calidad':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard de Control de Calidad'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        // Cuando esté listo:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => const CalidadDashboardScreen(),
        //   ),
        // );
        break;

      default:
        _apiService.logout();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso denegado. Rol no permitido: $rol'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 137, 29, 67),
      body: Stack(
        children: [
          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                // Botón de login en esquina superior derecha
                _buildLoginButton(),
                
                // Contenido central: Logo + Título + Card
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo y título centrados
                          _buildLogoYTitulo(),
                          
                          const SizedBox(height: 1),
                          
                          // Card de operarios
                          _buildOperariosCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Footer
                AppFooter(),
              ],
            ),
          ),
            
          // Loading overlay
          if (_verificandoSesion)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _irALogin(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.person,
                    size: 28,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoYTitulo() {
    return Column(
      children: [
        // Logo
        Container(
          padding: EdgeInsets.all(1),
          child: ClipRRect(
            child: Image.asset(
              'assets/images/logo_entrelagos3.png', 
              width: 400,
              height: 400,
              errorBuilder: (context, error, stackTrace) {
                // Si la imagen no carga, mostrar ícono de respaldo
                return Icon(
                  Icons.business,
                  size: 64,
                  color: const Color.fromARGB(255, 137, 29, 66),
                );
              },
            ),
          ),
        ),

        SizedBox(height: 10),
      ],
    );
  }

  Widget _buildOperariosCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
      child: Card(
        elevation: 8,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SeleccionLineaScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 70),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono grande
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 137, 29, 66).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.factory,
                    size: 50,
                    color: Color.fromARGB(255, 137, 29, 66),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Título
                Text(
                  'OPERARIOS',
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 137, 29, 66),
                    letterSpacing: 2,
                  ),
                ),
                
                const SizedBox(height: 5),
          
                // Flecha
                Icon(
                  Icons.arrow_forward,
                  size: 40,
                  color: Color.fromARGB(255, 137, 29, 66),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}