// lib/services/biometric_service.dart
// Déverrouillage de l'app par empreinte/reconnaissance faciale — l'activation
// est stockée localement (SharedPreferences) : elle ne concerne que cet
// appareil, jamais synchronisée sur le compte Firestore.
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _prefKey = 'biometric_unlock_enabled';
  static final _auth = LocalAuthentication();

  // L'appareil dispose-t-il d'un capteur biométrique configuré ?
  static Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      debugPrint('[Biometric] canCheckBiometrics=$canCheck isDeviceSupported=$supported');
      return canCheck && supported;
    } catch (e) {
      debugPrint('[Biometric] isDeviceSupported error: $e');
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  // Dernier message d'erreur natif rencontré — affiché sur l'écran de
  // verrouillage pour diagnostiquer sans avoir besoin des logs adb.
  static String? lastError;

  // Déclenche le prompt biométrique natif. Retourne false si l'utilisateur
  // annule, si le capteur échoue, ou si aucune biométrie n'est enregistrée.
  static Future<bool> authenticate({required String reason}) async {
    lastError = null;
    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // autorise le PIN/schéma en repli
          stickyAuth: true,
        ),
      );
      debugPrint('[Biometric] authenticate() → $result');
      return result;
    } catch (e) {
      debugPrint('[Biometric] authenticate() error: $e');
      lastError = e.toString();
      return false;
    }
  }
}
