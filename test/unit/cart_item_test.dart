import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/cart_model.dart';

void main() {
  group('CartItem', () {
    test('priceInt parse un nombre simple', () {
      final item = _item(price: '1500');
      expect(item.priceInt, equals(1500));
    });

    test('priceInt ignore les caractères non numériques', () {
      final item = _item(price: '2 500 FCFA');
      expect(item.priceInt, equals(2500));
    });

    test('priceInt retourne 0 pour une chaîne vide', () {
      final item = _item(price: '');
      expect(item.priceInt, equals(0));
    });

    test('priceInt retourne 0 pour une chaîne sans chiffre', () {
      final item = _item(price: 'gratuit');
      expect(item.priceInt, equals(0));
    });

    test('totalPrice = priceInt × quantity', () {
      final item = _item(price: '1000', quantity: 3);
      expect(item.totalPrice, equals(3000));
    });

    test('totalPrice quantity=1 par défaut', () {
      final item = _item(price: '750');
      expect(item.totalPrice, equals(750));
    });

    test('imageUrl retourne null si img ne commence pas par http', () {
      expect(_item(img: 'assets/img.png').imageUrl, isNull);
      expect(_item(img: '').imageUrl, isNull);
      expect(_item(img: '/storage/img.jpg').imageUrl, isNull);
    });

    test('imageUrl retourne l\'URL si img commence par http', () {
      const url = 'https://example.com/food.jpg';
      expect(_item(img: url).imageUrl, equals(url));
    });

    test('imageUrl accepte http (sans s)', () {
      const url = 'http://cdn.example.com/img.png';
      expect(_item(img: url).imageUrl, equals(url));
    });

    test('toJson contient tous les champs', () {
      final item = _item(name: 'Alloco', price: '800', quantity: 2);
      final json = item.toJson();
      expect(json['name'], equals('Alloco'));
      expect(json['price'], equals('800'));
      expect(json['quantity'], equals(2));
      expect(json['restaurantId'], equals('rest_test'));
    });

    test('fromJson reconstruit un CartItem identique', () {
      final original = CartItem(
        name: 'Jollof Rice',
        price: '1 500 FCFA',
        img: 'https://img.io/jollof.jpg',
        restaurantName: 'Chez Maman',
        restaurantId: 'r42',
        quantity: 3,
      );
      final restored = CartItem.fromJson(original.toJson());
      expect(restored.name, equals(original.name));
      expect(restored.price, equals(original.price));
      expect(restored.img, equals(original.img));
      expect(restored.restaurantName, equals(original.restaurantName));
      expect(restored.restaurantId, equals(original.restaurantId));
      expect(restored.quantity, equals(original.quantity));
    });

    test('fromJson applique quantity=1 si champ absent', () {
      final json = {
        'name': 'Test',
        'price': '500',
        'img': '',
        'restaurantName': 'R',
        'restaurantId': 'r',
      };
      expect(CartItem.fromJson(json).quantity, equals(1));
    });
  });
}

CartItem _item({
  String name = 'Item',
  String price = '500',
  String img = '',
  int quantity = 1,
}) =>
    CartItem(
      name: name,
      price: price,
      img: img,
      restaurantName: 'Test Restaurant',
      restaurantId: 'rest_test',
      quantity: quantity,
    );
