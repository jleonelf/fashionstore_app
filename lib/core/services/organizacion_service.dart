import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/organizacion_model.dart';

class OrganizacionService {
  final String _endpointCiudades = '${ApiConstants.baseUrl}/ciudades';
  final String _endpointSucursales = '${ApiConstants.baseUrl}/sucursales';

  /**
   * CU03 / RF03: Listar ciudades
   */
  Future<List<CiudadModel>> gestionarCiudades({bool soloActivas = true}) async {
    final response = await http.get(Uri.parse('$_endpointCiudades?solo_activas=$soloActivas'));
    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((j) => CiudadModel.fromJson(j)).toList();
    } else {
      throw Exception('Error al listar ciudades: ${response.statusCode}');
    }
  }

  /**
   * CU03 / RF03: Registrar ciudad
   */
  Future<CiudadModel> registrarCiudad(String nombre) async {
    final response = await http.post(
      Uri.parse(_endpointCiudades),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nombre': nombre}),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return CiudadModel.fromJson(json);
    } else {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(json['detail'] ?? 'Error al crear ciudad');
    }
  }

  /**
   * CU03 / RF03: Listar sucursales
   */
  Future<List<SucursalModel>> gestionarSucursales({String? ciudadId}) async {
    final queryParams = <String, String>{};
    if (ciudadId != null) queryParams['ciudad_id'] = ciudadId;

    final uri = Uri.parse(_endpointSucursales).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((j) => SucursalModel.fromJson(j)).toList();
    } else {
      throw Exception('Error al listar sucursales: ${response.statusCode}');
    }
  }

  /**
   * CU03 / RF03: Registrar sucursal
   */
  Future<SucursalModel> registrarSucursal({
    required String ciudadId,
    required String nombre,
    required String direccion,
    String? telefono,
    int? numeroAnillo,
    double tarifaBaseDelivery = 15.0,
    double incrementoAnilloDelivery = 3.0,
    int anilloMinimoDelivery = 1,
    int anilloMaximoDelivery = 10,
    bool deliveryActivo = true,
  }) async {
    final response = await http.post(
      Uri.parse(_endpointSucursales),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ciudad_id': ciudadId,
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'numero_anillo': numeroAnillo,
        'tarifa_base_delivery': tarifaBaseDelivery,
        'incremento_anillo_delivery': incrementoAnilloDelivery,
        'anillo_minimo_delivery': anilloMinimoDelivery,
        'anillo_maximo_delivery': anilloMaximoDelivery,
        'delivery_activo': deliveryActivo,
      }),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return SucursalModel.fromJson(json);
    } else {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(json['detail'] ?? 'Error al crear sucursal');
    }
  }

  /**
   * CU03 / RF03: Configurar tarifas delivery
   */
  Future<SucursalModel> configurarTarifasDelivery({
    required String sucursalId,
    required double tarifaBaseDelivery,
    required double incrementoAnilloDelivery,
    int? anilloMinimoDelivery,
    int? anilloMaximoDelivery,
    bool? deliveryActivo,
  }) async {
    final response = await http.patch(
      Uri.parse('$_endpointSucursales/$sucursalId/tarifas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tarifa_base_delivery': tarifaBaseDelivery,
        'incremento_anillo_delivery': incrementoAnilloDelivery,
        'anillo_minimo_delivery': anilloMinimoDelivery,
        'anillo_maximo_delivery': anilloMaximoDelivery,
        'delivery_activo': deliveryActivo,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return SucursalModel.fromJson(json);
    } else {
      throw Exception('Error al actualizar tarifas de delivery');
    }
  }
}
