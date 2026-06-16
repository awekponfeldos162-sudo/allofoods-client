// lib/pages/PanierPage.dart
// ? 3 onglets : Panier | Favoris | Historique

import 'package:flutter/material.dart';
import 'package:flutter_application_2/favorites_provider.dart';
import 'package:flutter_application_2/services/payment_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/cart_model.dart';
import '../models/restaurant_model.dart';
import '../models/review_model.dart';
import '../services/receipt_service.dart';
import 'adressePage.dart';
import 'PaiementPage.dart';
import 'RestaurantProfilPage.dart';
import '../l10n/app_localizations.dart';

class PanierPage extends StatefulWidget {
  const PanierPage({super.key});
  @override
  State<PanierPage> createState() => _PanierPageState();
}

class _PanierPageState extends State<PanierPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final barColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    // true = page pushée (a un back) ; false = tab principal dans le PageView
    final isPushed = ModalRoute.of(context)?.canPop ?? false;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        // Seulement quand pushée : le Scaffold du tab gére déjà la status bar
        top: isPushed,
        bottom: false,
        child: Column(children: [
          // Header retour é visible seulement quand pushée
          if (isPushed)
            Container(
              color: barColor,
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Retour',
                ),
                const SizedBox(width: 2),
                Text(
                  AppLocalizations.of(context).myCart,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ]),
            ),

          // TabBar
          Container(
            color: barColor,
            child: TabBar(
              controller: _tabs,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shopping_cart_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(AppLocalizations.of(context).cart),
                      if (cart.itemCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            cart.itemCount > 99 ? '99+' : '${cart.itemCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
                Tab(
                    icon: const Icon(Icons.favorite_outline, size: 16),
                    text: AppLocalizations.of(context).favorites),
                Tab(
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    text: AppLocalizations.of(context).history),
              ],
            ),
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const _CartTab(),
                const _FavoritesTab(),
                const _HistoryTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ONGLET 1 é PANIER
class _CartTab extends StatelessWidget {
  const _CartTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, __) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: cart.items.isEmpty
              ? const _EmptyCart(key: ValueKey('empty'))
              : Column(key: const ValueKey('full'), children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                      itemCount: cart.items.length,
                      itemBuilder: (ctx, i) =>
                          _CartItemCard(index: i, item: cart.items[i]),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: _Summary(cart: cart),
                  ),
                ]),
        );
      },
    );
  }
}

// ONGLET 2 é FAVORIS
class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final ids = favs.favRestaurants.toList();

        if (ids.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.favorite_outline,
                    size: 56, color: Colors.red.shade300),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context).noFavorites,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).addFavoritesHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ]),
          );
        }

        return FutureBuilder<List<Restaurant>>(
          future: _loadFavRestaurants(ids),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.orange));
            }
            final restaurants = snap.data ?? [];
            if (restaurants.isEmpty) {
              return Center(
                child: Text(AppLocalizations.of(context).restaurantsNotFound,
                    style: TextStyle(color: Colors.grey.shade500)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: restaurants.length,
              itemBuilder: (_, i) => _FavCard(
                restaurant: restaurants[i],
                onRemove: () => favs.toggleRestaurant(restaurants[i].id),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Restaurant>> _loadFavRestaurants(List<String> ids) async {
    final list = <Restaurant>[];
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(id)
            .get();
        if (doc.exists) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          list.add(Restaurant.fromJson(data));
        }
      } catch (_) {}
    }
    return list;
  }
}

class _FavCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onRemove;
  const _FavCard({required this.restaurant, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RestaurantProfilePage(restaurant: restaurant))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: _Img(img: restaurant.coverImg, width: 90, height: 90),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(restaurant.style,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star, size: 13, color: Colors.amber),
                      Text(' ${restaurant.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 10),
                      const Icon(Icons.timer, size: 13, color: Colors.grey),
                      Text(' ${restaurant.deliveryTime} min',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                  ]),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.favorite, color: Colors.red.shade400, size: 22),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers locaux historique ────────────────────────────────────────────────
