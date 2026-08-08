// test/unit/payment_service_test.dart
// Tests unitaires pour PaymentService — ventilation financière allofoods
// Modèle : com1 = food*5% (restaurant), com2 = food*5% (client), T = food + com2 + delivery

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_application_2/services/payment_service.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  // ──────────────────────────────────────────────────────────
  group('PaymentService — computeServiceFee (com2 = food × 5%)', () {
    test('1 000 FCFA food → 50 FCFA', () {
      expect(PaymentService.computeServiceFee(1000), equals(50));
    });

    test('5 000 FCFA food → 250 FCFA', () {
      expect(PaymentService.computeServiceFee(5000), equals(250));
    });

    test('10 000 FCFA food → 500 FCFA', () {
      expect(PaymentService.computeServiceFee(10000), equals(500));
    });

    test('0 FCFA food → 0 FCFA (pas de commission)', () {
      expect(PaymentService.computeServiceFee(0), equals(0));
    });

    test('arrondi correct : 101 FCFA → 5 FCFA (pas 5.05)', () {
      // 101 * 0.05 = 5.05 → arrondi à 5
      expect(PaymentService.computeServiceFee(101), equals(5));
    });

    test('arrondi correct : 109 FCFA → 5 FCFA', () {
      // 109 * 0.05 = 5.45 → arrondi à 5
      expect(PaymentService.computeServiceFee(109), equals(5));
    });

    test('arrondi correct : 110 FCFA → 6 FCFA', () {
      // 110 * 0.05 = 5.5 → arrondi à 6
      expect(PaymentService.computeServiceFee(110), equals(6));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('PaymentService — computeCommission (com1 = food × 5%)', () {
    test('identique à computeServiceFee (même taux 5%)', () {
      for (final amount in [0, 500, 1000, 5000, 10000]) {
        expect(
          PaymentService.computeCommission(amount),
          equals(PaymentService.computeServiceFee(amount)),
          reason: 'Échec pour foodAmount=$amount',
        );
      }
    });

    test('2 000 FCFA → 100 FCFA', () {
      expect(PaymentService.computeCommission(2000), equals(100));
    });

    test('résultat toujours >= 0', () {
      expect(PaymentService.computeCommission(0), isNonNegative);
    });
  });

  // ──────────────────────────────────────────────────────────
  group('PaymentService — calculerVentilation', () {
    test('cas standard : 5 000 food + 1 000 livraison', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 5000,
        deliveryFee: 1000,
      );
      expect(v['foodAmount'],  equals(5000));
      expect(v['commission'],  equals(250));   // 5000 * 5% = com1
      expect(v['serviceFee'],  equals(250));   // 5000 * 5% = com2
      expect(v['deliveryFee'], equals(1000));
      expect(v['totalClient'], equals(6250));  // 5000 + 250 + 1000
      expect(v['restoAmount'], equals(4750));  // 5000 - 250
      expect(v['alloAmount'],  equals(1500));  // 250 + 250 + 1000
    });

    test('invariant : totalClient = foodAmount + serviceFee + deliveryFee', () {
      for (final data in [
        (food: 3000, delivery: 500),
        (food: 8000, delivery: 1500),
        (food: 15000, delivery: 2000),
      ]) {
        final v = PaymentService.calculerVentilation(
          foodAmount: data.food,
          deliveryFee: data.delivery,
        );
        expect(
          v['totalClient'],
          equals(v['foodAmount']! + v['serviceFee']! + v['deliveryFee']!),
          reason: 'food=${data.food} delivery=${data.delivery}',
        );
      }
    });

    test('invariant : restoAmount + alloAmount = totalClient', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 8000,
        deliveryFee: 1500,
      );
      expect(
        v['restoAmount']! + v['alloAmount']!,
        equals(v['totalClient']),
      );
    });

    test('livraison à 0 FCFA (commande à emporter)', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 2000,
        deliveryFee: 0,
      );
      expect(v['deliveryFee'], equals(0));
      expect(v['totalClient'], equals(2100)); // 2000 + 100 + 0
      expect(v['alloAmount'],  equals(200));  // 100 + 100 + 0
    });

    test('food à 0 FCFA → pas de commission', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 0,
        deliveryFee: 500,
      );
      expect(v['commission'],  equals(0));
      expect(v['serviceFee'],  equals(0));
      expect(v['restoAmount'], equals(0));
      expect(v['totalClient'], equals(500));
      expect(v['alloAmount'],  equals(500)); // 0 + 0 + 500
    });

    test('grande commande : 50 000 food + 2 000 livraison', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 50000,
        deliveryFee: 2000,
      );
      expect(v['commission'],  equals(2500));  // 50000 * 5%
      expect(v['serviceFee'],  equals(2500));  // 50000 * 5%
      expect(v['totalClient'], equals(54500)); // 50000 + 2500 + 2000
      expect(v['restoAmount'], equals(47500)); // 50000 - 2500
      expect(v['alloAmount'],  equals(7000));  // 2500 + 2500 + 2000
    });

    test('retourne toutes les clés attendues', () {
      final v = PaymentService.calculerVentilation(
        foodAmount: 1000,
        deliveryFee: 500,
      );
      expect(v.keys, containsAll([
        'foodAmount', 'commission', 'serviceFee',
        'deliveryFee', 'totalClient', 'restoAmount', 'alloAmount',
      ]));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('PaymentService — formatage numéro téléphone (logique _apiPhone)', () {
    // Logique extraite de PaiementPage._apiPhone :
    //   "0196123456" (10 chiffres, commence par "01") → retire "01" → "22996123456"
    //   "96123456"   (8 chiffres)                     → ajoute "229" → "22996123456"

    String buildApiPhone(String raw) {
      final digits = (raw.length == 10 && raw.startsWith('01'))
          ? raw.substring(2)
          : raw;
      return '229$digits';
    }

    test('format local 10 digits "0196XXXXXX" → "22996XXXXXX"', () {
      expect(buildApiPhone('0196123456'), equals('22996123456'));
    });

    test('format court 8 digits "96XXXXXX" → "22996XXXXXX"', () {
      expect(buildApiPhone('96123456'), equals('22996123456'));
    });

    test('résultat identique pour les deux formats du même numéro', () {
      expect(buildApiPhone('0196123456'), equals(buildApiPhone('96123456')));
    });

    test('Moov Money "94XXXXXX" → "22994XXXXXX"', () {
      expect(buildApiPhone('94000000'), equals('22994000000'));
    });

    test('Celtis "99XXXXXX" → "22999XXXXXX"', () {
      expect(buildApiPhone('99000000'), equals('22999000000'));
    });

    test('résultat commence toujours par "229"', () {
      for (final num in ['96000000', '94000000', '0166000000']) {
        expect(buildApiPhone(num), startsWith('229'));
      }
    });
  });
}
