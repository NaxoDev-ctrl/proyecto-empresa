// ============================================================================
// PANTALLA: Detalle de Trazabilidad para Supervisor
// Permite ver, editar y firmar trazabilidades
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class DetalleTrazabilidadSupervisorScreen extends StatefulWidget {
  final int trazabilidadId;

  const DetalleTrazabilidadSupervisorScreen({
    Key? key,
    required this.trazabilidadId,
  }) : super(key: key);

  @override
  State<DetalleTrazabilidadSupervisorScreen> createState() =>
      _DetalleTrazabilidadSupervisorScreenState();
}

class _DetalleTrazabilidadSupervisorScreenState
    extends State<DetalleTrazabilidadSupervisorScreen> {
  // ========== ESTADO ==========
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _trazabilidad;
  String? _error;
  bool _modoEdicion = false;

  // ========== CONTROLLERS PARA EDICIÓN ==========
  final TextEditingController _cantidadProducidaController =
      TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _cargarTrazabilidad();
  }

  @override
  void dispose() {
    _cantidadProducidaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // ========== CARGAR TRAZABILIDAD ==========
  Future<void> _cargarTrazabilidad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getTrazabilidadDetalle(widget.trazabilidadId);

      print('🔍 DATOS DE TRAZABILIDAD RECIBIDOS:');
      print('Tipo: ${data.runtimeType}');
      print('Contenido completo: $data');
      print('hoja_procesos tipo: ${data['hoja_procesos'].runtimeType}');
      print('hoja_procesos valor: ${data['hoja_procesos']}');

      setState(() {
        _trazabilidad = data;
        _cantidadProducidaController.text =
            data['cantidad_producida']?.toString() ?? '';
        _observacionesController.text = data['observaciones'] ?? '';
      });
    } catch (e) {
      print('❌ ERROR al cargar trazabilidad: $e');
      setState(() {
        _error = 'Error al cargar trazabilidad: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== GUARDAR CAMBIOS ==========
  Future<void> _guardarCambios() async {
    // Validar cantidad producida
    final cantidadProducida = double.tryParse(_cantidadProducidaController.text);
    if (cantidadProducida == null || cantidadProducida <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad producida debe ser un número válido mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final body = {
        'cantidad_producida': cantidadProducida.toInt(),
        'observaciones': _observacionesController.text.trim(),
      };

      await _apiService.updateTrazabilidad(widget.trazabilidadId, body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _modoEdicion = false;
        });

        await _cargarTrazabilidad();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========== FIRMAR TRAZABILIDAD ==========
  Future<void> _firmarTrazabilidad() async {
    // Confirmar acción
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Firma'),
        content: const Text(
          '¿Estás seguro de que deseas firmar esta trazabilidad?\n\n'
          'Una vez firmada, no podrás modificarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Firmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _apiService.firmarTrazabilidad(widget.trazabilidadId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trazabilidad firmada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        await _cargarTrazabilidad();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al firmar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========== UI: INFORMACIÓN DE LA TAREA ==========
  Widget _buildSeccionTarea() {
    // Verificar que existan los datos
    final hojaProcesos = _trazabilidad!['hoja_procesos_detalle'];
    if (hojaProcesos == null || hojaProcesos is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final tarea = hojaProcesos['tarea'];
    if (tarea == null || tarea is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final producto = tarea['producto'];
    final linea = tarea['linea'];
    final turno = tarea['turno'];

    if (producto == null || producto is! Map<String, dynamic> ||
        linea == null || linea is! Map<String, dynamic> ||
        turno == null || turno is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    final fecha = tarea['fecha'];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Producto', producto['nombre']?.toString() ?? ''),
            _buildInfoRow('Código', producto['codigo']?.toString() ?? ''),
            _buildInfoRow('Línea', linea['nombre']?.toString() ?? ''),
            _buildInfoRow('Turno', turno['nombre']?.toString() ?? ''),
            _buildInfoRow('Fecha', fecha != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha)) : ''),
            _buildInfoRow(
              'Fecha Creación',
              DateFormat('dd/MM/yyyy HH:mm').format(
                DateTime.parse(_trazabilidad!['fecha_creacion']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== UI: CANTIDAD PRODUCIDA Y OBSERVACIONES ==========
  Widget _buildSeccionProduccion() {
    final firmas = _trazabilidad!['firmas'] as List? ?? [];
    final tieneFirmaSupervisor = firmas.any(
      (f) => f is Map && f['tipo_firma'] == 'supervisor',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Producción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (!tieneFirmaSupervisor)
                  IconButton(
                    icon: Icon(_modoEdicion ? Icons.close : Icons.edit),
                    onPressed: () {
                      setState(() {
                        _modoEdicion = !_modoEdicion;
                      });
                    },
                    tooltip: _modoEdicion ? 'Cancelar' : 'Editar',
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Cantidad Producida
            if (_modoEdicion)
              TextFormField(
                controller: _cantidadProducidaController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad Producida',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.production_quantity_limits),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              )
            else
              _buildInfoRow(
                'Cantidad Producida',
                '${_trazabilidad!['cantidad_producida']} unidades',
              ),

            const SizedBox(height: 16),

            // Observaciones
            if (_modoEdicion)
              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observaciones:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _trazabilidad!['observaciones'] ?? 'Sin observaciones',
                    style: TextStyle(
                      color: _trazabilidad!['observaciones'] != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ],
              ),

            // Botón Guardar (solo en modo edición)
            if (_modoEdicion) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardarCambios,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== UI: MATERIAS PRIMAS ==========
  Widget _buildSeccionMateriasPrimas() {
    final materiasPrimas = _trazabilidad!['materias_primas_usadas'] as List;

    if (materiasPrimas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Materias Primas Utilizadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),
            ...materiasPrimas.map((mp) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mp['materia_prima']['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Lote: ${mp['lote']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${mp['cantidad_usada_kg']} kg',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ========== UI: REPROCESOS ==========
  Widget _buildSeccionReprocesos() {
    final reprocesos = _trazabilidad!['reprocesos'] as List;

    if (reprocesos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.loop, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Reprocesos (${reprocesos.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const Divider(),
            ...reprocesos.map((reproceso) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${reproceso['cantidad_kg']} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reproceso['descripcion'] ?? 'Sin descripción',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ========== UI: MERMAS ==========
  Widget _buildSeccionMermas() {
    final mermas = _trazabilidad!['mermas'] as List;

    if (mermas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Mermas (${mermas.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const Divider(),
            ...mermas.map((merma) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${merma['cantidad_kg']} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      merma['descripcion'] ?? 'Sin descripción',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ========== UI: FIRMAS ==========
  Widget _buildSeccionFirmas() {
    final firmas = _trazabilidad!['firmas'] as List;
    final tieneFirmaSupervisor = firmas.any((f) => f['tipo_firma'] == 'supervisor');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firmas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(),

            if (firmas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Sin firmas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...firmas.map((firma) {
                final esSupervisor = firma['tipo_firma'] == 'supervisor';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esSupervisor
                        ? Colors.green[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: esSupervisor
                          ? Colors.green[200]!
                          : Colors.blue[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: esSupervisor ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esSupervisor ? 'Supervisor' : 'Control de Calidad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esSupervisor ? Colors.green[700] : Colors.blue[700],
                              ),
                            ),
                            Text(
                              firma['usuario_nombre'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                DateTime.parse(firma['fecha_firma']),
                              ),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

            // Botón de firma (solo si no tiene firma de supervisor)
            if (!tieneFirmaSupervisor) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _firmarTrazabilidad,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit_note),
                  label: Text(_isSaving ? 'Firmando...' : 'Firmar Trazabilidad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Una vez firmada, no podrás modificar esta trazabilidad.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== HELPER: FILA DE INFORMACIÓN ==========
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ========== BUILD PRINCIPAL ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Trazabilidad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarTrazabilidad,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarTrazabilidad,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarTrazabilidad,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSeccionTarea(),
                        _buildSeccionProduccion(),
                        _buildSeccionMateriasPrimas(),
                        _buildSeccionReprocesos(),
                        _buildSeccionMermas(),
                        _buildSeccionFirmas(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }
}