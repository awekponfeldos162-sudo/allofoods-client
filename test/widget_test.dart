// test/widget_test.dart
// Tests de smoke : vérification que les providers s'instancient sans erreur
// et que les widgets de base s'affichent.
//
// Note : allofoodsApp nécessite Firebase initialisé → non testé ici.
// Voir test/widget/cart_widget_test.dart pour les tests widget complets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/models/cart_model.dart';
import 'package:flutter_application_2/models/delivery_model.dart';
import 'package:flutter_application_2/providers/active_order_notifier.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CartProvider et DeliveryProvider s\'initialisent dans un widget',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => DeliveryProvider()),
          ChangeNotifierProvider(create: (_) => ActiveOrderNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<CartProvider>(
              builder: (_, cart, __) => Text('panier: ${cart.itemCount}'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('panier: 0'), findsOneWidget);
  });

  testWidgets('ActiveOrderNotifier — showBanner false dans widget', (tester) async {
    final notifier = ActiveOrderNotifier();
    await tester.pumpWidget(
      ChangeNotifierProvider<ActiveOrderNotifier>.value(
        value: notifier,
        child: MaterialApp(
          home: Consumer<ActiveOrderNotifier>(
            builder: (_, n, __) => Text(n.showBanner ? 'banner' : 'no-banner'),
          ),
        ),
      ),
    );
    expect(find.text('no-banner'), findsOneWidget);

    notifier.orderId = 'order42';
    notifier.status = 'en_route';
    notifier.notifyListeners();
    await tester.pump();

    expect(find.text('banner'), findsOneWidget);

    notifier.setOrderPageOpen(true);
    await tester.pump();
    expect(find.text('no-banner'), findsOneWidget);
  });
}
