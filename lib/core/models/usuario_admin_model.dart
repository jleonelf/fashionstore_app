class RolModel {
  final String id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  RolModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory RolModel.fromJson(Map<String, dynamic> json) {
    return RolModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
    );
  }
}

class UsuarioListadoModel {
  final String id;
  final String rolId;
  final String rolNombre;
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String correoElectronico;
  final String? telefono;
  final String estado;
  final DateTime creadoEn;

  UsuarioListadoModel({
    required this.id,
    required this.rolId,
    required this.rolNombre,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.correoElectronico,
    this.telefono,
    required this.estado,
    required this.creadoEn,
  });

  factory UsuarioListadoModel.fromJson(Map<String, dynamic> json) {
    return UsuarioListadoModel(
      id: json['id'] ?? '',
      rolId: json['rol_id'] ?? '',
      rolNombre: json['rol_nombre'] ?? '',
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      correoElectronico: json['correo_electronico'] ?? '',
      telefono: json['telefono'],
      estado: json['estado'] ?? 'ACTIVO',
      creadoEn: DateTime.tryParse(json['creado_en'] ?? '') ?? DateTime.now(),
    );
  }
}
