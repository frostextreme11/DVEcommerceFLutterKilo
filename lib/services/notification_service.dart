import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

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
        _handleNotificationOpen(message);
      }
    });

    // Handle when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    _showLocalNotification(message);
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
      _navigateToOrderDetails(orderId);
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    String? orderId = message.data['order_id'];
    if (orderId != null && orderId.isNotEmpty) {
      _navigateToOrderDetails(orderId);
    }
  }

  void _navigateToOrderDetails(String orderId) {
    // This will be called when the app context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _getCurrentContext?.call();
      if (context != null) {
        context.push('/admin/order-details/$orderId');
      }
    });
  }

  BuildContext Function()? _getCurrentContext;

  Future<void> sendOrderNotificationToAdmin({
    required String adminToken,
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

      // Send notification via FCM
      await _sendFCMNotification(
        token: adminToken,
        title: 'New Order Received!',
        body:
            'Customer: $customerName\nItems: $quantity\nTotal: $formattedPrice\nTime: $formattedDate',
        data: {
          'type': 'new_order',
          'order_id': orderId,
          'customer_name': customerName,
          'quantity': quantity.toString(),
          'total_price': totalPrice.toString(),
          'order_date': orderDate.toIso8601String(),
        },
      );

      print('Order notification sent to admin successfully');
    } catch (e) {
      print('Error sending order notification: $e');
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
      // Call Supabase Edge Function instead of direct FCM
      await _callEdgeFunctionForNotification(
        adminToken: token,
        customerName: data['customer_name'] ?? 'Unknown',
        quantity: int.parse(data['quantity'] ?? '0'),
        totalPrice: double.parse(data['total_price'] ?? '0'),
        orderId: data['order_id'] ?? '',
        orderDate: data['order_date'] ?? DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error sending FCM notification via Edge Function: $e');
      rethrow;
    }
  }

  Future<void> _callEdgeFunctionForNotification({
    required String adminToken,
    required String customerName,
    required int quantity,
    required double totalPrice,
    required String orderId,
    required String orderDate,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'send_notification',
        body: {
          'adminToken': adminToken,
          'customerName': customerName,
          'quantity': quantity,
          'totalPrice': totalPrice,
          'orderId': orderId,
          'orderDate': orderDate,
        },
      );

      if (response.status == 200 && response.data['success'] == true) {
        print('Notification sent successfully via Edge Function');
        print('Edge Function Response: ${response.data}');
      } else {
        print('Edge Function returned error: ${response.data}');
        throw Exception('Edge Function failed to send notification');
      }
    } catch (e) {
      print('Error calling Edge Function: $e');
      rethrow;
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
}

// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');

  // Initialize Firebase if not already done
  await Firebase.initializeApp();

  // Handle the background message by showing local notification
  await _showBackgroundNotification(message);

  print('Background message data: ${message.data}');
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
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
    }
  } catch (e) {
    print('Error showing background notification: $e');
  }
}
