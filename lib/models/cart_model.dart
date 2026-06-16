// lib/models/cart_model.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String name;
  final String price;
  final String img;
  final String restaurantName;
  final String restaurantId;
  int quantity;

  CartItem({
    required this.name,
    required this.price,
    required this.img,
    required this.restaurantName,
    required this.restaurantId,
    this.quantity = 1,
  });

  String? get imageUrl => img.startsWith('http') ? img : null;

  int get priceInt {
    final cleaned = price.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  int get totalPrice => priceInt * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'img': img,
        'restaurantName': restaurantName,
        'restaurantId': restaurantId,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        name: json['name'] as String,
        price: json['price'] as String,
        img: json['img'] as String,
        restaurantName: json['restaurantName'] as String,
        restaurantId: json['restaurantId'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

class CartProvider extends ChangeNotifier {
  static const _kItems = 'cart_items';
  static const _kRestId = 'cart_restaurant_id';
  static const _kRestName = 'cart_restaurant_name';

  final List<CartItem> _items = [];
  String _currentRestaurantId = '';
  String _currentRestaurantName = '';

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  int get totalPrice => _items.fold(0, (s, i) => s + i.totalPrice);
  int get totalAmount => totalPrice;
  String get totalPriceFormatted => '$totalPrice FCFA';
  String get restaurantId => _currentRestaurantId;
  String get restaurantName => _currentRestaurantName;

  CartProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kItems);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items.addAll(list
            .whereType<Map<String, dynamic>>()
            .map(CartItem.fromJson));
      }
      _currentRestaurantId = prefs.getString(_kRestId) ?? '';
      _currentRestaurantName = prefs.getString(_kRestName) ?? '';
      if (_items.isNotEmpty) notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kItems, jsonEncode(_items.map((i) => i.toJson()).toList()));
      await prefs.setString(_kRestId, _currentRestaurantId);
      await prefs.setString(_kRestName, _currentRestaurantName);
    } catch (_) {}
  }

  // Retourne true si l'article a été ajouté/incrémenté, false si limite atteinte
  bool addItem({
    required String name,
    required String price,
    required String img,
    required String restaurantName,
    required String restaurantId,
  }) {
    if (_items.isNotEmpty &&
        _currentRestaurantId.isNotEmpty &&
        _currentRestaurantId != restaurantId) {
      _items.clear();
    }

    _currentRestaurantId = restaurantId;
    _currentRestaurantName = restaurantName;

    final idx = _items
        .indexWhere((i) => i.name == name && i.restaurantId == restaurantId);
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(
        name: name,
        price: price,
        img: img,
        restaurantName: restaurantName,
        restaurantId: restaurantId,
      ));
    }
    _save();
    notifyListeners();
    return true;
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      if (_items.isEmpty) {
        _currentRestaurantId = '';
        _currentRestaurantName = '';
      }
      _save();
      notifyListeners();
    }
  }

  void increaseQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity++;
      _save();
      notifyListeners();
    }
  }

  void decreaseQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _save();
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _currentRestaurantId = '';
    _currentRestaurantName = '';
    _save();
    notifyListeners();
  }

  // Recharge le panier depuis une commande existante (retry paiement)
  void loadCart({
    required List<CartItem> items,
    required String restaurantId,
    required String restaurantName,
  }) {
    _items.clear();
    _currentRestaurantId = restaurantId;
    _currentRestaurantName = restaurantName;
    _items.addAll(items);
    _save();
    notifyListeners();
  }

  // Vide le panier après confirmation de commande (badge réinitialisé)
  Future<void> clearAfterOrder() async {
    _items.clear();
    _currentRestaurantId = '';
    _currentRestaurantName = '';
    await _save();
    notifyListeners();
  }
}
