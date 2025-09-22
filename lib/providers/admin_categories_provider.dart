import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import 'products_provider.dart';

class AdminCategoriesProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Filtered categories based on search
  List<Category> get filteredCategories {
    if (_searchQuery.isEmpty) {
      return _categories;
    }

    return _categories.where((category) {
      return category.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (category.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  // Get active categories only
  List<Category> get activeCategories {
    return _categories.where((category) => category.isActive).toList();
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_categories')
          .select()
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      final categoriesData = response as List;
      _categories = categoriesData.map((data) => Category.fromJson(data)).toList();

      print('AdminCategoriesProvider: Successfully loaded ${_categories.length} categories');
    } catch (e) {
      _error = 'Failed to load categories: ${e.toString()}';
      print('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCategory(Category category) async {
    try {
      // Get the next display order
      final maxOrder = _categories.isEmpty ? 0 : _categories.map((c) => c.displayOrder).reduce((a, b) => a > b ? a : b);
      final newOrder = maxOrder + 1;

      final categoryData = category.toJson();
      categoryData.remove('id'); // Remove id as it will be auto-generated
      categoryData['display_order'] = newOrder;

      final response = await _supabase
          .from('kl_categories')
          .insert(categoryData)
          .select()
          .single();

      final newCategory = Category.fromJson(response);
      _categories.add(newCategory);
      _sortCategoriesByOrder();
      notifyListeners();

      print('AdminCategoriesProvider: Category created successfully: ${newCategory.name}');
      return true;
    } catch (e) {
      _error = 'Failed to create category: ${e.toString()}';
      print('Error creating category: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(Category category) async {
    try {
      final categoryData = category.toJson();

      await _supabase
          .from('kl_categories')
          .update(categoryData)
          .eq('id', category.id);

      // Update local category
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        _categories[index] = category;
        notifyListeners();
      }

      print('AdminCategoriesProvider: Category updated successfully: ${category.name}');
      return true;
    } catch (e) {
      _error = 'Failed to update category: ${e.toString()}';
      print('Error updating category: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _supabase
          .from('kl_categories')
          .delete()
          .eq('id', categoryId);

      _categories.removeWhere((category) => category.id == categoryId);
      notifyListeners();

      print('AdminCategoriesProvider: Category deleted successfully: $categoryId');
      return true;
    } catch (e) {
      _error = 'Failed to delete category: ${e.toString()}';
      print('Error deleting category: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleCategoryStatus(String categoryId, bool isActive) async {
    try {
      await _supabase
          .from('kl_categories')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', categoryId);

      // Update local category
      final index = _categories.indexWhere((c) => c.id == categoryId);
      if (index >= 0) {
        _categories[index] = _categories[index].copyWith(isActive: isActive);
        notifyListeners();
      }

      print('AdminCategoriesProvider: Category status updated successfully: $categoryId');
      return true;
    } catch (e) {
      _error = 'Failed to update category status: ${e.toString()}';
      print('Error updating category status: $e');
      notifyListeners();
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Category? getCategoryById(String categoryId) {
    return _categories.firstWhere(
      (category) => category.id == categoryId,
      orElse: () => throw Exception('Category not found'),
    );
  }

  Category? getCategoryByName(String name) {
    return _categories.firstWhere(
      (category) => category.name == name,
      orElse: () => throw Exception('Category not found'),
    );
  }

  // Reordering methods
  void _sortCategoriesByOrder() {
    _categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    notifyListeners();
  }

  Future<bool> reorderCategories(List<String> categoryIds) async {
    try {
      // Update display_order for each category
      for (int i = 0; i < categoryIds.length; i++) {
        await _supabase
            .from('kl_categories')
            .update({
              'display_order': i,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', categoryIds[i]);
      }

      // Reload categories to get updated order
      await loadCategories();

      // Refresh categories in products provider to reflect new order
      try {
        final productsProvider = ProductsProvider();
        await productsProvider.refreshCategories();
        print('AdminCategoriesProvider: Products provider categories refreshed');
      } catch (e) {
        print('AdminCategoriesProvider: Failed to refresh products provider categories: $e');
      }

      print('AdminCategoriesProvider: Categories reordered successfully');
      return true;
    } catch (e) {
      _error = 'Failed to reorder categories: ${e.toString()}';
      print('Error reordering categories: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategoryOrder(String categoryId, int newOrder) async {
    try {
      await _supabase
          .from('kl_categories')
          .update({
            'display_order': newOrder,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', categoryId);

      // Update local category
      final index = _categories.indexWhere((c) => c.id == categoryId);
      if (index >= 0) {
        _categories[index] = _categories[index].copyWith(displayOrder: newOrder);
        _sortCategoriesByOrder();
      }

      print('AdminCategoriesProvider: Category order updated successfully: $categoryId');
      return true;
    } catch (e) {
      _error = 'Failed to update category order: ${e.toString()}';
      print('Error updating category order: $e');
      notifyListeners();
      return false;
    }
  }

  // Get categories ordered by display_order
  List<Category> get orderedCategories {
    final sorted = List<Category>.from(_categories);
    sorted.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return sorted;
  }

  // Get active categories ordered by display_order
  List<Category> get orderedActiveCategories {
    return orderedCategories.where((category) => category.isActive).toList();
  }
}