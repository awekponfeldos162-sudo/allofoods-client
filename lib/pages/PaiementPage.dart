// lib/pages/PaiementPage.dart
// Paiement via FedaPay (Mobile Money uniquement)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_model.dart';
import '../models/delivery_model.dart'
    show DeliveryCalculator, DeliveryLocation, DeliveryProvider;
import '../services/fedapay_service.dart';
import '../services/local_notification_service.dart';
import '../services/payment_service.dart';
import 'WaitingPage.dart';
import 'fedapay_checkout_page.dart';


class PaiementPage extends StatefulWidget {
  final int totalAmount;
  final String deliveryAddress;
  final int deliveryFee;
  final double distanceKm;
  final String restaurantName;
  final String restaurantId;
  final double deliveryLat;
  final double deliveryLng;
  final String deliveryNote;
  final bool deliveryPayCash;
  final DeliveryLocation? deliveryLocation;

  final int promoDiscount;
  final String? promoCode;
  final String? promoDocId;

  const PaiementPage({
    super.key,
    required this.totalAmount,
    required this.deliveryAddress,
    this.deliveryFee = 500,
    this.distanceKm = 0,
    this.restaurantName = '',
    this.restaurantId = '',
    this.deliveryLat = 6.3654,
    this.deliveryLng = 2.4183,
    this.deliveryNote = '',
    this.deliveryPayCash = false,
    this.deliveryLocation,
    this.promoDiscount = 0,
    this.promoCode,
    this.promoDocId,
  });

  @override
  State<PaiementPage> createState() => _PaiementPageState();
}

class _PaiementPageState extends State<PaiementPage> {
  bool _processing = false;
  bool _paymentInProgress = false;
  String _statusMessage = '';
  String? _activeOrderId;
  String? _activeTransactionId;
  Timer? _paymentPollTimer;
  final _phoneCtrl = TextEditingController();
  String _selectedOperator = 'mtn_open'; // 'mtn_open' | 'moov' | 'celtis'
  String? _detectedOperator; // réseau détecté automatiquement depuis le numéro saisi

  // Génère un orderId unique
  String get _newOrderId => 'ORD-${DateTime.now().millisecondsSinceEpoch}';

  // Numéro FedaPay propre : si l'utilisateur saisit le format local béninois
  // "0196XXXXXX" (10 chiffres), on retire le "01" → "22996XXXXXX" (FedaPay).
  // Si 8 chiffres (ancien format), on ajoute juste "229".
  String get _apiPhone {
    final raw = _phoneCtrl.text.trim();
    final digits = (raw.length == 10 && raw.startsWith('01'))
        ? raw.substring(2)
        : raw;
    return '229$digits';
  }

  // Nouveau modèle : totalAmount = food + com2 + delivery
  int get _foodAmount {
    final net = widget.totalAmount - widget.deliveryFee;
    return (net / (1 + PaymentService.commissionRate)).round();
  }

  int get _serviceFee => PaymentService.computeServiceFee(_foodAmount);
  int get _commission => PaymentService.computeCommission(_foodAmount);
  int get _restoAmount => _foodAmount - _commission;
  int get _alloAmount => _commission + _serviceFee + widget.deliveryFee;

  int get _paidOnline => widget.deliveryPayCash
      ? widget.totalAmount - widget.deliveryFee
      : widget.totalAmount;

