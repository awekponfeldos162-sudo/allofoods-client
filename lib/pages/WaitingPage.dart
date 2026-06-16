// lib/pages/WaitingPage.dart
// Flux : paid ? preparing ? ready_for_pickup ? delivering ? delivered
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/cart_model.dart';
import '../providers/active_order_notifier.dart';
import 'TrackingPage.dart';

enum _Phase {
  paid,
  preparing,
  readyForPickup,
  delivering,
  delivered,
  cancelled,
}

class WaitingPage extends StatefulWidget {
  final String orderId;
  final int totalAmount;
  final String restaurantName;

  const WaitingPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.restaurantName,
  });

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  ActiveOrderNotifier? _orderNotifier;
  _Phase _phase = _Phase.paid;
  bool _navigated = false;
  bool _cartCleared = false;
  String _cancelReason = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(_onOrderUpdate, onError: (e) {
      debugPrint('[WaitingPage] Erreur stream : $e');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _orderNotifier = context.read<ActiveOrderNotifier>();
      _orderNotifier?.setOrderPageOpen(true);
    });
  }

  @override
  void dispose() {
    _orderNotifier?.setOrderPageOpen(false);
    _orderSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onOrderUpdate(DocumentSnapshot snap) {
    if (!snap.exists || _navigated || !mounted) return;
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final status = data['status'] as String? ?? '';

    switch (status) {
      case 'paid':
      case 'awaiting_payment':
        // Vider le panier une seule fois à la confirmation de paiement
        if (!_cartCleared && mounted) {
          _cartCleared = true;
          try {
            context.read<CartProvider>().clearAfterOrder();
          } catch (_) {}
        }
        _setPhase(_Phase.paid);
        break;
      case 'preparing':
        _setPhase(_Phase.preparing);
        break;
      case 'ready_for_pickup':
        _setPhase(_Phase.readyForPickup);
        break;
      case 'delivering':
      case 'en_route':
        _goToTracking();
        break;
      case 'delivered':
        _setPhase(_Phase.delivered);
        break;
      case 'cancelled':
      case 'cancelled_by_restaurant':
        final reason = data['cancellationReason'] as String? ?? '';
        if (mounted) {
          setState(() {
            _phase = _Phase.cancelled;
            _cancelReason = reason;
          });
        }
        break;
    }
  }

  void _setPhase(_Phase p) {
    if (mounted && _phase != p) setState(() => _phase = p);
  }

  void _goToTracking() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TrackingPage(
          orderId: widget.orderId,
          orderAmount: widget.totalAmount,
          restaurantName: widget.restaurantName,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<bool> _showExitDialog() async {
    if (_phase == _Phase.cancelled || _phase == _Phase.delivered) return true;
    final t = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.exitDialogTitle),
        content: Text(t.exitDialogMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.stay)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.leave, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _showExitDialog();
        if (exit && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_appBarTitle(AppLocalizations.of(context)),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final exit = await _showExitDialog();
                if (exit && mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(),
        ),
      ),
    );
  }

  String _appBarTitle(AppLocalizations t) {
    switch (_phase) {
      case _Phase.paid:
        return t.paymentConfirmed;
      case _Phase.preparing:
        return t.inPreparation;
      case _Phase.readyForPickup:
        return t.orderReady;
      case _Phase.delivering:
        return t.orderOnTheWay;
      case _Phase.delivered:
        return t.orderDelivered;
      case _Phase.cancelled:
        return t.orderCancelled;
    }
  }

  Widget _buildBody() {
    final t = AppLocalizations.of(context);
    final shortId = widget.orderId.length >= 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

    switch (_phase) {
      case _Phase.paid:
        return Column(
          key: const ValueKey('paid'),
          children: [
            Expanded(
              child: _StatusView(
                icon: Icons.check_circle,
                color: Colors.green,
                title: t.paymentReceived,
                subtitle: t.restaurantWillPrepare,
                pulse: _pulse,
                showLoader: true,
                loaderLabel: t.awaitingPreparation,
                orderId: shortId,
                showEstimatedTime: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: _CancelOrderButton(orderId: widget.orderId),
            ),
          ],
        );
      case _Phase.preparing:
        return _StatusView(
          key: const ValueKey('preparing'),
          icon: Icons.restaurant,
          color: Colors.orange,
          title: t.orderInPreparation,
          subtitle: t.restaurantPreparingWithCare,
          pulse: _pulse,
          showLoader: true,
          loaderLabel: t.preparationInProgress,
          orderId: shortId,
        );
      case _Phase.readyForPickup:
        return _StatusView(
          key: const ValueKey('ready_pickup'),
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
          title: t.yourOrderIsReady,
          subtitle: t.driverTakingCharge,
          pulse: _pulse,
          showLoader: true,
          loaderLabel: t.searchingForDriver,
          orderId: shortId,
        );
      case _Phase.delivering:
        return _StatusView(
          key: const ValueKey('delivering'),
          icon: Icons.delivery_dining,
          color: Colors.indigo,
          title: t.orderOnTheWay,
          subtitle: t.driverHeadingToYou,
          pulse: _pulse,
          showLoader: true,
          loaderLabel: t.redirectingToTracking,
          orderId: shortId,
        );
      case _Phase.delivered:
        return _DeliveredView(
          key: const ValueKey('delivered'),
          restaurantName: widget.restaurantName,
          onBack: () => Navigator.of(context).pop(),
        );
      case _Phase.cancelled:
        return _CancelledView(
          key: const ValueKey('cancelled'),
          restaurantName: widget.restaurantName,
          reason: _cancelReason,
          onBack: () => Navigator.of(context).pop(),
        );
    }
  }
}

