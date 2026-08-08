import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_application_2/models/delivery_model.dart';

void main() {
  setUpAll(() {
    // Initialise dotenv avec une chaîne vide (isOptional:true évite l'erreur
    // EmptyEnvFileError). Env.* utilisera ses valeurs de repli codées en dur :
    // 500/1000/1500 FCFA aux seuils 3/10/15 km.
    dotenv.loadFromString(isOptional: true);
  });

  // ──────────────────────────────────────────────────────────
  group('DeliveryCalculator — calculateDistance (Haversine)', () {
    test('points identiques → 0 km', () {
      final d = DeliveryCalculator.calculateDistance(6.365, 2.418, 6.365, 2.418);
      expect(d, closeTo(0.0, 0.001));
    });

    test('Cotonou → Porto-Novo ≈ 28-32 km', () {
      // Cotonou (6.365, 2.418) → Porto-Novo (6.497, 2.628)
      final d = DeliveryCalculator.calculateDistance(6.365, 2.418, 6.497, 2.628);
      expect(d, greaterThan(25));
      expect(d, lessThan(35));
    });

    test('résultat symétrique A→B = B→A', () {
      final ab = DeliveryCalculator.calculateDistance(6.365, 2.418, 6.497, 2.628);
      final ba = DeliveryCalculator.calculateDistance(6.497, 2.628, 6.365, 2.418);
      expect(ab, closeTo(ba, 0.001));
    });

    test('déplacement purement latitudinal ≈ 1.11 km / 0.01°', () {
      final d = DeliveryCalculator.calculateDistance(6.000, 2.418, 6.010, 2.418);
      expect(d, closeTo(1.11, 0.05));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('DeliveryCalculator — calculateDeliveryFee', () {
    // Paliers par défaut : 500/1000/1500 FCFA aux seuils 3/10/15 km

    test('palier 1 : 0 km → 500 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(0), equals(500));
    });

    test('palier 1 : exactement 3 km → 500 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(3.0), equals(500));
    });

    test('palier 2 : 3.1 km → 1000 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(3.1), equals(1000));
    });

    test('palier 2 : 7 km → 1000 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(7.0), equals(1000));
    });

    test('palier 2 : exactement 10 km → 1000 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(10.0), equals(1000));
    });

    test('palier 3 : 10.1 km → 1500 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(10.1), equals(1500));
    });

    test('palier 3 : 12 km → 1500 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(12.0), equals(1500));
    });

    test('palier 3 : exactement 15 km → 1500 FCFA', () {
      expect(DeliveryCalculator.calculateDeliveryFee(15.0), equals(1500));
    });

    test('au-delà de 15 km : 20 km → 2000 FCFA', () {
      // 1500 + (20 - 15) * 100 = 2000
      expect(DeliveryCalculator.calculateDeliveryFee(20.0), equals(2000));
    });

    test('au-delà de 15 km : 25 km → 2500 FCFA', () {
      // 1500 + (25 - 15) * 100 = 2500
      expect(DeliveryCalculator.calculateDeliveryFee(25.0), equals(2500));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('DeliveryCalculator — estimatedMinutes', () {
    test('minimum 15 minutes même pour très courte distance', () {
      expect(DeliveryCalculator.estimatedMinutes(0), equals(15));
      expect(DeliveryCalculator.estimatedMinutes(0.5), equals(15));
      expect(DeliveryCalculator.estimatedMinutes(2.0), equals(15));
    });

    test('3 km = 15 minutes (seuil exact)', () {
      expect(DeliveryCalculator.estimatedMinutes(3.0), equals(15));
    });

    test('4 km → 20 minutes', () {
      expect(DeliveryCalculator.estimatedMinutes(4.0), equals(20));
    });

    test('10 km → 50 minutes', () {
      expect(DeliveryCalculator.estimatedMinutes(10.0), equals(50));
    });

    test('distance grande → résultat proportionnel', () {
      final m20 = DeliveryCalculator.estimatedMinutes(20.0);
      final m40 = DeliveryCalculator.estimatedMinutes(40.0);
      expect(m40, equals(m20 * 2));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('LatLngPoint', () {
    test('stocke lat et lng', () {
      const p = LatLngPoint(6.365, 2.418);
      expect(p.lat, equals(6.365));
      expect(p.lng, equals(2.418));
    });

    test('toString retourne (lat, lng)', () {
      const p = LatLngPoint(6.365, 2.418);
      expect(p.toString(), equals('(6.365, 2.418)'));
    });

    test('const constructor', () {
      const p1 = LatLngPoint(1.0, 2.0);
      const p2 = LatLngPoint(1.0, 2.0);
      // Const objects — same values
      expect(p1.lat, equals(p2.lat));
      expect(p1.lng, equals(p2.lng));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('DeliveryLocation — toMap / fromMap', () {
    test('toMap sérialise tous les champs', () {
      const loc = DeliveryLocation(
        lat: 6.370,
        lng: 2.425,
        addressName: 'Akpakpa, Cotonou',
        description: 'Près de la pharmacie',
        recipientContact: '22997000000',
        recipientName: 'Émile',
        isCustomAddress: true,
      );
      final m = loc.toMap();
      expect(m['lat'], equals(6.370));
      expect(m['lng'], equals(2.425));
      expect(m['address_name'], equals('Akpakpa, Cotonou'));
      expect(m['description'], equals('Près de la pharmacie'));
      expect(m['recipient_contact'], equals('22997000000'));
      expect(m['recipient_name'], equals('Émile'));
      expect(m['is_custom_address'], isTrue);
    });

    test('fromMap désérialise correctement', () {
      final m = {
        'lat': 6.370,
        'lng': 2.425,
        'address_name': 'Haie Vive',
        'description': 'Face boulangerie',
        'recipient_contact': '22966000000',
        'recipient_name': 'Marie',
        'is_custom_address': false,
      };
      final loc = DeliveryLocation.fromMap(m);
      expect(loc.lat, equals(6.370));
      expect(loc.lng, equals(2.425));
      expect(loc.addressName, equals('Haie Vive'));
      expect(loc.recipientContact, equals('22966000000'));
      expect(loc.isCustomAddress, isFalse);
    });

    test('fromMap accepte les types num pour lat/lng', () {
      final m = {'lat': 6, 'lng': 2}; // int, pas double
      final loc = DeliveryLocation.fromMap(m);
      expect(loc.lat, equals(6.0));
      expect(loc.lng, equals(2.0));
    });

    test('fromMap gère les champs manquants avec des défauts', () {
      final loc = DeliveryLocation.fromMap({});
      expect(loc.lat, equals(0.0));
      expect(loc.lng, equals(0.0));
      expect(loc.addressName, isEmpty);
      expect(loc.description, isEmpty);
      expect(loc.recipientContact, isEmpty);
      expect(loc.recipientName, isEmpty);
      expect(loc.isCustomAddress, isFalse);
    });

    test('roundtrip toMap → fromMap conserve toutes les données', () {
      const original = DeliveryLocation(
        lat: 6.412,
        lng: 2.350,
        addressName: 'Cotonou Centre',
        description: 'Derrière la mairie',
        recipientContact: '22991234567',
        recipientName: 'Jean',
        isCustomAddress: true,
      );
      final restored = DeliveryLocation.fromMap(original.toMap());
      expect(restored.lat, equals(original.lat));
      expect(restored.lng, equals(original.lng));
      expect(restored.addressName, equals(original.addressName));
      expect(restored.description, equals(original.description));
      expect(restored.recipientContact, equals(original.recipientContact));
      expect(restored.recipientName, equals(original.recipientName));
      expect(restored.isCustomAddress, equals(original.isCustomAddress));
    });

    test('description vide par défaut si non fourni', () {
      const loc = DeliveryLocation(lat: 0, lng: 0, addressName: 'Test');
      expect(loc.description, isEmpty);
      expect(loc.recipientContact, isEmpty);
      expect(loc.recipientName, isEmpty);
      expect(loc.isCustomAddress, isFalse);
    });
  });
}
