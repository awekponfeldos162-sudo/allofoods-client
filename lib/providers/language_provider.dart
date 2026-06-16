// lib/providers/language_provider.dart
// ? Firebase : pas de changement é SharedPreferences pour la langue, c'est correct

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  Locale _locale = const Locale('fr');
  Locale get locale => _locale;

  static const Map<String, String> supported = {
    'fr': '🇫🇷  Français',
    'en': '🇬🇧  English',
  };

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'fr';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (!supported.containsKey(code)) return;
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  String get currentName => supported[_locale.languageCode] ?? 'Français';
}