int _numH(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
String _strH(dynamic v) => v?.toString() ?? '';

// Recharge le panier et relance le paiement depuis une commande échouée
void _retryOrderFromHistory(BuildContext context, Map<String, dynamic> data) {
  final cart = context.read<CartProvider>();

  void doRetry() {
    final restaurantId = _strH(data['restaurantId']);
    final restaurantName = _strH(data['restaurantName']);
    final rawItems = (data['items'] as List?)?.whereType<Map>().toList() ?? [];
    final items = rawItems.map((item) => CartItem(
          name: _strH(item['name']),
          price: _strH(item['price']).isNotEmpty ? _strH(item['price']) : '0',
          img: _strH(item['img']),
          restaurantName: _strH(item['restaurantName']).isNotEmpty
              ? _strH(item['restaurantName'])
              : restaurantName,
          restaurantId: restaurantId,
          quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        )).toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de retrouver les articles de cette commande.'),
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
        totalAmount: _numH(data['totalAmount']),
        deliveryFee: _numH(data['deliveryFee']),
        deliveryAddress: _strH(data['deliveryAddress']),
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
        deliveryLat: (data['clientLat'] as num?)?.toDouble() ?? 6.3654,
        deliveryLng: (data['clientLng'] as num?)?.toDouble() ?? 2.4183,
        deliveryNote: _strH(data['deliveryNote']),
        deliveryPayCash: _strH(data['delivery_payment_method']) == 'cash',
        promoDiscount: _numH(data['promoDiscount']),
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

// ── ONGLET 3 — HISTORIQUE (2 sous-onglets) ───────────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final Set<String> _hiddenIds = {};

  void _deleteOrder(String docId) {
    setState(() => _hiddenIds.add(docId));
    FirebaseFirestore.instance
        .collection('orders')
        .doc(docId)
        .update({'clientHidden': true});
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(
          child: Text(AppLocalizations.of(context).loginToSeeOrders,
              style: TextStyle(color: Colors.grey.shade500)));
    }
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          indicatorWeight: 2,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 14),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).deliveredTab, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).failedTab, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            _HistoryDeliveredTab(
              uid: uid,
              hiddenIds: _hiddenIds,
              onDelete: _deleteOrder,
            ),
            _HistoryCancelledTab(uid: uid),
          ]),
        ),
      ]),
    );
  }
}

// ── HELPERS ──────────────────────────────────────────────────────────────────
String _hStr(dynamic v) => v?.toString() ?? '';
int _hNum(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
String _hDate(dynamic ts) {
  if (ts == null) return '—';
  try {
    final d = ts is Timestamp ? ts.toDate() : DateTime.now();
    return DateFormat('dd/MM/yyyy à HH:mm').format(d);
  } catch (_) {
    return '—';
  }
}

// ── ONGLET HISTORIQUE — LIVRÉES ──────────────────────────────────────────────
class _HistoryDeliveredTab extends StatelessWidget {
  final String uid;
  final Set<String> hiddenIds;
  final void Function(String) onDelete;
  const _HistoryDeliveredTab({
    required this.uid,
    required this.hiddenIds,
    required this.onDelete,
  });

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
        final docs = (snap.data?.docs ?? [])
            .where((d) =>
                !hiddenIds.contains(d.id) &&
                (d.data() as Map?)?['clientHidden'] != true)
            .toList();
        if (docs.isEmpty) return const _HisEmptyDelivered();

        final grouped = <String, List<QueryDocumentSnapshot>>{};
        for (final doc in docs) {
          final ts = (doc.data() as Map<String, dynamic>)['createdAt'];
          final date = ts is Timestamp ? ts.toDate() : DateTime.now();
          final key = DateFormat('MMMM yyyy', 'fr_FR').format(date);
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            _HisSummaryBar(total: docs.length),
            const SizedBox(height: 16),
            ...grouped.entries.map((e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HisMonthLabel(e.key),
                    ...e.value.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete_outline,
                                    color: Colors.white, size: 26),
                                const SizedBox(height: 4),
                                Text(AppLocalizations.of(context).deleteLabel,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11)),
                              ]),
                        ),
                        onDismissed: (_) => onDelete(doc.id),
                        child: _HisOrderCard(
                          data: data,
                          onTap: () => _showDeliveredDetail(
                              context, data, doc.id),
                          onDelete: () => onDelete(doc.id),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showDeliveredDetail(
      BuildContext context, Map<String, dynamic> data, String orderId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (_) =>
          _HisOrderDetailSheet(data: data, orderId: orderId),
    );
  }
}

