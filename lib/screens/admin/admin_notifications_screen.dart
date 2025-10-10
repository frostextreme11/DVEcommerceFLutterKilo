import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_notification_provider.dart';
import '../../providers/admin_orders_provider.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  String _currentFilter = 'All'; // 'All', 'Order', 'Payment'

  @override
  void initState() {
    super.initState();
    // Refresh notifications when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNotificationProvider>().refreshNotifications();
    });
  }

  List<AdminNotification> _getFilteredNotifications(
    List<AdminNotification> notifications,
  ) {
    if (_currentFilter == 'All') {
      return notifications;
    }
    return notifications
        .where(
          (notification) =>
              notification.type.toLowerCase() == _currentFilter.toLowerCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filter dropdown
          Consumer<AdminNotificationProvider>(
            builder: (context, notificationProvider, child) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: DropdownButton<String>(
                  value: _currentFilter,
                  dropdownColor: Theme.of(context).primaryColor,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: Container(),
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  items: ['All', 'Payment'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentFilter = newValue;
                      });
                    }
                  },
                ),
              );
            },
          ),
          // Mark all read button
          Consumer<AdminNotificationProvider>(
            builder: (context, notificationProvider, child) {
              return TextButton(
                onPressed: notificationProvider.displayedNotifications.isEmpty
                    ? null
                    : () {
                        context
                            .read<AdminNotificationProvider>()
                            .markAllAsRead();
                      },
                child: const Text(
                  'Mark All Read',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminNotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allNotifications = notificationProvider.displayedNotifications;
          final notifications = _getFilteredNotifications(allNotifications);

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    _currentFilter == 'All'
                        ? 'No notifications yet'
                        : 'No ${_currentFilter.toLowerCase()} notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _currentFilter == 'All'
                        ? 'Notifications will appear here when customers place orders'
                        : '${_currentFilter} notifications will appear here',
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
                  context.read<AdminNotificationProvider>().deleteNotification(
                    notification.id,
                  );
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
                        if (notification.type == 'order') ...[
                          Text(
                            'Customer: ${notification.customerName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Items: ${notification.quantity} | Total: Rp ${notification.totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        Text(
                          'Order ID: ${notification.orderId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${notification.orderDate.day}/${notification.orderDate.month}/${notification.orderDate.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${notification.orderDate.hour}:${notification.orderDate.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      // Mark as read when tapped (before navigation)
                      if (!notification.isRead) {
                        await context
                            .read<AdminNotificationProvider>()
                            .markAsRead(notification.id);
                      }

                      // Navigate after marking as read
                      if (context.mounted) {
                        context.push(
                          '/admin/order-details/${notification.orderId}',
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<AdminNotificationProvider>(
        builder: (context, notificationProvider, child) {
          return FloatingActionButton(
            onPressed: () {
              context.read<AdminNotificationProvider>().refreshNotifications();
            },
            child: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          );
        },
      ),
    );
  }
}
