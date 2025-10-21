class Usuario {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String nombreCompleto;
  final String email;
  final String rol;
  final String rolDisplay;
  final bool activo;

  Usuario({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    required this.rolDisplay,
    required this.activo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      username: json['username'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'],
      rolDisplay: json['rol_display'],
      activo: json['activo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'nombre_completo': nombreCompleto,
      'email': email,
      'rol': rol,
      'rol_display': rolDisplay,
      'activo': activo,
    };
  }
}