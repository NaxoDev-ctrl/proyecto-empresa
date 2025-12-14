import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import '../services/api_service.dart';
import '../models/colaborador.dart';

class ColaboradoresScreen extends StatefulWidget {
  const ColaboradoresScreen({super.key});

  @override
  State<ColaboradoresScreen> createState() => _ColaboradoresScreenState();
}

class _ColaboradoresScreenState extends State<ColaboradoresScreen> {
  final ApiService _apiService = ApiService();
  List<Colaborador> _colaboradores = [];
  List<Colaborador> _colaboradoresFiltrados = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarColaboradores();
    _searchController.addListener(_filtrarColaboradores);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarColaboradores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getColaboradores();
      setState(() {
        _colaboradores = data.map((json) => Colaborador.fromJson(json)).toList();
        _colaboradoresFiltrados = _colaboradores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filtrarColaboradores() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _colaboradoresFiltrados = _colaboradores;
      } else {
        _colaboradoresFiltrados = _colaboradores.where((c) {
          return c.codigo.toString().contains(query) ||
                 c.nombreCompleto.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _cargarDesdeExcel() async {
    try {
      // Usar file picker para web
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // Usuario canceló
      }

      final file = result.files.first;
      
      if (file.bytes == null) {
        _mostrarError('No se pudo leer el archivo');
        return;
      }

      // Procesar archivo Excel
      late final List<Map<String, dynamic>> colaboradoresData;
      try {
        colaboradoresData = await _procesarArchivoExcel(file.bytes!);
      } catch (e) {
        _mostrarError(e.toString());
        return;
      }

      // Mostrar diálogo de confirmación ANTES de cargar
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => _DialogConfirmacionCarga(
          colaboradores: colaboradoresData,
        ),
      );

      if (confirmar != true) {
        return; // Usuario canceló
      }

      // Mostrar diálogo de carga
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando colaboradores...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Enviar al backend
      final response = await _apiService.cargarColaboradoresJson(colaboradoresData);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        
        // Mostrar resultado
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Carga Exitosa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total procesados: ${response['total']}'),
                Text('Nuevos: ${response['creados']}'),
                Text('Actualizados: ${response['actualizados']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cargarColaboradores(); // Recargar lista
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga si está abierto
      }
      _mostrarError('Error al cargar archivo: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _procesarArchivoExcel(List<int> bytes) async {
    try {
      // Decodificar el archivo Excel
      final excelFile = excel_pkg.Excel.decodeBytes(bytes);
      
      // Obtener la primera hoja
      final sheet = excelFile.tables.keys.first;
      final rows = excelFile.tables[sheet]?.rows;
      
      if (rows == null || rows.isEmpty) {
        throw Exception('El archivo está vacío');
      }

      // Validar que tenga al menos 2 filas (1 encabezado + 1 dato)
      if (rows.length < 2) {
        throw Exception('El archivo debe tener al meno un colaborador (ademáss del encabezado)');
      }

      List<Map<String, dynamic>> colaboradoresData = [];

      // Empezar desde la fila 1 (índice 1), asumiendo que la fila 0 tiene encabezados
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        // Validar que tenga al menos 3 columnas
        if (row.length < 3) continue;
        
        // Obtener valores y convertirlos a String
        final codigo = row[0]?.value?.toString().trim() ?? '';
        final nombre = row[1]?.value?.toString().trim() ?? '';
        final apellido = row[2]?.value?.toString().trim() ?? '';
        
        // Solo agregar si todos los campos tienen valor
        if (codigo.isNotEmpty && nombre.isNotEmpty && apellido.isNotEmpty) {
          colaboradoresData.add({
            'codigo': codigo,
            'nombre': nombre,
            'apellido': apellido,
          });
        }
      }

      if (colaboradoresData.isEmpty) {
        throw Exception('El archivo no contiene datos válidos de colaboradores');
      }

      return colaboradoresData;
    } catch (e) {
      throw Exception('Error al procesar Excel: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  Future<void> _mostrarInstrucciones() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Formato del Archivo Excel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El archivo Excel debe tener el siguiente formato:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: const Text(
                  'Código | Nombre | Apellido\n'
                  '001    | Juan   | Pérez\n'
                  '002    | María  | González\n'
                  '003    | Carlos | Rodríguez',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Requisitos:'),
              const SizedBox(height: 8),
              const Text('• La primera fila debe contener los encabezados'),
              const Text('• Código: Identificador único del colaborador'),
              const Text('• Nombre: Nombre del colaborador'),
              const Text('• Apellido: Apellido del colaborador'),
              const Text('• Los datos comienzan desde la fila 2'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header con búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            color: Color.fromARGB(255, 217, 244, 205),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por código o nombre...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _cargarDesdeExcel,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Cargar Excel'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      tooltip: 'Ver formato de archivo',
                      onPressed: _mostrarInstrucciones,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de colaboradores: ${_colaboradores.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Lista de colaboradores
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar colaboradores', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarColaboradores,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_colaboradoresFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No hay colaboradores registrados'
                  : 'No se encontraron resultados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Carga colaboradores desde un archivo Excel',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarColaboradores,
      child: _colaboradoresFiltrados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_search,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se encontraron colaboradores',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_searchController.text.isNotEmpty)
                    Text(
                      'Intenta con otro término de búsqueda',
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  else
                    const Text(
                      'Carga colaboradores desde un archivo Excel',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _colaboradoresFiltrados.length,
              itemBuilder: (context, index) {
                final colaborador = _colaboradoresFiltrados[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color.fromARGB(255, 217, 244, 205),
                      child: Text(
                        colaborador.codigo.toString().length >= 3
                        ? colaborador.codigo.toString().substring(0, 3)
                        : colaborador.codigo.toString(),
                        style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(colaborador.nombreCompleto),
                    trailing: Icon(
                      colaborador.activo ? Icons.check_circle : Icons.cancel,
                      color: colaborador.activo ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Dialog de confirmación antes de cargar
class _DialogConfirmacionCarga extends StatelessWidget {
  final List<Map<String, dynamic>> colaboradores;

  const _DialogConfirmacionCarga({
    required this.colaboradores,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar Carga de Colaboradores'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📋 Se cargarán ${colaboradores.length} colaboradores',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vista previa de los primeros 5 colaboradores:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: colaboradores.length > 5 ? 5 : colaboradores.length,
                itemBuilder: (context, index) {
                  final c = colaboradores[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, 
                          color: Colors.green, 
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${c['codigo']} - ${c['nombre']} ${c['apellido']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (colaboradores.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '... y ${colaboradores.length - 5} más',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los colaboradores duplicados serán actualizados',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: const Text('Confirmar Carga'),
        ),
      ],
    );
  }
}