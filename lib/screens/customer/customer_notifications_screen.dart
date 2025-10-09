import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_notification_provider.dart';
import '../../models/order.dart';
import '../orders/order_tracking_screen.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh notifications when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerNotificationProvider>().refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Navigate back to cart screen when cart is empty
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifikasi'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          actions: [
            Consumer<CustomerNotificationProvider>(
              builder: (context, notificationProvider, child) {
                return TextButton(
                  onPressed: notificationProvider.displayedNotifications.isEmpty
                      ? null
                      : () {
                          context
                              .read<CustomerNotificationProvider>()
                              .markAllAsRead();
                        },
                  child: const Text(
                    'Tandai Semua Sudah Dibaca',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<CustomerNotificationProvider>(
          builder: (context, notificationProvider, child) {
            if (notificationProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = notificationProvider.displayedNotifications;

            if (notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Notifications will appear here when you receive updates',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount:
                  notifications.length +
                  (notificationProvider.hasMoreNotifications ? 1 : 0),
              itemBuilder: (context, index) {
                // Load more item
                if (index == notifications.length &&
                    notificationProvider.hasMoreNotifications) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: notificationProvider.isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () {
                              notificationProvider.loadMoreNotifications();
                            },
                            child: const Text('Load More Notifications'),
                          ),
                  );
                }

                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    context
                        .read<CustomerNotificationProvider>()
                        .deleteNotification(notification.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification deleted'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notification.isRead
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                        child: Icon(
                          notification.isRead
                              ? Icons.notifications
                              : Icons.notifications_active,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${notification.createdAt.day}/${notification.createdAt.month}/${notification.createdAt.year} ${notification.createdAt.hour}:${notification.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        // Mark as read when tapped
                        if (!notification.isRead) {
                          context
                              .read<CustomerNotificationProvider>()
                              .markAsRead(notification.id);
                        }

                        // Navigate to order tracking screen if notification has order_id
                        if (notification.orderId.isNotEmpty) {
                          print(
                            'Navigating to order tracking screen for order: ${notification.orderId}',
                          );
                          try {
                            // Use push to maintain proper navigation stack for back button functionality
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => OrderTrackingScreen(
                                  orderId: notification.orderId,
                                ),
                              ),
                            );
                          } catch (e) {
                            print('Error navigating to order tracking: $e');
                            // Fallback: try using go router if push fails
                            try {
                              context.push('/orders/${notification.orderId}');
                            } catch (e2) {
                              print('Both navigation methods failed: $e2');
                            }
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: Consumer<CustomerNotificationProvider>(
          builder: (context, notificationProvider, child) {
            return FloatingActionButton(
              onPressed: () {
                context
                    .read<CustomerNotificationProvider>()
                    .refreshNotifications();
              },
              child: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            );
          },
        ),
      ),
    );
  }
}