// ── ONGLET HISTORIQUE — ÉCHOUÉES ─────────────────────────────────────────────
class _HistoryCancelledTab extends StatelessWidget {
  final String uid;
  const _HistoryCancelledTab({required this.uid});

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
        if (docs.isEmpty) return const _HisEmptyCancelled();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            _HisCancelledSummaryBar(total: docs.length),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _HisCancelledCard(
                data: data,
                onTap: () => _showCancelledDetail(context, data, doc.id),
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showCancelledDetail(
      BuildContext context, Map<String, dynamic> data, String orderId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (sheetCtx) => _HisCancelledDetailSheet(
        data: data,
        orderId: orderId,
        onRetry: () {
          Navigator.pop(sheetCtx);
          _retryOrderFromHistory(context, data);
        },
      ),
    );
  }
}

// ── WIDGETS LIVRÉES ──────────────────────────────────────────────────────────
class _HisSummaryBar extends StatelessWidget {
  final int total;
  const _HisSummaryBar({required this.total});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline,
                color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                AppLocalizations.of(context).deliveriesCount(total),
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(AppLocalizations.of(context).deliveredOrdersOnly,
                style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ]),
        ]),
      );
}

class _HisMonthLabel extends StatelessWidget {
  final String label;
  const _HisMonthLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.2)),
      );
}

class _HisOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HisOrderCard(
      {required this.data, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final ts = data['createdAt'] as Timestamp?;
    final totalAmount = _hNum(data['totalAmount']);
    final delivPayCash =
        (data['delivery_payment_method'] as String?) == 'cash';
    final appAmount =
        delivPayCash ? totalAmount - _hNum(data['deliveryFee']) : totalAmount;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.restaurant,
                  color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hStr(data['restaurantName']),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    Text(ts != null ? _hDate(ts) : '—',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 12),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context).deliveredBadge,
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
                items
                        .take(3)
                        .map((i) => '${i['quantity']}× ${i['name']}')
                        .join(' • ') +
                    (items.length > 3
                        ? ' +${items.length - 3}'
                        : ''),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Row(children: [
              const Icon(Icons.phone_android,
                  size: 11, color: Colors.black54),
              const SizedBox(width: 4),
              Text('App : $appAmount FCFA',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600)),
            ]),
            if (delivPayCash) ...[
              const SizedBox(width: 10),
              Row(children: [
                const Icon(Icons.money, size: 11, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                    'Cash : ${_hNum(data['deliveryFee'])} FCFA',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            const Spacer(),
            Text('$totalAmount FCFA',
                style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
        ]),
      ),
    );
  }
}

