import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WishlistItem {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String description;
  final String? variantId; // Add variant ID for proper cart integration
  final List<Map<String, dynamic>>? variants; // Add variants for size selection

  WishlistItem({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.description,
    this.variantId,
    this.variants,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
      'variantId': variantId,
      'variants': variants,
    };
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      variantId: json['variantId']?.toString(),
      variants: json['variants'] != null
          ? List<Map<String, dynamic>>.from(json['variants'])
          : null,
    );
  }
}

class WishlistModel extends ChangeNotifier {
  List<WishlistItem> _items = [];
  late SharedPreferences _prefs;
  bool _initialized = false;

  WishlistModel() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadWishlist();
    _initialized = true;
  }

  Future<void> _loadWishlist() async {
    final String? wishlistJson = _prefs.getString('wishlist');
    if (wishlistJson == null) return;
    try {
      final List<dynamic> wishlistList = json.decode(wishlistJson);
      _items = wishlistList.map((item) => WishlistItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading wishlist, clearing corrupted data: $e');
      await _prefs.remove('wishlist');
      _items = [];
    }
  }

  Future<void> _saveWishlist() async {
    if (!_initialized) return;
    final String wishlistJson = json.encode(_items.map((item) => item.toJson()).toList());
    await _prefs.setString('wishlist', wishlistJson);
  }

  List<WishlistItem> get items => [..._items];
  int get itemCount => _items.length;

  void toggleWishlist(Map<String, dynamic> product) {
    final existingIndex = _items.indexWhere((item) => item.id == product['id']);

    if (existingIndex >= 0) {
      _items.removeAt(existingIndex);
    } else {
      _items.add(
        WishlistItem(
          id: product['id'],
          title: product['title'],
          price: double.parse(product['price'].toString()),
          imageUrl: product['imageUrl'],
          description: product['description'] ?? '',
          variantId: product['variantId'],
          variants: product['variants'] != null 
              ? List<Map<String, dynamic>>.from(product['variants'])
              : null,
        ),
      );
    }

    _saveWishlist();
    notifyListeners();
  }

  void removeFromWishlist(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveWishlist();
    notifyListeners();
  }

  void clearWishlist() {
    _items.clear();
    _saveWishlist();
    notifyListeners();
  }

  bool isInWishlist(String id) {
    return _items.any((item) => item.id == id);
  }
} 