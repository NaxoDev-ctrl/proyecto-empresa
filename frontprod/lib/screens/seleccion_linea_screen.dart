import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/linea.dart';
import 'seleccion_tarea_screen.dart';

class SeleccionLineaScreen extends StatefulWidget {
  const SeleccionLineaScreen({super.key});

  @override
  State<SeleccionLineaScreen> createState() => _SeleccionLineaScreenState();
}

class _SeleccionLineaScreenState extends State<SeleccionLineaScreen> {
  final ApiService _apiService = ApiService();
  List<Linea> _lineas = [];
  bool _isLoading = true;
  String? _error;
  final Color _primaryColor = const Color(0xFF891D43);
  final Color _onPrimaryColor = const Color(0xFFFFD9C6);
  final Color _cardColor = const Color(0xFFFFEFE9); // Fondo de la tarjeta
  final Color _cardTextColor = const Color(0xFF5A102A);
  final Map<String, String> _lineaImageAssets = {
    'L1': 'assets/images/logo_entrelagos2.png',
    'L2': 'assets/images/logo_entrelagosE.png',
    'L3': 'assets/images/foto_linea3.jpg',
    'L4': 'assets/images/foto_linea4.jpg',
    // Agrega más mapeos según necesites:
    // 'L3': 'assets/images/imagenL3.png',
  };

  @override
  void initState() {
    super.initState();
    _cargarLineas();
  }

  Future<void> _cargarLineas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getLineas();
      setState(() {
        _lineas = data.map((json) => Linea.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _seleccionarLinea(Linea linea) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeleccionTareaScreen(linea: linea),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeaderFijo(context),
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
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: _buildContent(),
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
      
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: CircleAvatar(
            backgroundColor: _onPrimaryColor,
            radius: 22,
            child: Icon(
              Icons.arrow_back,
              color: _primaryColor,
              size: 35,
            ),
          ),
        ),
      ),
      
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SELECCIONA TU ZONA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onPrimaryColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'PRODUCTIVA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onPrimaryColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      centerTitle: true,
      
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Image.asset(
              'assets/images/logo_entrelagosE.png',
              fit: BoxFit.contain,
              color: _onPrimaryColor,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.emoji_events,
                color: _onPrimaryColor,
                size: 30,
              ),
            ),
          ),
        ),
      ],
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
            Text('Cargando líneas...'),
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
            Text('Error al cargar líneas'),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarLineas,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_lineas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay líneas disponibles',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarLineas,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: _lineas.length,
        itemBuilder: (context, index) {
          final linea = _lineas[index];
          return _buildLineaCard(linea);
        },
      ),
    );
  }

  Widget _buildLineaCard(Linea linea) {
    final String? imagePath = _lineaImageAssets[linea.nombre];
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _seleccionarLinea(linea),
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            image: imagePath != null
                ? DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    colorFilter: ColorFilter.mode(
                      _cardColor.withAlpha(102),
                      BlendMode.srcATop,
                    ),
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _cardColor.withAlpha(0), 
                        _cardColor.withAlpha(15),
                        _cardColor.withAlpha(243),
                        _cardColor,
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        linea.nombre,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _cardTextColor,
                          shadows: [
                            Shadow(
                              color: Colors.white.withAlpha(204),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      if (linea.descripcion != null && linea.descripcion!.isNotEmpty)
                        Text(
                          linea.descripcion!,
                          style: TextStyle(
                            fontSize: 14,
                            color: _cardTextColor.withAlpha(204),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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