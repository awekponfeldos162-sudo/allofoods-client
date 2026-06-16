// lib/providers/notification_provider.dart
// ? 100% Firebase é stream Firestore temps réel, aucun polling

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool get hasUnread => _unreadCount > 0;
  int get unreadCount => _unreadCount;

  StreamSubscription<QuerySnapshot>? _stream;

  NotificationProvider() {
    _listenToAuth();
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  // Démarre/arrête le stream selon l'état d'auth
  void _listenToAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _startStream(user.uid);
      } else {
        _stream?.cancel();
        _stream = null;
        _unreadCount = 0;
        notifyListeners();
      }
    });
  }

  // Stream push instantané é badge mis à jour dés qu'une notif isRead:false change
  void _startStream(String uid) {
    _stream?.cancel();
    _stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      final count = snap.docs.length;
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    }, onError: (_) {});
  }

  // Marquer tout lu é batch Firestore (le stream remet _unreadCount é 0 auto)
  Future<void> markAllAsRead() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  void increment() {
    _unreadCount++;
    notifyListeners();
  }

  void reset() {
    _unreadCount = 0;
    notifyListeners();
  }
}