// VUE GéNéRIQUE é statut intermédiaire avec loader amélioré
class _StatusView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, loaderLabel;
  final Animation<double> pulse;
  final bool showLoader;
  final String? orderId;
  final bool showEstimatedTime;

  const _StatusView({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.pulse,
    this.showLoader = false,
    this.loaderLabel = '',
    this.orderId,
    this.showEstimatedTime = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: pulse,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5)),
              child: Icon(icon, color: color, size: 48),
            ),
          ),
          const SizedBox(height: 28),
          Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center),

          // Numéro de commande
          if (orderId != null) ...[
            const SizedBox(height: 20),
            Text('#$orderId',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    color: Colors.grey,
                    letterSpacing: 1.5)),
          ],

          // Badge temps estimé (affiché uniquement à la phase "paid")
          if (showEstimatedTime) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined,
                    size: 15, color: Colors.orange),
                const SizedBox(width: 6),
                Text(AppLocalizations.of(context).estimatedDelivery,
                    style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
              ]),
            ),
          ],

          // Loader : LinearProgressIndicator + AnimatedDots
          if (showLoader) ...[
            const SizedBox(height: 36),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 16),
            _AnimatedDots(color: color),
            const SizedBox(height: 8),
            Text(loaderLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ]),
      ),
    );
  }
}

// WIDGET é 3 points animés (loader élégant)
class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({this.color = Colors.orange});
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            double t = (_ctrl.value - i * 0.33) % 1.0;
            if (t < 0) t += 1.0;
            final opacity = (t < 0.5 ? t * 2 : (1.0 - t) * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// VUE : LIVRAISON TERMINéE
class _DeliveredView extends StatelessWidget {
  final String restaurantName;
  final VoidCallback onBack;
  const _DeliveredView(
      {super.key, required this.restaurantName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle,
                color: Colors.green.shade600, size: 64),
          ),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).deliveryDone,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).thankyouOrdered(restaurantName),
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade600, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(AppLocalizations.of(context).returnHome,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// VUE : COMMANDE ANNULéE
class _CancelledView extends StatelessWidget {
  final String restaurantName, reason;
  final VoidCallback onBack;
  const _CancelledView({
    super.key,
    required this.restaurantName,
    required this.reason,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.cancel_outlined,
                color: Colors.red.shade400, size: 56),
          ),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).orderCancelled,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).restaurantRefused(restaurantName),
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${AppLocalizations.of(context).reason} $reason',
                style: const TextStyle(fontSize: 12, color: Colors.red),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              AppLocalizations.of(context).refundInfo,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(AppLocalizations.of(context).returnHome,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// BOUTON ANNULER LA COMMANDE
class _CancelOrderButton extends StatefulWidget {
  final String orderId;
  const _CancelOrderButton({required this.orderId});
  @override
  State<_CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends State<_CancelOrderButton> {
  bool _loading = false;

  Future<void> _cancel() async {
    final t = AppLocalizations.of(context);
    final reasons = [
      t.cancelReasonChangedMind,
      t.cancelReasonTooLong,
      t.cancelReasonOrderError,
      t.cancelReasonOther,
    ];
    String? selected = reasons[0];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t.cancelOrderDialog,
              style: const TextStyle(fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              t.cancelOrderWarning,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t.reason,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (v) => setS(() => selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: reasons.map((r) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  value: r,
                  activeColor: Colors.orange,
                )).toList(),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.keepMyOrder),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.cancelOrderBtn),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'cancelled',
        'cancellationReason': selected ?? 'Annulée par le client',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _loading ? null : _cancel,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: Colors.red, strokeWidth: 2))
            : const Icon(Icons.cancel_outlined, size: 16),
        label: Builder(builder: (ctx) {
          final t = AppLocalizations.of(ctx);
          return Text(_loading ? t.cancellingOrder : t.cancelOrderBtn);
        }),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.shade300),
          minimumSize: const Size(double.infinity, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
