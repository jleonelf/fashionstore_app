import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fashionstore_movil/features/ventas_pagos/checkout/checkout_screen.dart';
import 'package:fashionstore_movil/features/ventas_pagos/pago/pago_screen.dart';
import 'package:fashionstore_movil/features/ventas_pagos/pago/stripe_port.dart';
import 'package:fashionstore_movil/features/ventas_pagos/models/pago_model.dart';
import 'package:fashionstore_movil/features/ventas_pagos/services/pago_service.dart';
import 'package:fashionstore_movil/features/ventas_pagos/services/carrito_service.dart';
import 'package:fashionstore_movil/features/organizacion/services/sucursal_service.dart';
import 'package:fashionstore_movil/features/organizacion/models/organizacion_model.dart';
import 'package:fashionstore_movil/features/ventas_pagos/models/carrito_model.dart';
import 'package:fashionstore_movil/features/reservas_traslados/services/sincronizacion_offline_service.dart';
import 'package:fashionstore_movil/features/reservas_traslados/models/sincronizacion_model.dart';
import 'package:fashionstore_movil/features/ventas_pagos/services/entrega_service.dart';
import 'package:fashionstore_movil/features/ventas_pagos/models/entrega_model.dart';
import 'package:fashionstore_movil/features/organizacion/services/tasa_cambio_service.dart';
import 'package:fashionstore_movil/features/organizacion/models/tasa_cambio_model.dart';

class FakeEntregaService extends EntregaService {
  @override
  Future<CotizacionDelivery> cotizar({required String sucursalId, required int anilloDestino}) async {
    return CotizacionDelivery.fromJson({
      'tarifa_delivery_bob': 15.0,
      'anillo_destino': anilloDestino,
      'sucursal_id': sucursalId,
      'cubre': true,
    });
  }
}

