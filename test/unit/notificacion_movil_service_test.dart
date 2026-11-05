import 'package:flutter_test/flutter_test.dart';
import 'package:fashionstore_movil/features/identidad_empresas/services/notificacion_movil_service.dart';
import 'package:fashionstore_movil/core/network/api_client.dart';

class FakeApiClientNotificaciones extends ApiClient {
  final List<String> llamadas = [];

  @override
  Future<T> post<T>(
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
    String? idempotencyKey,
    required T Function(dynamic) convertir,
  }) async {
    llamadas.add('POST $ruta: $cuerpo');
    if (ruta == '/notificaciones/dispositivos') {
      final map = (cuerpo as Map?) ?? {};
      return convertir({
        'id': 'reg-1',
        'dispositivo_id': map['dispositivo_id'] ?? 'disp-1',
        'canal': map['canal'] ?? 'FLUTTER',
        'estado': 'ACTIVO',
        'creado_en': '2026-11-04T12:00:00Z',
      });
    }
    throw UnimplementedError('Ruta POST no mockeada: $ruta');
  }

  @override
  Future<T> delete<T>(
    String ruta, {
    Map<String, String>? query,
    String? idempotencyKey,
    required T Function(dynamic) convertir,
  }) async {
    llamadas.add('DELETE $ruta');
    if (ruta.startsWith('/notificaciones/dispositivos/')) {
      return convertir(null);
    }
    throw UnimplementedError('Ruta DELETE no mockeada: $ruta');
  }

  @override
  Future<T> get<T>(
    String ruta, {
    Map<String, String>? query,
    required T Function(dynamic) convertir,
  }) async {
    llamadas.add('GET $ruta');
    if (ruta == '/notificaciones/bandeja') {
      return convertir([
        {
          'id': 'notif-1',
          'tipo': 'COMPRA_CONFIRMADA',
          'titulo': '¡Pago recibido!',
          'cuerpo': 'Tu pedido fue capturado con éxito tras confirmación Stripe.',
          'recurso_tipo': 'PEDIDO',
          'recurso_id': 'ped-100',
          'creada_en': '2026-11-04T12:01:00Z',
          'leida_en': null,
        }
      ]);
    }
    throw UnimplementedError('Ruta GET no mockeada: $ruta');
  }

  @override
  Future<T> patch<T>(
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
    String? idempotencyKey,
    required T Function(dynamic) convertir,
  }) async {
    llamadas.add('PATCH $ruta');
    if (ruta.startsWith('/notificaciones/bandeja/') && ruta.endsWith('/leer')) {
      return convertir({
        'id': 'notif-1',
        'tipo': 'COMPRA_CONFIRMADA',
        'titulo': '¡Pago recibido!',
        'cuerpo': 'Tu pedido fue capturado con éxito tras confirmación Stripe.',
        'recurso_tipo': 'PEDIDO',
        'recurso_id': 'ped-100',
        'creada_en': '2026-11-04T12:01:00Z',
        'leida_en': '2026-11-04T12:05:00Z',
      });
    }
    throw UnimplementedError('Ruta PATCH no mockeada: $ruta');
  }
}

void main() {
  late FakeApiClientNotificaciones fakeApi;
  late NotificacionMovilService service;

  setUp(() {
    fakeApi = FakeApiClientNotificaciones();
    service = NotificacionMovilService(api: fakeApi);
  });

  group('NotificacionMovilService E2 Dispositivos y Bandeja Móvil', () {
    test('registrarDispositivo envía payload con canal FLUTTER y persiste vinculación', () async {
      final res = await service.registrarDispositivo(
        dispositivoId: 'disp-test-uuid',
        pushToken: 'token-fcm-test',
      );

      expect(res.id, equals('reg-1'));
      expect(res.dispositivoId, equals('disp-test-uuid'));
      expect(res.canal, equals('FLUTTER'));
      expect(res.estado, equals('ACTIVO'));
      expect(fakeApi.llamadas.first, contains('POST /notificaciones/dispositivos'));
      expect(fakeApi.llamadas.first, contains('canal: FLUTTER'));
    });

    test('revocarDispositivo invoca endpoint DELETE correspondiente', () async {
      await service.revocarDispositivo(dispositivoId: 'disp-test-uuid');
      expect(fakeApi.llamadas.any((l) => l.contains('DELETE /notificaciones/dispositivos/disp-test-uuid')), isTrue);
    });

    test('consultarBandeja y marcarLeida consumen avisos de negocio', () async {
      final lista = await service.consultarBandeja(limite: 10);
      expect(lista.length, equals(1));
      expect(lista.first.tipo, equals('COMPRA_CONFIRMADA'));
      expect(lista.first.estaLeida, isFalse);

      final leida = await service.marcarLeida('notif-1');
      expect(leida.id, equals('notif-1'));
      expect(leida.estaLeida, isTrue);
    });
  });
}
