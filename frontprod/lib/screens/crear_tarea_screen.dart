import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/filtro_provider.dart';
import '../models/linea.dart';
import '../models/turno.dart';
import '../models/producto.dart';
import '../models/colaborador.dart';

class CrearTareaScreen extends StatefulWidget {
  const CrearTareaScreen({super.key});

  @override
  State<CrearTareaScreen> createState() => _CrearTareaScreenState();
}

class _CrearTareaScreenState extends State<CrearTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers
  final _metaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _searchProductoController = TextEditingController();
  final _searchColaboradorController = TextEditingController();

  // Datos del formulario
  DateTime _selectedDate = DateTime.now();
  Linea? _selectedLinea;
  Turno? _selectedTurno;
  Producto? _selectedProducto;
  List<Colaborador> _selectedColaboradores = [];

  // Listas de opciones
  List<Linea> _lineas = [];
  List<Turno> _turnos = [];
  List<Producto> _productos = [];
  List<Colaborador> _colaboradores = [];

  // Estados
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final filtroProvider = Provider.of<FiltroProvider>(context, listen: false);
        setState(() {
          _selectedDate = filtroProvider.selectedDate;
        });
      }
    });

    _cargarDatos();
  }

  @override
  void dispose() {
    _metaController.dispose();
    _observacionesController.dispose();
    _searchProductoController.dispose();
    _searchColaboradorController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final lineasData = await _apiService.getLineas();
      final turnosData = await _apiService.getTurnos();
      final productosData = await _apiService.getProductos();
      final colaboradoresData = await _apiService.getColaboradores();

      setState(() {
        _lineas = lineasData.map((json) => Linea.fromJson(json)).toList();
        _turnos = turnosData.map((json) => Turno.fromJson(json)).toList();
        _productos = productosData.map((json) => Producto.fromJson(json)).toList();
        _colaboradores = colaboradoresData.map((json) => Colaborador.fromJson(json)).toList();
        _isLoadingData = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2080),
    );

    if (picked != null) {
      // Actualizar también en el FiltroProvider
      final filtroProvider = Provider.of<FiltroProvider>(context, listen: false);
      await filtroProvider.setSelectedDate(picked);
      
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _seleccionarProducto() async {
    final producto = await showDialog<Producto>(
      context: context,
      builder: (context) => _ProductoDialog(
        productos: _productos,
        searchController: _searchProductoController,
      ),
    );

    if (producto != null) {
      setState(() {
        _selectedProducto = producto;
      });
    }
  }

  Future<void> _seleccionarColaboradores() async {
    final seleccionados = await showDialog<List<Colaborador>>(
      context: context,
      builder: (context) => _ColaboradoresDialog(
        colaboradores: _colaboradores, // <--- **PASAR LA LISTA COMPLETA**
        searchController: _searchColaboradorController,
        seleccionados: _selectedColaboradores,
      ),
    );

    if (seleccionados != null) {
      setState(() {
        _selectedColaboradores = seleccionados;
      });
    }
  }

  Future<void> _guardarTarea() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLinea == null) {
      _mostrarError('Selecciona una línea');
      return;
    }

    if (_selectedTurno == null) {
      _mostrarError('Selecciona un turno');
      return;
    }

    if (_selectedProducto == null) {
      _mostrarError('Selecciona un producto');
      return;
    }

    if (_selectedColaboradores.isEmpty) {
      _mostrarError('Selecciona al menos un colaborador');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final usuario = authService.usuario;

      await _apiService.crearTarea(
        fecha: DateFormat('yyyy-MM-dd').format(_selectedDate),
        lineaId: _selectedLinea!.id,
        turnoId: _selectedTurno!.id,
        productoCodigo: _selectedProducto!.codigo,
        metaProduccion: int.parse(_metaController.text),
        supervisorId: usuario!['id'],
        colaboradoresIds: _selectedColaboradores.map((c) => c.id).toList(),
        observaciones: _observacionesController.text.isEmpty 
            ? null 
            : _observacionesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Tarea creada exitosamente')),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      String mensajeUsuario = 'Error al crear tarea: ';

      // Detectar si es un error de tarea duplicada
      if (errorMsg.contains('conjunto único') || 
          errorMsg.contains('ya existe') ||
          errorMsg.contains('duplicad')) {
        mensajeUsuario = '⚠️ Ya existe una tarea con esa línea, turno, fecha y producto.\n\n'
            'No se pueden crear tareas duplicadas. Verifica los datos e intenta con valores diferentes.';
      } else if (errorMsg.contains('no autorizado')) {
        mensajeUsuario = 'No tienes permisos para crear tareas';
      } else if (errorMsg.contains('servidor')) {
        mensajeUsuario = 'Error del servidor. Intenta nuevamente más tarde.';
      } else {
        mensajeUsuario = 'Error al crear tarea: $e';
      }

      _mostrarError(mensajeUsuario);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva Tarea')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Tarea'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Fecha
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('EEEE, d MMMM yyyy', 'es_CL').format(_selectedDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _seleccionarFecha,
              ),
            ),
            const SizedBox(height: 12),

            // Línea
            DropdownButtonFormField<Linea>(
              decoration: const InputDecoration(
                labelText: 'Línea',
                prefixIcon: Icon(Icons.straighten),
              ),
              value: _selectedLinea,
              items: _lineas.map((linea) {
                return DropdownMenuItem(
                  value: linea,
                  child: Text(linea.nombre),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLinea = value;
                });
              },
              validator: (value) => value == null ? 'Selecciona una línea' : null,
            ),
            const SizedBox(height: 12),

            // Turno
            DropdownButtonFormField<Turno>(
              decoration: const InputDecoration(
                labelText: 'Turno',
                prefixIcon: Icon(Icons.access_time),
              ),
              value: _selectedTurno,
              items: _turnos.map((turno) {
                return DropdownMenuItem(
                  value: turno,
                  child: Text(turno.nombreDisplay),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTurno = value;
                });
              },
              validator: (value) => value == null ? 'Selecciona un turno' : null,
            ),
            const SizedBox(height: 12),

            // Producto
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Producto'),
                subtitle: _selectedProducto != null
                    ? Text('${_selectedProducto!.codigo} - ${_selectedProducto!.nombre}')
                    : const Text('Selecciona un producto'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _seleccionarProducto,
              ),
            ),
            const SizedBox(height: 12),

            // Meta de producción
            TextFormField(
              controller: _metaController,
              decoration: const InputDecoration(
                labelText: 'Meta de Producción',
                prefixIcon: Icon(Icons.flag),
                suffixText: 'unidades',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa la meta de producción';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Ingresa un número válido mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Colaboradores
            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Colaboradores'),
                subtitle: _selectedColaboradores.isEmpty
                    ? const Text('Selecciona colaboradores')
                    : Text('${_selectedColaboradores.length} seleccionados'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _seleccionarColaboradores,
              ),
            ),
            if (_selectedColaboradores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedColaboradores.map((c) {
                  return Chip(
                    label: Text('${c.codigo} - ${c.nombreCompleto}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedColaboradores.remove(c);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),

            // Observaciones
            TextFormField(
              controller: _observacionesController,
              decoration: const InputDecoration(
                labelText: 'Observaciones (Opcional)',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _guardarTarea,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading ? 'Guardando...' : 'Crear Tarea',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Boton cancelar
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context, true),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog para seleccionar producto
class _ProductoDialog extends StatefulWidget {
  final List<Producto> productos;
  final TextEditingController searchController;

  const _ProductoDialog({
    required this.productos,
    required this.searchController,
  });

  @override
  State<_ProductoDialog> createState() => _ProductoDialogState();
}
class _ProductoDialogState extends State<_ProductoDialog> {
  late List<Producto> _productosMostrados;

  @override
  void initState() {
    super.initState();
    _productosMostrados = widget.productos;
    
    // Agrega el listener para la búsqueda en tiempo real
    widget.searchController.addListener(_onSearchChanged);
    
    if (widget.searchController.text.isNotEmpty) {
      _filtrarProductos(widget.searchController.text);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    _filtrarProductos(widget.searchController.text);
  }

  void _filtrarProductos(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (lowerCaseQuery.isEmpty) {
        _productosMostrados = widget.productos;
      } else {
        _productosMostrados = widget.productos.where((p) {
          // Filtrado por código O nombre
          return p.codigo.toLowerCase().contains(lowerCaseQuery) ||
                 p.nombre.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: widget.searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _productosMostrados.length,
                itemBuilder: (context, index) {
                  final producto = _productosMostrados[index];
                  return ListTile(
                    title: Text(producto.nombre),
                    subtitle: Text('Código: ${producto.codigo}'),
                    onTap: () => Navigator.pop(context, producto),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog para seleccionar colaboradores
class _ColaboradoresDialog extends StatefulWidget {
  final List<Colaborador> colaboradores;
  final TextEditingController searchController;
  final List<Colaborador> seleccionados;

  const _ColaboradoresDialog({
    required this.colaboradores,
    required this.searchController,
    required this.seleccionados,
  });

  @override
  State<_ColaboradoresDialog> createState() => _ColaboradoresDialogState();
}

class _ColaboradoresDialogState extends State<_ColaboradoresDialog> {
  late Set<Colaborador> _currentSeleccionados;
  late List<Colaborador> _colaboradoresMostrados;

  @override
  void initState() {
    super.initState();
    _currentSeleccionados = Set<Colaborador>.from(widget.seleccionados);
    _colaboradoresMostrados = widget.colaboradores;
    // Agrega el listener para la búsqueda en tiempo real
    widget.searchController.addListener(_onSearchChanged);
    // Filtrado inicial si ya hay texto (ej. si se reabrió el diálogo)
    if (widget.searchController.text.isNotEmpty) {
      _filtrarColaboradores(widget.searchController.text);
    }
  }

  @override
  void dispose() {
    // CRUCIAL: Remover el listener para evitar fugas de memoria
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    // Esto se ejecuta cada vez que el texto cambia
    _filtrarColaboradores(widget.searchController.text);
  }

  // Lógica de filtrado
  void _filtrarColaboradores(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (lowerCaseQuery.isEmpty) {
        _colaboradoresMostrados = widget.colaboradores;
      } else {
        _colaboradoresMostrados = widget.colaboradores.where((c) {
          // Filtrado por código O nombre
          return c.codigo.toLowerCase().contains(lowerCaseQuery) ||
                 c.nombreCompleto.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: widget.searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar colaborador',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            // Muestra mensaje si no hay resultados
            if (_colaboradoresMostrados.isEmpty)
              const Expanded(
                child: Center(
                  child: Text("No se encontraron colaboradores.", style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _colaboradoresMostrados.length,
                  itemBuilder: (context, index) {
                    final colaborador = _colaboradoresMostrados[index];
                    final isSelected = _currentSeleccionados.contains(colaborador);
                    
                    return CheckboxListTile(
                      title: Text(colaborador.nombreCompleto),
                      subtitle: Text('Código: ${colaborador.codigo}'),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _currentSeleccionados.add(colaborador);
                          } else {
                            _currentSeleccionados.remove(colaborador);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _currentSeleccionados.toList()),
                      child: Text('Confirmar (${_currentSeleccionados.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}