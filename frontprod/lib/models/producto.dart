class Producto {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final bool activo;

  Producto({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      codigo: json['codigo'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      activo: json['activo'],
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