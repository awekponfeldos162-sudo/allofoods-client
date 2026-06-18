// lib/services/adresse_search_service.dart
// Recherche de lieux optimisée pour Cotonou / Bénin
// Stratégie : Places API (New) → Places API Legacy → Geocoding → Nominatim

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LieuSuggestion {
  final String placeId;
  final String titre;
  final String sousTitre;
  final String adresseComplete;
  final double? lat;
  final double? lng;
  final double? distanceKm;

  const LieuSuggestion({
    required this.placeId,
    required this.titre,
    required this.sousTitre,
    required this.adresseComplete,
    this.lat,
    this.lng,
    this.distanceKm,
  });
}

typedef CoordResult = ({double lat, double lng, String adresse});

class AdresseSearchService {
  static const _placesNewUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const _placesLegacyUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _geocodingUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  static const double _lat = 6.3654;
  static const double _lng = 2.4183;

  // ════════════════════════════════════════════════════════════════════════════
  // RECHERCHE PRINCIPALE — 4 niveaux de fallback
  // ════════════════════════════════════════════════════════════════════════════
  static Future<List<LieuSuggestion>> rechercher({
    required String query,
    required String googleMapsKey,
    String? sessionToken,
    int limit = 8,
  }) async {
    if (query.trim().length < 2) return [];

    final hasKey =
        googleMapsKey.isNotEmpty && !googleMapsKey.contains('REMPLACER');

    if (hasKey) {
      // 1. Places API (New) — meilleur pour POI nommés, nécessite activation séparée
      try {
        final r = await _placesApiNew(
            query: query, key: googleMapsKey, sessionToken: sessionToken, limit: limit);
        if (r.isNotEmpty) return r;
      } catch (e) {
        debugPrint('[Search] Places New: $e');
      }

      // 2. Places API Legacy — activée par défaut avec une clé Maps standard
      try {
        final r = await _placesLegacy(
            query: query, key: googleMapsKey, sessionToken: sessionToken, limit: limit);
        if (r.isNotEmpty) return r;
      } catch (e) {
        debugPrint('[Search] Places Legacy: $e');
      }

      // 3. Google Geocoding — fallback avec clé
      try {
        final r = await _googleGeocoding(
            query: query, key: googleMapsKey, limit: limit);
        if (r.isNotEmpty) return r;
      } catch (e) {
        debugPrint('[Search] Geocoding: $e');
      }
    }

    // 4. Nominatim (OpenStreetMap) — sans clé, toujours disponible
    try {
      return await _nominatim(query: query, limit: limit);
    } catch (e) {
      debugPrint('[Search] Nominatim: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PLACES API (NEW)
  // ════════════════════════════════════════════════════════════════════════════
  static Future<List<LieuSuggestion>> _placesApiNew({
    required String query,
    required String key,
    String? sessionToken,
    required int limit,
  }) async {
    final body = <String, dynamic>{
      'input': query,
      'languageCode': 'fr',
      'maxResultCount': limit,
      'includedRegionCodes': ['bj'],
      if (sessionToken != null) 'sessionToken': sessionToken,
      'locationBias': {
        'circle': {
          'center': {'latitude': _lat, 'longitude': _lng},
          'radius': 80000.0,
        },
      },
    };

    final res = await http
        .post(
          Uri.parse(_placesNewUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    debugPrint('[Search] Places New status=${res.statusCode}');
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'] as List? ?? [];
    final List<LieuSuggestion> results = [];

    for (final s in suggestions.take(limit)) {
      final p = s['placePrediction'] as Map<String, dynamic>?;
      if (p == null) continue;
      final placeId = p['placeId'] as String? ?? '';
      if (placeId.isEmpty) continue;

      final sf = p['structuredFormat'] as Map? ?? {};
      final mainText = (sf['mainText'] as Map?)?['text'] as String? ?? '';
      final subText = (sf['secondaryText'] as Map?)?['text'] as String? ?? '';
      final fullText = (p['text'] as Map?)?['text'] as String? ?? '';

      results.add(LieuSuggestion(
        placeId: placeId,
        titre: mainText.isNotEmpty ? mainText : fullText,
        sousTitre: _clean(subText),
        adresseComplete:
            fullText.isNotEmpty ? _clean(fullText) : _clean('$mainText, $subText'),
        distanceKm: (p['distanceMeters'] as num?) != null
            ? (p['distanceMeters'] as num) / 1000.0
            : null,
      ));
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PLACES API LEGACY — activée par défaut avec une clé Maps standard
  // ════════════════════════════════════════════════════════════════════════════
  static Future<List<LieuSuggestion>> _placesLegacy({
    required String query,
    required String key,
    String? sessionToken,
    required int limit,
  }) async {
    final uri = Uri.parse(
      '$_placesLegacyUrl'
      '?input=${Uri.encodeQueryComponent(query)}'
      '&key=$key'
      '&language=fr'
      '&components=country:bj'
      '&location=$_lat,$_lng'
      '&radius=80000'
      '${sessionToken != null ? "&sessiontoken=$sessionToken" : ""}',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    debugPrint(
        '[Search] Places Legacy status=${res.statusCode}');
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    debugPrint('[Search] Places Legacy status API: ${data['status']}');
    final predictions = data['predictions'] as List? ?? [];
    final List<LieuSuggestion> results = [];

    for (final p in predictions.take(limit)) {
      final m = p as Map<String, dynamic>;
      final placeId = m['place_id'] as String? ?? '';
      if (placeId.isEmpty) continue;

      final sf = m['structured_formatting'] as Map? ?? {};
      final mainText = (sf['main_text'] as String?)?.trim() ?? '';
      final subText = (sf['secondary_text'] as String?)?.trim() ?? '';
      final description = m['description'] as String? ?? '';

      results.add(LieuSuggestion(
        placeId: placeId,
        titre: mainText.isNotEmpty ? mainText : description,
        sousTitre: _clean(subText),
        adresseComplete: _clean(description),
        distanceKm: null,
      ));
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GOOGLE GEOCODING
  // ════════════════════════════════════════════════════════════════════════════
  static Future<List<LieuSuggestion>> _googleGeocoding({
    required String query,
    required String key,
    required int limit,
  }) async {
    final uri = Uri.parse(
      '$_geocodingUrl'
      '?address=${Uri.encodeQueryComponent("$query, Bénin")}'
      '&region=bj&language=fr&key=$key',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    debugPrint('[Search] Geocoding status=${res.statusCode}');
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];

    final rawList = data['results'] as List? ?? [];
    final List<LieuSuggestion> results = [];

    for (final r in rawList.take(limit)) {
      final m = r as Map<String, dynamic>;
      final formatted = m['formatted_address'] as String? ?? '';
      final geometry = m['geometry'] as Map?;
      final location = geometry?['location'] as Map?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      final comps = m['address_components'] as List? ?? [];

      final titre = _extractTitre(comps, formatted);
      final sousTitre = _extractSousTitre(comps, formatted, titre);

      if (titre.isEmpty || lat == null) continue;

      results.add(LieuSuggestion(
        placeId: '',
        titre: titre,
        sousTitre: sousTitre,
        adresseComplete: _clean(formatted),
        lat: lat,
        lng: lng,
      ));
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NOMINATIM (OpenStreetMap) — sans clé
  // ════════════════════════════════════════════════════════════════════════════
  static Future<List<LieuSuggestion>> _nominatim({
    required String query,
    required int limit,
  }) async {
    // Ajouter "Cotonou" si la requête n'a pas de contexte géographique
    final enriched = query.contains(',') ? query : '$query, Cotonou';

    final uri = Uri.parse(
      '$_nominatimUrl'
      '?q=${Uri.encodeQueryComponent(enriched)}'
      '&format=json&countrycodes=bj'
      '&limit=$limit'
      '&addressdetails=1'
      '&namedetails=1'
      '&accept-language=fr',
    );

    final res = await http.get(
      uri,
      headers: {'User-Agent': 'AlloFoods/1.0'},
    ).timeout(const Duration(seconds: 6));

    debugPrint('[Search] Nominatim status=${res.statusCode}');
    if (res.statusCode != 200) return [];

    final list = jsonDecode(res.body) as List? ?? [];
    final List<LieuSuggestion> results = [];

    for (final item in list.take(limit)) {
      final m = item as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').trim();
      final display = (m['display_name'] as String? ?? '').trim();
      final addr = m['address'] as Map? ?? {};
      final lat = double.tryParse(m['lat'] as String? ?? '');
      final lng = double.tryParse(m['lon'] as String? ?? '');

      final titre =
          name.isNotEmpty ? name : display.split(',').first.trim();

      final suburb = addr['suburb'] as String? ?? '';
      final city = addr['city'] as String? ??
          addr['town'] as String? ??
          addr['village'] as String? ?? '';
      final road = addr['road'] as String? ?? '';

      final sousParts = <String>[];
      if (road.isNotEmpty && road != titre) sousParts.add(road);
      if (suburb.isNotEmpty && suburb != titre) sousParts.add(suburb);
      if (city.isNotEmpty && city != titre) sousParts.add(city);

      if (titre.isEmpty || lat == null) continue;

      results.add(LieuSuggestion(
        placeId: '',
        titre: titre,
        sousTitre: sousParts.take(2).join(', '),
        adresseComplete: _buildAdresse(titre, sousParts.take(2).join(', '), city),
        lat: lat,
        lng: lng,
      ));
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PLACE DETAILS — coordonnées depuis un place_id
  // New API → Legacy API en fallback
  // ════════════════════════════════════════════════════════════════════════════
  static Future<CoordResult?> getCoordinates({
    required LieuSuggestion lieu,
    required String googleMapsKey,
    String? sessionToken,
  }) async {
    // Coordonnées déjà disponibles (Nominatim / Geocoding)
    if (lieu.lat != null && lieu.lng != null) {
      return (lat: lieu.lat!, lng: lieu.lng!, adresse: lieu.adresseComplete);
    }

    if (lieu.placeId.isEmpty ||
        googleMapsKey.isEmpty ||
        googleMapsKey.contains('REMPLACER')) return null;

    // Tentative 1 : Places API (New) Details
    try {
      final uri = Uri.https(
        'places.googleapis.com',
        '/v1/places/${lieu.placeId}',
        {
          'languageCode': 'fr',
          if (sessionToken != null) 'sessionToken': sessionToken,
        },
      );
      final res = await http.get(uri, headers: {
        'X-Goog-Api-Key': googleMapsKey,
        'X-Goog-FieldMask': 'location,formattedAddress',
      }).timeout(const Duration(seconds: 5));

      debugPrint('[Search] Details New status=${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = data['location'] as Map?;
        if (loc != null) {
          return (
            lat: (loc['latitude'] as num).toDouble(),
            lng: (loc['longitude'] as num).toDouble(),
            adresse: _clean(
                data['formattedAddress'] as String? ?? lieu.adresseComplete),
          );
        }
      } else {
        debugPrint('[Search] Details New error: ${res.body}');
      }
    } catch (e) {
      debugPrint('[Search] Details New: $e');
    }

    // Tentative 2 : Legacy Place Details
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeQueryComponent(lieu.placeId)}'
        '&fields=geometry,formatted_address'
        '&language=fr'
        '&key=$googleMapsKey'
        '${sessionToken != null ? "&sessiontoken=$sessionToken" : ""}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      debugPrint('[Search] Details Legacy status=${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        final loc =
            (result?['geometry'] as Map?)?['location'] as Map?;
        if (loc != null) {
          return (
            lat: (loc['lat'] as num).toDouble(),
            lng: (loc['lng'] as num).toDouble(),
            adresse: _clean(
                result?['formatted_address'] as String? ?? lieu.adresseComplete),
          );
        }
      } else {
        debugPrint('[Search] Details Legacy error: ${res.body}');
      }
    } catch (e) {
      debugPrint('[Search] Details Legacy: $e');
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  // Supprime ", Bénin" / ", BJ" en fin d'adresse pour un affichage propre
  static String _clean(String raw) {
    var s = raw
        .replaceAll(RegExp(r',?\s*Bénin\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r',?\s*Benin\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r',?\s*BJ\s*$'), '')
        .trim();
    if (s.endsWith(',')) s = s.substring(0, s.length - 1).trim();
    return s;
  }

  static String _extractTitre(List comps, String formatted) {
    for (final c in comps) {
      final types = (c['types'] as List? ?? []);
      if (types.any((t) => [
            'establishment',
            'point_of_interest',
            'premise',
            'natural_feature',
            'park',
            'airport',
          ].contains(t))) {
        final n = (c['long_name'] as String?)?.trim() ?? '';
        if (n.isNotEmpty) return n;
      }
    }
    for (final c in comps) {
      if ((c['types'] as List? ?? []).contains('route')) {
        return (c['long_name'] as String?)?.trim() ?? '';
      }
    }
    for (final part in formatted.split(',')) {
      final p = part.trim();
      if (p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p)) return p;
    }
    return formatted.split(',').first.trim();
  }

  static String _extractSousTitre(
      List comps, String formatted, String titre) {
    final parts = <String>[];
    for (final c in comps) {
      final types = (c['types'] as List? ?? []);
      final name = (c['long_name'] as String?)?.trim() ?? '';
      if (name == titre ||
          name == 'Bénin' ||
          name == 'Benin' ||
          name == 'BJ') continue;
      if (types.any((t) => [
            'sublocality',
            'sublocality_level_1',
            'locality',
            'administrative_area_level_2',
          ].contains(t))) {
        parts.add(name);
      }
    }
    return parts.take(2).join(', ');
  }

  static String _buildAdresse(
      String titre, String sousTitre, String city) {
    final parts = [titre];
    if (sousTitre.isNotEmpty) parts.add(sousTitre);
    if (city.isNotEmpty && !sousTitre.contains(city)) parts.add(city);
    return parts.join(', ');
  }
}
