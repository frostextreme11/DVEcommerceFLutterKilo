import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

enum SortOption {
  newest,
  priceLowToHigh,
  priceHighToLow,
  nameAZ,
  nameZA,
  popularity,
}

class ProductsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedCategory;
  SortOption _sortOption = SortOption.newest;
  RangeValues _priceRange = const RangeValues(0, 1000000);

  // Getters
  List<Product> get products => _filteredProducts;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  SortOption get sortOption => _sortOption;
  RangeValues get priceRange => _priceRange;

  // Computed getters
  List<Product> get featuredProducts => _products.where((p) => p.isFeatured).toList();
  List<Product> get bestSellerProducts => _products.where((p) => p.isBestSeller).toList();
  List<Product> get discountedProducts => _products.where((p) => p.hasDiscount).toList();

  ProductsProvider() {
    loadProducts();
    loadCategories();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_products')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      _applyFilters();
    } catch (e) {
      print('Error loading products: $e');
      _products = [];
      _filteredProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      final response = await _supabase
          .from('kl_categories')
          .select('name')
          .eq('is_active', true);

      _categories = (response as List)
          .map((json) => json['name'] as String)
          .toList();
    } catch (e) {
      print('Error loading categories: $e');
      _categories = [];
    }
    notifyListeners();
  }

  void _applyFilters() {
    List<Product> filtered = List.from(_products);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // Apply category filter
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((product) =>
          product.category == _selectedCategory
      ).toList();
    }

    // Apply price range filter
    filtered = filtered.where((product) =>
        product.currentPrice >= _priceRange.start &&
        product.currentPrice <= _priceRange.end
    ).toList();

    // Apply sorting
    _sortProducts(filtered);

    _filteredProducts = filtered;
  }

  void _sortProducts(List<Product> products) {
    switch (_sortOption) {
      case SortOption.newest:
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.priceLowToHigh:
        products.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case SortOption.priceHighToLow:
        products.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case SortOption.nameAZ:
        products.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameZA:
        products.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.popularity:
        // For now, sort by best seller status, then by creation date
        products.sort((a, b) {
          if (a.isBestSeller && !b.isBestSeller) return -1;
          if (!a.isBestSeller && b.isBestSeller) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  // Public methods for updating filters
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _applyFilters();
    notifyListeners();
  }

  void setPriceRange(RangeValues range) {
    _priceRange = range;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _sortOption = SortOption.newest;
    _priceRange = const RangeValues(0, 1000000);
    _applyFilters();
    notifyListeners();
  }

  // Get product by ID
  Product? getProductById(String id) {
    return _products.firstWhere(
      (product) => product.id == id,
      orElse: () => throw Exception('Product not found'),
    );
  }

  // Get products by category
  List<Product> getProductsByCategory(String category) {
    return _products.where((product) => product.category == category).toList();
  }

  // Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;

    return _products.where((product) =>
        product.name.toLowerCase().contains(query.toLowerCase()) ||
        product.description.toLowerCase().contains(query.toLowerCase()) ||
        (product.category?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  // Refresh products
  Future<void> refreshProducts() async {
    await loadProducts();
  }
}