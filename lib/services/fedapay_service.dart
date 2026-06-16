// lib/services/fedapay_service.dart
// La clé secrète FedaPay est gérée côté serveur (Cloud Functions).
// Ce service appelle les fonctions proxy — jamais l'API FedaPay directement.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class FedaPayService {
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  // Crée une transaction FedaPay et génère le token de paiement.
  // Le montant est lu depuis Firestore côté serveur (non falsifiable).
  static Future<Map<String, dynamic>> createTransaction({
    required String orderId,
    // Les paramètres suivants sont ignorés — le serveur lit depuis Firestore.
    // Conservés pour rétrocompatibilité de l'API appelante.
    int amountFcfa = 0,
    String description = '',
    String customerEmail = '',
    String customerName = '',
    String? customerPhone,
    String? restaurantId,
    String? restaurantName,
  }) async {
    try {
      debugPrint('[FedaPay] initFedaPayPayment orderId=$orderId');
      final result = await _functions
          .httpsCallable('initFedaPayPayment')
          .call({'orderId': orderId});

      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('[FedaPay] Transaction créée → ${data['transactionId']}');
      return {
        'success': true,
        'transactionId': data['transactionId'] ?? '',
        'token': data['token'] ?? '',
        'paymentUrl': data['paymentUrl'] ?? '',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[FedaPay] createTransaction error: ${e.code} ${e.message}');
      return {'error': true, 'message': e.message ?? 'Erreur serveur FedaPay'};
    } catch (e) {
      debugPrint('[FedaPay] createTransaction exception: $e');
      return {'error': true, 'message': 'Erreur réseau : $e'};
    }
  }

  // Déclenche le push USSD Mobile Money (MTN / Moov).
  static Future<Map<String, dynamic>> sendPaymentWithToken({
    required String token,
    required String phoneNumber,
    required String operator,
  }) async {
    if (token.isEmpty) {
      return {'error': true, 'message': 'Token de paiement manquant.'};
    }
    try {
      debugPrint('[FedaPay] sendFedaPayMomo operator=$operator');
      final result = await _functions
          .httpsCallable('sendFedaPayMomo')
          .call({'token': token, 'phoneNumber': phoneNumber, 'operator': operator});

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['useCheckout'] == true) {
        return {
          'error': true,
          'useCheckout': true,
          'message': data['message'] ?? 'Opérateur non disponible.',
        };
      }
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? 'Paiement initié.',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[FedaPay] sendPaymentWithToken error: ${e.code}');
      return {'error': true, 'message': e.message ?? 'Erreur paiement MoMo'};
    } catch (e) {
      debugPrint('[FedaPay] sendPaymentWithToken exception: $e');
      return {'error': true, 'message': 'Erreur réseau : $e'};
    }
  }

  // Génère le token checkout (non nécessaire si createTransaction renvoie déjà le token).
  // Conservé pour rétrocompatibilité.
  static Future<Map<String, dynamic>> generateToken(String transactionId) async {
    // Le token est déjà retourné par createTransaction via initFedaPayPayment.
    // Cette méthode ne devrait plus être appelée, mais on la garde par sécurité.
    debugPrint('[FedaPay] generateToken called — token already in createTransaction response');
    return {'error': true, 'message': 'Utilisez createTransaction qui retourne déjà le token.'};
  }

  // Vérifie le statut d'une transaction.
  static Future<Map<String, dynamic>> getTransaction(String transactionId) async {
    try {
      debugPrint('[FedaPay] checkFedaPayStatus transactionId=$transactionId');
      final result = await _functions
          .httpsCallable('checkFedaPayStatus')
          .call({'transactionId': transactionId});

      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'success': data['success'] == true,
        'transactionId': transactionId,
        'status': data['status'] ?? '',
        'isPaid': data['isPaid'] == true,
        'isExpired': data['isExpired'] == true,
        'amount': data['amount'],
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[FedaPay] getTransaction error: ${e.code}');
      return {'error': true, 'message': e.message ?? 'Erreur vérification'};
    } catch (e) {
      debugPrint('[FedaPay] getTransaction exception: $e');
      return {'error': true, 'message': 'Erreur vérification : $e'};
    }
  }
}
