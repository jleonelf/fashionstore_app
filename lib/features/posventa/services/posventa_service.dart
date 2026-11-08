import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../models/posventa_models.dart';

/// Servicio de Posventa para la App Móvil:
/// - CU09: Saldo personal y movimientos
/// - CU08: Cambios de prendas
/// - CU20: Devoluciones en período voluntario
/// - CU27: Consulta y seguimiento de reembolsos
class PosventaService {
  final ApiClient _api;

  PosventaService({ApiClient? api}) : _api = api ?? ApiClient();

  // ---------------- CU09: Saldo ----------------
  Future<SaldoClienteModel> obtenerMiSaldo() {
    return _api.get<SaldoClienteModel>(
      '/posventa/saldos/mio',
      convertir: (j) =>
          SaldoClienteModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  // ---------------- CU20: Devoluciones ----------------
  Future<List<DevolucionModel>> obtenerMisDevoluciones() {
    return _api.get<List<DevolucionModel>>(
      '/posventa/devoluciones/mias',
      convertir: (j) {
        if (j is List) {
          return j
              .map((e) => DevolucionModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
        }
        return [];
      },
    );
  }

  Future<DevolucionModel> solicitarDevolucion({
    required String ventaId,
    required String sucursalId,
    required String motivo,
    required List<Map<String, dynamic>> lineas,
    String? claveIdempotencia,
  }) {
    return _api.post<DevolucionModel>(
      '/posventa/devoluciones/solicitudes',
      cuerpo: {
        'venta_id': ventaId,
        'sucursal_id': sucursalId,
        'motivo': motivo,
        'lineas': lineas,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) =>
          DevolucionModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  // ---------------- CU08: Cambios ----------------
  Future<List<CambioModel>> obtenerMisCambios() {
    return _api.get<List<CambioModel>>(
      '/posventa/cambios/mios',
      convertir: (j) {
        if (j is List) {
          return j
              .map((e) => CambioModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
        }
        return [];
      },
    );
  }

  Future<CambioModel> solicitarCambio({
    required String ventaId,
    required String sucursalId,
    required String motivo,
    required List<Map<String, dynamic>> lineas,
    String? claveIdempotencia,
  }) {
    return _api.post<CambioModel>(
      '/posventa/cambios',
      cuerpo: {
        'venta_id': ventaId,
        'sucursal_id': sucursalId,
        'motivo': motivo,
        'lineas': lineas,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) => CambioModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  Future<Map<String, dynamic>> resolverDiferenciaCambio({
    required String cambioId,
    required String accion, // ACEPTAR_DIFERENCIA_CERO | SALDO_A_FAVOR | REEMBOLSO | PAGO_ADICIONAL
    String? metodoPago,
    String? claveIdempotencia,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/posventa/cambios/$cambioId/resolver-diferencia',
      cuerpo: {
        'accion': accion,
        if (metodoPago != null) 'metodo_pago': metodoPago,
      },
      idempotencyKey: claveIdempotencia ?? const Uuid().v4(),
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  // ---------------- CU27: Reembolsos ----------------
  Future<List<ReembolsoModel>> obtenerMisReembolsos() {
    return _api.get<List<ReembolsoModel>>(
      '/posventa/reembolsos/mios',
      convertir: (j) {
        if (j is List) {
          return j
              .map((e) => ReembolsoModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
        }
        return [];
      },
    );
  }
}
