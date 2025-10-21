class Colaborador {
  final int id;
  final String codigo;
  final String nombre;
  final String apellido;
  final String nombreCompleto;
  final bool activo;

  Colaborador({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.nombreCompleto,
    required this.activo,
  });

  factory Colaborador.fromJson(Map<String, dynamic> json) {
    return Colaborador(
      id: json['id'],
      codigo: json['codigo'],
      nombre: json['nombre'],
      apellido: json['apellido'],
      nombreCompleto: json['nombre_completo'],
      activo: json['activo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'apellido': apellido,
      'nombre_completo': nombreCompleto,
      'activo': activo,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Colaborador && other.id == id; // Compara solo por ID
  }

  @override
  int get hashCode => id.hashCode; // El hashcode se basa en el ID
}

