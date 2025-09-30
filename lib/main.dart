import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/products_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/admin_products_provider.dart';
import 'providers/admin_orders_provider.dart';
import 'providers/admin_users_provider.dart';
import 'providers/admin_categories_provider.dart';
import 'providers/admin_notification_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/products_admin_screen.dart';
import 'screens/admin/orders_admin_screen.dart';
import 'screens/admin/users_admin_screen.dart';
import 'screens/admin/categories_admin_screen.dart';
import 'screens/admin/product_form_screen.dart';
import 'screens/admin/order_details_screen.dart';
import 'screens/admin/user_form_screen.dart';
import 'screens/admin/category_form_screen.dart';
import 'screens/admin/admin_notifications_screen.dart';
import 'screens/checkout/checkout_screen.dart';
import 'screens/orders/order_history_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => AdminProductsProvider()),
        ChangeNotifierProvider(create: (_) => AdminOrdersProvider()),
        ChangeNotifierProvider(create: (_) => AdminUsersProvider()),
        ChangeNotifierProvider(create: (_) => AdminCategoriesProvider()),
        ChangeNotifierProvider(create: (_) => AdminNotificationProvider()),
      ],
      child: const DalanovaEcommerceApp(),
    ),
  );
}

class DalanovaEcommerceApp extends StatelessWidget {
  const DalanovaEcommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Dalanova Ecommerce',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          routerConfig: _router,
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrderHistoryScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/products',
      builder: (context, state) => const ProductsAdminScreen(),
    ),
    GoRoute(
      path: '/admin/products/add',
      builder: (context, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/admin/products/edit',
      builder: (context, state) {
        final product = state.extra as dynamic;
        return ProductFormScreen(product: product);
      },
    ),
    GoRoute(
      path: '/admin/orders',
      builder: (context, state) => const OrdersAdminScreen(),
    ),
    GoRoute(
      path: '/admin/orders/:id',
      builder: (context, state) {
        final order = state.extra as dynamic;
        return OrderDetailsScreen(order: order);
      },
    ),
    GoRoute(
      path: '/admin/order-details/:orderId',
      builder: (context, state) {
        final orderId = state.pathParameters['orderId']!;
        return OrderDetailsScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UsersAdminScreen(),
    ),
    GoRoute(
      path: '/admin/users/edit',
      builder: (context, state) {
        final user = state.extra as dynamic;
        return UserFormScreen(user: user);
      },
    ),
    GoRoute(
      path: '/admin/categories',
      builder: (context, state) => const CategoriesAdminScreen(),
    ),
    GoRoute(
      path: '/admin/categories/add',
      builder: (context, state) => const CategoryFormScreen(),
    ),
    GoRoute(
      path: '/admin/categories/edit',
      builder: (context, state) {
        final category = state.extra as dynamic;
        return CategoryFormScreen(category: category);
      },
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (context, state) => const AdminNotificationsScreen(),
    ),
  ],
  redirect: (context, state) {
    try {
      // Check if context is available and has providers
      if (context == null) {
        print('Router redirect: context is null, redirecting to splash');
        return '/splash';
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isAuthenticated;
      final isAdmin = authProvider.isAdmin;

      print('Router redirect check:');
      print('  Location: ${state.matchedLocation}');
      print('  isLoggedIn: $isLoggedIn');
      print('  isAdmin: $isAdmin');
      print('  user: ${authProvider.user?.email}');

      // Allow access to auth-related routes
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/register') {
        print('  Allowing access to auth route');
        return null;
      }

      // If not logged in, redirect to login
      if (!isLoggedIn) {
        print('  Redirecting to login (not logged in)');
        return '/login';
      }

      // If logged in as admin and trying to access home, redirect to admin
      if (isLoggedIn && isAdmin && state.matchedLocation == '/home') {
        print('  Redirecting admin to admin dashboard');
        return '/admin';
      }

      // If logged in as regular user and trying to access admin, redirect to home
      if (isLoggedIn && !isAdmin && state.matchedLocation == '/admin') {
        print('  Redirecting regular user away from admin');
        return '/home';
      }

      print('  No redirect needed');
      return null;
    } catch (e) {
      print('Router redirect error: $e');
      // If there's an error with auth provider, redirect to splash to reinitialize
      return '/splash';
    }
  },
);
