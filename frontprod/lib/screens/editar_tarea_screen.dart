import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/linea.dart';
import '../models/turno.dart';
import '../models/producto.dart';
import '../models/colaborador.dart';

class EditarTareaScreen extends StatefulWidget {
  final Map<String, dynamic> tarea;

  const EditarTareaScreen({
    super.key,
    required this.tarea,
  });

  @override
  State<EditarTareaScreen> createState() => _EditarTareaScreenState();
}

class _EditarTareaScreenState extends State<EditarTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers
  final _metaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _searchProductoController = TextEditingController();
  final _searchColaboradorController = TextEditingController();

  // Datos del formulario
  late DateTime _selectedDate;
  Linea? _selectedLinea;
  Turno? _selectedTurno;
  Producto? _selectedProducto;
  List<Colaborador> _selectedColaboradores = [];

  // Listas de opciones
  List<Linea> _lineas = [];
  List<Turno> _turnos = [];
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Colaborador> _colaboradores = [];
  List<Colaborador> _colaboradoresFiltrados = [];

  // Estados
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _cargarDatos();
    _searchProductoController.addListener(_filtrarProductos);
    _searchColaboradorController.addListener(_filtrarColaboradores);
  }

  void _initializeData() {
    // Inicializar con los datos de la tarea
    _selectedDate = DateTime.parse(widget.tarea['fecha']);
    _metaController.text = widget.tarea['meta_produccion'].toString();
    _observacionesController.text = widget.tarea['observaciones'] ?? '';
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
        _productosFiltrados = _productos;
        _colaboradores = colaboradoresData.map((json) => Colaborador.fromJson(json)).toList();
        _colaboradoresFiltrados = _colaboradores;

        // Seleccionar valores actuales
        _selectedLinea = _lineas.firstWhere(
          (l) => l.id == widget.tarea['linea'],
          orElse: () => _lineas.first,
        );
        
        _selectedTurno = _turnos.firstWhere(
          (t) => t.id == widget.tarea['turno'],
          orElse: () => _turnos.first,
        );
        
        _selectedProducto = _productos.firstWhere(
          (p) => p.codigo == widget.tarea['producto'],
          orElse: () => _productos.first,
        );

        // Cargar colaboradores seleccionados
        final colaboradoresActuales = widget.tarea['colaboradores'] as List;
        _selectedColaboradores = _colaboradores.where((c) {
          return colaboradoresActuales.any((ca) => ca['id'] == c.id);
        }).toList();

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

  void _filtrarProductos() {
    final query = _searchProductoController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((p) {
        return p.codigo.toLowerCase().contains(query) ||
               p.nombre.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _filtrarColaboradores() {
    final query = _searchColaboradorController.text.toLowerCase();
    setState(() {
      _colaboradoresFiltrados = _colaboradores.where((c) {
        return c.codigo.toString().contains(query) ||
               c.nombreCompleto.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _seleccionarProducto() async {
    final producto = await showDialog<Producto>(
      context: context,
      builder: (context) => _ProductoDialog(
        productos: _productosFiltrados,
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
        colaboradores: _colaboradoresFiltrados,
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

  Future<void> _guardarCambios() async {
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
      // Primero, verificar que la tarea siga siendo editable
      final tareaActual = await _apiService.getTareaDetalle(widget.tarea['id']);
      
      if (tareaActual['estado'] != 'pendiente') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Tarea ya no es editable'),
              content: Text(
                'El estado de la tarea cambió a "${tareaActual['estado_display']}".\n\n'
                'No se pueden editar tareas que no estén en estado pendiente.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar diálogo
                    Navigator.pop(context); // Cerrar pantalla de edición
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _apiService.actualizarTarea(
        id: widget.tarea['id'],
        fecha: DateFormat('yyyy-MM-dd').format(_selectedDate),
        lineaId: _selectedLinea!.id,
        turnoId: _selectedTurno!.id,
        productoCodigo: _selectedProducto!.codigo,
        metaProduccion: int.parse(_metaController.text),
        supervisorId: widget.tarea['supervisor_asignador'],
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
                Expanded(child: Text('Tarea actualizada exitosamente')),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      String mensajeUsuario = 'Error al editar tarea: ';

      // Detectar si es un error de tarea duplicada
      if (errorMsg.contains('conjunto único') || 
          errorMsg.contains('ya existe') ||
          errorMsg.contains('duplicad')) {
        mensajeUsuario = '⚠️ Ya existe una tarea con esa línea, turno, fecha y producto.\n\n'
            'No se pueden editar tareas duplicadas. Verifica los datos e intenta con valores diferentes.';
      } else if (errorMsg.contains('no autorizado')) {
        mensajeUsuario = 'No tienes permisos para editar tareas';
      } else if (errorMsg.contains('servidor')) {
        mensajeUsuario = 'Error del servidor. Intenta nuevamente más tarde.';
      } else {
        mensajeUsuario = 'Error al editar tarea: $e';
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
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Tarea')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Tarea'),
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
            // Advertencia si la tarea no está pendiente
            if (widget.tarea['estado'] != 'pendiente')
              Card(
                color: Colors.orange.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Esta tarea ya no está pendiente. Los cambios pueden no ser apropiados.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Fecha
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)),
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

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _guardarCambios,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog para seleccionar producto (reutilizado de crear_tarea_screen)
class _ProductoDialog extends StatelessWidget {
  final List<Producto> productos;
  final TextEditingController searchController;

  const _ProductoDialog({
    required this.productos,
    required this.searchController,
  });

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
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
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

// Dialog para seleccionar colaboradores (reutilizado de crear_tarea_screen)
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
  late List<Colaborador> _seleccionados;

  @override
  void initState() {
    super.initState();
    _seleccionados = List.from(widget.seleccionados);
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
            Expanded(
              child: ListView.builder(
                itemCount: widget.colaboradores.length,
                itemBuilder: (context, index) {
                  final colaborador = widget.colaboradores[index];
                  final isSelected = _seleccionados.any((c) => c.id == colaborador.id);
                  
                  return CheckboxListTile(
                    title: Text(colaborador.nombreCompleto),
                    subtitle: Text('Código: ${colaborador.codigo}'),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _seleccionados.add(colaborador);
                        } else {
                          _seleccionados.removeWhere((c) => c.id == colaborador.id);
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
                      onPressed: () => Navigator.pop(context, _seleccionados),
                      child: Text('Confirmar (${_seleccionados.length})'),
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