  int get _toPayToDriver => widget.deliveryPayCash ? widget.deliveryFee : 0;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final raw = _phoneCtrl.text.trim();
    final isComplete = raw.length == 8 || (raw.length == 10 && raw.startsWith('01'));
    final detected = isComplete ? _detectNetwork(raw) : null;
    if (detected != _detectedOperator) {
      setState(() => _detectedOperator = detected);
    }
  }

  // Détecte l'opérateur béninois depuis les 2 premiers chiffres du numéro local (8 chiffres)
  static String? _detectNetwork(String rawPhone) {
    var digits = rawPhone.trim();
    if (digits.length == 10 && digits.startsWith('01')) digits = digits.substring(2);
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

  // CRÉER LA COMMANDE DANS FIRESTORE
  Future<void> _createOrder(String orderId, {required String status}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final cart = context.read<CartProvider>();
    final del = context.read<DeliveryProvider>();
    final ventilation = PaymentService.calculerVentilation(
      foodAmount: _foodAmount,
      deliveryFee: widget.deliveryFee,
    );

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final customerPhone = userData['phone'] as String? ?? '';
    final customerName = userData['name'] as String? ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Client';

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'clientUid': uid,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'restaurantId': cart.restaurantId.isNotEmpty
          ? cart.restaurantId
          : widget.restaurantId,
      'restaurantName': cart.restaurantName.isNotEmpty
          ? cart.restaurantName
          : widget.restaurantName,
      'items': cart.items
          .map((i) => {
                'name': i.name,
                'price': i.price,
                'quantity': i.quantity,
                'img': i.img,
                'restaurantName': i.restaurantName,
              })
          .toList(),
      // Financier (nouveau modèle com1 + com2)
      'foodAmount': _foodAmount,
      'commission': _commission,
      'serviceFee': _serviceFee,
      'deliveryFee': widget.deliveryFee,
      'totalAmount': widget.totalAmount,
      'restoAmount': _restoAmount,
      'alloAmount': _alloAmount,
      'paidOnline': _paidOnline,
      'toPayToDriver': _toPayToDriver,
      'ventilation': ventilation,
      // Paiement
      'paymentStatus': 'PENDING',
      'paymentMethod': 'mobile_money_fedapay',
      'delivery_payment_method': widget.deliveryPayCash ? 'cash' : 'online',
      'total_paid_app': _paidOnline,
      'delivery_fee_cash': _toPayToDriver,
      'is_delivery_paid_online': !widget.deliveryPayCash,
      'status': status,
      // Livraison
      'deliveryAddress': widget.deliveryAddress,
      'deliveryNote': widget.deliveryNote,
      'clientLat': widget.deliveryLat,
      'clientLng': widget.deliveryLng,
      'restaurantLat': del.restaurantPos.lat,
      'restaurantLng': del.restaurantPos.lng,
      'distanceKm': widget.distanceKm,
      if (widget.deliveryLocation != null)
        'delivery_location': widget.deliveryLocation!.toMap(),
      'driverName': '',
      'driverPhone': '',
      'estimatedArrival':
          '${DeliveryCalculator.estimatedMinutes(widget.distanceKm)} min',
      'createdAt': FieldValue.serverTimestamp(),
      if (widget.promoDiscount > 0) ...{
        'promoCode': widget.promoCode,
        'promoDocId': widget.promoDocId,
        'promoDiscount': widget.promoDiscount,
      },
    });
  }

  // Envoie une notification à l'utilisateur connecté
  Future<void> _sendNotification({
    required String orderId,
    required String title,
    required String message,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'type': 'order',
        'isRead': false,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // FLUX PRINCIPAL
  Future<void> _pay() async {
    if (_paymentInProgress) {
      await _pollPaymentStatus(manual: true);
      return;
    }

    if (context.read<CartProvider>().items.isEmpty || _foodAmount <= 0) {
      _snack('Votre panier est vide. Ajoutez des articles avant de commander.', Colors.orange);
      return;
    }

    final digits = _phoneCtrl.text.trim();
    final validLength = digits.length == 8 ||
        (digits.length == 10 && digits.startsWith('01'));
    if (!validLength) {
      _snack(
          'Entrez votre numéro Mobile Money (ex : 0196123456 ou 96123456)',
          Colors.orange);
      return;
    }
    setState(() {
      _processing = true;
      _statusMessage = 'Preparation de votre commande...';
    });
    final orderId = _newOrderId;

    try {
      await _createOrder(orderId, status: 'awaiting_payment');
      if (!mounted) return;
      await _runFedaPay(orderId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusMessage = '';
      });
      _snack('Erreur : $e', Colors.red);
    }
  }

  // Lancer FedaPay — paiement sans redirection via token + opérateur explicite
  Future<void> _runFedaPay(String orderId) async {
    try {
      final apiPhone = _apiPhone;
      final user = FirebaseAuth.instance.currentUser;
      final restaurantId = context.read<CartProvider>().restaurantId.isNotEmpty
          ? context.read<CartProvider>().restaurantId
          : widget.restaurantId;

      // 1. Créer la transaction avec merchant_reference et custom_metadata
      final txResult = await FedaPayService.createTransaction(
        amountFcfa: _paidOnline,
        description: 'allofoods — ${widget.restaurantName}',
        customerEmail: user?.email ?? 'client@allofoods.bj',
        customerName: user?.displayName ?? 'Client allofoods',
        customerPhone: apiPhone,
        orderId: orderId,
        restaurantId: restaurantId,
        restaurantName: widget.restaurantName,
      );
      if (!mounted) return;
      if (txResult['error'] == true) {
        await PaymentService.onPaymentFailure(orderId: orderId);
        await _sendNotification(
          orderId: orderId,
          title: 'Commande échouée',
          message: 'Impossible de déclencher le paiement. Veuillez réessayer.',
        );
        setState(() => _processing = false);
        _snack(txResult['message'] ?? 'Erreur FedaPay', Colors.red);
        return;
      }

      final transactionId = txResult['transactionId'] as String;
      // Le token et l'URL sont déjà retournés par initFedaPayPayment (Cloud Function)
      final paymentToken = txResult['token'] as String? ?? '';
      final checkoutUrl = txResult['paymentUrl'] as String? ?? '';

      // Pas de token → pas de push USSD possible
      if (paymentToken.isEmpty) {
        if (checkoutUrl.isEmpty) {
          await PaymentService.onPaymentFailure(orderId: orderId);
          setState(() => _processing = false);
          _snack('Impossible de générer le token de paiement.', Colors.red);
          return;
        }
        // Token absent mais URL disponible → WebView directement
        context.read<CartProvider>().clear();
        setState(() => _processing = false);
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => FedaPayCheckoutPage(
              checkoutUrl: checkoutUrl,
              transactionId: transactionId,
              orderId: orderId,
            ),
          ),
        );
        if (!mounted) return;
        if (result?['success'] == true) {
          await _onPaymentSuccess(orderId, transactionId);
        } else {
          await PaymentService.onPaymentFailure(orderId: orderId);
          _snack(result?['message'] as String? ?? 'Paiement annulé.', Colors.orange);
        }
        return;
      }

      // 3. Envoi paiement sans redirection — token + opérateur sélectionné
      final pushResult = await FedaPayService.sendPaymentWithToken(
        token: paymentToken,
        phoneNumber: apiPhone,
        operator: _selectedOperator,
      );
      if (!mounted) return;

      if (pushResult['error'] == true && pushResult['useCheckout'] != true) {
        await PaymentService.onPaymentFailure(orderId: orderId);
        await _sendNotification(
          orderId: orderId,
          title: 'Commande échouée',
          message: 'Impossible de lancer le paiement. Veuillez réessayer.',
        );
        setState(() {
          _processing = false;
          _statusMessage = '';
        });
        _snack(pushResult['message'] ?? 'Impossible de lancer le paiement', Colors.red);
        return;
      }

      // Opérateur non disponible → fallback checkout WebView
      if (pushResult['useCheckout'] == true) {
        context.read<CartProvider>().clear();
        setState(() => _processing = false);
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => FedaPayCheckoutPage(
              checkoutUrl: checkoutUrl,
              transactionId: transactionId,
              orderId: orderId,
            ),
          ),
        );
        if (!mounted) return;
        if (result?['success'] == true) {
          await _onPaymentSuccess(orderId, transactionId);
        } else {
          await PaymentService.onPaymentFailure(orderId: orderId);
          _snack(result?['message'] as String? ?? 'Paiement annulé.', Colors.orange);
        }
        return;
      }

      // Push USSD réussi → mode polling
      setState(() {
        _processing = false;
        _paymentInProgress = true;
        _activeOrderId = orderId;
        _activeTransactionId = transactionId;
        _statusMessage = 'Confirmez le paiement sur votre téléphone. Vérification automatique en cours.';
      });
      context.read<CartProvider>().clear();
      LocalNotificationService.showUssdPaymentSent(phoneNumber: _apiPhone);
      _startPaymentPolling();
    } catch (e) {
      debugPrint('[PaiementPage] Erreur FedaPay : $e');
      if (mounted) {
        await PaymentService.onPaymentFailure(orderId: orderId);
        await _sendNotification(
          orderId: orderId,
          title: 'Commande échouée',
          message: 'Une erreur technique est survenue. Veuillez réessayer.',
        );
        setState(() => _processing = false);
        _snack('Erreur paiement : $e', Colors.red);
      }
    }
  }

  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _pollPaymentStatus(),
    );
  }

  Future<void> _pollPaymentStatus({bool manual = false}) async {
    final orderId = _activeOrderId;
    final transactionId = _activeTransactionId;
    if (orderId == null || transactionId == null || _processing) return;

    if (manual && mounted) {
      setState(() {
        _processing = true;
        _statusMessage = 'Verification du paiement...';
      });
    }

    try {
      final res = await FedaPayService.getTransaction(transactionId);
      if (!mounted) return;
      final status = res['status'] as String? ?? '';

      if (status == 'approved') {
        _paymentPollTimer?.cancel();
        setState(() {
          _processing = false;
          _paymentInProgress = false;
          _statusMessage = 'Paiement confirme.';
        });
        await _onPaymentSuccess(orderId, transactionId);
        return;
      }

      if (status == 'declined' ||
          status == 'canceled' ||
          status == 'cancelled' ||
          status == 'expired') {
        _paymentPollTimer?.cancel();
        await PaymentService.onPaymentFailure(orderId: orderId);
        final isExpired = status == 'expired';
        await _sendNotification(
          orderId: orderId,
          title: isExpired ? 'Paiement expiré' : 'Paiement annulé',
          message: isExpired
              ? 'La demande de paiement a expiré. Veuillez recommencer.'
              : 'Votre paiement chez ${widget.restaurantName} a été refusé ou annulé.',
        );
        if (!mounted) return;
        setState(() {
          _processing = false;
          _paymentInProgress = false;
          _activeOrderId = null;
          _activeTransactionId = null;
          _statusMessage = '';
        });
        _snack(
          isExpired ? 'Paiement expiré. Veuillez réessayer.' : 'Paiement refusé ou annulé.',
          Colors.orange,
        );
        return;
      }

      setState(() {
        _processing = false;
        _statusMessage = status.isEmpty || status == 'pending'
            ? 'Paiement en attente. Confirmez sur votre telephone.'
            : 'Statut paiement : $status.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusMessage =
            'Verification impossible pour le moment. Nous reessayons automatiquement.';
      });
    }
  }

  Future<void> _onPaymentSuccess(String orderId, String txId) async {
    try {
      // Un seul update — consolide PaymentService.onPaymentSuccess + confirmation
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'paid',
        'paymentStatus': 'PAID',
        'fedaPayTransactionId': txId,
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
        'paidAt': FieldValue.serverTimestamp(),
      });
      if (widget.promoDocId != null) {
        // promoDocId est le chemin complet : "promo_codes/id" ou "restaurants/id/promos/id"
        final uid = FirebaseAuth.instance.currentUser?.uid;
        await FirebaseFirestore.instance.doc(widget.promoDocId!).update({
          'usedCount': FieldValue.increment(1),
          if (uid != null) 'usedBy': FieldValue.arrayUnion([uid]),
        });
      }
      await _sendNotification(
        orderId: orderId,
        title: 'Commande confirmée !',
        message: 'Votre commande chez ${widget.restaurantName} est confirmée. '
            'Un livreur va être assigné.',
      );
      if (!mounted) return;
      _goToWaiting(orderId);
    } catch (e) {
      debugPrint('[PaiementPage] Erreur onPaymentSuccess : $e');
      if (mounted) _snack('Erreur confirmation paiement : $e', Colors.red);
    }
  }

  void _goToWaiting(String orderId) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WaitingPage(
          orderId: orderId,
          totalAmount: widget.totalAmount,
          restaurantName: widget.restaurantName.isNotEmpty
              ? widget.restaurantName
              : 'Restaurant',
        ),
      ),
      (route) => route.isFirst,
    );
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Paiement',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Récapitulatif commande
        _Recap(
          address: widget.deliveryAddress,
          note: widget.deliveryNote,
          total: widget.totalAmount,
          foodAmount: _foodAmount,
          serviceFee: _serviceFee,
          deliveryFee: widget.deliveryFee,
          distanceKm: widget.distanceKm,
          restaurantName: widget.restaurantName,
          deliveryPayCash: widget.deliveryPayCash,
          paidOnline: _paidOnline,
          toPayToDriver: _toPayToDriver,
          promoDiscount: widget.promoDiscount,
          promoCode: widget.promoCode,
        ),
        const SizedBox(height: 14),

        // Détail des frais
        VentilationSummary(
          foodAmount: _foodAmount,
          deliveryFee: widget.deliveryFee,
        ),
        const SizedBox(height: 20),

        // Formulaire Mobile Money / état paiement / panier vide
        if (_paymentInProgress) ...[
          _PaymentWaitingPanel(
            phone: _apiPhone,
            statusMessage: _statusMessage,
            processing: _processing,
          ),
        ] else if (_foodAmount > 0) ...[
          _MomoForm(
            phoneCtrl: _phoneCtrl,
            selectedOperator: _selectedOperator,
            onOperatorChanged: (op) => setState(() => _selectedOperator = op),
            detectedOperator: _detectedOperator,
          ),
          const SizedBox(height: 14),
          const _FedaPayBadge(),
        ] else ...[
          _EmptyCartBanner(),
        ],
        const SizedBox(height: 24),

        // Bouton payer / vérifier (masqué si panier vide et pas de paiement en cours)
        if (_foodAmount > 0 || _paymentInProgress)
          ElevatedButton(
            onPressed: _processing ? null : _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _paymentInProgress ? Colors.black87 : Colors.orange,
              disabledBackgroundColor: (_paymentInProgress
                      ? Colors.black87
                      : Colors.orange)
                  .withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _processing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _paymentInProgress ? Icons.refresh : Icons.lock_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _paymentInProgress
                            ? 'Vérifier mon paiement'
                            : 'Commander — $_paidOnline FCFA',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
          ),
        const SizedBox(height: 12),

        // Ligne sécurité
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.security, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Paiement sécurisé — Commande confirmée après paiement',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// RECAP COMMANDE
class _Recap extends StatelessWidget {
  final String address, note, restaurantName;
  final int total,
      foodAmount,
      serviceFee,
      deliveryFee,
      paidOnline,
      toPayToDriver;
  final double distanceKm;
  final bool deliveryPayCash;
  final int promoDiscount;
  final String? promoCode;

