import 'package:fashionstore_movil/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App arranca en splash y decide sesión', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FashionStoreApp());
    // Splash inicial.
    expect(find.text('FashionStore'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // Sin sesión debe llegar al login.
    expect(find.text('Inicia sesión para continuar'), findsOneWidget);
  });
}
