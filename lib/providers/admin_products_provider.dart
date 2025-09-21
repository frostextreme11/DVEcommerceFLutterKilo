import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class AdminProductsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategory;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  // Filtered products based on search and category
  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == null ||
          product.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Get unique categories
  List<String> get categories {
    return _products
        .map((product) => product.category)
        .where((category) => category != null)
        .toSet()
        .cast<String>()
        .toList();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_products')
          .select()
          .order('created_at', ascending: false);

      final productsData = response as List;
      _products = productsData.map((data) => Product.fromJson(data)).toList();

      print('AdminProductsProvider: Successfully loaded ${_products.length} products');
    } catch (e) {
      _error = 'Failed to load products: ${e.toString()}';
      print('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProduct(Product product) async {
    try {
      final productData = product.toJson();
      productData.remove('id'); // Remove id as it will be auto-generated

      final response = await _supabase
          .from('kl_products')
          .insert(productData)
          .select()
          .single();

      final newProduct = Product.fromJson(response);
      _products.insert(0, newProduct);
      notifyListeners();

      print('AdminProductsProvider: Product created successfully: ${newProduct.name}');
      return true;
    } catch (e) {
      _error = 'Failed to create product: ${e.toString()}';
      print('Error creating product: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final productData = product.toJson();

      await _supabase
          .from('kl_products')
          .update(productData)
          .eq('id', product.id);

      // Update local product
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _products[index] = product;
        notifyListeners();
      }

      print('AdminProductsProvider: Product updated successfully: ${product.name}');
      return true;
    } catch (e) {
      _error = 'Failed to update product: ${e.toString()}';
      print('Error updating product: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('kl_products')
          .delete()
          .eq('id', productId);

      _products.removeWhere((product) => product.id == productId);
      notifyListeners();

      print('AdminProductsProvider: Product deleted successfully: $productId');
      return true;
    } catch (e) {
      _error = 'Failed to delete product: ${e.toString()}';
      print('Error deleting product: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleProductStatus(String productId, bool isActive) async {
    try {
      await _supabase
          .from('kl_products')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      // Update local product
      final index = _products.indexWhere((p) => p.id == productId);
      if (index >= 0) {
        _products[index] = _products[index].copyWith(isActive: isActive);
        notifyListeners();
      }

      print('AdminProductsProvider: Product status updated successfully: $productId');
      return true;
    } catch (e) {
      _error = 'Failed to update product status: ${e.toString()}';
      print('Error updating product status: $e');
      notifyListeners();
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Product? getProductById(String productId) {
    return _products.firstWhere(
      (product) => product.id == productId,
      orElse: () => throw Exception('Product not found'),
    );
  }
}