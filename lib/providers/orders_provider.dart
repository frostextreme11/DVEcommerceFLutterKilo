import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../providers/cart_provider.dart';
import '../providers/admin_notification_provider.dart';
import '../services/notification_service.dart';

class OrdersProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Get orders by status
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _orders.where((order) => order.status == status).toList();
  }

  // Get recent orders (last 10)
  List<Order> get recentOrders => _orders.take(10).toList();

  OrdersProvider() {
    _initializeOrdersProvider();
  }

  void _initializeOrdersProvider() {
    // Listen for auth state changes to load orders when user signs in
    _supabase.auth.onAuthStateChange.listen((event) async {
      print('OrdersProvider: Auth state changed: ${event.event}');

      if (event.event == AuthChangeEvent.signedIn &&
          event.session?.user != null) {
        if (shouldLoadOrders()) {
          print('OrdersProvider: User signed in, loading orders...');
          await loadUserOrders();
        }
      } else if (event.event == AuthChangeEvent.signedOut) {
        print('OrdersProvider: User signed out, clearing orders...');
        _orders.clear();
        _isInitialized = false;
        _error = null;
        notifyListeners();
      }
    });

    // Check if user is already authenticated and load orders
    if (shouldLoadOrders()) {
      print('OrdersProvider: User already authenticated, loading orders...');
      loadUserOrders();
    }
  }

  Future<void> loadUserOrders({
    DateTime? startDate,
    DateTime? endDate,
    OrderStatus? status,
    String? searchQuery,
    bool loadTodayOnly = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Build the query with filters
      var query = _supabase.from('kl_orders').select().eq('user_id', userId);

      // Apply date filters
      if (loadTodayOnly) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(
          today.year,
          today.month,
          today.day,
          23,
          59,
          59,
        );

        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String());
      } else {
        if (startDate != null) {
          query = query.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          query = query.lte('created_at', endDate.toIso8601String());
        }
      }

      // Apply status filter
      if (status != null) {
        query = query.eq('status', status.databaseValue);
      }

      // Apply search filter (order number or receiver name)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'order_number.ilike.%$searchQuery%,receiver_name.ilike.%$searchQuery%',
        );
      }

      // Order by creation date (newest first) and execute query
      final ordersResponse = await query.order('created_at', ascending: false);
      final ordersData = ordersResponse as List;

      // Load order items for each order
      final orders = <Order>[];
      for (final orderData in ordersData) {
        final orderId = orderData['id'];

        final itemsResponse = await _supabase
            .from('kl_order_items')
            .select()
            .eq('order_id', orderId);

        final items = (itemsResponse as List)
            .map((item) => OrderItem.fromJson(item))
            .toList();

        orders.add(Order.fromJson(orderData, items));
      }

      _orders = orders;
      _isInitialized = true;
      print(
        'OrdersProvider: Successfully loaded ${orders.length} orders with filters - Today: $loadTodayOnly, Status: $status, Search: $searchQuery',
      );
    } catch (e) {
      _error = 'Failed to load orders: ${e.toString()}';
      print('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Optimized method to load today's orders (for homescreen)
  Future<void> loadTodayOrders() async {
    await loadUserOrders(loadTodayOnly: true);
  }

  // Optimized method to load orders by status
  Future<void> loadOrdersByStatus(OrderStatus status) async {
    await loadUserOrders(status: status);
  }

  // Optimized method to load orders within date range
  Future<void> loadOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await loadUserOrders(startDate: startDate, endDate: endDate);
  }

  // Optimized method to search orders by query
  Future<void> searchOrders(String query) async {
    await loadUserOrders(searchQuery: query);
  }

  // Method to load all orders (legacy support)
  Future<void> loadAllOrders() async {
    await loadUserOrders();
  }

  // Method to load finished orders (both lunas and barangDikirim)
  Future<void> loadFinishedOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Build the query for finished orders (lunas and barangDikirim)
      final finishedStatuses = [
        OrderStatus.lunas.databaseValue,
        OrderStatus.barangDikirim.databaseValue,
      ];

      var query = _supabase
          .from('kl_orders')
          .select()
          .eq('user_id', userId)
          .inFilter('status', finishedStatuses);

      // Order by creation date (newest first) and execute query
      final ordersResponse = await query.order('created_at', ascending: false);
      final ordersData = ordersResponse as List;

      // Load order items for each order
      final orders = <Order>[];
      for (final orderData in ordersData) {
        final orderId = orderData['id'];

        final itemsResponse = await _supabase
            .from('kl_order_items')
            .select()
            .eq('order_id', orderId);

        final items = (itemsResponse as List)
            .map((item) => OrderItem.fromJson(item))
            .toList();

        orders.add(Order.fromJson(orderData, items));
      }

      _orders = orders;
      _isInitialized = true;
      print(
        'OrdersProvider: Successfully loaded ${orders.length} finished orders',
      );
    } catch (e) {
      _error = 'Failed to load finished orders: ${e.toString()}';
      print('Error loading finished orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> createOrder({
    required List<CartItem> cartItems,
    required String shippingAddress,
    required String paymentMethod,
    String? notes,
    String? receiverName,
    String? receiverPhone,
    required String courierInfo,
    bool isDropship = false,
    String? senderName,
    String? senderPhone,
    double additionalCosts = 0.0,
    String? originCity,
    String? destinationCity,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Calculate subtotal amount
      final subtotalAmount = cartItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      // Generate order number first
      final orderNumber = Order.generateOrderNumber();

      // Extract last 3 digits from order number for unique identifier
      final orderNumberLast3Digits = _extractLast3DigitsFromOrderNumber(
        orderNumber,
      );

      // Calculate final total including additional costs (shipping) and unique identifier
      final totalAmount =
          subtotalAmount + additionalCosts + orderNumberLast3Digits;

      // Create order data
      final orderData = {
        'user_id': userId,
        'order_number': orderNumber,
        'status': 'menunggu_pembayaran',
        'total_amount': totalAmount,
        'subtotal_amount': subtotalAmount,
        'additional_costs': additionalCosts,
        'shipping_address': shippingAddress,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'courier_info': courierInfo,
        'notes': notes,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'is_dropship': isDropship,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'origin_city': originCity,
        'destination_city': destinationCity,
      };

      // Insert order
      final orderResponse = await _supabase
          .from('kl_orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'];

      // Create order items
      final orderItems = cartItems.map((cartItem) {
        return {
          'order_id': orderId,
          'product_id': cartItem.productId,
          'product_name': cartItem.name,
          'product_image_url': cartItem.imageUrl,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.price,
          'discount_price': cartItem.discountPrice,
          'total_price': cartItem.totalPrice,
        };
      }).toList();

      await _supabase.from('kl_order_items').insert(orderItems);

      // Create order object
      final orderItemsObjects = orderItems
          .map(
            (item) => OrderItem(
              id: '', // Will be set by database
              orderId: orderId,
              productId: item['product_id'],
              productName: item['product_name'],
              productImageUrl: item['product_image_url'],
              quantity: item['quantity'],
              unitPrice: item['unit_price'],
              discountPrice: item['discount_price'],
              totalPrice: item['total_price'],
              createdAt: DateTime.now(),
            ),
          )
          .toList();

      final order = Order(
        id: orderId,
        userId: userId,
        orderNumber: orderNumber,
        status: OrderStatus.menungguPembayaran,
        totalAmount: totalAmount,
        subtotalAmount: subtotalAmount,
        additionalCosts: additionalCosts,
        uniqueIdentifier: orderNumberLast3Digits,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        paymentStatus: PaymentStatus.pending,
        courierInfo: courierInfo,
        notes: notes,
        receiverName: receiverName,
        receiverPhone: receiverPhone,
        isDropship: isDropship,
        senderName: senderName,
        senderPhone: senderPhone,
        originCity: originCity,
        destinationCity: destinationCity,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: orderItemsObjects,
      );

      // Add to local orders list for immediate UI update
      _orders.insert(0, order);
      _isInitialized = true;

      // Send notification to admin
      await _sendNotificationToAdmin(order, cartItems);

      _isLoading = false;
      notifyListeners();

      print('OrdersProvider: Order created successfully: ${order.orderNumber}');
      return order;
    } catch (e) {
      _error = 'Failed to create order: ${e.toString()}';
      print('Error creating order: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'status': newStatus.databaseValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to update order status: ${e.toString()}';
      print('Error updating order status: $e');
      return false;
    }
  }

  Future<bool> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus,
  ) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'payment_status': newStatus.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          paymentStatus: newStatus,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to update payment status: ${e.toString()}';
      print('Error updating payment status: $e');
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    return updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  Order? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      print('Order not found in local cache: $orderId');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refreshOrders() async {
    _isInitialized = false; // Reset initialization to force reload
    await loadUserOrders();
  }

  Future<void> forceRefreshOrders() async {
    print('OrdersProvider: Force refreshing orders...');
    _isInitialized = false;
    _orders.clear();
    _error = null;
    await loadUserOrders();
  }

  Future<void> refreshOrderById(String orderId) async {
    try {
      print('OrdersProvider: Refreshing order by ID: $orderId');

      // Load specific order
      final orderResponse = await _supabase
          .from('kl_orders')
          .select()
          .eq('id', orderId)
          .single();

      // Load order items for this order
      final itemsResponse = await _supabase
          .from('kl_order_items')
          .select()
          .eq('order_id', orderId);

      final items = (itemsResponse as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();

      final updatedOrder = Order.fromJson(orderResponse, items);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = updatedOrder;
        notifyListeners();
        print(
          'OrdersProvider: Order updated successfully: ${updatedOrder.orderNumber}',
        );
      } else {
        // Add to local list if not found
        _orders.add(updatedOrder);
        notifyListeners();
        print(
          'OrdersProvider: New order added to list: ${updatedOrder.orderNumber}',
        );
      }
    } catch (e) {
      _error = 'Failed to refresh order: ${e.toString()}';
      print('Error refreshing order: $e');
      throw e; // Re-throw to let the calling method handle it
    }
  }

  bool shouldLoadOrders() {
    final currentUser = _supabase.auth.currentUser;
    return currentUser != null && !_isInitialized && !_isLoading;
  }

  double _extractLast3DigitsFromOrderNumber(String orderNumber) {
    try {
      // Extract the last part after ORD- (e.g., "545E" from "ORD-47520-545E")
      final parts = orderNumber.split('-');
      if (parts.length >= 3) {
        final lastPart = parts[1]; // "545E"
        // Extract only the numeric digits from the last part
        final digits = lastPart.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 3) {
          // Take last 3 digits and convert to double
          final last3Digits = digits.substring(digits.length - 3);
          return double.parse(
            last3Digits,
          ); // Divide by 100 to make it reasonable (e.g., 545 -> 5.45)
        }
      }
      return 0.0; // Default to 0 if extraction fails
    } catch (e) {
      print('Error extracting digits from order number: $e');
      return 0.0;
    }
  }

  Future<void> _sendNotificationToAdmin(
    Order order,
    List<CartItem> cartItems,
  ) async {
    try {
      // Get customer information
      final customerResponse = await _supabase
          .from('kl_users')
          .select('full_name')
          .eq('id', order.userId)
          .maybeSingle();

      if (customerResponse == null) {
        print('Customer not found for order ${order.id}');
        return;
      }

      final customerName = customerResponse['full_name'] ?? 'Unknown Customer';

      // Calculate total quantity
      final totalQuantity = cartItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      // Insert notification directly into admin notifications table
      // The AdminNotificationProvider will pick this up via real-time listener
      final notificationData = {
        'order_id': order.id,
        'user_id': order.userId,
        'customer_name': customerName,
        'quantity': totalQuantity,
        'total_price': order.totalAmount,
        'title': 'New Order Received',
        'message':
            'New order from $customerName: $totalQuantity item(s), Total: \$${order.totalAmount.toStringAsFixed(2)}',
        'order_date': order.createdAt.toIso8601String(),
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final insertResponse = await _supabase
          .from('kl_admin_notifications')
          .insert(notificationData)
          .select()
          .single();

      print(
        'Admin notification inserted successfully: ${insertResponse['id']}',
      );

      // Get admin FCM tokens and send push notifications
      final adminTokensResponse = await _supabase
          .from('kl_admin_fcm_tokens')
          .select('fcm_token');

      final adminTokens = (adminTokensResponse as List)
          .map((token) => token['fcm_token'] as String)
          .toList();

      // Send notification to each admin
      for (final adminToken in adminTokens) {
        try {
          // Use the notification service to send push notification
          await NotificationService().sendOrderNotificationToAdmin(
            adminToken: adminToken,
            title: 'New Order Received',
            customerName: customerName,
            quantity: totalQuantity,
            totalPrice: order.totalAmount,
            orderId: order.id,
            orderDate: order.createdAt,
          );
        } catch (e) {
          print('Error sending notification to admin $adminToken: $e');
        }
      }

      print(
        'OrdersProvider: Notifications sent to ${adminTokens.length} admin(s)',
      );
    } catch (e) {
      print('Error sending notifications to admin: $e');
      // Don't throw error here as order creation should still succeed
    }
  }
}
