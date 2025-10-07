import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/notification_service.dart';
import '../models/order.dart';

class AdminNotification {
  final String id;
  final String orderId;
  final String customerName;
  final int quantity;
  final double totalPrice;
  final DateTime orderDate;
  final bool isRead;
  final DateTime createdAt;
  final String title;
  final String message;
  final String type;

  AdminNotification({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.quantity,
    required this.totalPrice,
    required this.orderDate,
    this.isRead = false,
    required this.createdAt,
    required this.title,
    required this.message,
    required this.type,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'],
      orderId: json['order_id'],
      customerName: json['customer_name'],
      quantity: json['quantity'],
      totalPrice: (json['total_price'] as num).toDouble(),
      orderDate: DateTime.parse(json['order_date']),
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      title: json['title'] ?? 'New Order Received!',
      message: json['message'] ?? 'A new order has been placed.',
      type: json['type'] ?? 'order',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'customer_name': customerName,
      'quantity': quantity,
      'total_price': totalPrice,
      'order_date': orderDate.toIso8601String(),
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AdminNotification copyWith({
    String? id,
    String? orderId,
    String? customerName,
    int? quantity,
    double? totalPrice,
    DateTime? orderDate,
    bool? isRead,
    DateTime? createdAt,
    String? title,
    String? message,
    String? type,
  }) {
    return AdminNotification(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      orderDate: orderDate ?? this.orderDate,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
    );
  }
}

class AdminNotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final NotificationService _notificationService;

  List<AdminNotification> _notifications = [];
  List<AdminNotification> _displayedNotifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _adminFcmToken;
  int _currentPage = 0;
  static const int _pageSize = 10;
  bool _hasMoreNotifications = true;

  List<AdminNotification> get notifications => _notifications;
  List<AdminNotification> get displayedNotifications => _displayedNotifications;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get adminFcmToken => _adminFcmToken;
  bool get hasMoreNotifications => _hasMoreNotifications;

  // Get unread notifications count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Get recent notifications (last 10) - for backward compatibility
  List<AdminNotification> get recentNotifications =>
      _displayedNotifications.take(10).toList();

  AdminNotificationProvider() {
    // Initialize asynchronously to avoid blocking provider creation
    Future.microtask(() => _initializeAdminNotifications());
  }

  StreamSubscription<List<dynamic>>? _notificationsSubscription;

  Future<void> _initializeAdminNotifications() async {
    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((event) async {
      print('AdminNotificationProvider: Auth state changed: ${event.event}');

      if (event.event == AuthChangeEvent.signedIn &&
          event.session?.user != null) {
        if (await _isUserAdmin()) {
          print(
            'AdminNotificationProvider: Admin signed in, initializing notifications...',
          );
          await _initializeNotifications();
        }
      } else if (event.event == AuthChangeEvent.signedOut) {
        print(
          'AdminNotificationProvider: User signed out, clearing notifications...',
        );
        _clearNotifications();
      }
    });

    // Check if user is already authenticated and is admin
    if (await _isUserAdmin()) {
      print(
        'AdminNotificationProvider: Admin already authenticated, initializing notifications...',
      );
      await _initializeNotifications();
    }
  }

  Future<bool> _isUserAdmin() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final userResponse = await _supabase
          .from('kl_users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userResponse == null) {
        print('User not found in database');
        return false;
      }

      final userRole = userResponse['role'];
      return userRole == 'admin';
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  Future<void> _initializeNotifications() async {
    if (!await _isUserAdmin()) {
      print(
        'AdminNotificationProvider: User is not admin, skipping initialization',
      );
      return;
    }

    try {
      print('AdminNotificationProvider: Starting initialization...');

      // Initialize notification service lazily
      _notificationService = NotificationService();
      await _notificationService.initialize();
      print('AdminNotificationProvider: Notification service initialized');

      await _loadAdminNotifications();
      print('AdminNotificationProvider: Notifications loaded');

      await _getOrCreateAdminFcmToken();
      print('AdminNotificationProvider: FCM token setup completed');

      await _setupRealtimeListener();
      print('AdminNotificationProvider: Real-time listener setup completed');

      print(
        'AdminNotificationProvider: Notifications initialized successfully',
      );
    } catch (e) {
      print('Error initializing admin notifications: $e');
      // Don't rethrow to prevent provider creation failure
    }
  }

  Future<void> _setupRealtimeListener() async {
    try {
      // Cancel existing subscription if any
      await _notificationsSubscription?.cancel();

      print('AdminNotificationProvider: Setting up real-time listener...');

      // Set up real-time listener for new notifications
      _notificationsSubscription = _supabase
          .from('kl_admin_notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((List<dynamic> data) {
            print(
              'Real-time notification update received: ${data.length} notifications',
            );

            // Update notifications list
            _notifications = data
                .map((json) => AdminNotification.fromJson(json))
                .toList();

            // Update displayed notifications to show latest 10
            _displayedNotifications = _notifications.take(_pageSize).toList();
            _currentPage = 0;
            _hasMoreNotifications = _notifications.length > _pageSize;

            notifyListeners();

            // Show local notification for new orders if it's a new notification
            if (data.isNotEmpty) {
              print(
                'AdminNotificationProvider: New notifications received: ${data.length}',
              );
            }
          });

      print('Real-time notification listener set up successfully');
    } catch (e) {
      print('Error setting up real-time listener: $e');
    }
  }

