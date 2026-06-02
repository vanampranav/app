import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/shopify_service.dart';

class CartItem {
  final String id;
  final String variantId;
  final String title;
  final double price;
  final String imageUrl;
  final int quantity;
  final String size;

  CartItem({
    required this.id,
    required this.variantId,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    required this.size,
  });

  CartItem copyWith({
    String? id,
    String? variantId,
    String? title,
    double? price,
    String? imageUrl,
    int? quantity,
    String? size,
  }) {
    return CartItem(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      title: title ?? this.title,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variantId': variantId,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'size': size,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      size: json['size']?.toString() ?? 'M',
    );
  }

  double get total => price * quantity;
}

class CartModel with ChangeNotifier {
  List<CartItem> _items = [];
  double _subtotal = 0;
  double _shipping = 5.99;
  double _tax = 0;
  late SharedPreferences _prefs;
  bool _initialized = false;

  CartModel() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCart();
    _initialized = true;
  }

  Future<void> _loadCart() async {
    final String? cartJson = _prefs.getString('cart');
    if (cartJson == null) return;
    try {
      final List<dynamic> cartList = json.decode(cartJson);
      _items = cartList.map((item) => CartItem.fromJson(item)).toList();
      _updateTotals();
    } catch (e) {
      debugPrint('Error loading cart, clearing corrupted data: $e');
      await _prefs.remove('cart');
      _items = [];
    }
  }

  Future<void> _saveCart() async {
    if (!_initialized) return;
    final String cartJson = json.encode(_items.map((item) => item.toJson()).toList());
    await _prefs.setString('cart', cartJson);
  }

  List<CartItem> get items => [..._items];
  int get itemCount => _items.length;
  double get subtotal => _subtotal;
  double get shipping => _shipping;
  double get tax => _tax;
  double get total => _subtotal + _shipping + _tax;
  double get totalPrice => total;

  void addToCart(Map<String, dynamic> product, String variantId, int quantity, {String size = 'M'}) {
    // Clean up the variant ID - ensure it's in the correct format
    if (!variantId.startsWith('gid://shopify/ProductVariant/')) {
      // Remove any existing Shopify prefix
      variantId = variantId.replaceAll('gid://shopify/Product/', '');
      variantId = variantId.replaceAll('gid://shopify/ProductVariant/', '');
      // Add the correct prefix
      variantId = 'gid://shopify/ProductVariant/$variantId';
    }
    
    final existingIndex = _items.indexWhere((item) => 
      item.variantId == variantId && item.size == size
    );

    if (existingIndex >= 0) {
      // Update existing item
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      // Add new item
      _items.add(
        CartItem(
          id: product['id'],
          variantId: variantId,
          title: product['title'],
          price: double.parse(product['price'].toString()),
          imageUrl: product['imageUrl'],
          quantity: quantity,
          size: size,
        ),
      );
    }

    _updateTotals();
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String variantId, String size) {
    _items.removeWhere((item) => item.variantId == variantId && item.size == size);
    _updateTotals();
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String variantId, String size, int quantity) {
    final index = _items.indexWhere(
      (item) => item.variantId == variantId && item.size == size,
    );

    if (index >= 0) {
      if (quantity > 0) {
        _items[index] = _items[index].copyWith(quantity: quantity);
      } else {
        _items.removeAt(index);
      }
      _updateTotals();
      _saveCart();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _updateTotals();
    _saveCart();
    notifyListeners();
  }

  void _updateTotals() {
    _subtotal = _items.fold(0, (sum, item) => sum + item.total);
    _tax = _subtotal * 0.08; // 8% tax
  }
} 