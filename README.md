# Dalanova Ecommerce App

A comprehensive Flutter e-commerce application for Muslim fashion with modern design, beautiful animations, and full functionality.

## Features

### Authentication
- **Google Sign-In**: Seamless authentication with Google accounts
- **Email/Password**: Traditional email and password registration and login
- **User Profiles**: Complete user profile management with personal information
- **Role-based Access**: Admin and Customer roles with different permissions

### E-commerce Features
- **Product Catalog**: Browse products with search and filtering
- **Shopping Cart**: Add, remove, and manage cart items with persistence
- **Product Details**: View detailed product information with images
- **Order Management**: Complete order lifecycle with status tracking
- **Invoice Generation**: PDF invoice generation for orders
- **Discount System**: Support for discount codes and promotional pricing

### Admin Dashboard
- **Sales Analytics**: View sales data, order statistics, and revenue
- **Product Management**: CRUD operations for products
- **User Management**: Manage users and assign admin roles
- **Order Management**: View and update order statuses
- **Banner Management**: Manage promotional banners
- **Stock Management**: Track and update product inventory
- **Category Management**: Organize products by categories

### UI/UX Features
- **Three Themes**: Light, Dark, and Luxury themes (default)
- **Responsive Design**: Optimized for mobile devices
- **Beautiful Animations**: Smooth transitions and interactive elements
- **Modern Design**: Clean, contemporary interface design

## Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Authentication, Storage)
- **State Management**: Provider
- **Navigation**: Go Router
- **PDF Generation**: pdf package
- **Image Handling**: Cached Network Image
- **Local Storage**: Shared Preferences

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Android Studio or VS Code
- Supabase account

### 1. Clone the Repository
```bash
git clone <repository-url>
cd dalanovaecomercekilo
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Supabase

#### Create a Supabase Project
1. Go to [Supabase](https://supabase.com) and create a new project
2. Wait for the project to be fully initialized

#### Database Setup
1. Go to your Supabase project's SQL Editor
2. Copy and paste the entire content from `database_schema.sql`
3. Execute the SQL script to create all tables, policies, and sample data

#### Create Admin User
Since users are created through the authentication system, you'll need to:
1. Register a user through the app using either Google Sign-In or Email/Password
2. Go to your Supabase Dashboard → Table Editor → kl_users
3. Find the user you just created and change their `role` from 'Customer' to 'Admin'
4. This user will now have admin access to the dashboard

#### Authentication Configuration
1. In your Supabase dashboard, go to Authentication > Settings
2. Configure the following:
   - **Site URL**: `http://localhost:3000` (for development)
   - **Redirect URLs**: Add your app's redirect URLs
3. Enable Google OAuth:
   - Go to Authentication > Providers
   - Enable Google provider
   - Add your Google OAuth credentials

#### Update Configuration
1. Open `lib/config/supabase_config.dart`
2. Update the values with your Supabase project details:
   ```dart
   static const String supabaseUrl = 'https://your-project-id.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key';
   static const String supabaseServiceRoleKey = 'your-service-role-key';
   ```

### 4. Google Sign-In Setup (Android)

#### For Android:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials
5. Add your package name: `com.example.dalanovaecomercekilo`
6. Copy the SHA-1 fingerprint from your development keystore
7. Download the `google-services.json` file
8. Place it in `android/app/google-services.json`

#### Update Android Configuration:
1. Open `android/app/build.gradle`
2. Add your Google Sign-In configuration

### 5. Run the Application
```bash
flutter run
```

## Database Schema

The application uses the following main tables (all prefixed with `kl_`):

### Core Tables
- `kl_users` - User profiles and authentication data
- `kl_products` - Product catalog with pricing and inventory
- `kl_categories` - Product categories
- `kl_orders` - Customer orders
- `kl_order_items` - Individual order line items

### Administrative Tables
- `kl_banners` - Promotional banners
- `kl_promo_codes` - Discount codes and promotions
- `kl_user_promo_usage` - Track promo code usage
- `kl_stock_opname` - Stock inventory management
- `kl_product_batch` - Batch product operations

## User Roles

### Customer
- Browse products and categories
- Add items to cart
- Place orders
- View order history
- Manage profile

### Admin
- All customer permissions plus:
- Manage products (CRUD)
- Manage categories
- View all orders and update status
- Manage users and assign roles
- Manage banners and promotions
- View analytics and reports
- Manage inventory

## API Usage