  Future<void> _loadAdminNotifications() async {
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreNotifications = true;
    notifyListeners();

    try {
      try {
        final response = await _supabase
            .from('kl_admin_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(_pageSize);

        final notificationsData = response as List;
        _notifications = notificationsData
            .map((data) => AdminNotification.fromJson(data))
            .toList();

        _displayedNotifications = List.from(_notifications);
        _hasMoreNotifications = _notifications.length == _pageSize;
      } catch (e) {
        print('Failed to load admin notifications: $e');
        _notifications = []; // Start with empty list if database fails
        _displayedNotifications = [];
        _hasMoreNotifications = false;
      }

      print(
        'AdminNotificationProvider: Loaded ${_notifications.length} notifications',
      );
    } catch (e) {
      _error = 'Failed to load notifications: ${e.toString()}';
      print('Error loading admin notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNotifications() async {
    if (!_hasMoreNotifications || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final offset = nextPage * _pageSize;

      final response = await _supabase
          .from('kl_admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final notificationsData = response as List;
      final newNotifications = notificationsData
          .map((data) => AdminNotification.fromJson(data))
          .toList();

      if (newNotifications.isNotEmpty) {
        _notifications.addAll(newNotifications);
        _displayedNotifications.addAll(newNotifications);
        _currentPage = nextPage;
        _hasMoreNotifications = newNotifications.length == _pageSize;
      } else {
        _hasMoreNotifications = false;
      }

      print(
        'AdminNotificationProvider: Loaded ${newNotifications.length} more notifications',
      );
    } catch (e) {
      print('Error loading more admin notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _getOrCreateAdminFcmToken() async {
    try {
      // Get current FCM token
      String? token = _notificationService.fcmToken;

      if (token == null || token.isEmpty) {
        // Refresh token if null or empty
        await _notificationService.refreshToken();
        token = _notificationService.fcmToken;
      }

      if (token != null && token.isNotEmpty) {
        _adminFcmToken = token;

        // Store/update admin FCM token in database
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          try {
            await _supabase.from('kl_admin_fcm_tokens').upsert({
              'user_id': currentUser.id,
              'fcm_token': token,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id');
            print('Admin FCM token stored successfully: $token');
          } catch (e) {
            print('Failed to store admin FCM token: $e');
            // Continue without storing token
          }
        }

        print('AdminNotificationProvider: Admin FCM token set: $token');
      } else {
        print('AdminNotificationProvider: FCM token is null or empty');
      }
    } catch (e) {
      print('Error getting/creating admin FCM token: $e');
    }
  }

  Future<void> addNotification({
    required String orderId,
    required String customerName,
    required int quantity,
    required double totalPrice,
    required DateTime orderDate,
    String? title,
    String? message,
    String? type,
  }) async {
    try {
      final notificationData = {
        'order_id': orderId,
        'customer_name': customerName,
        'quantity': quantity,
        'total_price': totalPrice,
        'order_date': orderDate.toIso8601String(),
        'title': title ?? 'New Order Received!',
        'message': message ?? 'A new order has been placed.',
        'type': type ?? 'order',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final response = await _supabase
            .from('kl_admin_notifications')
            .insert(notificationData)
            .select()
            .single();

        final newNotification = AdminNotification.fromJson(response);

        // Add to local list
        _notifications.insert(0, newNotification);
      } catch (e) {
        print('Failed to add admin notification to database: $e');
        // Continue without adding to database
      }

      // Send push notification to admin
      if (_adminFcmToken != null && _adminFcmToken!.isNotEmpty) {
        print(
          'AdminNotificationProvider: Sending push notification to admin: $_adminFcmToken',
        );
        await _notificationService.sendOrderNotificationToAdmin(
          adminToken: _adminFcmToken!,
          customerName: customerName,
          quantity: quantity,
          totalPrice: totalPrice,
          orderId: orderId,
          orderDate: orderDate,
        );
      } else {
        print(
          'AdminNotificationProvider: Admin FCM token is null or empty, cannot send push notification',
        );
      }

      notifyListeners();
      print(
        'AdminNotificationProvider: New notification added for order: $orderId',
      );
    } catch (e) {
      _error = 'Failed to add notification: ${e.toString()}';
      print('Error adding admin notification: $e');
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('kl_admin_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // Update local notification
      final notificationIndex = _notifications.indexWhere(
        (n) => n.id == notificationId,
      );
      if (notificationIndex >= 0) {
        _notifications[notificationIndex] = _notifications[notificationIndex]
            .copyWith(isRead: true);
        notifyListeners();
      }

      print(
        'AdminNotificationProvider: Notification marked as read: $notificationId',
      );
    } catch (e) {
      print('Error marking notification as read (updating locally): $e');
      // Update locally even if database update fails
      final notificationIndex = _notifications.indexWhere(
        (n) => n.id == notificationId,
      );
      if (notificationIndex >= 0) {
        _notifications[notificationIndex] = _notifications[notificationIndex]
            .copyWith(isRead: true);
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final unreadIds = _notifications
          .where((n) => !n.isRead)
          .map((n) => n.id)
          .toList();

      if (unreadIds.isNotEmpty) {
        await _supabase
            .from('kl_admin_notifications')
            .update({'is_read': true})
            .inFilter('id', unreadIds);

        // Update local notifications
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        notifyListeners();

        print('AdminNotificationProvider: All notifications marked as read');
      }
    } catch (e) {
      print('Error marking all notifications as read (updating locally): $e');
      // Update locally even if database update fails
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('kl_admin_notifications')
          .delete()
          .eq('id', notificationId);

      // Remove from local list
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();

      print('AdminNotificationProvider: Notification deleted: $notificationId');
    } catch (e) {
      print('Error deleting notification (removing locally): $e');
      // Remove locally even if database deletion fails
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _supabase
          .from('kl_admin_notifications')
          .delete()
          .neq('id', ''); // Delete all

      _notifications.clear();
      notifyListeners();

      print('AdminNotificationProvider: All notifications cleared');
    } catch (e) {
      print('Error clearing notifications (clearing locally): $e');
      // Clear locally even if database deletion fails
      _notifications.clear();
      notifyListeners();
    }
  }

  void _clearNotifications() {
    _notifications.clear();
    _displayedNotifications.clear();
    _adminFcmToken = null;
    _error = null;
    _currentPage = 0;
    _hasMoreNotifications = true;
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    await _loadAdminNotifications();
  }
}
