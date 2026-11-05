import 'package:flutter_test/flutter_test.dart';
import 'package:fashionstore_movil/features/posventa/services/posventa_service.dart';
import 'package:fashionstore_movil/core/network/api_client.dart';

class FakeApiClientPosventa extends ApiClient {
  @override
  Future<T> get<T>(
    String ruta, {
    Map<String, String>? query,
    required T Function(dynamic) convertir,
  }) async {
    if (ruta == '/posventa/saldos/mio') {
      return convertir({
        'cliente_id': 'cli-101',
        'empresa_id': 'emp-202',
        'saldo_disponible_bob': 150.50,
        'saldo_retenido_bob': 0.0,
        'moneda': 'BOB',
        'movimientos': [
          {
            'id': 'mov-1',
            'tipo': 'ABONO_REEMBOLSO',
            'monto_bob': 150.50,
            'saldo_resultante_bob': 150.50,
            'motivo': 'Reembolso derivado por falta de stock',
            'creada_en': '2026-11-04T12:00:00Z',
          }
        ],
      });
    } else if (ruta == '/posventa/devoluciones/mias') {
      return convertir([
        {
          'id': 'dev-1',
          'venta_id': 'v-10',
          'estado': 'EN_CUSTODIA',
          'motivo': 'Talla no adecuada',
          'sucursal_id': 'suc-1',
          'creada_en': '2026-11-04T10:00:00Z',
          'lineas': [],
        }
      ]);
    } else if (ruta == '/posventa/cambios/mios') {
      return convertir([
        {
          'id': 'cam-1',
          'venta_id': 'v-20',
          'estado': 'REGISTRADO',
          'diferencia_bob': 0.0,
          'direccion_diferencia': 'CERO',
          'nota_vigencia_hasta': '2026-11-11T10:00:00Z',
          'creada_en': '2026-11-04T10:00:00Z',
        }
      ]);
    } else if (ruta == '/posventa/reembolsos/mios') {
      return convertir([
        {
          'id': 'rem-1',
          'origen_tipo': 'COMPRA_DIFERIDA_SIN_STOCK',
          'estado': 'PENDIENTE_AUTORIZACION',
          'monto_total_bob': 300.0,
          'creada_en': '2026-11-04T10:00:00Z',
        }
      ]);
    }
    throw UnimplementedError('Ruta GET no mockeada: $ruta');
  }

  @override
  Future<T> post<T>(
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
    String? idempotencyKey,
    required T Function(dynamic) convertir,
  }) async {
    final map = (cuerpo as Map?) ?? {};
    if (ruta == '/posventa/devoluciones/solicitudes') {
      return convertir({
        'id': 'dev-new',
        'venta_id': map['venta_id'],
        'estado': 'EN_CUSTODIA',
        'motivo': map['motivo'],
        'sucursal_id': map['sucursal_id'],
        'creada_en': '2026-11-04T14:00:00Z',
        'lineas': map['lineas'],
      });
    } else if (ruta == '/posventa/cambios') {
      return convertir({
        'id': 'cam-new',
        'venta_id': map['venta_id'],
        'estado': 'REGISTRADO',
        'diferencia_bob': 0.0,
        'direccion_diferencia': 'CERO',
        'nota_vigencia_hasta': '2026-11-11T14:00:00Z',
        'creada_en': '2026-11-04T14:00:00Z',
      });
    } else if (ruta.endsWith('/resolver-diferencia')) {
      return convertir({
        'cambio_id': 'cam-1',
        'estado': 'RESUELTO',
        'accion': map['accion'],
      });
    }
    throw UnimplementedError('Ruta POST no mockeada: $ruta');
  }
}

void main() {
  late PosventaService service;

  setUp(() {
    service = PosventaService(api: FakeApiClientPosventa());
  });

  group('PosventaService CU09, CU08, CU20, CU27', () {
    test('obtenerMiSaldo retorna saldo y lista de movimientos (CU09)', () async {
      final s = await service.obtenerMiSaldo();
      expect(s.clienteId, equals('cli-101'));
      expect(s.saldoDisponibleBob, equals(150.50));
      expect(s.movimientos.length, equals(1));
      expect(s.movimientos.first.tipo, equals('ABONO_REEMBOLSO'));
    });

    test('obtenerMisDevoluciones y solicitarDevolucion funcionan (CU20)', () async {
      final lista = await service.obtenerMisDevoluciones();
      expect(lista.length, equals(1));
      expect(lista.first.estado, equals('EN_CUSTODIA'));

      final dev = await service.solicitarDevolucion(
        ventaId: 'v-10',
        sucursalId: 'suc-1',
        motivo: 'Prenda con falla de costura',
        lineas: [{'variante_id': 'var-1', 'cantidad': 1}],
      );
      expect(dev.id, equals('dev-new'));
      expect(dev.estado, equals('EN_CUSTODIA'));
    });

    test('obtenerMisCambios, solicitarCambio y resolverDiferencia funcionan (CU08)', () async {
      final cambios = await service.obtenerMisCambios();
      expect(cambios.length, equals(1));
      expect(cambios.first.diferenciaBob, equals(0.0));

      final nuevo = await service.solicitarCambio(
        ventaId: 'v-20',
        sucursalId: 'suc-1',
        motivo: 'Cambio de talla por L',
        lineas: [{'variante_original_id': 'v-orig', 'variante_nueva_id': 'v-new', 'cantidad': 1}],
      );
      expect(nuevo.id, equals('cam-new'));

      final res = await service.resolverDiferenciaCambio(
        cambioId: 'cam-1',
        accion: 'ACEPTAR_DIFERENCIA_CERO',
      );
      expect(res['estado'], equals('RESUELTO'));
    });

    test('obtenerMisReembolsos retorna lista de reembolsos del cliente (CU27)', () async {
      final reembolsos = await service.obtenerMisReembolsos();
      expect(reembolsos.length, equals(1));
      expect(reembolsos.first.montoTotalBob, equals(300.0));
      expect(reembolsos.first.estado, equals('PENDIENTE_AUTORIZACION'));
    });
  });
}
