import '../../../core/network/api_client.dart';
import '../../../core/session/dispositivo_helper.dart';
import '../models/notificacion_model.dart';

/// Servicio de Notificaciones y Registro de Dispositivos Móviles (E2 Avisos Push).
///
/// Registra y revoca el dispositivo Flutter en el backend central contra
/// `/api/v1/notificaciones/dispositivos`.
/// En entornos de prueba o ejecución sin credenciales de Google Services / FCM,
/// se registra el identificador de dispositivo sin push_token nativo,
/// garantizando que la vinculación del canal FLUTTER esté persistida y activa.
class NotificacionMovilService {
  final ApiClient _api;

  NotificacionMovilService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Registra el dispositivo móvil activo ante el backend.
  Future<DispositivoRegistroModel> registrarDispositivo({
    String? pushToken,
    String? sucursalId,
    String? dispositivoId,
  }) async {
    final dispId = dispositivoId ?? await DispositivoHelper.obtenerDispositivoId();
    return _api.post<DispositivoRegistroModel>(
      '/notificaciones/dispositivos',
      cuerpo: {
        'dispositivo_id': dispId,
        'canal': 'FLUTTER',
        if (pushToken != null && pushToken.trim().isNotEmpty)
          'push_token': pushToken.trim(),
        if (sucursalId != null && sucursalId.trim().isNotEmpty)
          'sucursal_id': sucursalId.trim(),
      },
      convertir: (j) =>
          DispositivoRegistroModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }

  /// Revoca el registro del dispositivo al cerrar sesión.
  Future<void> revocarDispositivo({String? dispositivoId}) async {
    final dispId = dispositivoId ?? await DispositivoHelper.obtenerDispositivoId();
    try {
      await _api.delete(
        '/notificaciones/dispositivos/$dispId',
        convertir: (_) => null,
      );
    } catch (_) {
      // Defensivo: no bloquear el cierre de sesión si no hay red
    }
  }

  /// Consulta la bandeja de notificaciones propia del usuario.
  Future<List<NotificacionAvisoModel>> consultarBandeja({int limite = 50}) async {
    return _api.get<List<NotificacionAvisoModel>>(
      '/notificaciones/bandeja',
      query: {'limite': '$limite'},
      convertir: (j) => (j as List)
          .map((e) =>
              NotificacionAvisoModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Marca una notificación como leída.
  Future<NotificacionAvisoModel> marcarLeida(String notificacionId) async {
    return _api.patch<NotificacionAvisoModel>(
      '/notificaciones/bandeja/$notificacionId/leer',
      convertir: (j) =>
          NotificacionAvisoModel.fromJson((j as Map).cast<String, dynamic>()),
    );
  }
}
