// Servicio Ciclo 3 — Stripe Test como único pago (CU15).
//
// - Crear intención y reintento requieren Idempotency-Key.
// - Consultar estado es solo lectura con polling acotado desde la UI.
// - La aprobación definitiva proviene del webhook y se refleja en backend.
import 'package:uuid/uuid.dart';

import '../models/pago_model.dart';
import '../../../core/network/api_client.dart';

class PagoService {
  final ApiClient _api;
  PagoService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<IntencionStripe> crearIntencion({
    required String ventaId,
    String? claveIdempotencia,
  }) {
    return _api.post<IntencionStripe>(
      '/pagos/stripe/intenciones',
      cuerpo: {'venta_id': ventaId},
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) =>
          IntencionStripe.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<IntencionStripe> reintentar({
    required String ventaId,
    String? claveIdempotencia,
  }) {
    return _api.post<IntencionStripe>(
      '/pagos/stripe/intenciones/reintento',
      cuerpo: {'venta_id': ventaId},
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) =>
          IntencionStripe.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<EstadoPagoVenta> consultarEstado(String ventaId) {
    return _api.get<EstadoPagoVenta>(
      '/pagos/stripe/estado/$ventaId',
      convertir: (j) =>
          EstadoPagoVenta.fromJson((j as Map).cast<String, dynamic>()),
    );
  }
}
