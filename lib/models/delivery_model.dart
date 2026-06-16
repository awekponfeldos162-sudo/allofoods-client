// lib/models/delivery_model.dart
// ? Positions RéELLES :
//   - Client : position choisie dans AdressePage (géolocalisation ou saisie manuelle)
//   - Restaurant : coordonnées récupérées depuis Firestore (champ lat/lng du restaurant)
//   - Plus de positions hardcodées

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter_application_2/config/env_config.dart';

// Point GPS
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);

  @override
  String toString() => '($lat, $lng)';
}

// Objet structuré de livraison
class DeliveryLocation {
  final double lat;
  final double lng;
  final String addressName;
  final String description;
  final String recipientContact;
  final String recipientName;
  final bool isCustomAddress;

  const DeliveryLocation({
    required this.lat,
    required this.lng,
    required this.addressName,
    this.description = '',
    this.recipientContact = '',
    this.recipientName = '',
    this.isCustomAddress = false,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'address_name': addressName,
    'description': description,
    'recipient_contact': recipientContact,
    'recipient_name': recipientName,
    'is_custom_address': isCustomAddress,
  };

  factory DeliveryLocation.fromMap(Map<String, dynamic> m) => DeliveryLocation(
    lat: (m['lat'] as num?)?.toDouble() ?? 0.0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0.0,
    addressName: m['address_name'] as String? ?? '',
    description: m['description'] as String? ?? '',
    recipientContact: m['recipient_contact'] as String? ?? '',
    recipientName: m['recipient_name'] as String? ?? '',
    isCustomAddress: m['is_custom_address'] as bool? ?? false,
  );
}

// Calculs livraison
class DeliveryCalculator {
  static const double _earthRadius = 6371.0; // km

  /// Formule Haversine à distance réelle entre 2 points GPS
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  /// Frais par paliers :
  /// 0é3 km  ? 500 FCFA
  /// 3é10 km ? 1 000 FCFA
  /// 10é15 km? 1 500 FCFA
  /// > 15 km ? 1 500 + 100 FCFA/km supplémentaire
  static int calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= Env.deliveryFeeTier1MaxKm) return Env.deliveryFeeTier1;
    if (distanceKm <= Env.deliveryFeeTier2MaxKm) return Env.deliveryFeeTier2;
    if (distanceKm <= Env.deliveryFeeTier3MaxKm) return Env.deliveryFeeTier3;
    return Env.deliveryFeeTier3 + ((distanceKm - Env.deliveryFeeTier3MaxKm) * 100).round();
  }

  /// Durée estimée : 5 min/km, minimum 15 min
  static int estimatedMinutes(double distanceKm) =>
      math.max(15, (distanceKm * 5).round());
}

// Statuts de livraison
enum DeliveryStatus { pending, preparing, onTheWay, nearBy, delivered }

// Provider partagé
class DeliveryProvider extends ChangeNotifier {
  // Position CLIENT (choisie dans AdressePage)
  LatLngPoint? _clientPosition;
  String _clientAddress = '';

  // Position RESTAURANT (chargée depuis Firestore)
  LatLngPoint _restaurantPos =
      const LatLngPoint(6.3654, 2.4183); // Cotonou défaut
  String _restaurantId = '';
  bool _loadingRestaurant = false;

  // Frais calculés
  double _distanceKm = 0;
  int _deliveryFee = 500;
  int _estMinutes = 30;

  // Suivi livreur
  DeliveryStatus _status = DeliveryStatus.pending;
  LatLngPoint? _driverPos;

  // Getters
  LatLngPoint? get clientPos => _clientPosition;
  LatLngPoint get restaurantPos => _restaurantPos;
  LatLngPoint get clientPosOrDef =>
      _clientPosition ?? const LatLngPoint(6.3654, 2.4183);
  String get clientAddress => _clientAddress;
  double get distanceKm => _distanceKm;
  int get deliveryFee => _deliveryFee;
  int get estMinutes => _estMinutes;
  String get restaurantId => _restaurantId;
  DeliveryStatus get status => _status;
  LatLngPoint? get driverPos => _driverPos;
  bool get hasAddress => _clientPosition != null;
  bool get loadingRestaurant => _loadingRestaurant;

  // POSITION CLIENT é définie après sélection dans AdressePage
  // (GPS réel ou adresse saisie + geocoding)
  void setClientPosition(LatLngPoint pos, String address) {
    _clientPosition = pos;
    _clientAddress = address;
    _recalc();
    notifyListeners();
  }

  // POSITION RESTAURANT é chargée depuis Firestore
  // Le document restaurant doit avoir les champs lat + lng
  // Si absent ? fallback centre Cotonou
  Future<void> setRestaurant(String id) async {
    if (id == _restaurantId && id.isNotEmpty) return; // déjà chargé
    _restaurantId = id;
    _loadingRestaurant = true;
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(id)
          .get();

      if (snap.exists) {
        final data = snap.data()!;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          _restaurantPos = LatLngPoint(lat, lng);
        } else {
          // Champ lat/lng absent ? essai avec address via geocoding
          debugPrint('?? Restaurant $id sans coordonnées GPS dans Firestore');
          // Fallback : centre de Cotonou
          _restaurantPos = const LatLngPoint(6.3654, 2.4183);
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement position restaurant : $e');
      _restaurantPos = const LatLngPoint(6.3654, 2.4183);
    }

    _loadingRestaurant = false;
    if (_clientPosition != null) _recalc();
    notifyListeners();
  }

  // Recalcul distance + frais
  void _recalc() {
    if (_clientPosition == null) return;
    _distanceKm = DeliveryCalculator.calculateDistance(
      _clientPosition!.lat,
      _clientPosition!.lng,
      _restaurantPos.lat,
      _restaurantPos.lng,
    );
    _deliveryFee = DeliveryCalculator.calculateDeliveryFee(_distanceKm);
    _estMinutes = DeliveryCalculator.estimatedMinutes(_distanceKm);
  }

  // Tracking livreur
  void startTracking() {
    _status = DeliveryStatus.preparing;
    _driverPos = _restaurantPos; // livreur part du restaurant
    notifyListeners();
  }

  void updateDriverPos(LatLngPoint pos) {
    _driverPos = pos;
    notifyListeners();
  }

  void updateStatus(DeliveryStatus s) {
    _status = s;
    notifyListeners();
  }

  void reset() {
    _status = DeliveryStatus.pending;
    _driverPos = null;
    notifyListeners();
  }
}
