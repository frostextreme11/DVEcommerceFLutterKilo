import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_products_provider.dart';
import '../../providers/admin_orders_provider.dart';
import '../../providers/admin_users_provider.dart';
import '../../providers/admin_categories_provider.dart';
import '../../providers/admin_notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import '../admin/products_admin_screen.dart';
import '../admin/orders_admin_screen.dart';
import '../admin/users_admin_screen.dart';
import '../admin/categories_admin_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardOverviewScreen(),
    const ProductsAdminScreen(),
    const OrdersAdminScreen(),
    const UsersAdminScreen(),
    const CategoriesAdminScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Products',
    'Orders',
    'Users',
    'Categories',
  ];

  @override
  void initState() {
    super.initState();
    // Load data when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final productsProvider = context.read<AdminProductsProvider>();
    final ordersProvider = context.read<AdminOrdersProvider>();
    final usersProvider = context.read<AdminUsersProvider>();
    final categoriesProvider = context.read<AdminCategoriesProvider>();

    // Load essential data only (products, users, categories)
    // Orders will be loaded only when the orders tab is accessed
    productsProvider.loadProducts();
    usersProvider.loadUsers();
    categoriesProvider.loadCategories();

    // Reset sales values to ensure clean state for tap-to-calculate
    ordersProvider.resetSalesValues();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Navigate back to cart screen when cart is empty
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // Notifications Button
            Consumer<AdminNotificationProvider>(
              builder: (context, notificationProvider, child) {
                final unreadCount = notificationProvider.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        context.push('/admin/notifications');
                      },
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Theme Settings Button
            IconButton(
              icon: const Icon(Icons.palette),
              onPressed: () {
                _showThemeSettingsDialog(context);
              },
              tooltip: 'Theme Settings',
            ),
            // Logout Button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                _showLogoutDialog(context);
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });

            // Load orders only when orders tab is selected
            if (index == 2) {
              // Orders tab index
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ordersProvider = context.read<AdminOrdersProvider>();
                if (ordersProvider.orders.isEmpty) {
                  ordersProvider.loadAllOrders();
                }
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Orders',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
            BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Categories',
            ),
          ],
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }

  void _showThemeSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Settings'),
        content: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AppTheme>(
                  title: const Text('Light Theme'),
                  value: AppTheme.light,
                  groupValue: themeProvider.currentAppTheme,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setTheme(value);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme updated to Light'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                RadioListTile<AppTheme>(
                  title: const Text('Dark Theme'),
                  value: AppTheme.dark,
                  groupValue: themeProvider.currentAppTheme,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setTheme(value);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme updated to Dark'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                RadioListTile<AppTheme>(
                  title: const Text('Luxury Theme'),
                  value: AppTheme.luxury,
                  groupValue: themeProvider.currentAppTheme,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setTheme(value);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme updated to Luxury'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().signOut();
              Navigator.pop(context);
              context.go('/login');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Logout'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

class DashboardOverviewScreen extends StatelessWidget {
  const DashboardOverviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Overview of your e-commerce platform',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Sales Statistics Cards
          Consumer<AdminOrdersProvider>(
            builder: (context, ordersProvider, child) {
              final monthlySalesText = ordersProvider.monthlySales > 0
                  ? 'Rp ${ordersProvider.monthlySales.toStringAsFixed(0)}'
                  : 'Tap to calculate';

              final yearlySalesText = ordersProvider.yearlySales > 0
                  ? 'Rp ${ordersProvider.yearlySales.toStringAsFixed(0)}'
                  : 'Tap to calculate';

              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          ordersProvider.monthlySales == 0 &&
                              !ordersProvider.isCalculatingSales
                          ? () => ordersProvider.calculateMonthlySales()
                          : null,
                      child: _buildSalesCard(
                        context,
                        'Monthly Sales',
                        monthlySalesText,
                        Icons.trending_up,
                        Colors.green,
                        isLoading:
                            ordersProvider.isCalculatingSales &&
                            ordersProvider.monthlySales == 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          ordersProvider.yearlySales == 0 &&
                              !ordersProvider.isCalculatingSales
                          ? () => ordersProvider.calculateYearlySales()
                          : null,
                      child: _buildSalesCard(
                        context,
                        'Yearly Sales',
                        yearlySalesText,
                        Icons.calendar_today,
                        Colors.blue,
                        isLoading:
                            ordersProvider.isCalculatingSales &&
                            ordersProvider.yearlySales == 0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Stats Cards
          Consumer4<
            AdminProductsProvider,
            AdminOrdersProvider,
            AdminUsersProvider,
            AdminCategoriesProvider
          >(
            builder:
                (
                  context,
                  productsProvider,
                  ordersProvider,
                  usersProvider,
                  categoriesProvider,
                  child,
                ) {
                  final totalProducts = productsProvider.products.length;
                  final totalOrders = ordersProvider.orders.length;
                  final totalUsers = usersProvider.users.length;
                  final totalCategories = categoriesProvider.categories.length;

                  // Handle order stats - show 0 if orders not loaded yet
                  final pendingOrders = ordersProvider.orders.isNotEmpty
                      ? ordersProvider
                                .getOrdersByStatus(OrderStatus.menungguOngkir)
                                .length +
                            ordersProvider
                                .getOrdersByStatus(
                                  OrderStatus.menungguPembayaran,
                                )
                                .length +
                            ordersProvider
                                .getOrdersByStatus(
                                  OrderStatus.pembayaranPartial,
                                )
                                .length
                      : 0;

                  final activeProducts = productsProvider.products
                      .where((p) => p.isActive)
                      .length;

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        context,
                        'Total Products',
                        totalProducts.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        context,
                        'Active Products',
                        activeProducts.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatCard(
                        context,
                        'Total Orders',
                        totalOrders.toString(),
                        Icons.shopping_cart,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        context,
                        'Pending Orders',
                        pendingOrders.toString(),
                        Icons.pending,
                        Colors.yellow.shade700,
                      ),
                      _buildStatCard(
                        context,
                        'Total Users',
                        totalUsers.toString(),
                        Icons.people,
                        Colors.purple,
                      ),
                      _buildStatCard(
                        context,
                        'Categories',
                        totalCategories.toString(),
                        Icons.category,
                        Colors.teal,
                      ),
                    ],
                  );
                },
          ),

          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildQuickActionButton(
          //         context,
          //         'Add Product',
          //         Icons.add,
          //         Colors.blue,
          //         () {
          //           context.push('/admin/products/add');
          //         },
          //       ),
          //     ),
          //     const SizedBox(width: 16),
          //     Expanded(
          //       child: _buildQuickActionButton(
          //         context,
          //         'Add Category',
          //         Icons.category,
          //         Colors.teal,
          //         () {
          //           context.push('/admin/categories/add');
          //         },
          //       ),
          //     ),
          //   ],
          // ),

          // const SizedBox(height: 16),

          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildQuickActionButton(
          //         context,
          //         'View Orders',
          //         Icons.list,
          //         Colors.orange,
          //         () {
          //           // Switch to orders tab and load orders
          //           final state = context
          //               .findAncestorStateOfType<_AdminDashboardScreenState>();
          //           state?.setState(() {
          //             state._selectedIndex = 2; // Orders tab index
          //           });

          //           // Load orders after switching to orders tab
          //           WidgetsBinding.instance.addPostFrameCallback((_) {
          //             final ordersProvider = context
          //                 .read<AdminOrdersProvider>();
          //             if (ordersProvider.orders.isEmpty) {
          //               ordersProvider.loadAllOrders();
          //             }
          //           });
          //         },
          //       ),
          //     ),
          //     const SizedBox(width: 16),
          //     Expanded(
          //       child: _buildQuickActionButton(
          //         context,
          //         'Manage Users',
          //         Icons.people,
          //         Colors.purple,
          //         () {
          //           // Switch to users tab
          //           final state = context
          //               .findAncestorStateOfType<_AdminDashboardScreenState>();
          //           state?.setState(() {
          //             state._selectedIndex = 3; // Users tab index
          //           });
          //         },
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 24),

          // Generate Overall Order Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/admin/overall-order-report');
              },
              icon: const Icon(Icons.analytics, size: 28),
              label: const Text(
                'Generate Overall Order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Product Quantity Ordered Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/admin/product-quantity-ordered');
              },
              icon: const Icon(Icons.table_chart, size: 28),
              label: const Text(
                'Product Quantity Ordered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Product Stock Log Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/admin/product-stock-log');
              },
              icon: const Icon(Icons.history, size: 28),
              label: const Text(
                'Product Stock Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
