class Linea {
  final int id;
  final String nombre;
  final bool activa;
  final String? descripcion;

  Linea({
    required this.id,
    required this.nombre,
    required this.activa,
    this.descripcion,
  });

  factory Linea.fromJson(Map<String, dynamic> json) {
    return Linea(
      id: json['id'],
      nombre: json['nombre'],
      activa: json['activa'],
      descripcion: json['descripcion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'activa': activa,
      'descripcion': descripcion,
    };
  }
}