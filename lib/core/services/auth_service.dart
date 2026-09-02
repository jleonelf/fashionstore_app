import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/usuario_model.dart';

class AuthService {
  /**
   * CU01 / RF01: Registrar nuevo cliente
   */
  Future<ClientePerfilModel> registrarCliente({
    required String nombres,
    required String apellidos,
    required String correoElectronico,
    required String contrasenia,
    String? telefono,
    String? direccionReferencia,
    String? fechaNacimiento,
    Map<String, dynamic>? preferencias,
  }) async {
    final url = Uri.parse(ApiConstants.endpointClientes);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombres': nombres,
        'apellidos': apellidos,
        'correo_electronico': correoElectronico,
        'contrasenia': contrasenia,
        'telefono': telefono,
        'direccion_referencia': direccionReferencia,
        'fecha_nacimiento': fechaNacimiento,
        'preferencias': preferencias ?? {},
      }),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return ClientePerfilModel.fromJson(json);
    } else if (response.statusCode == 409) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(json['detail'] ?? 'El correo electrónico ya se encuentra registrado.');
    } else {
      throw Exception('Error al registrar cliente: ${response.statusCode}');
    }
  }

  /**
   * CU01 / RF01: Iniciar sesión
   */
  Future<TokenRespuestaModel> iniciarSesion({
    required String correoElectronico,
    required String contrasenia,
  }) async {
    final url = Uri.parse(ApiConstants.endpointSesion);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'correo_electronico': correoElectronico,
        'contrasenia': contrasenia,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final tokenRespuesta = TokenRespuestaModel.fromJson(json);

      // Guardar token y usuario en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fs_token', tokenRespuesta.accessToken);
      await prefs.setString('fs_usuario', jsonEncode(tokenRespuesta.usuario.toJson()));

      return tokenRespuesta;
    } else if (response.statusCode == 401) {
      throw Exception('Credenciales incorrectas. Verifique su correo o contraseña.');
    } else {
      throw Exception('Error de inicio de sesión: ${response.statusCode}');
    }
  }

  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fs_token');
    await prefs.remove('fs_usuario');
  }

  Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fs_token');
  }

  Future<bool> estaAutenticado() async {
    final token = await obtenerToken();
    return token != null && token.isNotEmpty;
  }
}
