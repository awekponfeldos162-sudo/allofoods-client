// lib/pages/OrderHistoryPage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cart_model.dart';
import '../models/review_model.dart';
import '../services/receipt_service.dart';
import '../l10n/app_localizations.dart';
import 'PaiementPage.dart';

int _n(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

// Recharge le panier et relance le paiement depuis une commande échouée.
// Affiche un dialog si le panier actuel n'est pas vide.
void _retryOrder(BuildContext context, Map<String, dynamic> data) {
  final cart = context.read<CartProvider>();

  void doRetry() {
    final restaurantId = data['restaurantId'] as String? ?? '';
    final restaurantName = data['restaurantName'] as String? ?? '';

    final rawItems = (data['items'] as List?)?.cast<Map>() ?? [];
    final items = rawItems
        .map((item) => CartItem(
              name: item['name'] as String? ?? '',
              price: item['price']?.toString() ?? '0',
              img: item['img'] as String? ?? '',
              restaurantName:
                  (item['restaurantName'] as String?)?.isNotEmpty == true
                      ? item['restaurantName'] as String
                      : restaurantName,
              restaurantId: restaurantId,
              quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            ))
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).cannotRetry),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    cart.loadCart(
      items: items,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaiementPage(
        totalAmount: _n(data['totalAmount']),
        deliveryFee: _n(data['deliveryFee']),
        deliveryAddress: data['deliveryAddress'] as String? ?? '',
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
        deliveryLat: (data['clientLat'] as num?)?.toDouble() ?? 6.3654,
        deliveryLng: (data['clientLng'] as num?)?.toDouble() ?? 2.4183,
        deliveryNote: data['deliveryNote'] as String? ?? '',
        deliveryPayCash:
            (data['delivery_payment_method'] as String?) == 'cash',
        promoDiscount: _n(data['promoDiscount']),
        promoCode: data['promoCode'] as String?,
        promoDocId: data['promoDocId'] as String?,
      ),
    ));
  }

  if (cart.items.isNotEmpty) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.replaceCartTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(t.replaceCartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(t.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              doRetry();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text(t.continueBtn),
          ),
        ],
      ),
    );
  } else {
    doRetry();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════════

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).myOrders,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).deliveredTab),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.replay_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).failedTab),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: uid == null
            ? Center(
                child: Text(AppLocalizations.of(context).loginToSeeOrders))
            : TabBarView(children: [
                _DeliveredTab(uid: uid),
                _CancelledTab(uid: uid),
              ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 1 — LIVRÉES
// ════════════════════════════════════════════════════════════════════════════

class _DeliveredTab extends StatelessWidget {
  final String uid;
  const _DeliveredTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientUid', isEqualTo: uid)
          .where('status', isEqualTo: 'delivered')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState();

        final grouped = <String, List<QueryDocumentSnapshot>>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['createdAt'] as Timestamp?;
          final date = ts?.toDate() ?? DateTime.now();
          final key = DateFormat('MMMM yyyy', 'fr_FR').format(date);
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            _SummaryBar(total: docs.length),
            const SizedBox(height: 16),
            ...grouped.entries.map((e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthLabel(e.key),
                    ...e.value.map((doc) => _OrderCard(
                          doc: doc,
                          onTap: () => _showDetail(context, doc),
                        )),
                    const SizedBox(height: 8),
                  ],
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showDetail(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      builder: (_) => _OrderDetailSheet(data: data, orderId: doc.id),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 2 — ÉCHOUÉES / ANNULÉES
// ════════════════════════════════════════════════════════════════════════════

class _CancelledTab extends StatelessWidget {
  final String uid;
  const _CancelledTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientUid', isEqualTo: uid)
          .where('status', isEqualTo: 'cancelled')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyCancelledState();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            _CancelledSummaryBar(total: docs.length),
            const SizedBox(height: 16),
            ...docs.map((doc) => _CancelledOrderCard(
                  doc: doc,
                  onTap: () => _showCancelledDetail(context, doc),
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showCancelledDetail(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      builder: (sheetCtx) => _CancelledOrderDetailSheet(
        data: data,
        orderId: doc.id,
        onRetry: () {
          Navigator.pop(sheetCtx);
          _retryOrder(context, data);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS — LIVRÉES
// ════════════════════════════════════════════════════════════════════════════

class _SummaryBar extends StatelessWidget {
  final int total;
  const _SummaryBar({required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                AppLocalizations.of(context).deliveriesCount(total),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(AppLocalizations.of(context).deliveredOrdersOnly,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
      );
}

class _MonthLabel extends StatelessWidget {
  final String label;
  const _MonthLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2)),
      );
}

class _OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;
  const _OrderCard({required this.doc, required this.onTap});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final ts = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.restaurant, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['restaurantName'] as String? ?? 'Restaurant',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_formatDate(ts),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 13),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context).deliveredBadge,
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (items.isNotEmpty)
            Text(
                items
                        .take(3)
                        .map((i) => '${i['quantity']}× ${i['name']}')
                        .join(' • ') +
                    (items.length > 3
                        ? ' +${items.length - 3} autre(s)'
                        : ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          _PaymentBreakdown(data: data),
        ]),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  const _OrderDetailSheet({required this.data, required this.orderId});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _n(data['totalAmount']);
    final status = data['status'] as String? ?? 'pending';
    final payment = data['paymentMethod'] as String? ?? '—';
    final txId = data['transactionId'] as String? ?? '—';

    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.max, children: [
        Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['restaurantName'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('Commande #${orderId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
            ),
            _StatusBadge(status),
          ]),
        ),
        const Divider(height: 24),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.of(context).orderedItems,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text('${item['quantity']}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 13))),
                      Text('${_n(item['price']) * _n(item['quantity'])} FCFA',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  )),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              _PaymentBreakdown(data: data, showFull: true),
              const Divider(height: 16),
              _DetailRow(AppLocalizations.of(context).totalPaidApp, '$total FCFA',
                  bold: true, color: Colors.orange),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).detailsLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _DetailRow(AppLocalizations.of(context).address, data['deliveryAddress'] as String? ?? '—'),
              _DetailRow(AppLocalizations.of(context).paymentMethodLabel, _paymentLabel(context, payment)),
              if (txId != '—' && txId != 'CASH')
                _DetailRow(AppLocalizations.of(context).transactionLabel, txId),
              _DetailRow(
                  AppLocalizations.of(context).dateLabel, _formatDate(data['createdAt'] as Timestamp?)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _ReceiptActions(data: data, orderId: orderId),
        ),
        if ((data['restaurantId'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _ReviewButton(
              restaurantId: data['restaurantId'] as String,
              restaurantName:
                  data['restaurantName'] as String? ?? 'Restaurant',
              orderId: orderId,
            ),
          ),
      ]),
    );
  }

  String _paymentLabel(BuildContext context, String p) {
    final t = AppLocalizations.of(context);
    switch (p) {
      case 'mobile_money':
      case 'mobile_money_fedapay':
        return 'Mobile Money';
      case 'card':
        return t.cardPayment;
      case 'cash':
        return t.cashDelivery;
      default:
        return p;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS — ÉCHOUÉES
// ════════════════════════════════════════════════════════════════════════════

class _CancelledSummaryBar extends StatelessWidget {
  final int total;
  const _CancelledSummaryBar({required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.replay_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppLocalizations.of(context).failedOrdersCount(total),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(AppLocalizations.of(context).tapToRetry,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class _CancelledOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;
  const _CancelledOrderCard({required this.doc, required this.onTap});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final ts = data['createdAt'] as Timestamp?;
    final totalAmount = _n(data['totalAmount']);
    final paymentStatus = data['paymentStatus'] as String? ?? '';
    final t = AppLocalizations.of(context);
    final failedLabel = paymentStatus == 'PAYMENT_FAILED'
        ? t.failedPaymentLabel
        : t.cancelled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.restaurant, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['restaurantName'] as String? ?? 'Restaurant',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_formatDate(ts),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 13),
                const SizedBox(width: 4),
                Text(failedLabel,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (items.isNotEmpty)
            Text(
              items
                      .take(3)
                      .map((i) => '${i['quantity']}× ${i['name']}')
                      .join(' • ') +
                  (items.length > 3
                      ? ' +${items.length - 3} autre(s)'
                      : ''),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$totalAmount FCFA',
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.replay, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).retryLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _CancelledOrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final VoidCallback onRetry;

  const _CancelledOrderDetailSheet({
    required this.data,
    required this.orderId,
    required this.onRetry,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _n(data['totalAmount']);
    final deliveryFee = _n(data['deliveryFee']);
    final paymentStatus = data['paymentStatus'] as String? ?? '';
    final t2 = AppLocalizations.of(context);
    final failReason = paymentStatus == 'PAYMENT_FAILED'
        ? t2.failedPaymentReason
        : t2.cancelledBeforePayment;

    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.max, children: [
        Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['restaurantName'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('Commande #${orderId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3))),
              child: Text(AppLocalizations.of(context).failedOrderBadge,
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ]),
        ),

        // Raison de l'échec
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(failReason,
                    style:
                        TextStyle(fontSize: 12, color: Colors.red.shade700)),
              ),
            ]),
          ),
        ),

        const Divider(height: 24),

        // Contenu scrollable
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.of(context).itemsLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text('${item['quantity']}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 13))),
                      Text(
                          '${_n(item['price']) * _n(item['quantity'])} FCFA',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  )),
              const SizedBox(height: 14),
              const Divider(),
              _DetailRow(AppLocalizations.of(context).subtotalDishes,
                  '${total - deliveryFee} FCFA'),
              _DetailRow(AppLocalizations.of(context).deliveryLabel, '$deliveryFee FCFA'),
              _DetailRow(AppLocalizations.of(context).total, '$total FCFA',
                  bold: true, color: Colors.orange),
              const SizedBox(height: 8),
              _DetailRow(AppLocalizations.of(context).address,
                  data['deliveryAddress'] as String? ?? '—'),
              _DetailRow(AppLocalizations.of(context).dateLabel,
                  _formatDate(data['createdAt'] as Timestamp?)),
              const SizedBox(height: 8),
            ]),
          ),
        ),

        // Bouton relancer
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay, size: 20),
            label: Text(AppLocalizations.of(context).retryPayment,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _EmptyCancelledState extends StatelessWidget {
  const _EmptyCancelledState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.shade400),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context).noFailedOrders,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).allPaymentsSuccess,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13, height: 1.5)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS PARTAGÉS
// ════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _DetailRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: color ?? Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'cancelled_by_restaurant':
        return Colors.red;
      case 'en_route':
        return Colors.indigo;
      case 'delivering':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _label(BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (status) {
      case 'delivered':
        return t.statusDeliveredBadge;
      case 'cancelled':
      case 'cancelled_by_restaurant':
        return t.cancelled;
      case 'en_route':
        return t.statusEnRouteBadge;
      case 'delivering':
        return t.statusConfirmedBadge;  // livreur accepté → "Confirmée"
      default:
        return t.statusPendingBadge;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withValues(alpha: 0.3))),
        child: Text(_label(context),
            style: TextStyle(
                color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _PaymentBreakdown extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showFull;
  const _PaymentBreakdown({required this.data, this.showFull = false});

  @override
  Widget build(BuildContext context) {
    final foodAmount = _n(data['foodAmount']);
    final serviceFee = _n(data['serviceFee']);
    final deliveryFee = _n(data['deliveryFee']);
    final totalAmount = _n(data['totalAmount']);
    final delivPayCash =
        (data['delivery_payment_method'] as String?) == 'cash';

    if (showFull) {
      final t = AppLocalizations.of(context);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DetailRow(t.dishesPriceLabel, '$foodAmount FCFA'),
        _DetailRow(t.commissionLabel, '$serviceFee FCFA'),
        _DetailRow(
          delivPayCash ? t.deliveryCash : t.deliveryApp,
          '$deliveryFee FCFA',
          color: delivPayCash ? Colors.green : Colors.blue,
        ),
      ]);
    }

    final appAmount =
        delivPayCash ? totalAmount - deliveryFee : totalAmount;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.phone_android, size: 12, color: Colors.blue.shade600),
            const SizedBox(width: 4),
            Text('App : $appAmount FCFA',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600)),
          ]),
          if (delivPayCash) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.money, size: 12, color: Colors.green.shade600),
              const SizedBox(width: 4),
              Text('Cash livreur : $deliveryFee FCFA',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
        ]),
      ),
      Text('$totalAmount FCFA',
          style: const TextStyle(
              color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AVIS
// ════════════════════════════════════════════════════════════════════════════

class _ReviewButton extends StatefulWidget {
  final String restaurantId, restaurantName, orderId;
  const _ReviewButton({
    required this.restaurantId,
    required this.restaurantName,
    required this.orderId,
  });
  @override
  State<_ReviewButton> createState() => _ReviewButtonState();
}

class _ReviewButtonState extends State<_ReviewButton> {
  bool? _alreadyReviewed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final done =
        await ReviewService.hasAlreadyReviewed(widget.restaurantId, uid);
    if (mounted) setState(() => _alreadyReviewed = done);
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReviewSheet(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        orderId: widget.orderId,
        onSubmitted: () => setState(() => _alreadyReviewed = true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyReviewed == null) return const SizedBox.shrink();
    if (_alreadyReviewed == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Text('Avis déjà soumis — merci !',
              style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
        ]),
      );
    }
    return OutlinedButton.icon(
      onPressed: _openSheet,
      icon: const Icon(Icons.star_border_outlined, size: 18),
      label: const Text('Laisser un avis'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.orange,
        side: BorderSide(color: Colors.orange.shade300),
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final String restaurantId, restaurantName, orderId;
  final VoidCallback onSubmitted;
  const _ReviewSheet({
    required this.restaurantId,
    required this.restaurantName,
    required this.orderId,
    required this.onSubmitted,
  });
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  double _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = userDoc.data()?['name'] as String? ?? 'Client';
      await ReviewService.addReview(
        widget.restaurantId,
        ReviewModel(
          id: '',
          clientUid: uid,
          clientName: name,
          rating: _rating,
          comment: _commentCtrl.text.trim(),
          orderId: widget.orderId,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Merci pour votre avis !'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Évaluer ${widget.restaurantName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star.toDouble()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _rating >= 5
                ? 'Excellent !'
                : _rating >= 4
                    ? 'Très bien'
                    : _rating >= 3
                        ? 'Bien'
                        : _rating >= 2
                            ? 'Moyen'
                            : 'Décevant',
            style: TextStyle(
                color: Colors.orange.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Partagez votre expérience (optionnel)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.orange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Envoi en cours...' : 'Publier mon avis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// DOCUMENTS (reçu, ticket, impression)
// ════════════════════════════════════════════════════════════════════════════

class _ReceiptActions extends StatefulWidget {
  final Map<String, dynamic> data;
  final String orderId;
  const _ReceiptActions({required this.data, required this.orderId});

  @override
  State<_ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends State<_ReceiptActions> {
  bool _loadingReceipt = false;
  bool _loadingTicket = false;
  bool _loadingPrint = false;

  Future<void> _run(
    Future<void> Function() action,
    void Function(bool) setLoading,
  ) async {
    setLoading(true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erreur lors de la génération du document'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Reçu PDF',
              color: Colors.blue,
              loading: _loadingReceipt,
              onTap: _loadingReceipt
                  ? null
                  : () => _run(
                        () => ReceiptService.shareClientReceipt(
                            widget.orderId, widget.data),
                        (v) => setState(() => _loadingReceipt = v),
                      ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.receipt_long_outlined,
              label: 'Ticket',
              color: Colors.purple,
              loading: _loadingTicket,
              onTap: _loadingTicket
                  ? null
                  : () => _run(
                        () => ReceiptService.shareRestaurantTicket(
                            widget.orderId, widget.data),
                        (v) => setState(() => _loadingTicket = v),
                      ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              icon: Icons.print_outlined,
              label: 'Imprimer',
              color: Colors.teal,
              loading: _loadingPrint,
              onTap: _loadingPrint
                  ? null
                  : () => _run(
                        () => ReceiptService.printRestaurantTicket(
                            widget.orderId, widget.data),
                        (v) => setState(() => _loadingPrint = v),
                      ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ÉTATS VIDES
// ════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.orange.shade300),
          ),
          const SizedBox(height: 20),
          const Text('Aucune commande',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Vos commandes livrées apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Commander maintenant'),
          ),
        ]),
      );
}
