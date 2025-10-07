import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/notification_service.dart';

class CustomerNotification {
  final String id;
  final String userId;
  final String orderId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  CustomerNotification({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: json['id'],
      userId: json['user_id'],
      orderId: json['order_id'] ?? '',
      title: json['title'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_id': orderId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CustomerNotification copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return CustomerNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CustomerNotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final NotificationService _notificationService;

  List<CustomerNotification> _notifications = [];
  List<CustomerNotification> _displayedNotifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _customerFcmToken;
  int _currentPage = 0;
  static const int _pageSize = 10;
  bool _hasMoreNotifications = true;

  List<CustomerNotification> get notifications => _notifications;
  List<CustomerNotification> get displayedNotifications =>
      _displayedNotifications;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get customerFcmToken => _customerFcmToken;
  bool get hasMoreNotifications => _hasMoreNotifications;

  // Get unread notifications count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Get recent notifications (last 10) - for backward compatibility
  List<CustomerNotification> get recentNotifications =>
      _displayedNotifications.take(10).toList();

  StreamSubscription<List<dynamic>>? _notificationsSubscription;

  CustomerNotificationProvider() {
    // Initialize asynchronously to avoid blocking provider creation
    Future.microtask(() => _initializeCustomerNotifications());
  }

  Future<void> _initializeCustomerNotifications() async {
    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((event) async {
      print('CustomerNotificationProvider: Auth state changed: ${event.event}');

      if (event.event == AuthChangeEvent.signedIn &&
          event.session?.user != null) {
        if (await _isUserCustomer()) {
          print(
            'CustomerNotificationProvider: Customer signed in, initializing notifications...',
          );
          await _initializeNotifications();
        }
      } else if (event.event == AuthChangeEvent.signedOut) {
        print(
          'CustomerNotificationProvider: User signed out, clearing notifications...',
        );
        _clearNotifications();
      }
    });

    // Check if user is already authenticated and is customer
    if (await _isUserCustomer()) {
      print(
        'CustomerNotificationProvider: Customer already authenticated, initializing notifications...',
      );
      await _initializeNotifications();
    }
  }

  Future<bool> _isUserCustomer() async {
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
      return userRole == 'customer';
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  Future<void> _initializeNotifications() async {
    if (!await _isUserCustomer()) {
      print(
        'CustomerNotificationProvider: User is not customer, skipping initialization',
      );
      return;
    }

    try {
      print('CustomerNotificationProvider: Starting initialization...');

      // Initialize notification service lazily
      _notificationService = NotificationService();
      await _notificationService.initialize();
      print('CustomerNotificationProvider: Notification service initialized');

      await _loadCustomerNotifications();
      print('CustomerNotificationProvider: Notifications loaded');

      await _getOrCreateCustomerFcmToken();
      print('CustomerNotificationProvider: FCM token setup completed');

      await _setupRealtimeListener();
      print('CustomerNotificationProvider: Real-time listener setup completed');

      print(
        'CustomerNotificationProvider: Notifications initialized successfully',
      );
    } catch (e) {
      print('Error initializing customer notifications: $e');
      // Don't rethrow to prevent provider creation failure
    }
  }

  Future<void> _loadCustomerNotifications() async {
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMoreNotifications = true;
    notifyListeners();

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      try {
        final response = await _supabase
            .from('kl_customer_notifications')
            .select()
            .eq('user_id', currentUser.id)
            .order('created_at', ascending: false)
            .limit(_pageSize);

        final notificationsData = response as List;
        _notifications = notificationsData
            .map((data) => CustomerNotification.fromJson(data))
            .toList();

        _displayedNotifications = List.from(_notifications);
        _hasMoreNotifications = _notifications.length == _pageSize;
      } catch (e) {
        print('Failed to load customer notifications: $e');
        _notifications = []; // Start with empty list if database fails
        _displayedNotifications = [];
        _hasMoreNotifications = false;
      }

      print(
        'CustomerNotificationProvider: Loaded ${_notifications.length} notifications',
      );
    } catch (e) {
      _error = 'Failed to load notifications: ${e.toString()}';
      print('Error loading customer notifications: $e');
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
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final nextPage = _currentPage + 1;
      final offset = nextPage * _pageSize;

      final response = await _supabase
          .from('kl_customer_notifications')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final notificationsData = response as List;
      final newNotifications = notificationsData
          .map((data) => CustomerNotification.fromJson(data))
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
        'CustomerNotificationProvider: Loaded ${newNotifications.length} more notifications',
      );
    } catch (e) {
      print('Error loading more customer notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _getOrCreateCustomerFcmToken() async {
    try {
      print('CustomerNotificationProvider: Getting FCM token...');

      // Get current FCM token
      String? token = _notificationService.fcmToken;

      if (token == null || token.isEmpty) {
        print('CustomerNotificationProvider: FCM token is null, refreshing...');
        // Refresh token if null or empty
        await _notificationService.refreshToken();
        token = _notificationService.fcmToken;
      }

      if (token != null && token.isNotEmpty) {
        _customerFcmToken = token;

        // Store/update customer FCM token in database
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          try {
            print(
              'CustomerNotificationProvider: Storing FCM token for user: ${currentUser.id}',
            );
            await _supabase.from('kl_customer_fcm_tokens').upsert({
              'user_id': currentUser.id,
              'fcm_token': token,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id');
            print('✅ Customer FCM token stored successfully: $token');
          } catch (e) {
            print('❌ Failed to store customer FCM token: $e');
            // Continue without storing token
          }
        }

        print('✅ CustomerNotificationProvider: Customer FCM token set: $token');
      } else {
        print(
          '❌ CustomerNotificationProvider: FCM token is still null or empty after refresh',
        );
      }
    } catch (e) {
      print('❌ Error getting/creating customer FCM token: $e');
    }
  }

  Future<void> _setupRealtimeListener() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Cancel existing subscription if any
      await _notificationsSubscription?.cancel();

      // Set up real-time listener for new notifications
      _notificationsSubscription = _supabase
          .from('kl_customer_notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .listen((List<dynamic> data) {
            print(
              'Real-time customer notification update received: ${data.length} notifications',
            );

            // Update notifications list
            _notifications = data
                .map((json) => CustomerNotification.fromJson(json))
                .toList();

            // Update displayed notifications to show latest 10
            _displayedNotifications = _notifications.take(_pageSize).toList();
            _currentPage = 0;
            _hasMoreNotifications = _notifications.length > _pageSize;

            notifyListeners();
          });

      print('Real-time customer notification listener set up successfully');
    } catch (e) {
      print('Error setting up real-time listener: $e');
    }
  }

  Future<void> addNotification({
    required String userId,
    required String orderId,
    required String title,
    required String message,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'order_id': orderId,
        'title': title,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final response = await _supabase
            .from('kl_customer_notifications')
            .insert(notificationData)
            .select()
            .single();

        final newNotification = CustomerNotification.fromJson(response);

        // Add to local list
        _notifications.insert(0, newNotification);
      } catch (e) {
        print('Failed to add customer notification to database: $e');
        // Create notification locally without database
        final newNotification = CustomerNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          orderId: orderId,
          title: title,
          message: message,
          isRead: false,
          createdAt: DateTime.now(),
        );
        _notifications.insert(0, newNotification);
      }

      // Send push notification to customer
      if (_customerFcmToken != null && _customerFcmToken!.isNotEmpty) {
        print(
          'CustomerNotificationProvider: Sending push notification to customer: $_customerFcmToken',
        );
        await _notificationService.sendOrderNotificationToCustomer(
          customerToken: _customerFcmToken!,
          title: title,
          body: message,
          orderId: orderId,
        );
      } else {
        print(
          'CustomerNotificationProvider: Customer FCM token is null or empty, cannot send push notification',
        );
      }

      notifyListeners();
      print(
        'CustomerNotificationProvider: New notification added for order: $orderId',
      );
    } catch (e) {
      _error = 'Failed to add notification: ${e.toString()}';
      print('Error adding customer notification: $e');
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('kl_customer_notifications')
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
        'CustomerNotificationProvider: Notification marked as read: $notificationId',
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
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final unreadIds = _notifications
          .where((n) => !n.isRead)
          .map((n) => n.id)
          .toList();

      if (unreadIds.isNotEmpty) {
        await _supabase
            .from('kl_customer_notifications')
            .update({'is_read': true})
            .eq('user_id', currentUser.id)
            .inFilter('id', unreadIds);

        // Update local notifications
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        notifyListeners();

        print('CustomerNotificationProvider: All notifications marked as read');
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
          .from('kl_customer_notifications')
          .delete()
          .eq('id', notificationId);

      // Remove from local list
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();

      print(
        'CustomerNotificationProvider: Notification deleted: $notificationId',
      );
    } catch (e) {
      _error = 'Failed to delete notification: ${e.toString()}';
      print('Error deleting notification: $e');
      notifyListeners();
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase
          .from('kl_customer_notifications')
          .delete()
          .eq('user_id', currentUser.id);

      _notifications.clear();
      notifyListeners();

      print('CustomerNotificationProvider: All notifications cleared');
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
    _customerFcmToken = null;
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
    await _loadCustomerNotifications();
  }
}
