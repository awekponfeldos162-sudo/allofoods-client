import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/models/cart_model.dart';

void main() {
  setUp(() {
    // CartProvider._load() appelle SharedPreferences.getInstance()
    SharedPreferences.setMockInitialValues({});
  });

  group('CartProvider — état initial', () {
    test('panier vide au démarrage', () {
      final cart = CartProvider();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, equals(0));
      expect(cart.totalPrice, equals(0));
      expect(cart.restaurantId, isEmpty);
      expect(cart.restaurantName, isEmpty);
    });
  });

  group('CartProvider — addItem', () {
    test('ajoute un nouvel article', () {
      final cart = CartProvider();
      cart.addItem(
        name: 'Jollof Rice',
        price: '1500',
        img: '',
        restaurantName: 'Chez Maman',
        restaurantId: 'r1',
      );
      expect(cart.items.length, equals(1));
      expect(cart.itemCount, equals(1));
      expect(cart.totalPrice, equals(1500));
      expect(cart.restaurantId, equals('r1'));
      expect(cart.restaurantName, equals('Chez Maman'));
    });

    test('incrémente la quantité si même article / même restaurant', () {
      final cart = CartProvider();
      _add(cart, name: 'Poulet', price: '2000', id: 'r1');
      _add(cart, name: 'Poulet', price: '2000', id: 'r1');
      expect(cart.items.length, equals(1));
      expect(cart.itemCount, equals(2));
      expect(cart.totalPrice, equals(4000));
    });

    test('articles différents s\'accumulent dans le même restaurant', () {
      final cart = CartProvider();
      _add(cart, name: 'Poulet', price: '2000', id: 'r1');
      _add(cart, name: 'Alloco', price: '800', id: 'r1');
      expect(cart.items.length, equals(2));
      expect(cart.itemCount, equals(2));
      expect(cart.totalPrice, equals(2800));
    });

    test('vide le panier si restaurant différent', () {
      final cart = CartProvider();
      _add(cart, name: 'Poulet', price: '2000', id: 'r1', restaurantName: 'R1');
      _add(cart, name: 'Sushi', price: '3000', id: 'r2', restaurantName: 'R2');
      expect(cart.items.length, equals(1));
      expect(cart.items.first.name, equals('Sushi'));
      expect(cart.restaurantId, equals('r2'));
      expect(cart.restaurantName, equals('R2'));
    });

    test('retourne true', () {
      final cart = CartProvider();
      final result = cart.addItem(
        name: 'A',
        price: '500',
        img: '',
        restaurantName: 'R',
        restaurantId: 'r',
      );
      expect(result, isTrue);
    });
  });

  group('CartProvider — removeItem', () {
    test('supprime l\'article à l\'index donné', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '500', id: 'r');
      _add(cart, name: 'B', price: '600', id: 'r');
      cart.removeItem(0);
      expect(cart.items.length, equals(1));
      expect(cart.items.first.name, equals('B'));
    });

    test('réinitialise restaurantId quand panier vide', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '500', id: 'r1');
      cart.removeItem(0);
      expect(cart.restaurantId, isEmpty);
      expect(cart.restaurantName, isEmpty);
    });

    test('index hors limite est ignoré silencieusement', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '500', id: 'r');
      cart.removeItem(5); // hors limite
      expect(cart.items.length, equals(1));
    });
  });

  group('CartProvider — increaseQuantity / decreaseQuantity', () {
    test('increaseQuantity augmente la quantité de 1', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '1000', id: 'r');
      cart.increaseQuantity(0);
      expect(cart.items.first.quantity, equals(2));
      expect(cart.totalPrice, equals(2000));
    });

    test('decreaseQuantity diminue la quantité de 1', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '1000', id: 'r');
      cart.increaseQuantity(0); // qty=2
      cart.decreaseQuantity(0); // qty=1
      expect(cart.items.first.quantity, equals(1));
      expect(cart.totalPrice, equals(1000));
    });

    test('decreaseQuantity supprime l\'article quand quantity=1', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '1000', id: 'r');
      cart.decreaseQuantity(0); // qty=1 → supprimé
      expect(cart.items, isEmpty);
    });
  });

  group('CartProvider — clear', () {
    test('vide tous les articles', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '500', id: 'r');
      _add(cart, name: 'B', price: '700', id: 'r');
      cart.clear();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, equals(0));
      expect(cart.totalPrice, equals(0));
      expect(cart.restaurantId, isEmpty);
    });
  });

  group('CartProvider — loadCart', () {
    test('remplace le contenu du panier', () {
      final cart = CartProvider();
      _add(cart, name: 'Ancien', price: '999', id: 'old');
      final newItems = [
        CartItem(
          name: 'Nouveau',
          price: '1200',
          img: '',
          restaurantName: 'Nouveau R',
          restaurantId: 'new',
        ),
      ];
      cart.loadCart(
          items: newItems, restaurantId: 'new', restaurantName: 'Nouveau R');
      expect(cart.items.length, equals(1));
      expect(cart.items.first.name, equals('Nouveau'));
      expect(cart.restaurantId, equals('new'));
      expect(cart.restaurantName, equals('Nouveau R'));
    });
  });

  group('CartProvider — calculs', () {
    test('itemCount = somme des quantités', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '500', id: 'r'); // qty=1
      _add(cart, name: 'A', price: '500', id: 'r'); // qty=2
      _add(cart, name: 'B', price: '700', id: 'r'); // qty=1
      expect(cart.itemCount, equals(3));
    });

    test('totalPriceFormatted contient le prix et "FCFA"', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '1500', id: 'r');
      expect(cart.totalPriceFormatted, contains('1500'));
      expect(cart.totalPriceFormatted, contains('FCFA'));
    });

    test('totalAmount est identique à totalPrice', () {
      final cart = CartProvider();
      _add(cart, name: 'A', price: '2000', id: 'r');
      expect(cart.totalAmount, equals(cart.totalPrice));
    });
  });
}

void _add(
  CartProvider cart, {
  required String name,
  required String price,
  required String id,
  String restaurantName = 'Restaurant Test',
}) {
  cart.addItem(
    name: name,
    price: price,
    img: '',
    restaurantName: restaurantName,
    restaurantId: id,
  );
}
