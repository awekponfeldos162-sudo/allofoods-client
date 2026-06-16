// lib/pages/RecapPage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/delivery_model.dart';
import '../services/payment_service.dart';
import '../l10n/app_localizations.dart';
import 'PaiementPage.dart';

class RecapPage extends StatefulWidget {
  final int deliveryFee;
  final double distanceKm;
  final String restaurantName;
  final String restaurantId;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String deliveryNote;
  final DeliveryLocation? deliveryLocation;

  const RecapPage({
    super.key,
    required this.deliveryFee,
    required this.distanceKm,
    required this.restaurantName,
    required this.restaurantId,
    required this.deliveryAddress,
    this.deliveryLat = 6.3654,
    this.deliveryLng = 2.4183,
    this.deliveryNote = '',
    this.deliveryLocation,
  });

  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  bool _deliveryCash = false;

  final _promoCtrl = TextEditingController();
  String? _promoCode;
  String? _promoDocId;
  int _promoDiscount = 0;
  bool _promoLoading = false;
  String? _promoError;

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _promoLoading = true; _promoError = null; });

    final cart = context.read<CartProvider>();

    try {
      QueryDocumentSnapshot<Map<String, dynamic>>? matchedDoc;
      String? docPath;

      final adminSnap = await FirebaseFirestore.instance
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        matchedDoc = adminSnap.docs.first;
        docPath = 'promo_codes/${matchedDoc.id}';
      } else {
        String restId = cart.restaurantId;
        if (restId.isEmpty && cart.items.isNotEmpty) {
          restId = cart.items.first.restaurantId;
        }
        if (restId.isNotEmpty) {
          final restSnap = await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restId)
              .collection('promos')
              .where('code', isEqualTo: code)
              .limit(1)
              .get();
          if (restSnap.docs.isNotEmpty) {
            matchedDoc = restSnap.docs.first;
            docPath = 'restaurants/$restId/promos/${matchedDoc.id}';
          }
        }
      }

      if (matchedDoc == null || docPath == null) {
        setState(() { _promoError = AppLocalizations.of(context).invalidPromoCode; _promoLoading = false; });
        return;
      }

      final data = matchedDoc.data();

      if (data['isActive'] != true) {
        setState(() { _promoError = AppLocalizations.of(context).promoCodeInactive; _promoLoading = false; });
        return;
      }

      final expiresAt = data['expiresAt'];
      if (expiresAt != null) {
        final expiry = (expiresAt as Timestamp).toDate();
        if (DateTime.now().isAfter(expiry)) {
          setState(() { _promoError = AppLocalizations.of(context).promoCodeExpired; _promoLoading = false; });
          return;
        }
      }

      final maxUses = (data['maxUses'] as num?)?.toInt();
      final usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;
      if (maxUses != null && usedCount >= maxUses) {
        setState(() { _promoError = AppLocalizations.of(context).promoCodeLimitReached; _promoLoading = false; });
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final usedBy = (data['usedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (uid != null && usedBy.contains(uid)) {
        setState(() { _promoError = AppLocalizations.of(context).promoCodeAlreadyUsed; _promoLoading = false; });
        return;
      }

      final minOrder = (data['minOrderAmount'] as num?)?.toInt() ?? 0;
      if (cart.totalPrice < minOrder) {
        setState(() { _promoError = AppLocalizations.of(context).minOrderRequired(minOrder); _promoLoading = false; });
        return;
      }

      final discountType = (data['discountType'] as String? ?? 'fixed').toLowerCase();
      final discountValue = (data['discountValue'] as num?)?.toInt() ?? 0;
      int discount;
      if (discountType == 'percentage' || discountType == 'pourcentage') {
        discount = (cart.totalPrice * discountValue / 100).round();
      } else {
        discount = discountValue;
      }
      discount = discount.clamp(0, cart.totalPrice);

      setState(() {
        _promoCode = code;
        _promoDocId = docPath;
        _promoDiscount = discount;
        _promoLoading = false;
        _promoError = null;
        _promoCtrl.clear();
      });
    } catch (e) {
      final t = AppLocalizations.of(context);
      String msg = t.promoCheckError;
      final err = e.toString().toLowerCase();
      if (err.contains('permission') || err.contains('denied') || err.contains('insufficient')) {
        msg = t.firestoreAccessDenied;
      } else if (err.contains('network') || err.contains('unavailable') || err.contains('offline')) {
        msg = t.noConnection;
      }
      setState(() { _promoError = msg; _promoLoading = false; });
    }
  }

  void _removePromo() {
    setState(() {
      _promoCode = null;
      _promoDocId = null;
      _promoDiscount = 0;
      _promoError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final foodSubtotal = cart.totalPrice;
    final serviceFee = PaymentService.computeServiceFee(foodSubtotal);
    final totalBase = (foodSubtotal + serviceFee - _promoDiscount).clamp(0, 999999999).toInt();
    final fedaPayAmount =
        _deliveryCash ? totalBase : totalBase + widget.deliveryFee;
    final cashToDriver = _deliveryCash ? widget.deliveryFee : 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(t.recap,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _SectionCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(
              icon: Icons.shopping_bag_outlined,
              title: t.yourItems,
              trailing: t.itemCount(cart.itemCount),
            ),
            const SizedBox(height: 12),
            ...cart.items.map((item) => _ItemRow(item: item)),
          ]),
        ),
        const SizedBox(height: 14),

        _SectionCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(
                icon: Icons.receipt_long_outlined, title: t.amountDetail),
            const SizedBox(height: 12),
            _PriceLine(t.subtotalDishes, foodSubtotal, Colors.black87),
            const SizedBox(height: 6),
            _PriceLine(t.serviceFeeFive, serviceFee, Colors.black87),
            const SizedBox(height: 10),
            if (_promoCode == null) ...[
              _PromoInputRow(
                controller: _promoCtrl,
                loading: _promoLoading,
                onApply: _applyPromoCode,
              ),
              if (_promoError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_promoError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
            ] else
              _PromoAppliedRow(
                code: _promoCode!,
                discount: _promoDiscount,
                onRemove: _removePromo,
              ),
            const SizedBox(height: 10),
            _PriceLine(
              t.deliveryFeeKm(widget.distanceKm),
              widget.deliveryFee,
              Colors.black87,
              suffix: _deliveryCash ? ' (cash)' : null,
            ),
            const Divider(height: 20),
            Row(children: [
              Flexible(
                child: Text(t.orderTotal,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${totalBase + widget.deliveryFee} FCFA',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 16)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        _SectionCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(
              icon: Icons.local_shipping_outlined,
              title: t.deliveryFee,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _DeliveryChip(
                  icon: Icons.phone_android,
                  label: t.driverOnline,
                  sublabel: t.viaAllofoods,
                  selected: !_deliveryCash,
                  color: Colors.blue,
                  onTap: () => setState(() => _deliveryCash = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DeliveryChip(
                  icon: Icons.money,
                  label: t.cash,
                  sublabel: t.toDriver,
                  selected: _deliveryCash,
                  color: Colors.green,
                  onTap: () => setState(() => _deliveryCash = true),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        if (_deliveryCash) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.black54, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      TextSpan(text: t.cashDeliveryNoticePrefix),
                      TextSpan(
                          text: '${widget.deliveryFee} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: t.cashDeliveryNoticeSuffix),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.lock_outline, color: Colors.black54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.debitedViaApp,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$fedaPayAmount FCFA',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
            ]),
            if (cashToDriver > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.money, color: Colors.black54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.toGiveToDriver,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$cashToDriver FCFA',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: () => _proceed(context, cart, totalBase),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.payAmount(fedaPayAmount),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.security, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(t.securedPayment,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _proceed(BuildContext context, CartProvider cart, int totalBase) {
    // PaiementPage attend toujours le total complet (food+5%+livraison)
    // deliveryPayCash détermine ce qui est payé en ligne vs en cash au livreur
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaiementPage(
          totalAmount: totalBase + widget.deliveryFee,
          deliveryAddress: widget.deliveryAddress,
          deliveryFee: widget.deliveryFee,
          distanceKm: widget.distanceKm,
          restaurantName: widget.restaurantName.isNotEmpty
              ? widget.restaurantName
              : cart.restaurantName,
          restaurantId: widget.restaurantId.isNotEmpty
              ? widget.restaurantId
              : cart.restaurantId,
          deliveryLat: widget.deliveryLat,
          deliveryLng: widget.deliveryLng,
          deliveryNote: widget.deliveryNote,
          deliveryPayCash: _deliveryCash,
          deliveryLocation: widget.deliveryLocation,
          promoDiscount: _promoDiscount,
          promoCode: _promoCode,
          promoDocId: _promoDocId,
        ),
      ),
    );
  }
}

// WIDGETS INTERNES

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Colors.black54, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(trailing!,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
      ]);
}

class _ItemRow extends StatelessWidget {
  final CartItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${item.quantity}',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${item.totalPrice} FCFA',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      );
}

class _PriceLine extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String? suffix;
  const _PriceLine(this.label, this.value, this.color, {this.suffix});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$value FCFA${suffix ?? ''}',
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ),
        ],
      );
}

class _DeliveryChip extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _DeliveryChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.black87 : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                size: 20,
                color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.grey.shade700)),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white70
                          : Colors.grey.shade500)),
            ]),
          ]),
        ),
      );
}

class _PromoInputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onApply;
  const _PromoInputRow(
      {required this.controller, required this.loading, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 13, letterSpacing: 1.2),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).promoCodeLabel,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
            prefixIcon: const Icon(Icons.local_offer_outlined,
                size: 18, color: Colors.orange),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.orange.withValues(alpha: 0.3), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange, width: 1.5),
            ),
          ),
          onSubmitted: (_) => onApply(),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: loading ? null : onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(AppLocalizations.of(context).applyCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}

class _PromoAppliedRow extends StatelessWidget {
  final String code;
  final int discount;
  final VoidCallback onRemove;
  const _PromoAppliedRow(
      {required this.code, required this.discount, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.black54, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(code,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            Text(AppLocalizations.of(context).promoDiscountApplied(discount),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 16, color: Colors.black54),
        ),
      ]),
    );
  }
}
