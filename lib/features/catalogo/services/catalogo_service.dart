import '../models/catalogo_model.dart';
import '../../../core/network/api_client.dart';

/// Catálogo del cliente (contrato real del backend).
///
/// - GET /productos (lista + filtros)
/// - GET /productos/{id}
/// - GET /variantes?producto_id=
/// - GET /variantes/{id}
/// - GET /variantes/{id}/disponibilidad
/// - GET /catalogo/filtros-opciones
class CatalogoService {
  final ApiClient _api;
  CatalogoService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Producto>> listarProductos({
    required FiltrosCatalogo filtros,
    int limit = 20,
    int offset = 0,
  }) {
    return _api.get<List<Producto>>(
      '/productos',
      query: filtros.toQuery(limit: limit, offset: offset),
      convertir: (j) => ((j as List?) ?? [])
          .whereType<Map>()
          .map((e) => Producto.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<Producto> obtenerProducto(String id) {
    return _api.get<Producto>(
      '/productos/$id',
      convertir: (j) => Producto.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<List<Variante>> variantesPorProducto(String productoId) {
    return _api.get<List<Variante>>(
      '/variantes',
      query: {'producto_id': productoId, 'limit': '100', 'offset': '0'},
      convertir: (j) => ((j as List?) ?? [])
          .whereType<Map>()
          .map((e) => Variante.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<Variante> obtenerVariante(String id) {
    return _api.get<Variante>(
      '/variantes/$id',
      convertir: (j) => Variante.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<List<DisponibilidadSucursal>> disponibilidad(String varianteId) {
    return _api.get<List<DisponibilidadSucursal>>(
      '/variantes/$varianteId/disponibilidad',
      convertir: (j) => ((j as List?) ?? [])
          .whereType<Map>()
          .map(
              (e) => DisponibilidadSucursal.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<FiltrosOpciones> filtrosOpciones() {
    return _api.get<FiltrosOpciones>(
      '/catalogo/filtros-opciones',
      convertir: (j) =>
          FiltrosOpciones.fromJson((j as Map).cast<String, dynamic>()),
    );
  }
}