  const _Recap({
    required this.address,
    required this.note,
    required this.total,
    required this.foodAmount,
    required this.serviceFee,
    required this.deliveryFee,
    required this.distanceKm,
    required this.restaurantName,
    required this.paidOnline,
    required this.toPayToDriver,
    this.deliveryPayCash = false,
    this.promoDiscount = 0,
    this.promoCode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Titre
        Row(children: [
          const Icon(Icons.receipt_long_outlined,
              color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              restaurantName.isNotEmpty ? restaurantName : 'Récapitulatif',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const Divider(height: 16),

        // Adresse
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined,
              color: Colors.black54, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(address,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('📝 $note',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ]),
        if (distanceKm > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.straighten, color: Colors.grey, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${distanceKm.toStringAsFixed(1)} km — Livraison : $deliveryFee FCFA',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
        const Divider(height: 16),

        // Détail prix
        _PriceLine('Nourriture', '$foodAmount FCFA', Colors.black87),
        const SizedBox(height: 4),
        _PriceLine(
            'Commission allofoods (5%)', '$serviceFee FCFA', Colors.black87),
        if (promoDiscount > 0) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Row(children: [
                const Icon(Icons.local_offer_outlined,
                    size: 13, color: Colors.black54),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Code promo${promoCode != null ? ' ($promoCode)' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            Text('− $promoDiscount FCFA',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 4),
        _PriceLine('Frais de livraison', '$deliveryFee FCFA', Colors.grey),
        const Divider(height: 16),

        // Bloc paiement en ligne
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Row(children: [
                const Icon(Icons.phone_android,
                    size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text('Payé via Mobile Money',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Text('$paidOnline FCFA',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ]),
        ),

        // Bloc paiement cash livreur (si applicable)
        if (deliveryPayCash) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.money, size: 16, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('À remettre au livreur',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ]),
                  Text('$toPayToDriver FCFA',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ]),
          ),
        ],

        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total commande',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('$total FCFA',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16)),
        ]),
      ]),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PriceLine(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      );
}

// FORMULAIRE MOBILE MONEY
class _MomoForm extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final String selectedOperator;
  final ValueChanged<String> onOperatorChanged;
  final String? detectedOperator;

  const _MomoForm({
    required this.phoneCtrl,
    required this.selectedOperator,
    required this.onOperatorChanged,
    this.detectedOperator,
  });

  static const _operators = [
    ('mtn_open', 'MTN MoMo',   Color(0xFFFFCC00)),
    ('moov',     'Moov Money', Color(0xFF0057A8)),
    ('celtis',   'Celtis',     Color(0xFF00A859)),
  ];

  static String _operatorLabel(String key) => switch (key) {
    'mtn_open' => 'MTN MoMo',
    'moov'     => 'Moov Money',
    'celtis'   => 'Celtis',
    _          => key,
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _deco(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mobile Money',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Sélecteur d'opérateur
          const Text('Opérateur',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(children: _operators.map((op) {
            final (key, label, color) = op;
            final isSelected = selectedOperator == key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onOperatorChanged(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? color : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),

          // Numéro Mobile Money
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(
              'Numéro Mobile Money',
              Icons.phone_android,
              '01 96 XX XX XX',
            ).copyWith(counterText: ''),
          ),
          // Banner de détection réseau — visible si le numéro saisi ne correspond pas à l'opérateur choisi
          if (detectedOperator != null && detectedOperator != selectedOperator)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Numéro ${_operatorLabel(detectedOperator!)} détecté',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onOperatorChanged(detectedOperator!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Basculer',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          _info(
              Icons.info_outline,
              Colors.blue,
              'Une notification USSD sera envoyée sur votre téléphone. '
              'Confirmez avec votre code secret Mobile Money.'),
        ]),
      );
}

// PANIER VIDE
class _EmptyCartBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: [
          Icon(Icons.shopping_cart_outlined,
              color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Votre panier est vide',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Retournez au menu et ajoutez des articles pour passer une commande.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

// BADGE FEDAPAY
class _FedaPayBadge extends StatelessWidget {
  const _FedaPayBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('AlloFoods',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Paiement sécurisé — PCI DSS — SSL',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          const Icon(Icons.verified_user, color: Colors.black54, size: 18),
        ]),
      );
}

class _PaymentWaitingPanel extends StatelessWidget {
  final String phone;
  final String statusMessage;
  final bool processing;

  const _PaymentWaitingPanel({
    required this.phone,
    required this.statusMessage,
    required this.processing,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.phone_android, color: Colors.black54, size: 20),
            SizedBox(width: 8),
            Text(
              'Paiement Mobile Money en cours',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14),
            ),
          ]),
          const SizedBox(height: 12),
          _InfoRow(label: 'Numéro', value: phone),
          const SizedBox(height: 12),
          if (processing)
            Row(children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage.isEmpty
                      ? 'Vérification du paiement...'
                      : statusMessage,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ])
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Colors.black54, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage.isEmpty
                        ? 'Confirmez le paiement sur votre téléphone, puis appuyez sur "Vérifier mon paiement".'
                        : statusMessage,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$label : ',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ]);
}

// HELPERS
BoxDecoration _deco(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3))
    ],
  );
}

InputDecoration _inputDeco(String label, IconData icon, String hint) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black54, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black87, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );

Widget _info(IconData icon, Color color, String text) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.black54, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 11, color: Colors.black54))),
      ]),
    );
