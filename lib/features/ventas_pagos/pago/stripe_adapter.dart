// Adaptador real Stripe Test con PaymentSheet (CU15).
//
// Usa flutter_stripe. La clave publicable se configura por entorno
// (StripeConfig); nunca secret key ni webhook secret.
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/config/stripe_config.dart';
import 'stripe_port.dart';

class AdaptadorStripe implements PuertoStripe {
  bool _configurado = false;

  void _asegurarConfiguracion() {
    if (_configurado) return;
    final pk = StripeConfig.publishableKey;
    if (pk.isEmpty) {
      throw Exception(
        'Falta STRIPE_PUBLISHABLE_KEY. Ejecuta con --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...',
      );
    }
    Stripe.publishableKey = pk;
    _configurado = true;
  }

  @override
  Future<void> inicializarHoja({required String clientSecret}) async {
    _asegurarConfiguracion();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'FashionStore',
      ),
    );
  }

  @override
  Future<ResultadoHojaPago> presentarHoja() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      return ResultadoHojaPago.completado;
    } on StripeException catch (_) {
      return ResultadoHojaPago.fallido;
    } catch (_) {
      return ResultadoHojaPago.cancelado;
    }
  }
}
