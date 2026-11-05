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

  /// Prepara método con SetupIntent para cobros off-session (CU22).
  Future<Map<String, dynamic>> prepararMetodoSetupIntent({
    String? huellaDispositivo,
    String? claveIdempotencia,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/pagos/stripe/metodos/preparar',
      cuerpo: {
        if (huellaDispositivo != null && huellaDispositivo.isNotEmpty)
          'huella_dispositivo': huellaDispositivo,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  /// Crea orden de pago off-session o conectada Stripe (CU22).
  Future<Map<String, dynamic>> crearOrdenPago({
    String? contexto,
    String? recursoId,
    String? ventaId,
    String? pedidoCompraId,
    String? metodoPreparadoId,
    int? ofertaRevision,
    bool consentimientoCobroPosterior = false,
    double? montoBob,
    String? claveIdempotencia,
  }) {
    final ctx = contexto ?? (ventaId != null ? 'VENTA' : (pedidoCompraId != null ? 'PEDIDO' : 'VENTA'));
    final recId = recursoId ?? ventaId ?? pedidoCompraId ?? '';
    return _api.post<Map<String, dynamic>>(
      '/pagos/stripe/ordenes',
      cuerpo: {
        'contexto': ctx,
        'recurso_id': recId,
        'oferta_revision': ofertaRevision ?? 1,
        if (metodoPreparadoId != null && metodoPreparadoId.isNotEmpty)
          'metodo_preparado_id': metodoPreparadoId,
        'consentimiento_cobro_posterior': consentimientoCobroPosterior,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  /// Consulta estado de una orden de pago (CU22).
  Future<Map<String, dynamic>> consultarOrdenPago(String ordenId) {
    return _api.get<Map<String, dynamic>>(
      '/pagos/stripe/ordenes/$ordenId',
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  /// Continúa una orden de pago tras confirmación de acción 3DS (CU22).
  Future<Map<String, dynamic>> continuarAccionOrden({
    required String ordenId,
    String? paymentIntentId,
    String? claveIdempotencia,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/pagos/stripe/ordenes/$ordenId/continuar-accion',
      cuerpo: {
        if (paymentIntentId != null && paymentIntentId.isNotEmpty)
          'payment_intent_id': paymentIntentId,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  /// Consulta un método preparado previamente online (CU22).
  Future<Map<String, dynamic>> consultarMetodoPreparado(String metodoId) {
    return _api.get<Map<String, dynamic>>(
      '/pagos/stripe/metodos/$metodoId',
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}
