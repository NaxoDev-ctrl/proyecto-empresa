class Tarea {
  final int id;
  final String fecha;
  final int linea;
  final String lineaNombre;
  final int turno;
  final String turnoNombre;
  final String productoCodigo;
  final String productoNombre;
  final int metaProduccion;
  final String estado;
  final String estadoDisplay;
  final String supervisorNombre;
  final String fechaCreacion;

  Tarea({
    required this.id,
    required this.fecha,
    required this.linea,
    required this.lineaNombre,
    required this.turno,
    required this.turnoNombre,
    required this.productoCodigo,
    required this.productoNombre,
    required this.metaProduccion,
    required this.estado,
    required this.estadoDisplay,
    required this.supervisorNombre,
    required this.fechaCreacion,
  });

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['id'],
      fecha: json['fecha'],
      linea: json['linea'],
      lineaNombre: json['linea_nombre'],
      turno: json['turno'],
      turnoNombre: json['turno_nombre'],
      productoCodigo: json['producto_codigo'],
      productoNombre: json['producto_nombre'],
      metaProduccion: json['meta_produccion'],
      estado: json['estado'],
      estadoDisplay: json['estado_display'],
      supervisorNombre: json['supervisor_nombre'],
      fechaCreacion: json['fecha_creacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha,
      'linea': linea,
      'linea_nombre': lineaNombre,
      'turno': turno,
      'turno_nombre': turnoNombre,
      'producto_codigo': productoCodigo,
      'producto_nombre': productoNombre,
      'meta_produccion': metaProduccion,
      'estado': estado,
      'estado_display': estadoDisplay,
      'supervisor_nombre': supervisorNombre,
      'fecha_creacion': fechaCreacion,
    };
  }
}