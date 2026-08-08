import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/models/cart_model.dart';

// Widget de test autonome qui affiche le nombre d'articles du panier
class _CartCountDisplay extends StatelessWidget {
  const _CartCountDisplay();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('count:${cart.itemCount}', key: const Key('count')),
        Text('total:${cart.totalPrice}', key: const Key('total')),
        Text('rest:${cart.restaurantId}', key: const Key('rest')),
      ],
    );
  }
}

Widget _buildTestApp(CartProvider cart) => ChangeNotifierProvider<CartProvider>.value(
      value: cart,
      child: const MaterialApp(
        home: Scaffold(body: _CartCountDisplay()),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartProvider — widget tests', () {
    testWidgets('panier vide : affiche 0 articles, 0 total', (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump(); // attend le _load() async

      expect(find.text('count:0'), findsOneWidget);
      expect(find.text('total:0'), findsOneWidget);
      expect(find.text('rest:'), findsOneWidget);
    });

    testWidgets('addItem met à jour le compteur dans le widget', (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump();

      cart.addItem(
        name: 'Jollof Rice',
        price: '1500',
        img: '',
        restaurantName: 'Chez Maman',
        restaurantId: 'r1',
      );
      await tester.pump();

      expect(find.text('count:1'), findsOneWidget);
      expect(find.text('total:1500'), findsOneWidget);
      expect(find.text('rest:r1'), findsOneWidget);
    });

    testWidgets('deux articles différents : itemCount = 2', (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump();

      cart.addItem(name: 'A', price: '500', img: '', restaurantName: 'R', restaurantId: 'r1');
      cart.addItem(name: 'B', price: '700', img: '', restaurantName: 'R', restaurantId: 'r1');
      await tester.pump();

      expect(find.text('count:2'), findsOneWidget);
      expect(find.text('total:1200'), findsOneWidget);
    });

    testWidgets('même article ajouté deux fois : itemCount = 2 (1 ligne)', (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump();

      cart.addItem(name: 'A', price: '1000', img: '', restaurantName: 'R', restaurantId: 'r1');
      cart.addItem(name: 'A', price: '1000', img: '', restaurantName: 'R', restaurantId: 'r1');
      await tester.pump();

      expect(find.text('count:2'), findsOneWidget);
      expect(find.text('total:2000'), findsOneWidget);
    });

    testWidgets('clear() remet le widget à 0', (tester) async {
      final cart = CartProvider();
      cart.addItem(name: 'A', price: '500', img: '', restaurantName: 'R', restaurantId: 'r1');
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump();

      cart.clear();
      await tester.pump();

      expect(find.text('count:0'), findsOneWidget);
      expect(find.text('total:0'), findsOneWidget);
    });

    testWidgets('removeItem met à jour le widget', (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_buildTestApp(cart));
      await tester.pump();

      cart.addItem(name: 'A', price: '800', img: '', restaurantName: 'R', restaurantId: 'r1');
      cart.addItem(name: 'B', price: '900', img: '', restaurantName: 'R', restaurantId: 'r1');
      await tester.pump();
      expect(find.text('count:2'), findsOneWidget);

      cart.removeItem(0); // supprime 'A'
      await tester.pump();

      expect(find.text('count:1'), findsOneWidget);
      expect(find.text('total:900'), findsOneWidget);
    });
  });
}
