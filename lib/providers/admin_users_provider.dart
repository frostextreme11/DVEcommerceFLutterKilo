import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as AppUser;

class AdminUsersProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AppUser.User> _users = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  AppUser.UserRole? _selectedRole;

  List<AppUser.User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  AppUser.UserRole? get selectedRole => _selectedRole;

  // Filtered users based on search and role
  List<AppUser.User> get filteredUsers {
    return _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (user.fullName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (user.phoneNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesRole = _selectedRole == null ||
          user.role == _selectedRole;

      return matchesSearch && matchesRole;
    }).toList();
  }

  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_users')
          .select()
          .order('created_at', ascending: false);

      final usersData = response as List;
      _users = usersData.map((data) => AppUser.User.fromJson(data)).toList();

      print('AdminUsersProvider: Successfully loaded ${_users.length} users');
    } catch (e) {
      _error = 'Failed to load users: ${e.toString()}';
      print('Error loading users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserRole(String userId, AppUser.UserRole newRole) async {
    try {
      await _supabase
          .from('kl_users')
          .update({
            'role': newRole.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Update local user
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex >= 0) {
        _users[userIndex] = _users[userIndex].copyWith(role: newRole);
        notifyListeners();
      }

      print('AdminUsersProvider: User role updated successfully: $userId');
      return true;
    } catch (e) {
      _error = 'Failed to update user role: ${e.toString()}';
      print('Error updating user role: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserProfile(String userId, {
    String? fullName,
    String? phoneNumber,
    String? fullAddress,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (fullAddress != null) updateData['full_address'] = fullAddress;

      await _supabase
          .from('kl_users')
          .update(updateData)
          .eq('id', userId);

      // Update local user
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex >= 0) {
        _users[userIndex] = _users[userIndex].copyWith(
          fullName: fullName ?? _users[userIndex].fullName,
          phoneNumber: phoneNumber ?? _users[userIndex].phoneNumber,
          fullAddress: fullAddress ?? _users[userIndex].fullAddress,
        );
        notifyListeners();
      }

      print('AdminUsersProvider: User profile updated successfully: $userId');
      return true;
    } catch (e) {
      _error = 'Failed to update user profile: ${e.toString()}';
      print('Error updating user profile: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      // Note: In a real app, you might want to soft delete or handle this carefully
      // For now, we'll do a hard delete
      await _supabase
          .from('kl_users')
          .delete()
          .eq('id', userId);

      _users.removeWhere((user) => user.id == userId);
      notifyListeners();

      print('AdminUsersProvider: User deleted successfully: $userId');
      return true;
    } catch (e) {
      _error = 'Failed to delete user: ${e.toString()}';
      print('Error deleting user: $e');
      notifyListeners();
      return false;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedRole(AppUser.UserRole? role) {
    _selectedRole = role;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedRole = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  AppUser.User? getUserById(String userId) {
    return _users.firstWhere(
      (user) => user.id == userId,
      orElse: () => throw Exception('User not found'),
    );
  }

  // Get users by role
  List<AppUser.User> getUsersByRole(AppUser.UserRole role) {
    return _users.where((user) => user.role == role).toList();
  }

  // Get admin users
  List<AppUser.User> get adminUsers => getUsersByRole(AppUser.UserRole.admin);

  // Get customer users
  List<AppUser.User> get customerUsers => getUsersByRole(AppUser.UserRole.customer);
}