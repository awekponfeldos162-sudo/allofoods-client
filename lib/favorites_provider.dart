// lib/providers/favorites_provider.dart
// ? Favoris restaurants + plats é sauvegardés en local (SharedPreferences)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favRestaurants = {};
  Set<String> _favPlats = {};

  Set<String> get favRestaurants => _favRestaurants;
  Set<String> get favPlats => _favPlats;

  FavoritesProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getStringList('fav_restaurants') ?? [];
    final p = prefs.getStringList('fav_plats') ?? [];
    _favRestaurants = r.toSet();
    _favPlats = p.toSet();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fav_restaurants', _favRestaurants.toList());
    await prefs.setStringList('fav_plats', _favPlats.toList());
  }

  // Restaurants
  bool isFavRestaurant(String id) => _favRestaurants.contains(id);

  void toggleRestaurant(String id) {
    if (_favRestaurants.contains(id)) {
      _favRestaurants.remove(id);
    } else {
      _favRestaurants.add(id);
    }
    _save();
    notifyListeners();
  }

  // Plats
  bool isFavPlat(String id) => _favPlats.contains(id);

  void togglePlat(String id) {
    if (_favPlats.contains(id)) {
      _favPlats.remove(id);
    } else {
      _favPlats.add(id);
    }
    _save();
    notifyListeners();
  }

  int get totalFavs => _favRestaurants.length + _favPlats.length;
}
