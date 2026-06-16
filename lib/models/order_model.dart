// lib/models/order_model.dart
// Structure complète d'une commande allofoods
// Champs obligatoires pour la ventilation financière T = R + L + S

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  // Identifiants
  final String id;
  final String clientUid;
  final String restaurantId;
  final String restaurantName;
  final String? deliveryId; // UID du livreur (null si pas encore assigné)

  // Articles
  final List<OrderItem> items;

  // CHAMPS FINANCIERS é Ventilation T = R + L + S
  // Ces 3 champs sont OBLIGATOIRES pour le webhook

  /// R é Prix de la nourriture (va au restaurant)
  final int foodAmount;

  /// L é Frais de livraison (70% au livreur, 30% é allofoods)
  final int deliveryFee;

  /// S é Frais de service fixe (va é allofoods)
  final int serviceFee;

  /// T é Montant total payé par le client (= foodAmount + deliveryFee + serviceFee)
  final int totalAmount;

  // Paiement
  final String paymentMethod; // "mobile_money" | "cash"
  final String paymentStatus; // "pending" | "PAID" | "PAYMENT_FAILED"
  final String? transactionId; // ID Kkiapay après paiement

  // Ventilation calculée par le webhook
  final VentilationModel? ventilation;

  // Livraison
  final String deliveryAddress;
  final double clientLat;
  final double clientLng;
  final double restaurantLat;
  final double restaurantLng;
  final double distanceKm;

  // Statut
  /// pending ? confirmed ? preparing ? ready ? en_route ? delivered | cancelled
  final String status;

  // Tracking livreur
  final double? driverLat;
  final double? driverLng;
  final String? driverName;
  final String? driverPhone;
  final String? estimatedArrival;

  // Timestamps
  final Timestamp? createdAt;
  final Timestamp? paidAt;

  const OrderModel({
    required this.id,
    required this.clientUid,
    required this.restaurantId,
    required this.restaurantName,
    this.deliveryId,
    required this.items,
    required this.foodAmount,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.transactionId,
    this.ventilation,
    required this.deliveryAddress,
    required this.clientLat,
    required this.clientLng,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.distanceKm,
    this.status = 'pending',
    this.driverLat,
    this.driverLng,
    this.driverName,
    this.driverPhone,
    this.estimatedArrival,
    this.createdAt,
    this.paidAt,
  }) : assert(
          totalAmount == foodAmount + deliveryFee + serviceFee,
          'T doit étre égal é R + L + S',
        );

  // Vers Firestore
  Map<String, dynamic> toMap() => {
        'clientUid': clientUid,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'deliveryId': deliveryId,
        'items': items.map((i) => i.toMap()).toList(),

        // Champs financiers (OBLIGATOIRES pour webhook)
        'foodAmount': foodAmount, // R
        'deliveryFee': deliveryFee, // L
        'serviceFee': serviceFee, // S
        'totalAmount': totalAmount, // T = R + L + S

        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'transactionId': transactionId,

        'deliveryAddress': deliveryAddress,
        'clientLat': clientLat,
        'clientLng': clientLng,
        'restaurantLat': restaurantLat,
        'restaurantLng': restaurantLng,
        'distanceKm': distanceKm,

        'status': status,
        'driverLat': driverLat,
        'driverLng': driverLng,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'estimatedArrival': estimatedArrival,

        'createdAt': FieldValue.serverTimestamp(),
      };

  // Depuis Firestore
  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      clientUid: map['clientUid'] as String? ?? '',
      restaurantId: map['restaurantId'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      deliveryId: map['deliveryId'] as String?,
      items: (map['items'] as List? ?? [])
          .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      foodAmount: (map['foodAmount'] as num?)?.toInt() ?? 0,
      deliveryFee: (map['deliveryFee'] as num?)?.toInt() ?? 0,
      serviceFee: (map['serviceFee'] as num?)?.toInt() ?? 200,
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? 'mobile_money',
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      transactionId: map['transactionId'] as String?,
      ventilation: map['ventilation'] != null
          ? VentilationModel.fromMap(map['ventilation'] as Map<String, dynamic>)
          : null,
      deliveryAddress: map['deliveryAddress'] as String? ?? '',
      clientLat: (map['clientLat'] as num?)?.toDouble() ?? 0,
      clientLng: (map['clientLng'] as num?)?.toDouble() ?? 0,
      restaurantLat: (map['restaurantLat'] as num?)?.toDouble() ?? 0,
      restaurantLng: (map['restaurantLng'] as num?)?.toDouble() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending',
      driverLat: (map['driverLat'] as num?)?.toDouble(),
      driverLng: (map['driverLng'] as num?)?.toDouble(),
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      estimatedArrival: map['estimatedArrival'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      paidAt: map['paidAt'] as Timestamp?,
    );
  }
}

// VENTILATION MODEL
class VentilationModel {
  final int totalAmount;
  final int restaurantPart; // R
  final int driverPart; // L
  final int platformPart; // S

  const VentilationModel({
    required this.totalAmount,
    required this.restaurantPart,
    required this.driverPart,
    required this.platformPart,
  });

  factory VentilationModel.fromMap(Map<String, dynamic> map) =>
      VentilationModel(
        totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
        restaurantPart: (map['restaurantPart'] as num?)?.toInt() ?? 0,
        driverPart: (map['driverPart'] as num?)?.toInt() ?? 0,
        platformPart: (map['platformPart'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'totalAmount': totalAmount,
        'restaurantPart': restaurantPart,
        'driverPart': driverPart,
        'platformPart': platformPart,
      };
}

// ORDER ITEM MODEL
class OrderItem {
  final String name;
  final int price;
  final int quantity;
  final String img;
  final String restaurantName;

  const OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.img,
    required this.restaurantName,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'quantity': quantity,
        'img': img,
        'restaurantName': restaurantName,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toInt() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        img: map['img'] as String? ?? '',
        restaurantName: map['restaurantName'] as String? ?? '',
      );
}
