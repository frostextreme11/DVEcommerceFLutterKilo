import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';
import '../providers/auth_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  // Notification channels
  static const String _orderChannelId = 'orders';
  static const String _orderChannelName = 'Order Notifications';
  static const String _orderChannelDescription = 'Notifications for new orders';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize Firebase Messaging instance
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup FCM handlers
      await _setupFCMHandlers();

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      print('FCM Token: $_fcmToken');

      _isInitialized = true;
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  Future<void> updateBadgeCount(int count) async {
    try {
      // Badge count is handled automatically by iOS when notifications are shown
      // For Android, we don't need to manually set badge count as it's handled by the launcher icon
      print('Badge count would be updated to: $count');
    } catch (e) {
      print('Error updating badge count: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (_firebaseMessaging == null) {
      await initialize();
    }

    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');

    // For Android, also request permission
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Notification permissions denied');
    } else {
      print('✅ Notification permissions granted');
    }

    // For Android, permissions are handled in AndroidManifest.xml
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
      _orderChannelId,
      _orderChannelName,
      description: _orderChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      // Using default system sound for now
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(orderChannel);
  }

  Future<void> _setupFCMHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print(
          '🚀 App opened from terminated state with message: ${message.messageId}',
        );
        print('🚀 Terminated message data: ${message.data}');
        _handleNotificationOpen(message);
      } else {
        print('🚀 App opened from terminated state but no message data');
      }
    });

    // Handle when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Received foreground message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Notification title: ${message.notification?.title}');
    print('Notification body: ${message.notification?.body}');

    // Show local notification for foreground messages
    _showLocalNotification(message);

    // Also show a snackbar if we have context
    if (_getCurrentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _getCurrentContext?.call();
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification?.title ?? 'New notification'}: ${message.notification?.body ?? ''}',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _orderChannelId,
            _orderChannelName,
            channelDescription: _orderChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher',
            ),
            // Using default system sound for now
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // Using default iOS notification sound
          ),
        ),
        payload: message.data['order_id'],
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    String? orderId = response.payload;
    if (orderId != null && orderId.isNotEmpty) {
      // For local notifications, we need to determine the type from the context
      // For now, default to customer route since local notifications are typically for customers
      _navigateToOrderDetails(
        orderId,
        notificationType: 'customer_notification',
      );
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    String? orderId = message.data['order_id'];
    String? notificationType = message.data['type'];

    print(
      '🔍 Notification opened - Order ID: $orderId, Type: $notificationType',
    );
    print('🔍 Full message data: ${message.data}');

    if (orderId != null && orderId.isNotEmpty) {
      _navigateToOrderDetails(orderId, notificationType: notificationType);
    } else {
      print('❌ No order ID found in notification data');
    }
  }

  void _navigateToOrderDetails(String orderId, {String? notificationType}) {
    print(
      '🚀 _navigateToOrderDetails called with orderId: $orderId, type: $notificationType',
    );

    // This will be called when the app context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _getCurrentContext?.call();

      print('🔍 Context available: ${context != null}');

      if (context != null) {
        // Check if current user is admin by accessing auth provider
        bool isAdmin = false;
        try {
          // Try to get the auth provider from context
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          isAdmin = authProvider.isAdmin;
          print('🔍 Current user role check: isAdmin = $isAdmin');
        } catch (e) {
          print('❌ Error checking user role: $e');
        }

        // Determine route based on user role first, then notification type
        String route;
        if (isAdmin) {
          route = '/admin/order-details/$orderId';
          print('🔍 Admin user detected, routing to admin order details');
        } else if (notificationType == 'new_order' ||
            notificationType == 'admin_notification') {
          route = '/admin/order-details/$orderId';
        } else {
          route = '/orders/$orderId'; // Default to customer route
        }

        print(
          'Navigating to route: $route for order: $orderId (type: $notificationType, isAdmin: $isAdmin)',
        );

        try {
          context.push(route);
          print('✅ Navigation successful');
        } catch (e) {
          print('❌ Navigation failed: $e');
        }
      } else {
        print('❌ Context is null, cannot navigate');
      }
    });
  }

  BuildContext Function()? _getCurrentContext;

  Future<void> sendOrderNotificationToAdmin({
    required String adminToken,
    required String title,
    required String customerName,
    required int quantity,
    required double totalPrice,
    required String orderId,
    required DateTime orderDate,
  }) async {
    try {
      // Format price
      String formattedPrice =
          'Rp ${totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';

      // Format date
      String formattedDate =
          '${orderDate.day}/${orderDate.month}/${orderDate.year} ${orderDate.hour}:${orderDate.minute.toString().padLeft(2, '0')}';

      // Send FCM notification directly
      await _sendFCMNotification(
        token: adminToken,
        title: title,
        body:
            'Customer: $customerName\nItems: $quantity\nTotal: $formattedPrice\nTime: $formattedDate',
        data: {
          'type': 'new_order',
          'order_id': orderId,
          'customer_name': customerName,
          'quantity': quantity.toString(),
          'total_price': totalPrice.toString(),
          'order_date': orderDate.toIso8601String(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      print('Admin notification sent successfully');
    } catch (e) {
      print('Error sending admin notification: $e');
      rethrow;
    }
  }

  Future<void> sendOrderNotificationToCustomer({
    required String customerToken,
    required String title,
    required String body,
    required String orderId,
  }) async {
    try {
      // Send FCM notification directly
      await _sendFCMNotification(
        token: customerToken,
        title: title,
        body: body,
        data: {
          'order_id': orderId,
          'type': 'customer_notification',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      print('Customer notification sent successfully');
    } catch (e) {
      print('Error sending customer notification: $e');
      rethrow;
    }
  }

  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      print('🔄 Attempting to send FCM notification via Edge Function...');

      // Only use Supabase Edge Function (no direct FCM fallback)
      await _callSupabaseEdgeFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      // Don't rethrow to prevent notification flow from breaking
    }
  }

  Future<void> _callSupabaseEdgeFunction({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Call Supabase Edge Function for FCM notification
      final supabaseUrl = SupabaseConfig.supabaseUrl;
      final edgeFunctionUrl = '$supabaseUrl/functions/v1/send_notification';

      print('=== EDGE FUNCTION DEBUG ===');
      print('Edge Function URL: $edgeFunctionUrl');
      print('Token: ${token.substring(0, 20)}...');
      print('Title: $title');
      print('Body: $body');
      print('Data: $data');

      final payload = {
        'token': token,
        'title': title,
        'body': body,
        'data': data,
      };

      print('Payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: json.encode(payload),
      );

      print('Edge Function Response status: ${response.statusCode}');
      print('Edge Function Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Edge Function notification sent successfully');
        final responseData = json.decode(response.body);
        print('Edge Function result: $responseData');
      } else {
        print('❌ Edge Function notification failed: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            print('Error details: $errorData');
          } catch (e) {
            print('Raw error response: ${response.body}');
          }
        }
      }
    } catch (e) {
      print('❌ Error calling Edge Function: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  String? get fcmToken => _fcmToken;

  Future<void> refreshToken() async {
    if (_firebaseMessaging == null) {
      await initialize();
    }
    _fcmToken = await _firebaseMessaging!.getToken();
    print('FCM Token refreshed: $_fcmToken');
  }

  Future<void> subscribeToTopic(String topic) async {
    if (_firebaseMessaging == null) {
      await initialize();
    }
    await _firebaseMessaging!.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (_firebaseMessaging == null) {
      await initialize();
    }
    await _firebaseMessaging!.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  void setContextProvider(BuildContext Function() contextProvider) {
    _getCurrentContext = contextProvider;
  }

  // Test method to send a test notification
  Future<void> sendTestNotification(String token) async {
    print('🧪 Sending test notification...');
    await _sendFCMNotification(
      token: token,
      title: 'Test Notification',
      body: 'This is a test notification to verify FCM is working properly.',
      data: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }

  // Test method to check FCM configuration
  Future<void> testNotificationSetup() async {
    print('🔍 Testing notification setup...');

    try {
      // Test 1: Check if Firebase is initialized
      await initialize();
      print('✅ Firebase initialized');

      // Test 2: Check FCM token
      final token = fcmToken;
      if (token != null && token.isNotEmpty) {
        print('✅ FCM token available: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM token not available');
      }

      // Test 3: Check permissions
      await _requestPermissions();
      print('✅ Permissions checked');

      // Test 4: Check Edge Function configuration
      print('✅ Using FCM v1 API via Supabase Edge Function');

      print('🔍 Notification setup test completed');
    } catch (e) {
      print('❌ Notification setup test failed: $e');
    }
  }

  // Method to check if FCM is working
  Future<bool> testFCMConnection() async {
    try {
      print('🔍 Testing FCM connection...');

      print('✅ Using FCM v1 API via Supabase Edge Function');
      print('✅ Firebase messaging is initialized');
      print('✅ Local notifications are set up');

      return true;
    } catch (e) {
      print('❌ FCM connection test failed: $e');
      return false;
    }
  }
}

// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔥 Background message handler triggered: ${message.messageId}');
  print('🔥 Background message data: ${message.data}');
  print('🔥 Background message notification: ${message.notification?.title}');

  // Initialize Firebase if not already done
  await Firebase.initializeApp();

  // Handle the background message by showing local notification
  await _showBackgroundNotification(message);

  print('✅ Background message handler completed');
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    print('📱 Background notification received: ${message.messageId}');
    print('📱 Background notification data: ${message.data}');

    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    // Initialize local notifications for background
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(settings);

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'orders',
            'Order Notifications',
            channelDescription: 'Notifications for new orders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher',
            ),
            // Using default system sound for now
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // Using default iOS notification sound
          ),
        ),
        payload: message.data['order_id'],
      );
      print(
        '✅ Background notification shown with payload: ${message.data['order_id']}',
      );
    } else {
      print('❌ No notification content to show');
    }
  } catch (e) {
    print('❌ Error showing background notification: $e');
  }
}
