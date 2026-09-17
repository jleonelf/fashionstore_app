import '../models/organizacion_model.dart';
import '../network/api_client.dart';

/// Organización (contrato real). La app de cliente solo usa el listado.
class OrganizacionService {
  final ApiClient _api;
  OrganizacionService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<CiudadModel>> gestionarCiudades({bool soloActivas = true}) async {
    return _api.get<List<CiudadModel>>(
      '/ciudades',
      query: {'solo_activas': '$soloActivas'},
      convertir: (j) => ((j as List?) ?? [])
          .whereType<Map>()
          .map((e) => CiudadModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<CiudadModel> registrarCiudad(String nombre) {
    return _api.post<CiudadModel>(
      '/ciudades',
      cuerpo: {'nombre': nombre},
      convertir: (j) =>
          CiudadModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<List<SucursalModel>> gestionarSucursales({String? ciudadId}) {
    final q = <String, String>{};
    if (ciudadId != null) q['ciudad_id'] = ciudadId;
    return _api.get<List<SucursalModel>>(
      '/sucursales',
      query: q,
      convertir: (j) => ((j as List?) ?? [])
          .whereType<Map>()
          .map((e) => SucursalModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

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
  }) {
    return _api.post<SucursalModel>(
      '/sucursales',
      cuerpo: {
        'ciudad_id': ciudadId,
        'nombre': nombre,
        'direccion': direccion,
        if (telefono != null) 'telefono': telefono,
        if (numeroAnillo != null) 'numero_anillo': numeroAnillo,
        'tarifa_base_delivery': tarifaBaseDelivery,
        'incremento_anillo_delivery': incrementoAnilloDelivery,
        'anillo_minimo_delivery': anilloMinimoDelivery,
        'anillo_maximo_delivery': anilloMaximoDelivery,
        'delivery_activo': deliveryActivo,
      },
      convertir: (j) =>
          SucursalModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<SucursalModel> configurarTarifasDelivery({
    required String sucursalId,
    required double tarifaBaseDelivery,
    required double incrementoAnilloDelivery,
    int? anilloMinimoDelivery,
    int? anilloMaximoDelivery,
    bool? deliveryActivo,
  }) {
    return _api.patch<SucursalModel>(
      '/sucursales/$sucursalId/tarifas',
      cuerpo: {
        'tarifa_base_delivery': tarifaBaseDelivery,
        'incremento_anillo_delivery': incrementoAnilloDelivery,
        if (anilloMinimoDelivery != null)
          'anillo_minimo_delivery': anilloMinimoDelivery,
        if (anilloMaximoDelivery != null)
          'anillo_maximo_delivery': anilloMaximoDelivery,
        if (deliveryActivo != null) 'delivery_activo': deliveryActivo,
      },
      convertir: (j) =>
          SucursalModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }
}
