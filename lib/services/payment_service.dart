// lib/services/payment_service.dart
// Nouveau modèle financier allofoods :
//   com1 = food × 5%  — déduit du restaurant
//   com2 = food × 5%  — ajouté au client (frais de service)
//   totalClient = food + com2 + delivery
//   restoReceives = food - com1
//   allofoodsTotal = com1 + com2 + delivery

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/config/env_config.dart';

// CONSTANTES COMMISSION
class PaymentService {
  // Taux commission côté restaurant (com1) et côté client (com2)
  static const double commissionRate = 0.05;

  static double get fedaPayRate => Env.fedaPayRate;

  // Calcule les frais de service ajoutés au client (com2 = food × 5%)
  static int computeServiceFee(int foodAmount) =>
      (foodAmount * commissionRate).round();

  // Calcule la commission déduite du restaurant (com1 = food × 5%)
  static int computeCommission(int foodAmount) =>
      (foodAmount * commissionRate).round();

  /// Ventilation complète du nouveau modèle :
  ///   food        = prix des plats (fixé par le restaurant)
  ///   commission  = food × 5% (com1, déduit du restaurant)
  ///   serviceFee  = food × 5% (com2, ajouté au client)
  ///   delivery    = frais de livraison
  ///   totalClient = food + serviceFee + delivery
  ///   restoAmount = food - commission
  ///   alloAmount  = commission + serviceFee + delivery
  static Map<String, int> calculerVentilation({
    required int foodAmount,
    required int deliveryFee,
  }) {
    final commission = computeCommission(foodAmount); // com1
    final serviceFee = computeServiceFee(foodAmount); // com2
    final totalClient = foodAmount + serviceFee + deliveryFee;
    final restoAmount = foodAmount - commission;
    final alloAmount = commission + serviceFee + deliveryFee;

    return {
      'foodAmount': foodAmount,
      'commission': commission, // com1 — déduit du restaurant
      'serviceFee': serviceFee, // com2 — payé par le client
      'deliveryFee': deliveryFee,
      'totalClient': totalClient,
      'restoAmount': restoAmount, // ce que le restaurant reçoit
      'alloAmount': alloAmount, // ce qu'allofoods garde
    };
  }

  // Confirmer le paiement — délègue à la Cloud Function `confirmOrderPayment`
  // qui revérifie le statut auprès de FedaPay avant d'écrire Firestore.
  // Le client ne peut plus marquer une commande PAID directement (voir
  // firestore.rules) : c'est la seule voie légitime.
  //
  // [functions] est injectable pour les tests (mock de FirebaseFunctions) —
  // en production, le paramètre n'est jamais fourni et l'instance réelle est
  // utilisée automatiquement.
  static Future<void> onPaymentSuccess({
    required String orderId,
    required String txId,
    required int foodAmount,
    required int deliveryFee,
    FirebaseFunctions? functions,
  }) async {
    final callable = (functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'))
        .httpsCallable('confirmOrderPayment');
    await callable.call({
      'orderId': orderId,
      'transactionId': txId,
    });
  }

  // Marquer l'échec de paiement
  static Future<void> onPaymentFailure({required String orderId}) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'paymentStatus': 'PAYMENT_FAILED',
      'status': 'cancelled',
      'failedAt': FieldValue.serverTimestamp(),
    });
  }

  // Préparer la commande avant paiement
  static Future<void> prepareOrder({
    required String orderId,
    required String restaurantId,
    required String? driverId,
    required int foodAmount,
    required int deliveryFee,
  }) async {
    final clientUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final v =
        calculerVentilation(foodAmount: foodAmount, deliveryFee: deliveryFee);
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'foodAmount': foodAmount,
      'commission': v['commission'],
      'serviceFee': v['serviceFee'],
      'deliveryFee': deliveryFee,
      'totalAmount': v['totalClient'],
      'restoAmount': v['restoAmount'],
      'alloAmount': v['alloAmount'],
      'paymentStatus': 'pending',
      'restaurantId': restaurantId,
      'deliveryId': driverId,
      'clientUid': clientUid,
    });
  }
}

// WIDGET — Récapitulatif ventilation client
class VentilationSummary extends StatelessWidget {
  final int foodAmount;
  final int deliveryFee;

  const VentilationSummary({
    super.key,
    required this.foodAmount,
    required this.deliveryFee,
  });

  @override
  Widget build(BuildContext context) {
    final v = PaymentService.calculerVentilation(
      foodAmount: foodAmount,
      deliveryFee: deliveryFee,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(children: [
        _Line('Sous-total plats', '${v['foodAmount']} FCFA', Colors.black87),
        _Line('Frais de service (5%)', '${v['serviceFee']} FCFA', Colors.orange),
        _Line('Frais de livraison', '${v['deliveryFee']} FCFA', Colors.blue),
        const Divider(height: 14),
        _Line('Total à payer', '${v['totalClient']} FCFA', Colors.orange,
            bold: true),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Line(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ]),
      );
}
