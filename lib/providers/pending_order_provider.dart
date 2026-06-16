// lib/providers/pending_order_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingOrderProvider extends ChangeNotifier {
  Map<String, dynamic>? _pendingOrder;
  Map<String, dynamic>? get pendingOrder => _pendingOrder;
  bool get hasPending => _pendingOrder != null;

  StreamSubscription<QuerySnapshot>? _sub;

  PendingOrderProvider() {
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cutoff =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2)));

    _sub = FirebaseFirestore.instance
        .collection('orders')
        .where('clientUid', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'pending_payment'])
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      final found = snap.docs.isEmpty
          ? null
          : {
              'id': snap.docs.first.id,
              'restaurantName': snap.docs.first.data()['restaurantName'],
              'total':
                  (snap.docs.first.data()['totalAmount'] as num?)?.toDouble() ??
                      0.0,
              'status': snap.docs.first.data()['status'],
            };

      if (_pendingOrder?['id'] != found?['id']) {
        _pendingOrder = found;
        notifyListeners();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void dismiss() {
    _pendingOrder = null;
    notifyListeners();
  }
}
