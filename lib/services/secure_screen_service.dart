// lib/services/secure_screen_service.dart
// Active/désactive FLAG_SECURE (Android) pour empêcher captures d'écran et
// enregistrement pendant les écrans sensibles (paiement). No-op silencieux
// sur les plateformes sans équivalent (iOS/web) — pas d'erreur, juste inactif.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecureScreenService {
  SecureScreenService._();

  static const _channel = MethodChannel('com.allofoods.app/secure_screen');

  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('enable');
    } catch (e) {
      debugPrint('[SecureScreen] enable: $e');
    }
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disable');
    } catch (e) {
      debugPrint('[SecureScreen] disable: $e');
    }
  }
}
