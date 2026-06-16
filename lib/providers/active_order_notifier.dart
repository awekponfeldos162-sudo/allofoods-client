import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveOrderNotifier extends ChangeNotifier {
  String? orderId;
  String? status;
  String? restaurantName;
  int     totalAmount   = 0;
  bool    isOrderPageOpen = false;

  StreamSubscription<QuerySnapshot>? _sub;

  static const _bannerStatuses = {
    'confirmed', 'preparing', 'ready', 'ready_for_pickup',
    'en_route', 'delivering',
  };

  bool get showBanner =>
      orderId != null &&
      _bannerStatuses.contains(status) &&
      !isOrderPageOpen;

  void startWatching(String uid) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('orders')
        .where('clientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(_onSnapshot, onError: (_) {});
  }

  void _onSnapshot(QuerySnapshot snap) {
    if (snap.docs.isEmpty) {
      _clear();
      return;
    }
    final doc  = snap.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    final s    = data['status'] as String? ?? '';
    if (!_bannerStatuses.contains(s)) {
      _clear();
      return;
    }
    orderId        = doc.id;
    status         = s;
    restaurantName = data['restaurantName'] as String?;
    totalAmount    = (data['totalAmount'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  void stopWatching() {
    _sub?.cancel();
    _clear();
  }

  void setOrderPageOpen(bool v) {
    if (isOrderPageOpen == v) return;
    isOrderPageOpen = v;
    notifyListeners();
  }

  void _clear() {
    orderId        = null;
    status         = null;
    restaurantName = null;
    totalAmount    = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
