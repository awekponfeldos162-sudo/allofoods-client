// test/unit/order_model_test.dart
// Tests unitaires pour OrderModel.fromMap()
// Vérifie que les types mixtes (num/double/int/null) depuis Firestore ne crashent pas

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/order_model.dart';

// Données de base cohérentes (l'assert impose totalAmount == food + delivery + serviceFee)
Map<String, dynamic> _baseMap({
  int food = 5000,
  int delivery = 1000,
  int serviceFee = 250,
  int? total,
  String status = 'paid',
}) =>
    {
      'clientUid': 'uid-test',
      'restaurantId': 'resto-1',
      'restaurantName': 'Maquis Test',
      'foodAmount': food,
      'deliveryFee': delivery,
      'serviceFee': serviceFee,
      'totalAmount': total ?? (food + delivery + serviceFee),
      'paymentMethod': 'mobile_money_fedapay',
      'deliveryAddress': 'Cotonou, Bénin',
      'clientLat': 6.365,
      'clientLng': 2.418,
      'restaurantLat': 6.370,
      'restaurantLng': 2.425,
      'distanceKm': 3.5,
      'status': status,
    };

void main() {
  // ──────────────────────────────────────────────────────────
  group('OrderModel.fromMap — types mixtes Firestore', () {
    test('champs int stockés comme double → convertis sans crash', () {
      final map = _baseMap()
        ..addAll({
          'foodAmount': 5000.0,   // double au lieu de int
          'deliveryFee': 1000.0,
          'serviceFee': 250.0,
          'totalAmount': 6250.0,
        });
      final order = OrderModel.fromMap(map, 'order-1');
      expect(order.foodAmount,  equals(5000));
      expect(order.deliveryFee, equals(1000));
      expect(order.serviceFee,  equals(250));
      expect(order.totalAmount, equals(6250));
    });

    test('lat/lng stockés comme int → convertis en double', () {
      final map = _baseMap()
        ..addAll({
          'clientLat': 6,     // int, pas double
          'clientLng': 2,
          'restaurantLat': 6,
          'restaurantLng': 2,
          'distanceKm': 5,
        });
      final order = OrderModel.fromMap(map, 'order-2');
      expect(order.clientLat,    equals(6.0));
      expect(order.clientLng,    equals(2.0));
      expect(order.restaurantLat, equals(6.0));
      expect(order.distanceKm,   equals(5.0));
    });

    test('status absent → "pending" par défaut', () {
      final map = _baseMap()..remove('status');
      final order = OrderModel.fromMap(map, 'order-3');
      expect(order.status, equals('pending'));
    });

    test('paymentStatus absent → "pending" par défaut', () {
      final map = _baseMap();
      final order = OrderModel.fromMap(map, 'order-4');
      expect(order.paymentStatus, equals('pending'));
    });

    test('paymentMethod absent → "mobile_money" par défaut', () {
      final map = _baseMap()..remove('paymentMethod');
      final order = OrderModel.fromMap(map, 'order-5');
      expect(order.paymentMethod, equals('mobile_money'));
    });

    test('champs optionnels null → propriétés null', () {
      final map = _baseMap();
      final order = OrderModel.fromMap(map, 'order-6');
      expect(order.deliveryId,     isNull);
      expect(order.transactionId,  isNull);
      expect(order.driverLat,      isNull);
      expect(order.driverLng,      isNull);
      expect(order.driverName,     isNull);
      expect(order.driverPhone,    isNull);
      expect(order.estimatedArrival, isNull);
      expect(order.createdAt,      isNull);
      expect(order.paidAt,         isNull);
    });

    test('id passé en paramètre est correctement assigné', () {
      final order = OrderModel.fromMap(_baseMap(), 'mon-id-unique-123');
      expect(order.id, equals('mon-id-unique-123'));
    });

    test('restaurantName vide si absent', () {
      final map = _baseMap()..remove('restaurantName');
      final order = OrderModel.fromMap(map, 'order-7');
      expect(order.restaurantName, equals(''));
    });

    test('clientUid vide si absent', () {
      final map = _baseMap()..remove('clientUid');
      final order = OrderModel.fromMap(map, 'order-8');
      expect(order.clientUid, equals(''));
    });

    test('status "paid" reconnu correctement', () {
      final order = OrderModel.fromMap(_baseMap(status: 'paid'), 'order-9');
      expect(order.status, equals('paid'));
    });

    test('status "delivering" reconnu correctement', () {
      final map = _baseMap()..['status'] = 'delivering';
      final order = OrderModel.fromMap(map, 'order-10');
      expect(order.status, equals('delivering'));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('OrderModel.fromMap — champs items', () {
    test('items null → liste vide sans crash', () {
      final map = _baseMap()..['items'] = null;
      final order = OrderModel.fromMap(map, 'order-items-1');
      expect(order.items, isEmpty);
    });

    test('items absent → liste vide sans crash', () {
      final map = _baseMap()..remove('items');
      final order = OrderModel.fromMap(map, 'order-items-2');
      expect(order.items, isEmpty);
    });

    test('items avec price double → int', () {
      final map = _baseMap()
        ..['items'] = [
          {'name': 'Poulet braisé', 'price': 2500.0, 'quantity': 2, 'img': 'url', 'restaurantName': 'Test'},
        ];
      final order = OrderModel.fromMap(map, 'order-items-3');
      expect(order.items.first.price,    equals(2500));
      expect(order.items.first.quantity, equals(2));
      expect(order.items.first.name,     equals('Poulet braisé'));
    });

    test('items avec quantity double → int', () {
      final map = _baseMap()
        ..['items'] = [
          {'name': 'Riz', 'price': 1000, 'quantity': 3.0, 'img': '', 'restaurantName': 'Test'},
        ];
      final order = OrderModel.fromMap(map, 'order-items-4');
      expect(order.items.first.quantity, equals(3));
    });

    test('multiple items parsés correctement', () {
      final map = _baseMap()
        ..['items'] = [
          {'name': 'Plat 1', 'price': 1000, 'quantity': 1, 'img': '', 'restaurantName': 'R'},
          {'name': 'Plat 2', 'price': 2000, 'quantity': 2, 'img': '', 'restaurantName': 'R'},
          {'name': 'Plat 3', 'price': 3000, 'quantity': 1, 'img': '', 'restaurantName': 'R'},
        ];
      final order = OrderModel.fromMap(map, 'order-items-5');
      expect(order.items.length, equals(3));
      expect(order.items[0].name, equals('Plat 1'));
      expect(order.items[1].price, equals(2000));
      expect(order.items[2].quantity, equals(1));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('OrderItem.fromMap', () {
    test('parse complet', () {
      final item = OrderItem.fromMap({
        'name': 'Riz sauce graine',
        'price': 1500,
        'quantity': 3,
        'img': 'https://img.url/plat.jpg',
        'restaurantName': 'Maquis la bonne bouffe',
      });
      expect(item.name,           equals('Riz sauce graine'));
      expect(item.price,          equals(1500));
      expect(item.quantity,       equals(3));
      expect(item.img,            equals('https://img.url/plat.jpg'));
      expect(item.restaurantName, equals('Maquis la bonne bouffe'));
    });

    test('quantity absent → 1 par défaut', () {
      final item = OrderItem.fromMap({'name': 'Plat', 'price': 1000, 'img': '', 'restaurantName': ''});
      expect(item.quantity, equals(1));
    });

    test('price double → int', () {
      final item = OrderItem.fromMap({'name': 'Plat', 'price': 2500.0, 'quantity': 1, 'img': '', 'restaurantName': ''});
      expect(item.price, equals(2500));
    });

    test('name absent → chaîne vide', () {
      final item = OrderItem.fromMap({'price': 1000, 'quantity': 1, 'img': '', 'restaurantName': ''});
      expect(item.name, equals(''));
    });

    test('roundtrip toMap → fromMap', () {
      const original = OrderItem(
        name: 'Poulet yassa',
        price: 3000,
        quantity: 2,
        img: 'url',
        restaurantName: 'Le Carrefour',
      );
      final restored = OrderItem.fromMap(original.toMap());
      expect(restored.name,     equals(original.name));
      expect(restored.price,    equals(original.price));
      expect(restored.quantity, equals(original.quantity));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('VentilationModel.fromMap', () {
    test('parse correct', () {
      final v = VentilationModel.fromMap({
        'totalAmount':    6250,
        'restaurantPart': 4750,
        'driverPart':     1000,
        'platformPart':   500,
      });
      expect(v.totalAmount,    equals(6250));
      expect(v.restaurantPart, equals(4750));
      expect(v.driverPart,     equals(1000));
      expect(v.platformPart,   equals(500));
    });

    test('valeurs double → int sans crash', () {
      final v = VentilationModel.fromMap({
        'totalAmount': 6250.0,
        'restaurantPart': 4750.0,
        'driverPart': 1000.0,
        'platformPart': 500.0,
      });
      expect(v.totalAmount,    equals(6250));
      expect(v.restaurantPart, equals(4750));
    });

    test('champs manquants → 0 par défaut', () {
      final v = VentilationModel.fromMap({});
      expect(v.totalAmount,    equals(0));
      expect(v.restaurantPart, equals(0));
      expect(v.driverPart,     equals(0));
      expect(v.platformPart,   equals(0));
    });

    test('roundtrip toMap → fromMap', () {
      const original = VentilationModel(
        totalAmount: 5000,
        restaurantPart: 3800,
        driverPart: 800,
        platformPart: 400,
      );
      final restored = VentilationModel.fromMap(original.toMap());
      expect(restored.totalAmount,    equals(original.totalAmount));
      expect(restored.restaurantPart, equals(original.restaurantPart));
      expect(restored.driverPart,     equals(original.driverPart));
      expect(restored.platformPart,   equals(original.platformPart));
    });
  });
}