class _HisOrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  const _HisOrderDetailSheet(
      {required this.data, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _hNum(data['totalAmount']);
    final delivFee = _hNum(data['deliveryFee']);
    final serviceFee = _hNum(data['serviceFee']);
    final foodAmt = _hNum(data['foodAmount']);
    final delivPayCash =
        (data['delivery_payment_method'] as String?) == 'cash';
    final payment = _hStr(data['paymentMethod']);
    final shortId = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(children: [
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
                    Text(_hStr(data['restaurantName']),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('Commande #$shortId',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3))),
              child: Text(AppLocalizations.of(context).statusDeliveredBadge,
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ]),
        ),
        const Divider(height: 24),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(AppLocalizations.of(context).itemsLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
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
                          child: Text(
                              _hStr(item['name']),
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                      Text(
                          '${_hNum(item['price']) * _hNum(item['quantity'])} FCFA',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ]),
                  )),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              _DetailRow(AppLocalizations.of(context).dishesPriceLabel, '$foodAmt FCFA'),
              _DetailRow(AppLocalizations.of(context).commissionLabel, '$serviceFee FCFA'),
              _DetailRow(
                delivPayCash
                    ? AppLocalizations.of(context).deliveryCash
                    : AppLocalizations.of(context).deliveryApp,
                '$delivFee FCFA',
              ),
              const Divider(height: 16),
              _DetailRow(AppLocalizations.of(context).totalPaidApp, '$total FCFA', bold: true),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).detailsLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _DetailRow(AppLocalizations.of(context).address, _hStr(data['deliveryAddress'])),
              _DetailRow(AppLocalizations.of(context).paymentMethodLabel, _hPayLabel(context, payment)),
              _DetailRow(AppLocalizations.of(context).dateLabel, _hDate(data['createdAt'])),
              const SizedBox(height: 16),
              _HisReceiptActions(data: data, orderId: orderId),
              const SizedBox(height: 8),
              if (_hStr(data['restaurantId']).isNotEmpty)
                _HisReviewButton(
                  restaurantId: _hStr(data['restaurantId']),
                  restaurantName:
                      _hStr(data['restaurantName']),
                  orderId: orderId,
                ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }

  String _hPayLabel(BuildContext context, String p) {
    final t = AppLocalizations.of(context);
    switch (p) {
      case 'mobile_money':
      case 'mobile_money_fedapay':
        return 'Mobile Money (FedaPay)';
      case 'card':
        return t.cardPayment;
      case 'cash':
        return t.cashDelivery;
      default:
        return p.isNotEmpty ? p : '—';
    }
  }
}

// ── WIDGETS ÉCHOUÉES ─────────────────────────────────────────────────────────
class _HisCancelledSummaryBar extends StatelessWidget {
  final int total;
  const _HisCancelledSummaryBar({required this.total});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.replay_outlined,
                color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                  AppLocalizations.of(context).failedOrdersCount(total),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(AppLocalizations.of(context).tapToRetry,
                  style: const TextStyle(color: Colors.black54, fontSize: 11)),
            ]),
          ),
        ]),
      );
}

class _HisCancelledCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _HisCancelledCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final ts = data['createdAt'] as Timestamp?;
    final totalAmount = _hNum(data['totalAmount']);
    final paymentStatus = _hStr(data['paymentStatus']);
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
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.restaurant,
                  color: Colors.red, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hStr(data['restaurantName']),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    Text(ts != null ? _hDate(ts) : '—',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cancel_outlined,
                    color: Colors.red, size: 12),
                const SizedBox(width: 4),
                Text(failedLabel,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              items
                      .take(3)
                      .map((i) => '${i['quantity']}× ${i['name']}')
                      .join(' • ') +
                  (items.length > 3
                      ? ' +${items.length - 3}'
                      : ''),
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$totalAmount FCFA',
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context).retryLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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

class _HisCancelledDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final VoidCallback onRetry;
  const _HisCancelledDetailSheet({
    required this.data,
    required this.orderId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final total = _hNum(data['totalAmount']);
    final delivFee = _hNum(data['deliveryFee']);
    final paymentStatus = _hStr(data['paymentStatus']);
    final t2 = AppLocalizations.of(context);
    final failReason = paymentStatus == 'PAYMENT_FAILED'
        ? t2.failedPaymentReason
        : t2.cancelledBeforePayment;
    final shortId = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(children: [
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
                    Text(_hStr(data['restaurantName']),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('Commande #$shortId',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3))),
              child: Text(AppLocalizations.of(context).failedOrderBadge,
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ]),
        ),
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
              Icon(Icons.info_outline,
                  color: Colors.red.shade600, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(failReason,
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.shade700)),
              ),
            ]),
          ),
        ),
        const Divider(height: 20),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(AppLocalizations.of(context).itemsLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
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
                          child: Text(
                              _hStr(item['name']),
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                      Text(
                          '${_hNum(item['price']) * _hNum(item['quantity'])} FCFA',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ]),
                  )),
              const SizedBox(height: 14),
              const Divider(),
              _DetailRow(AppLocalizations.of(context).subtotalDishes, '${total - delivFee} FCFA'),
              _DetailRow(AppLocalizations.of(context).deliveryLabel, '$delivFee FCFA'),
              _DetailRow(AppLocalizations.of(context).total, '$total FCFA', bold: true),
              const SizedBox(height: 8),
              _DetailRow(AppLocalizations.of(context).address, _hStr(data['deliveryAddress'])),
              _DetailRow(AppLocalizations.of(context).dateLabel, _hDate(data['createdAt'])),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay, size: 20),
            label: Text(AppLocalizations.of(context).retryPayment,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
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

// ── WIDGETS PARTAGÉS HISTORIQUE ───────────────────────────────────────────────
class _HisEmptyDelivered extends StatelessWidget {
  const _HisEmptyDelivered();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.orange.shade300),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context).noDeliveredOrders,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).deliveredOrdersHint,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );
}

