import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/api_service.dart';

class TrazabilidadScreen extends StatefulWidget {
  final int tareaId;
  final int hojaProcesosId;

  const TrazabilidadScreen({
    super.key,
    required this.tareaId,
    required this.hojaProcesosId,
  });

  @override
  State<TrazabilidadScreen> createState() => _TrazabilidadScreenState();
}

class _TrazabilidadScreenState extends State<TrazabilidadScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _cantidadProducidaController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  // Datos de la tarea
  Map<String, dynamic>? _tarea;
  List<dynamic> _materiasPrimas = [];
  
  // Datos del formulario
  Map<int, Map<String, dynamic>> _lotesMP = {}; // {materiaprima_id: {lote, cantidad, unidad}}
  List<Map<String, dynamic>> _reprocesos = [];
  List<Map<String, dynamic>> _mermas = [];
  Uint8List? _fotoEtiqueta;
  String? _nombreArchivoFoto;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadProducidaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cargar tarea con producto y receta
      final tareaData = await _apiService.getTareaDetalle(widget.tareaId);
      
      setState(() {
        _tarea = tareaData;
        _materiasPrimas = tareaData['producto_detalle']['materias_primas'] ?? [];
        
        // Inicializar mapa de lotes
        for (var mp in _materiasPrimas) {
          _lotesMP[mp['codigo'].hashCode] = {
            'materia_prima_id': mp['codigo'],
            'lote': '',
            'cantidad_usada': '',
            'unidad_medida': 'kg',
            'requiere_lote': mp['requiere_lote'],
          };
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fotoEtiqueta = bytes;
          _nombreArchivoFoto = image.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _seleccionarFotoGaleria() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fotoEtiqueta = bytes;
          _nombreArchivoFoto = image.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _agregarReproceso() {
    showDialog(
      context: context,
      builder: (context) => _DialogReproceso(
        onAgregar: (reproceso) {
          setState(() {
            _reprocesos.add(reproceso);
          });
        },
      ),
    );
  }

  void _agregarMerma() {
    showDialog(
      context: context,
      builder: (context) => _DialogMerma(
        onAgregar: (merma) {
          setState(() {
            _mermas.add(merma);
          });
        },
      ),
    );
  }

  Future<void> _guardarTrazabilidad() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fotoEtiqueta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes tomar una foto de las etiquetas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirmar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Trazabilidad'),
        content: Text(
          '¿Estás seguro de guardar la trazabilidad?\n\n'
          'Cantidad: ${_cantidadProducidaController.text} unidades\n'
          'Materias primas: ${_lotesMP.length}\n'
          'Reprocesos: ${_reprocesos.length}\n'
          'Mermas: ${_mermas.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Preparar datos de materias primas
      List<Map<String, dynamic>> materiasPrimasData = [];
      
      _lotesMP.forEach((key, value) {
        if (value['cantidad_usada'].toString().isNotEmpty) {
          materiasPrimasData.add({
            'materia_prima_id': value['materia_prima_id'],
            'lote': value['lote'].isEmpty ? null : value['lote'],
            'cantidad_usada': double.parse(value['cantidad_usada']),
            'unidad_medida': value['unidad_medida'],
          });
        }
      });

      // Crear trazabilidad
      final trazabilidadData = await _apiService.crearTrazabilidad(
        hojaProcesosId: widget.hojaProcesosId,
        cantidadProducida: int.parse(_cantidadProducidaController.text),
        materiasPrimas: materiasPrimasData,
        reprocesos: _reprocesos.isNotEmpty ? _reprocesos : null,
        mermas: _mermas.isNotEmpty ? _mermas : null,
        observaciones: _observacionesController.text.isEmpty 
            ? null 
            : _observacionesController.text,
        fotoEtiquetas: _fotoEtiqueta, 
        nombreArchivoFoto: _nombreArchivoFoto,
      );

      if (!mounted) return;

      // Mostrar éxito
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Text('¡Trazabilidad Guardada!'),
            ],
          ),
          content: Text(
            'La trazabilidad se ha guardado correctamente.\n\n'
            'Ahora será revisada por el supervisor y control de calidad.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.popUntil(context, (route) => route.isFirst); // Volver al inicio
              },
              child: Text('Finalizar'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Cargando trazabilidad...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al cargar'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Trazabilidad'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            final confirmar = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('⚠️ Advertencia'),
                content: Text(
                  'Si sales ahora, perderás todos los datos ingresados.\n\n'
                  '¿Estás seguro?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('Salir sin guardar'),
                  ),
                ],
              ),
            );

            if (confirmar == true && mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Info del producto
            _buildProductoInfo(),
            const SizedBox(height: 24),

            // Cantidad producida
            _buildCantidadProducida(),
            const SizedBox(height: 24),

            // Materias primas
            _buildMateriasPrimas(),
            const SizedBox(height: 24),

            // Reprocesos
            _buildReprocesos(),
            const SizedBox(height: 24),

            // Mermas
            _buildMermas(),
            const SizedBox(height: 24),

            // Foto de etiquetas
            _buildFotoEtiquetas(),
            const SizedBox(height: 24),

            // Observaciones
            _buildObservaciones(),
            const SizedBox(height: 32),

            // Botón guardar
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _guardarTrazabilidad,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.save, size: 28),
                label: Text(
                  _isSaving ? 'GUARDANDO...' : 'GUARDAR TRAZABILIDAD',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRODUCTO',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tarea!['producto_detalle']['nombre'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Código: ${_tarea!['producto_detalle']['codigo']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('Meta: ${_tarea!['meta_produccion']} unidades'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCantidadProducida() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CANTIDAD PRODUCIDA *',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cantidadProducidaController,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: 'unidades',
                prefixIcon: Icon(Icons.production_quantity_limits),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa la cantidad producida';
                }
                if (int.tryParse(value) == null) {
                  return 'Ingresa un número válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriasPrimas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MATERIAS PRIMAS',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (_materiasPrimas.isEmpty)
              Center(
                child: Text(
                  'No hay materias primas definidas',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._materiasPrimas.map((mp) {
                final key = mp['codigo'].hashCode;
                return _buildMateriaPrimaItem(mp, key);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriaPrimaItem(Map<String, dynamic> mp, int key) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mp['nombre'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (mp['requiere_lote'])
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Requiere Lote',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Código: ${mp['codigo']}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (mp['requiere_lote'])
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Lote',
                hintText: 'Ej: LOT12345',
                isDense: true,
              ),
              onChanged: (value) {
                _lotesMP[key]!['lote'] = value;
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _lotesMP[key]!['cantidad_usada'] = value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _lotesMP[key]!['unidad_medida'],
                  decoration: InputDecoration(
                    labelText: 'Unidad',
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'unidades', child: Text('unidades')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _lotesMP[key]!['unidad_medida'] = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReprocesos() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'REPROCESOS (Opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _agregarReproceso,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
              ],
            ),
            if (_reprocesos.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay reprocesos registrados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._reprocesos.asMap().entries.map((entry) {
                final index = entry.key;
                final reproceso = entry.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${reproceso['cantidad_kg']} kg'),
                  subtitle: Text(reproceso['descripcion']),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _reprocesos.removeAt(index);
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMermas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MERMAS (Opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _agregarMerma,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
              ],
            ),
            if (_mermas.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay mermas registradas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._mermas.asMap().entries.map((entry) {
                final index = entry.key;
                final merma = entry.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${merma['cantidad_kg']} kg'),
                  subtitle: Text(merma['descripcion']),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _mermas.removeAt(index);
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFotoEtiquetas() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOTO DE ETIQUETAS *',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (_fotoEtiqueta == null)
              Column(
                children: [
                  Text(
                    'Debes tomar una foto de las etiquetas utilizadas',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Tomar Foto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _seleccionarFotoGaleria,
                          icon: Icon(Icons.photo_library),
                          label: Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _fotoEtiqueta!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _tomarFoto,
                          icon: Icon(Icons.refresh),
                          label: Text('Tomar otra'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _fotoEtiqueta = null;
                            });
                          },
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text('Eliminar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservaciones() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OBSERVACIONES (Opcional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacionesController,
              decoration: InputDecoration(
                hintText: 'Escribe observaciones adicionales...',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG: Agregar Reproceso
// ============================================================================
class _DialogReproceso extends StatefulWidget {
  final Function(Map<String, dynamic>) onAgregar;

  const _DialogReproceso({required this.onAgregar});

  @override
  State<_DialogReproceso> createState() => _DialogReprocesoState();
}

class _DialogReprocesoState extends State<_DialogReproceso> {
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _cantidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar Reproceso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _cantidadController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descripcionController,
            decoration: InputDecoration(
              labelText: 'Descripción',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_cantidadController.text.isEmpty || 
                _descripcionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Completa todos los campos')),
              );
              return;
            }

            widget.onAgregar({
              'cantidad_kg': double.parse(_cantidadController.text),
              'descripcion': _descripcionController.text,
            });

            Navigator.pop(context);
          },
          child: Text('Agregar'),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOG: Agregar Merma
// ============================================================================
class _DialogMerma extends StatefulWidget {
  final Function(Map<String, dynamic>) onAgregar;

  const _DialogMerma({required this.onAgregar});

  @override
  State<_DialogMerma> createState() => _DialogMermaState();
}

class _DialogMermaState extends State<_DialogMerma> {
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _cantidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar Merma'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _cantidadController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descripcionController,
            decoration: InputDecoration(
              labelText: 'Descripción',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_cantidadController.text.isEmpty || 
                _descripcionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Completa todos los campos')),
              );
              return;
            }

            widget.onAgregar({
              'cantidad_kg': double.parse(_cantidadController.text),
              'descripcion': _descripcionController.text,
            });

            Navigator.pop(context);
          },
          child: Text('Agregar'),
        ),
      ],
    );
  }
}