### Authentication
```dart
// Sign in with Google
await authProvider.signInWithGoogle();

// Sign in with Email/Password
await authProvider.signInWithEmail(email, password);

// Sign up with Email/Password
await authProvider.signUpWithEmail(email, password);

// Complete registration
await authProvider.completeRegistration(
  fullName: 'John Doe',
  phoneNumber: '+1234567890',
  fullAddress: '123 Main St, City, Country'
);
```

### Product Management
```dart
// Get products
final products = await supabase.from('kl_products').select();

// Create product
await supabase.from('kl_products').insert({
  'name': 'Product Name',
  'price': 100.00,
  'category': 'Category',
  'stock_quantity': 50,
});

// Update product
await supabase.from('kl_products').update({
  'price': 120.00,
}).eq('id', productId);
```

### Order Management
```dart
// Create order
await supabase.from('kl_orders').insert({
  'user_id': userId,
  'total_amount': 250.00,
  'status': 'paid',
});

// Update order status
await supabase.from('kl_orders').update({
  'status': 'shipped',
}).eq('id', orderId);
```

## File Structure

```
lib/
├── config/
│   └── supabase_config.dart          # Supabase configuration
├── providers/
│   ├── auth_provider.dart            # Authentication state management
│   ├── theme_provider.dart           # Theme management
│   └── cart_provider.dart            # Shopping cart management
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart         # Login screen
│   │   ├── signup_screen.dart        # Sign up screen
│   │   └── register_screen.dart      # Profile completion screen
│   ├── home/
│   │   └── home_screen.dart          # Main customer screen
│   ├── admin/
│   │   └── admin_dashboard_screen.dart # Admin dashboard
│   └── splash_screen.dart            # Splash screen
├── widgets/
│   ├── custom_button.dart            # Reusable button widget
│   └── custom_text_field.dart        # Reusable text field widget
└── main.dart                         # Application entry point

database_schema.sql                   # Complete database schema
```

## Development Guidelines

### Code Style
- Follow Flutter's official style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### State Management
- Use Provider for state management
- Separate business logic from UI
- Keep providers focused on specific domains

### Database Operations
- Always use the `kl_` prefixed table names
- Implement proper error handling
- Use transactions for complex operations
- Follow RLS policies for data access

### UI/UX Guidelines
- Maintain consistent spacing and colors
- Use the theme system for styling
- Implement proper loading states
- Add smooth animations for better UX

## Deployment

### Android APK Build
```bash
flutter build apk --release
```

### Web Build
```bash
flutter build web
```

### iOS Build
```bash
flutter build ios
```

## Troubleshooting

### Common Issues

1. **Database Schema Execution Errors**
   - **"permission denied to set parameter app.jwt_secret"**: This line has been removed from the schema as it requires superuser privileges
   - **"violates foreign key constraint"**: Ensure all foreign key references use the correct `kl_` prefixed table names
   - **Sample user insert fails**: Users must be created through the app's authentication system, not directly in the database

2. **Supabase Connection Issues**
   - Verify your Supabase URL and keys in `lib/config/supabase_config.dart`
   - Check network connectivity
   - Ensure RLS policies are correctly configured

3. **Google Sign-In Issues**
   - Verify Google OAuth credentials in Supabase Dashboard
   - Check package name and SHA-1 fingerprint
   - Ensure google-services.json is properly configured (Android only)

4. **Authentication Issues**
   - **No Sign Up button visible**: Use the "Sign Up" link at the bottom of the login screen
   - **Email/Password registration fails**: Ensure email authentication is enabled in Supabase Dashboard → Authentication → Providers
   - **Google Sign-In fails**: Check OAuth configuration in Supabase and Google Cloud Console, ensure google-services.json is properly configured
   - **Email login fails**: Ensure email/password authentication is enabled in Supabase, check console for detailed error messages
   - **First user not admin**: Register through the app, then manually change role to 'Admin' in Supabase Table Editor → kl_users
   - **Profile completion fails**: Check that all required fields are filled and database schema is properly executed

5. **Database Errors**
   - Check table names have `kl_` prefix
   - Verify user permissions and RLS policies
   - Check foreign key relationships

6. **Build Issues**
   - Run `flutter clean` and `flutter pub get`
   - Check Flutter and Dart versions
   - Verify all dependencies are compatible

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation for common solutions

---

**Dalanova Ecommerce App** - Bringing beautiful Muslim fashion to your fingertips with modern technology and elegant design.
