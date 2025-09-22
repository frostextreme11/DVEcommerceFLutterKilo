import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';

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

      if (event.event == AuthChangeEvent.signedIn && event.session?.user != null) {
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

  Future<void> loadUserOrders() async {
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

      // Load orders
      final ordersResponse = await _supabase
          .from('kl_orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

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
      print('OrdersProvider: Successfully loaded ${orders.length} orders');
    } catch (e) {
      _error = 'Failed to load orders: ${e.toString()}';
      print('Error loading orders: $e');
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
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Calculate total amount
      final totalAmount = cartItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      // Generate order number
      final orderNumber = Order.generateOrderNumber();

      // Create order data
      final orderData = {
        'user_id': userId,
        'order_number': orderNumber,
        'status': 'not_paid',
        'total_amount': totalAmount,
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

      await _supabase
          .from('kl_order_items')
          .insert(orderItems);

      // Create order object
      final orderItemsObjects = orderItems.map((item) => OrderItem(
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
      )).toList();

      final order = Order(
        id: orderId,
        userId: userId,
        orderNumber: orderNumber,
        status: OrderStatus.notPaid,
        totalAmount: totalAmount,
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: orderItemsObjects,
      );

      // Add to local orders list for immediate UI update
      _orders.insert(0, order);
      _isInitialized = true;

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
            'status': newStatus.toString().split('.').last,
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

  Future<bool> updatePaymentStatus(String orderId, PaymentStatus newStatus) async {
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
        _orders[orderIndex] = _orders[orderIndex].copyWith(paymentStatus: newStatus);
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
    return _orders.firstWhere(
      (order) => order.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );
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
        print('OrdersProvider: Order updated successfully: ${updatedOrder.orderNumber}');
      } else {
        print('OrdersProvider: Order not found in local list: $orderId');
      }
    } catch (e) {
      _error = 'Failed to refresh order: ${e.toString()}';
      print('Error refreshing order: $e');
    }
  }

  bool shouldLoadOrders() {
    final currentUser = _supabase.auth.currentUser;
    return currentUser != null && !_isInitialized && !_isLoading;
  }
}