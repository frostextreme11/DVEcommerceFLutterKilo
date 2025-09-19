# Dalanova Ecommerce App

A beautiful and modern Flutter e-commerce application for Muslim fashion, built with Supabase backend and featuring a complete shopping experience.

## 🚀 Features

### ✅ Core Features Implemented
- **🔐 Authentication System**
  - Google Sign-In integration
  - Email/password authentication
  - User registration with profile completion
  - Role-based access (Admin/Customer)
  - Forgot password functionality

- **🏠 Beautiful Homescreen**
  - Modern UI with gradient backgrounds
  - Advanced search and filtering
  - Featured products carousel
  - Best sellers section
  - Product grid with badges and discounts
  - Quick stats display

- **🛒 Complete Shopping Cart**
  - Add/remove products
  - Quantity management
  - Real-time price calculations
  - Discount calculations
  - Persistent cart storage
  - Empty cart state

- **💳 Checkout Process**
  - Order summary review
  - Shipping address management
  - Payment method selection
  - Order notes
  - Order confirmation

- **📦 Order Management**
  - Order history with tabbed interface
  - Order status tracking
  - Detailed order information
  - Order item management

- **👤 User Profile**
  - Profile information display
  - Edit profile functionality
  - User role management
  - Quick stats and navigation

- **🎨 Theme System**
  - Light, Dark, and Luxury themes
  - Persistent theme selection
  - Beautiful color schemes

### 🛠 Technical Features
- **State Management**: Provider pattern
- **Backend**: Supabase integration
- **Database**: PostgreSQL with Row Level Security
- **Authentication**: Supabase Auth
- **Navigation**: Go Router
- **Storage**: SharedPreferences for local data
- **UI**: Material Design 3 with custom components

## 📱 Screenshots

*(Add screenshots of your app here)*

## 🏗 Architecture

```
lib/
├── config/
│   └── supabase_config.dart          # Supabase configuration
├── models/
│   ├── product.dart                  # Product data model
│   └── order.dart                    # Order and order item models
├── providers/
│   ├── auth_provider.dart            # Authentication management
│   ├── cart_provider.dart            # Shopping cart logic
│   ├── products_provider.dart        # Product data & filtering
│   ├── orders_provider.dart          # Order management
│   └── theme_provider.dart           # Theme management
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart         # Login with Google/Email
│   │   ├── register_screen.dart      # User registration
│   │   └── signup_screen.dart        # Sign up screen
│   ├── home/
│   │   └── home_screen.dart          # Main app with tabs
│   ├── checkout/
│   │   └── checkout_screen.dart      # Checkout process
│   ├── orders/
│   │   └── order_history_screen.dart # Order history
│   ├── admin/
│   │   └── admin_dashboard_screen.dart # Admin panel
│   └── splash_screen.dart            # App launch screen
├── widgets/
│   ├── product_card.dart             # Product display component
│   ├── search_filter_widget.dart     # Search & filter UI
│   ├── custom_button.dart            # Reusable button component
│   └── custom_text_field.dart        # Custom text input
└── main.dart                         # App entry point
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Supabase account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/dalanova-ecommerce.git
   cd dalanova-ecommerce
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**

   a. Create a new project on [Supabase](https://supabase.com)

   b. Run the SQL schema from `database_schema.sql` in your Supabase SQL editor

   c. Update the Supabase configuration in `lib/config/supabase_config.dart`:
   ```dart
   class SupabaseConfig {
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

4. **Configure Google Sign-In (Android)**

   a. Go to [Google Cloud Console](https://console.cloud.google.com/)

   b. Create a new project or select existing one

   c. Enable Google Sign-In API

   d. Create OAuth 2.0 credentials

   e. Add your SHA-1 fingerprint from Android Studio

   f. Update the client ID in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.version"
       android:value="@integer/google_play_services_version" />
   <meta-data
       android:name="com.google.android.gms.auth.api.signin.CLIENT_ID"
       android:value="YOUR_CLIENT_ID.apps.googleusercontent.com" />
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_CLIENT_ID=your_google_client_id
```

### Build Configuration

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

## 📊 Database Schema

The app uses the following main tables:

- `kl_users` - User profiles and authentication
- `kl_products` - Product catalog
- `kl_categories` - Product categories
- `kl_orders` - Order information
- `kl_order_items` - Order line items
- `kl_banners` - Promotional banners
- `kl_promo_codes` - Discount codes

## 🔐 Security Features

- **Row Level Security (RLS)** enabled on all tables
- **JWT Authentication** with Supabase
- **Secure API calls** with proper error handling
- **Data validation** on both client and server side

## 🎨 Customization

### Themes
The app supports three themes:
- **Light Theme**: Clean and minimal
- **Dark Theme**: Easy on the eyes
- **Luxury Theme**: Elegant gold accents (default)

### Colors
Primary colors can be customized in `lib/providers/theme_provider.dart`

### Branding
Update app icons and branding in:
- `android/app/src/main/res/`
- `ios/Runner/Assets.xcassets/`

## 🧪 Testing

Run tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter drive --target=test_driver/app.dart
```

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Beautiful native apps in record time
- [Supabase](https://supabase.com/) - The open source Firebase alternative
- [Google Sign-In](https://pub.dev/packages/google_sign_in) - Google authentication
- [Provider](https://pub.dev/packages/provider) - State management

## 📞 Support

For support, email support@dalanova.com or join our Discord community.

---

**Made with ❤️ for the Muslim fashion community**