class FakeTasaService extends TasaCambioService {
  @override
  Future<TasaCambioModel> obtenerTasaVigente() async {
    return TasaCambioModel.fromJson({
      'id': 'tasa-1',
      'tasa_bob_por_usd': 6.96,
      'activa': true,
      'creado_en': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

class FakeCarritoService extends CarritoService {
  @override
  Future<CarritoCompra> obtenerOCrear({String canal = 'MOVIL'}) async {
    return CarritoCompra.fromJson({
      'id': 'car-1',
      'cliente_id': 'cli-1',
      'canal': 'MOVIL',
      'estado': 'ACTIVO',
      'subtotal': 180.0,
      'descuento_total': 0.0,
      'total': 180.0,
      'lineas': [
        {
          'id': 'lin-1',
          'variante_id': 'var-10',
          'cantidad': 2,
          'precio_unitario': 90.0,
          'descuento_unitario': 0.0,
          'subtotal': 180.0,
        }
      ],
    });
  }

  @override
  Future<CoberturaCarrito> cobertura({String canal = 'MOVIL'}) async {
    return CoberturaCarrito.fromJson({
      'sucursales': [
        {
          'sucursal_id': 'suc-1',
          'sucursal_nombre': 'Sucursal Centro',
          'cubre_todo': true,
          'faltantes': [],
        }
      ],
    });
  }
}

class FakeSucursalService extends SucursalService {
  @override
  Future<List<SucursalModel>> listar() async {
    return [
      SucursalModel.fromJson({
        'id': 'suc-1',
        'nombre': 'Sucursal Centro',
        'ciudad_id': 'ciu-1',
        'direccion': 'Av. Principal 123',
        'activa': true,
      }),
    ];
  }
}

class FakeSincronizacionOfflineService extends SincronizacionOfflineService {
  bool compraEncolada = false;
  String? ultimaSucursal;
  int lineasEncoladas = 0;

  @override
  Future<OperacionSincronizacionLocal> encolarCompraOffline({
    required String sucursalId,
    required List<Map<String, dynamic>> lineas,
    String modalidad = 'RECOJO',
    String? direccion,
    int? anilloDestino,
    Map<String, dynamic>? autorizacionCobro,
    String? empresaId,
    String? usuarioId,
    String? dispositivoId,
  }) async {
    compraEncolada = true;
    ultimaSucursal = sucursalId;
    lineasEncoladas = lineas.length;

    return OperacionSincronizacionLocal(
      operacionId: 'op-offline-mock-12345678',
      empresaId: 'emp-1',
      usuarioId: 'usr-1',
      dispositivoId: 'disp-1',
      secuenciaLocal: 1,
      creadaLocalEn: '2026-11-04T12:00:00Z',
      datosJson: '{}',
      actualizadoEn: '2026-11-04T12:00:00Z',
    );
  }
}

class FakePagoServiceE2 extends PagoService {
  bool ordenCreada = false;
  bool setupIntentPreparado = false;

  @override
  Future<EstadoPagoVenta> consultarEstado(String ventaId) async {
    return EstadoPagoVenta.fromJson({
      'venta_id': ventaId,
      'estado': 'PENDIENTE_PAGO',
      'monto_total_bob': 180.0,
      'pago_aprobado': false,
      'venta_vencida': false,
      'puede_reintentar': true,
      'monto_formateado': 'Bs 180.00',
    });
  }

  @override
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
  }) async {
    ordenCreada = true;
    return {
      'orden_pago_id': 'ord-cu22-123',
      'client_secret': 'pi_secret_mock_cu22',
      'estado': 'PENDIENTE',
    };
  }

  @override
  Future<Map<String, dynamic>> prepararMetodoSetupIntent({
    String? huellaDispositivo,
    String? claveIdempotencia,
  }) async {
    setupIntentPreparado = true;
    return {
      'preparacion_pago_id': 'prep-mock-cu22',
      'client_secret': 'seti_secret_mock_cu22',
      'estado': 'PENDIENTE',
    };
  }

  @override
  Future<Map<String, dynamic>> consultarOrdenPago(String ordenId) async {
    return {'orden_pago_id': ordenId, 'estado': 'PENDIENTE'};
  }

  @override
  Future<Map<String, dynamic>> consultarMetodoPreparado(String metodoId) async {
    return {'preparacion_pago_id': metodoId, 'estado': 'LISTO'};
  }
}

void main() {
  testWidgets('CheckoutScreen permite encolar compra offline CU05 v3', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fakeSync = FakeSincronizacionOfflineService();

    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          servicioCarrito: FakeCarritoService(),
          servicioSucursal: FakeSucursalService(),
          servicioEntrega: FakeEntregaService(),
          servicioTasa: FakeTasaService(),
          servicioSincronizacion: fakeSync,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll hasta el botón de compra offline
    final btnOffline = find.byKey(const Key('btn_compra_offline_cu05'));
    await tester.scrollUntilVisible(btnOffline, 300);
    expect(btnOffline, findsOneWidget);

    // Toca botón para guardar offline
    await tester.tap(btnOffline);
    await tester.pumpAndSettle();

    // Se invocó el servicio de sincronización y se muestra el diálogo
    expect(fakeSync.compraEncolada, isTrue);
    expect(fakeSync.ultimaSucursal, equals('suc-1'));
    expect(fakeSync.lineasEncoladas, equals(1));
    expect(find.text('Compra guardada offline (CU05 v3)'), findsOneWidget);
  });

  testWidgets('PagoScreen expone acciones CU22 de Orden de Pago y SetupIntent', (tester) async {
    final fakePago = FakePagoServiceE2();
    final fakeStripe = FakePuertoStripe(respuestas: [
      ResultadoHojaPago.completado,
      ResultadoHojaPago.completado,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PagoScreen(
          ventaId: 'v-test-100',
          servicioPago: fakePago,
          puertoStripe: fakeStripe,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Botones CU22 presentes
    expect(find.byKey(const Key('btn_pagar_orden_cu22')), findsOneWidget);
    expect(find.byKey(const Key('btn_preparar_metodo_cu22')), findsOneWidget);

    // Pagar con orden de pago CU22
    await tester.tap(find.byKey(const Key('btn_pagar_orden_cu22')));
    await tester.pumpAndSettle();
    expect(fakePago.ordenCreada, isTrue);

    // Preparar método SetupIntent CU22
    await tester.tap(find.byKey(const Key('btn_preparar_metodo_cu22')));
    await tester.pumpAndSettle();
    expect(fakePago.setupIntentPreparado, isTrue);
  });
}
