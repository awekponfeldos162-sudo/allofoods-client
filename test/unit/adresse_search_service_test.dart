// test/unit/adresse_search_service_test.dart
// Tests unitaires pour AdresseSearchService et LieuSuggestion
// Vérifie que le nom du lieu est préservé (pas remplacé par des chiffres de rue)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/adresse_search_service.dart';

// Logique extraite de adressePage.dart (_selectResult) :
// Le nom affiché utilise titre + sousTitre, JAMAIS formattedAddress
// qui retourne des numéros de rue comme "989, Boulevard X"
String _buildDisplayAddr(LieuSuggestion result) {
  return result.sousTitre.isNotEmpty
      ? '${result.titre}, ${result.sousTitre}'
      : result.titre;
}

void main() {
  // ──────────────────────────────────────────────────────────
  group('LieuSuggestion — construction', () {
    test('crée un lieu avec tous les champs', () {
      const lieu = LieuSuggestion(
        placeId: 'place-abc',
        titre: 'Centre Wedu Wedu',
        sousTitre: 'Cotonou, Bénin',
        adresseComplete: 'Centre Wedu Wedu, Cotonou',
        lat: 6.365,
        lng: 2.418,
        distanceKm: 1.2,
      );
      expect(lieu.placeId,        equals('place-abc'));
      expect(lieu.titre,          equals('Centre Wedu Wedu'));
      expect(lieu.sousTitre,      equals('Cotonou, Bénin'));
      expect(lieu.adresseComplete, equals('Centre Wedu Wedu, Cotonou'));
      expect(lieu.lat,            equals(6.365));
      expect(lieu.lng,            equals(2.418));
      expect(lieu.distanceKm,     equals(1.2));
    });

    test('champs optionnels null par défaut', () {
      const lieu = LieuSuggestion(
        placeId: 'place-xyz',
        titre: 'Akpakpa',
        sousTitre: '',
        adresseComplete: 'Akpakpa',
      );
      expect(lieu.lat,        isNull);
      expect(lieu.lng,        isNull);
      expect(lieu.distanceKm, isNull);
    });

    test('accepte lat/lng négatifs (hémisphère Sud)', () {
      const lieu = LieuSuggestion(
        placeId: 'p1',
        titre: 'Lieu Sud',
        sousTitre: '',
        adresseComplete: 'Lieu',
        lat: -1.5,
        lng: -3.2,
      );
      expect(lieu.lat, equals(-1.5));
      expect(lieu.lng, equals(-3.2));
    });

    test('placeId vide accepté', () {
      const lieu = LieuSuggestion(
        placeId: '',
        titre: 'Nominatim result',
        sousTitre: '',
        adresseComplete: 'Test',
        lat: 6.0,
        lng: 2.0,
      );
      expect(lieu.placeId, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  group('Affichage adresse — nom du lieu préservé (fix bug "989 COTONOU")', () {
    test('POI avec sousTitre → "titre, sousTitre" (pas de chiffre de rue)', () {
      const lieu = LieuSuggestion(
        placeId: 'p1',
        titre: 'Centre Wedu Wedu',
        sousTitre: 'Cotonou',
        // formattedAddress retournerait "989, Boulevard de la Marina" — ignoré
        adresseComplete: '989 Boulevard de la Marina, Cotonou',
      );
      final display = _buildDisplayAddr(lieu);
      expect(display, equals('Centre Wedu Wedu, Cotonou'));
      expect(display, isNot(contains('989')));
    });

    test('POI sans sousTitre → titre seul (pas de numéro de rue)', () {
      const lieu = LieuSuggestion(
        placeId: 'p2',
        titre: 'Marché Dantokpa',
        sousTitre: '',
        adresseComplete: '45 Rue du marché, Cotonou',
      );
      final display = _buildDisplayAddr(lieu);
      expect(display, equals('Marché Dantokpa'));
      expect(display, isNot(contains('45')));
    });

    test('hôtel avec quartier → conserve nom complet sans chiffre', () {
      const lieu = LieuSuggestion(
        placeId: 'p3',
        titre: 'Hôtel du Lac',
        sousTitre: 'Haie Vive, Cotonou',
        adresseComplete: '12 Rue du Lac, Cotonou',
      );
      final display = _buildDisplayAddr(lieu);
      expect(display, startsWith('Hôtel du Lac'));
      expect(display, isNot(matches(RegExp(r'^\d+')))); // ne commence pas par un chiffre
    });

    test('adresse normale avec numéro dans le titre → conservé', () {
      // Un titre qui contient un chiffre légitimement (ex: "Carrefour X5")
      const lieu = LieuSuggestion(
        placeId: 'p4',
        titre: 'Carrefour Route X5',
        sousTitre: 'Cadjehoun',
        adresseComplete: 'Route X5, Cadjehoun',
      );
      final display = _buildDisplayAddr(lieu);
      expect(display, equals('Carrefour Route X5, Cadjehoun'));
    });

    test('sousTitre vide → titre seul, pas de virgule orpheline', () {
      const lieu = LieuSuggestion(
        placeId: 'p5',
        titre: 'Pharmacie Centrale',
        sousTitre: '',
        adresseComplete: 'Rue quelconque',
      );
      final display = _buildDisplayAddr(lieu);
      expect(display, equals('Pharmacie Centrale'));
      expect(display, isNot(endsWith(',')));
      expect(display, isNot(endsWith(', ')));
    });

    test('restaurantName depuis titre — premier segment avant virgule', () {
      // Dans adressePage, _searchCtrl.text = result.titre (nom court du lieu)
      const lieu = LieuSuggestion(
        placeId: 'p6',
        titre: 'Maquis Le Calme',
        sousTitre: 'Fidjrossè, Cotonou',
        adresseComplete: '7 Rue Fidjrossè, Cotonou',
      );
      // La barre de recherche affiche result.titre
      expect(lieu.titre, equals('Maquis Le Calme'));
    });
  });

  // ──────────────────────────────────────────────────────────
  group('AdresseSearchService.rechercher — validation query', () {
    test('query vide → liste vide (pas d\'appel réseau)', () async {
      final results = await AdresseSearchService.rechercher(
        query: '',
        googleMapsKey: '',
      );
      expect(results, isEmpty);
    });

    test('query 1 caractère → liste vide (trop court)', () async {
      final results = await AdresseSearchService.rechercher(
        query: 'a',
        googleMapsKey: '',
      );
      expect(results, isEmpty);
    });

    test('query espaces seuls → liste vide', () async {
      final results = await AdresseSearchService.rechercher(
        query: '   ',
        googleMapsKey: '',
      );
      expect(results, isEmpty);
    });

    test('query 1 espace → liste vide (trim → length < 2)', () async {
      final results = await AdresseSearchService.rechercher(
        query: ' ',
        googleMapsKey: '',
      );
      expect(results, isEmpty);
    });

    test('clé REMPLACER → sans appel Google API (Nominatim uniquement)', () async {
      // Avec une clé invalide contenant "REMPLACER", hasKey = false
      // → seul Nominatim est essayé (peut retourner [] si pas de réseau)
      // Ce test vérifie simplement qu'il ne crash pas
      final results = await AdresseSearchService.rechercher(
        query: 'Cotonou',
        googleMapsKey: 'REMPLACER_PAR_VOTRE_CLE',
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );
      expect(results, isA<List<LieuSuggestion>>());
    });
  });

  // ──────────────────────────────────────────────────────────
  group('Détection opérateur béninois (logique PaiementPage)', () {
    // Logique _detectNetwork extraite de PaiementPage pour test isolé
    String? detectNetwork(String rawPhone) {
      var digits = rawPhone.trim();
      if (digits.length == 10 && digits.startsWith('01')) {
        digits = digits.substring(2);
      }
      if (digits.length < 2) return null;
      final prefix = digits.substring(0, 2);
      const mtn    = ['96', '97', '66', '67', '68', '69'];
      const moov   = ['94', '95', '61', '62', '64', '65'];
      const celtis = ['99', '98', '91', '93', '92', '63'];
      if (mtn.contains(prefix))    return 'mtn_open';
      if (moov.contains(prefix))   return 'moov';
      if (celtis.contains(prefix)) return 'celtis';
      return null;
    }

    test('96XXXXXX → MTN MoMo', () {
      expect(detectNetwork('96123456'), equals('mtn_open'));
    });

    test('97XXXXXX → MTN MoMo', () {
      expect(detectNetwork('97000000'), equals('mtn_open'));
    });

    test('94XXXXXX → Moov Money', () {
      expect(detectNetwork('94000000'), equals('moov'));
    });

    test('95XXXXXX → Moov Money', () {
      expect(detectNetwork('95000000'), equals('moov'));
    });

    test('99XXXXXX → Celtis', () {
      expect(detectNetwork('99000000'), equals('celtis'));
    });

    test('format long 0196XXXXXX → MTN MoMo', () {
      expect(detectNetwork('0196123456'), equals('mtn_open'));
    });

    test('format long 0194XXXXXX → Moov Money', () {
      expect(detectNetwork('0194000000'), equals('moov'));
    });

    test('numéro inconnu → null', () {
      expect(detectNetwork('00000000'), isNull);
    });

    test('numéro trop court → null', () {
      expect(detectNetwork('9'), isNull);
    });
  });
}
