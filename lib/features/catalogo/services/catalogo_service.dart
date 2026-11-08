import '../models/catalogo_model.dart';
import '../models/catalogo_snapshot_model.dart';
import '../../ventas_pagos/models/caja_model.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_database_service.dart';

/// Catálogo del cliente (contrato real del backend).
///
/// Soporta:
/// - Online: GET /productos, GET /variantes, GET /variantes/{id}/disponibilidad
/// - CU03: GET /catalogo/descarga y guardado atómico en SQLite vía staging
/// - CU16: Consulta sobre snapshot SQLite cuando falla o no hay conexión de red
class CatalogoService {
  final ApiClient _api;
  final LocalDatabaseService _storage;

  CatalogoService({ApiClient? api, LocalDatabaseService? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? LocalDatabaseService();

  LocalDatabaseService get storage => _storage;

  Future<List<Producto>> listarProductos({
    required FiltrosCatalogo filtros,
    int limit = 20,
    int offset = 0,
    String? empresaCodigo,
  }) {
    final query = filtros.toQuery(limit: limit, offset: offset);
    final emp = empresaCodigo ?? ApiConfig.empresaCodigoDefecto;
    if (emp.isNotEmpty) {
      query['empresa_codigo'] = emp;
    }
    return _api.get<List<Producto>>(
      '/productos',
      query: query,
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

  Future<List<DisponibilidadSucursal>> disponibilidad(String varianteId) async {
    try {
      return await _api.get<List<DisponibilidadSucursal>>(
        '/variantes/$varianteId/disponibilidad',
        convertir: (j) => ((j as List?) ?? [])
            .whereType<Map>()
            .map((e) => DisponibilidadSucursal.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      // Fallback a SQLite local si no hay conexión
      final local = await _storage.disponibilidadVarianteLocal(varianteId);
      if (local.isNotEmpty) return local;
      rethrow;
    }
  }

  Future<FiltrosOpciones> filtrosOpciones({String? empresaCodigo}) {
    final query = <String, String>{};
    final emp = empresaCodigo ?? ApiConfig.empresaCodigoDefecto;
    if (emp.isNotEmpty) query['empresa_codigo'] = emp;

    return _api.get<FiltrosOpciones>(
      '/catalogo/filtros-opciones',
      query: query.isEmpty ? null : query,
      convertir: (j) =>
          FiltrosOpciones.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  // -------------------------------------------------------------
  // CU03: DESCARGA DE CATÁLOGO OFFLINE (SQLITE)
  // -------------------------------------------------------------

  /// Descarga el snapshot completo del catálogo y lo persiste atómicamente en SQLite.
  Future<CatalogoSnapshotModel> descargarCatalogo({
    String? empresaCodigo,
    String? sucursalId,
    bool simularFalloAntesDeCommit = false,
  }) async {
    final codigo = empresaCodigo ?? ApiConfig.empresaCodigoDefecto;
    final query = <String, String>{
      'empresa_codigo': codigo,
    };
    if (sucursalId != null && sucursalId.isNotEmpty) {
      query['sucursal_id'] = sucursalId;
    }

    final snapshot = await _api.get<CatalogoSnapshotModel>(
      '/catalogo/descarga',
      query: query,
      convertir: (j) => CatalogoSnapshotModel.fromJson(
        (j as Map).cast<String, dynamic>(),
      ),
    );

    await _storage.guardarSnapshot(
      snapshot: snapshot,
      simularFalloAntesDeCommit: simularFalloAntesDeCommit,
    );

    return snapshot;
  }

  /// Obtiene los metadatos de la copia local activa desde SQLite.
  Future<SnapshotMetadata?> obtenerSnapshotActivo([String? empresaCodigoOId]) {
    final key = empresaCodigoOId ?? ApiConfig.empresaCodigoDefecto;
    return _storage.obtenerSnapshotActivo(key);
  }

  // -------------------------------------------------------------
  // CU16: CONSULTA LOCAL CON FILTROS EN SQLITE
  // -------------------------------------------------------------

  /// Consulta el catálogo localmente sobre SQLite cuando no hay conexión.
  Future<ResultadoConsultaLocal> consultarCatalogoLocal({
    String? empresaCodigoOId,
    String? texto,
    String? categoriaId,
    String? tallaId,
    String? colorId,
    List<String>? componentesColor,
    String modoColor = 'EXACTO',
    double? precioMin,
    double? precioMax,
    int limit = 20,
    int offset = 0,
  }) {
    final key = empresaCodigoOId ?? ApiConfig.empresaCodigoDefecto;
    return _storage.consultarCatalogoLocal(
      empresaCodigoOId: key,
      texto: texto,
      categoriaId: categoriaId,
      tallaId: tallaId,
      colorId: colorId,
      componentesColor: componentesColor,
      modoColor: modoColor,
      precioMin: precioMin,
      precioMax: precioMax,
      limit: limit,
      offset: offset,
    );
  }

  /// Lista las variantes disponibles para habilitación de cupos en Caja Móvil.
  Future<List<VarianteCajaDisponibleModel>> listarVariantesParaCaja({String? sucursalId}) async {
    // 1. Intentar online desde /variantes
    try {
      final variantes = await _api.get<List<Variante>>(
        '/variantes',
        query: {'solo_activas': 'true', 'limit': '100', 'offset': '0'},
        convertir: (j) => ((j as List?) ?? [])
            .whereType<Map>()
            .map((e) => Variante.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

      if (variantes.isNotEmpty) {
        final Map<String, String> nombresProductos = {};
        try {
          final prods = await listarProductos(filtros: FiltrosCatalogo(), limit: 100);
          for (final p in prods) {
            nombresProductos[p.id] = p.nombre;
          }
        } catch (_) {}

        return variantes.map((v) {
          final prodNombre = nombresProductos[v.productoId] ?? 'Prenda';
          return VarianteCajaDisponibleModel(
            varianteId: v.id,
            productoId: v.productoId,
            sku: v.sku,
            productoNombre: prodNombre,
            precioBob: v.precio,
          );
        }).toList();
      }
    } catch (_) {}

    // 2. Si no hay conexión o falla la API, fallback a SQLite local
    final rows = await _storage.listarVariantesParaCaja(sucursalId: sucursalId);
    return rows.map((r) {
      double precio = 0.0;
      final pRaw = r['precio_bob'];
      if (pRaw != null) {
        precio = double.tryParse(pRaw.toString()) ?? 0.0;
      }
      return VarianteCajaDisponibleModel(
        varianteId: '${r['variante_id']}',
        productoId: r['producto_id']?.toString(),
        sku: '${r['sku'] ?? 'SKU'}',
        productoNombre: r['producto_nombre']?.toString() ?? 'Prenda',
        talla: r['talla']?.toString(),
        color: r['color']?.toString(),
        precioBob: precio,
      );
    }).toList();
  }
}