class _HisEmptyCancelled extends StatelessWidget {
  const _HisEmptyCancelled();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.shade400),
          ),
          const SizedBox(height: 20),
          const Text('Aucune commande échouée',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Super ! Tous vos paiements ont réussi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );
}

class _HisReceiptActions extends StatefulWidget {
  final Map<String, dynamic> data;
  final String orderId;
  const _HisReceiptActions({required this.data, required this.orderId});
  @override
  State<_HisReceiptActions> createState() => _HisReceiptActionsState();
}

class _HisReceiptActionsState extends State<_HisReceiptActions> {
  bool _loadingReceipt = false;
  bool _loadingTicket = false;

  Future<void> _run(
      Future<void> Function() action, void Function(bool) set) async {
    set(true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erreur lors de la génération du document'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) set(false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documents',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _HisActionBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Reçu PDF',
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
              child: _HisActionBtn(
                icon: Icons.receipt_long_outlined,
                label: 'Ticket',
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
          ]),
        ],
      );
}

class _HisActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _HisActionBtn({
    required this.icon,
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54))
                : Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _HisReviewButton extends StatefulWidget {
  final String restaurantId, restaurantName, orderId;
  const _HisReviewButton({
    required this.restaurantId,
    required this.restaurantName,
    required this.orderId,
  });
  @override
  State<_HisReviewButton> createState() => _HisReviewButtonState();
}

