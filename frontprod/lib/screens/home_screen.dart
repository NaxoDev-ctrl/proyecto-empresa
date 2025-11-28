import 'package:flutter/material.dart';
import 'seleccion_linea_screen.dart';
import 'login_screen.dart';
import 'supervisor_dashboard_screen.dart';
import '../services/api_service.dart';

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
      body: Stack(
        children: [
          // Fondo con degradado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade700,
                  Colors.blue.shade400,
                  Colors.white,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
          
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
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo y título centrados
                          _buildLogoYTitulo(),
                          
                          const SizedBox(height: 48),
                          
                          // Card de operarios
                          _buildOperariosCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Footer
                _buildFooter(),
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
          padding: EdgeInsets.all(20),
          child: ClipRRect(
            child: Image.asset(
              'assets/images/logo_entrelagos.png', // <-- TU LOGO AQUÍ
              width: 170,
              height: 170,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Si la imagen no carga, mostrar ícono de respaldo
                return Icon(
                  Icons.business,
                  size: 64,
                  color: Colors.red.shade700,
                );
              },
            ),
          ),
        ),

        SizedBox(height: 24),
        
        // Título
        const Text(
          'Chocolatería Entrelagos',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Subtítulo
        const Text(
          'Sistema de Trazabilidad',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOperariosCard() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 400,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade50,
                      Colors.white,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícono grande
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.factory,
                        size: 80,
                        color: Colors.green.shade700,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Título
                    Text(
                      'OPERARIOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Subtítulo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Registro de Producción',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Flecha
                    Icon(
                      Icons.arrow_forward,
                      size: 32,
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade600,
              ),
              SizedBox(width: 8),
              Text(
                'Versión 2.1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '© 2025 Chocolatería Entrelagos',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}