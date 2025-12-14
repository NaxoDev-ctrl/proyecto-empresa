class Producto {
  final String codigo;
  final String nombre;
  final String unidadMedida;
  final String unidadMedidaDisplay;
  final String? descripcion;
  final bool activo;

  Producto({
    required this.codigo,
    required this.nombre,
    required this.unidadMedida,
    required this.unidadMedidaDisplay,
    this.descripcion,
    required this.activo,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      unidadMedida: json['unidad_medida'] ?? '',
      unidadMedidaDisplay: json['unidad_medida_display'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    };
  }
}