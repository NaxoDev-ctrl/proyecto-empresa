class Turno {
  final int id;
  final String nombre;
  final String nombreDisplay;
  final String horaInicio;
  final String horaFin;
  final bool activo;

  Turno({
    required this.id,
    required this.nombre,
    required this.nombreDisplay,
    required this.horaInicio,
    required this.horaFin,
    required this.activo,
  });

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      nombreDisplay: json['nombre_display'] ?? '',
      horaInicio: json['hora_inicio'] ?? '',
      horaFin: json['hora_fin'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'nombre_display': nombreDisplay,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'activo': activo,
    };
  }
}