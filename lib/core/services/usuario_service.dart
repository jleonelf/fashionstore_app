import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/usuario_admin_model.dart';

class UsuarioService {
  final String _endpointUsuarios = '${ApiConstants.baseUrl}/usuarios';
  final String _endpointRoles = '${ApiConstants.baseUrl}/roles';

  /// Listar roles (uso administrativo).
  Future<List<RolModel>> listarRoles() async {
    final response = await http.get(Uri.parse(_endpointRoles));
    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((j) => RolModel.fromJson(j)).toList();
    } else {
      throw Exception('Error al listar roles: ${response.statusCode}');
    }
  }

  /// Listar usuarios con filtros (uso administrativo).
  Future<List<UsuarioListadoModel>> gestionarUsuarios(
      {String? rolId, String? estado}) async {
    final queryParams = <String, String>{};
    if (rolId != null) queryParams['rol_id'] = rolId;
    if (estado != null) queryParams['estado'] = estado;

    final uri = Uri.parse(_endpointUsuarios)
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((j) => UsuarioListadoModel.fromJson(j)).toList();
    } else {
      throw Exception('Error al listar usuarios: ${response.statusCode}');
    }
  }

  /// Crear usuario interno (uso administrativo).
  Future<UsuarioListadoModel> crearUsuario({
    required String rolId,
    required String nombres,
    required String apellidos,
    required String correoElectronico,
    required String contrasenia,
    String? telefono,
  }) async {
    final response = await http.post(
      Uri.parse(_endpointUsuarios),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rol_id': rolId,
        'nombres': nombres,
        'apellidos': apellidos,
        'correo_electronico': correoElectronico,
        'contrasenia': contrasenia,
        'telefono': telefono,
      }),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return UsuarioListadoModel.fromJson(json);
    } else {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(json['detail'] ?? 'Error al crear usuario');
    }
  }

  /// Asignar nuevo rol a un usuario (uso administrativo).
  Future<UsuarioListadoModel> asignarRol(
      String usuarioId, String nuevoRolId) async {
    final response = await http.patch(
      Uri.parse('$_endpointUsuarios/$usuarioId/rol'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rol_id': nuevoRolId}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return UsuarioListadoModel.fromJson(json);
    } else {
      throw Exception('Error al cambiar rol: ${response.statusCode}');
    }
  }

  /// Desactivar usuario (uso administrativo).
  Future<UsuarioListadoModel> desactivarUsuario(String usuarioId) async {
    final response = await http.patch(
      Uri.parse('$_endpointUsuarios/$usuarioId/desactivar'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return UsuarioListadoModel.fromJson(json);
    } else {
      throw Exception('Error al desactivar usuario');
    }
  }
}
