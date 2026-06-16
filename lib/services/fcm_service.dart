// lib/services/fcm_service.dart
// Sauvegarder le token FCM dans Firestore au login
// Pour que les notifications push fonctionnent

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static bool _initialized = false;

  // Initialiser FCM + sauvegarder token (une seule fois par session)
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Demander permission notifications (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Sauvegarder le token initial
    await _saveToken();

    // S'abonner au topic promotions (reçoit les campagnes publicitaires)
    await _messaging.subscribeToTopic('promotions');
    debugPrint('[FCM] Abonné au topic "promotions"');

    // Mettre à jour le token si renouvelé
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenString);
  }

  // Sauvegarder token dans Firestore
  static Future<void> _saveToken() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await _saveTokenString(token);
      debugPrint('[FCM] Token sauvegardé: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Erreur sauvegarde token: $e');
    }
  }

  static Future<void> _saveTokenString(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.name,
    }, SetOptions(merge: true));
  }

  // Supprimer token à la déconnexion
  static Future<void> clearToken() async {
    _initialized = false;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).update({
      'fcmToken': FieldValue.delete(),
    });
    await _messaging.deleteToken();
  }

  // Gérer les messages reçus
  static void setupMessageHandlers({
    required Function(RemoteMessage) onMessage,
    required Function(RemoteMessage) onMessageOpenedApp,
  }) {
    // App au premier plan
    FirebaseMessaging.onMessage.listen(onMessage);
    // App en arrière-plan ouverte via notif
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);
  }

  // Vérifier si app ouverte via notification
  static Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }
}
