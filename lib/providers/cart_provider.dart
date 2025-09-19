import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartItem {
  final String id;
  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  final double? discountPrice;
  int quantity;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.discountPrice,
    this.quantity = 1,
  });

  double get currentPrice => discountPrice ?? price;
  double get totalPrice => currentPrice * quantity;
  double get discountAmount => discountPrice != null ? (price - discountPrice!) * quantity : 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'discountPrice': discountPrice,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      productId: json['productId'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      price: json['price'],
      discountPrice: json['discountPrice'],
      quantity: json['quantity'],
    );
  }
}

class CartProvider extends ChangeNotifier {
  static const String _cartKey = 'cart_items';

  List<CartItem> _items = [];
  late SharedPreferences _prefs;

  List<CartItem> get items => _items;
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalDiscount => _items.fold(0, (sum, item) => sum + item.discountAmount);
  double get total => subtotal;

  CartProvider() {
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCartFromStorage();
  }

  Future<void> _loadCartFromStorage() async {
    final cartData = _prefs.getString(_cartKey);
    if (cartData != null) {
      try {
        final List<dynamic> decodedData = json.decode(cartData);
        _items = decodedData.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      } catch (e) {
        // If there's an error loading cart, clear it
        _items = [];
        await _saveCartToStorage();
      }
    }
  }

  Future<void> _saveCartToStorage() async {
    final cartData = json.encode(_items.map((item) => item.toJson()).toList());
    await _prefs.setString(_cartKey, cartData);
  }

  Future<void> addItem({
    required String productId,
    required String name,
    required String imageUrl,
    required double price,
    double? discountPrice,
    int quantity = 1,
  }) async {
    final existingIndex = _items.indexWhere((item) => item.productId == productId);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      final newItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: productId,
        name: name,
        imageUrl: imageUrl,
        price: price,
        discountPrice: discountPrice,
        quantity: quantity,
      );
      _items.add(newItem);
    }

    await _saveCartToStorage();
    notifyListeners();
  }

  Future<void> removeItem(String productId) async {
    _items.removeWhere((item) => item.productId == productId);
    await _saveCartToStorage();
    notifyListeners();
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(productId);
      return;
    }

    final itemIndex = _items.indexWhere((item) => item.productId == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].quantity = newQuantity;
      await _saveCartToStorage();
      notifyListeners();
    }
  }

  Future<void> incrementQuantity(String productId) async {
    final itemIndex = _items.indexWhere((item) => item.productId == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].quantity++;
      await _saveCartToStorage();
      notifyListeners();
    }
  }

  Future<void> decrementQuantity(String productId) async {
    final itemIndex = _items.indexWhere((item) => item.productId == productId);
    if (itemIndex >= 0) {
      if (_items[itemIndex].quantity > 1) {
        _items[itemIndex].quantity--;
        await _saveCartToStorage();
        notifyListeners();
      } else {
        await removeItem(productId);
      }
    }
  }

  Future<void> clearCart() async {
    _items.clear();
    await _saveCartToStorage();
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  CartItem? getCartItem(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  int getQuantity(String productId) {
    final item = getCartItem(productId);
    return item?.quantity ?? 0;
  }
}