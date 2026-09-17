import 'package:uuid/uuid.dart';

import '../models/reserva_model.dart';
import '../network/api_client.dart';

/// Reservas del cliente (contrato real).
///
/// - POST /reservas (con Idempotency-Key)
/// - GET /reservas (paginado, propias)
/// - GET /reservas/{id} y /reservas/codigo/{codigo}
/// - PATCH /reservas/{id}/cancelar
class ReservaService {
  final ApiClient _api;
  ReservaService({ApiClient? api}) : _api = api ?? ApiClient();

  static String nuevaClaveIdempotencia() => const Uuid().v4();

  /// Crea la reserva. [clave] debe mantenerse estable durante el reintento
  /// de la misma bolsa (la genera la pantalla una vez por confirmación).
  Future<Reserva> crear({
    required String sucursalDestinoId,
    required List<ItemBolsa> items,
    DateTime? fechaVisita,
    String? observacion,
    String? claveIdempotencia,
  }) {
    final clave = claveIdempotencia ?? nuevaClaveIdempotencia();
    return _api.post<Reserva>(
      '/reservas',
      idempotencyKey: clave,
      cuerpo: {
        'sucursal_destino_id': sucursalDestinoId,
        if (fechaVisita != null)
          'fecha_visita': fechaVisita.toUtc().toIso8601String(),
        if (observacion != null && observacion.trim().isNotEmpty)
          'observacion': observacion.trim(),
        'lineas': items.map((e) => e.toJson()).toList(),
      },
      convertir: (j) => Reserva.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<ReservaLista> listarMias({int limit = 20, int offset = 0}) {
    return _api.get<ReservaLista>(
      '/reservas',
      query: {'limit': '$limit', 'offset': '$offset'},
      convertir: (j) =>
          ReservaLista.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<Reserva> obtener(String id) {
    return _api.get<Reserva>(
      '/reservas/$id',
      convertir: (j) => Reserva.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<Reserva> obtenerPorCodigo(String codigo) {
    return _api.get<Reserva>(
      '/reservas/codigo/${codigo.trim()}',
      convertir: (j) => Reserva.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<Reserva> cancelar(String id) {
    return _api.patch<Reserva>(
      '/reservas/$id/cancelar',
      convertir: (j) => Reserva.fromJson((j as Map).cast<String, dynamic>()),
    );
  }
}