class _HisReviewButtonState extends State<_HisReviewButton> {
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HisReviewSheet(
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              color: Colors.black54, size: 16),
          SizedBox(width: 8),
          Text('Avis déjà soumis — merci !',
              style: TextStyle(color: Colors.black54, fontSize: 13)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _HisReviewSheet extends StatefulWidget {
  final String restaurantId, restaurantName, orderId;
  final VoidCallback onSubmitted;
  const _HisReviewSheet({
    required this.restaurantId,
    required this.restaurantName,
    required this.orderId,
    required this.onSubmitted,
  });
  @override
  State<_HisReviewSheet> createState() => _HisReviewSheetState();
}

class _HisReviewSheetState extends State<_HisReviewSheet> {
  double _rating = 5;
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = userDoc.data()?['name'] as String? ?? 'Client';
      await ReviewService.addReview(
        widget.restaurantId,
        ReviewModel(
          id: '',
          clientUid: uid,
          clientName: name,
          rating: _rating,
          comment: _ctrl.text.trim(),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
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
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
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
                    size: 36,
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
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Partagez votre expérience (optionnel)',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Colors.orange, width: 1.5)),
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
              label: Text(
                  _saving ? 'Envoi en cours...' : 'Publier mon avis'),
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

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _DetailRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// WIDGETS PARTAGéS
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade900.withValues(alpha: 0.3)
                    : Colors.orange.shade50,
                shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 70, color: Colors.orange),
          ),
          const SizedBox(height: 20),
          const Text('Votre panier est vide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ajoutez des plats depuis les restaurants',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}

class _CartItemCard extends StatelessWidget {
  final int index;
  final CartItem item;
  const _CartItemCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Dismissible(
      key: Key('${item.name}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16)),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text('Supprimer',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
      onDismissed: (_) => cart.removeItem(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.img.startsWith('http')
                  ? Image.network(item.img,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _platFallback())
                  : Image.asset(item.img,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _platFallback()),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.restaurantName,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(item.price,
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ])),
            Column(children: [
              _QtyBtn(Icons.add, () => cart.increaseQuantity(index)),
              const SizedBox(height: 4),
              Text('${item.quantity}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              _QtyBtn(Icons.remove, () => cart.decreaseQuantity(index)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _platFallback() => Container(
      width: 70,
      height: 70,
      color: Colors.orange.shade50,
      child: const Icon(Icons.fastfood, color: Colors.orange));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, size: 16, color: Colors.orange),
        ),
      );
}

// FEUILLE DE COMMANDE
void showOrderSheet(BuildContext context, CartProvider cart) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // FIX : serviceFee dynamique = 5% du total nourriture
  final serviceFee = PaymentService.computeServiceFee(cart.totalPrice);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: Colors.orange),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Feuille de commande',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    '${cart.items.length} article${cart.items.length > 1 ? "s" : ""}',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // FIX : overflow corrigé avec Flexible + ellipsis
                ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item.img.startsWith('http')
                              ? Image.network(item.img,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _sheetImgFallback())
                              : Image.asset(item.img,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _sheetImgFallback()),
                        ),
                        const SizedBox(width: 12),
                        // FIX : Expanded + ellipsis évite l'overflow
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                              Text('${item.price} é ${item.quantity}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ])),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('${item.totalPrice} FCFA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 14)),
                        ),
                      ]),
                    )),
                const Divider(height: 24),
                _SheetRow('Sous-total plats', '${cart.totalAmount} FCFA'),
                _SheetRow('Frais de service (5%)', '$serviceFee FCFA'),
                const Divider(height: 16),
                _SheetRow(
                    'Total estimé', '${cart.totalAmount + serviceFee} FCFA',
                    bold: true, color: Colors.orange),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26))),
                  child: const Text('Confirmer et choisir l\'adresse',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

Widget _sheetImgFallback() => Container(
    width: 52,
    height: 52,
    color: Colors.orange.shade50,
    child: const Icon(Icons.fastfood, color: Colors.orange));

class _SheetRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _SheetRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Flexible(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color:
                        color ?? Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ]),
      );
}

// RéCAPITULATIF PANIER
class _Summary extends StatefulWidget {
  final CartProvider cart;
  const _Summary({required this.cart});
  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  int get _serviceFee =>
      PaymentService.computeServiceFee(widget.cart.totalPrice);
  int get _total => widget.cart.totalPrice + _serviceFee;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, -5))
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(children: [
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),

        _Row('Sous-total plats', '${widget.cart.totalPrice} FCFA'),
        const SizedBox(height: 8),
        _Row('Frais de service (5%)', '$_serviceFee FCFA'),

        const Divider(height: 20),
        _Row('Total (hors livraison)', '$_total FCFA', bold: true),
        const SizedBox(height: 4),
        Text('+ frais de livraison calculés à l\'étape suivante',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showOrderSheet(context, widget.cart),
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27))),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Récapitulatif de commande',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AdressePage(
                        totalAmount: _total,
                      ))),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27))),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.location_on_outlined),
            SizedBox(width: 8),
            Text('Choisir l\'adresse de livraison',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
        ),
        TextButton(
          onPressed: () => _confirmClear(context),
          child: const Text('Vider le panier',
              style: TextStyle(color: Colors.red)),
        ),
      ]),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<CartProvider>().clear();
              Navigator.pop(context);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 16 : 14,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: bold
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Colors.grey[700]),
                overflow: TextOverflow.ellipsis),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontSize: bold ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: bold
                        ? Colors.black87
                        : Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ],
      );
}

class _Img extends StatelessWidget {
  final String img;
  final double? width;
  final double height;
  const _Img({required this.img, this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: width,
        height: height,
        color: Colors.orange.shade100,
        child: const Center(
            child: Icon(Icons.restaurant, color: Colors.orange, size: 30)));
    if (img.startsWith('http'))
      return Image.network(img,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    if (img.startsWith('assets/'))
      return Image.asset(img,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    return fallback;
  }
}
