# Dalanova Ecommerce App

A modern, fully-animated Flutter e-commerce application for Muslim fashion with Google authentication, Supabase backend, and beautiful UI themes.

## 🚀 Features

### ✅ **Core Features**
- **Google Authentication** - Sign in with Google account
- **User Registration** - Complete profile with name, phone, and address
- **Product Catalog** - Browse products with search and filtering
- **Shopping Cart** - Add, remove, and manage cart items
- **Checkout Process** - Complete order with receiver information
- **Order History** - Track orders with status updates
- **PDF Invoice Generation** - Generate printable invoices

### ✅ **Admin Features**
- **Dashboard** - Sales analytics and overview
- **Product Management** - CRUD operations for products
- **Order Management** - Update order status and tracking
- **User Management** - View and manage users
- **Banner Management** - Manage promotional banners
- **Stock Management** - Stock opname and inventory control

### ✅ **UI/UX Features**
- **Three Themes** - Light, Dark, and Luxury themes
- **Fully Animated** - Smooth animations throughout the app
- **Mobile Optimized** - Responsive design for mobile devices
- **Modern Design** - Clean and beautiful interface

## 🛠️ **Setup Instructions**

### 1. **Prerequisites**
- Flutter SDK (3.9.0 or higher)
- Android Studio / VS Code
- Supabase account

### 2. **Clone and Setup**
```bash
# Clone the repository
git clone <repository-url>
cd dalanovaecomercekilo

# Install dependencies
flutter pub get
```

### 3. **Supabase Setup**

#### **Option A: Use Existing Supabase Project**
The app is configured to use the existing Supabase project:
- **Project ID**: `weagjqbymxgewtdpvagy`
- **URL**: `https://weagjqbymxgewtdpvagy.supabase.co`
- **API Key**: Already configured in `lib/config/supabase_config.dart`

#### **Option B: Create New Supabase Project**
1. Go to [Supabase](https://supabase.com)
2. Create a new project
3. Update the configuration in `lib/config/supabase_config.dart`

### 4. **Database Schema Setup**

#### **Important: Run the Migration Script**
1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Copy and paste the contents of `supabase_migration.sql`
4. Click **Run** to execute the migration

This will create all necessary tables:
- `kl_users` - User profiles
- `kl_products` - Product catalog
- `kl_orders` - Order management
- `kl_order_items` - Order line items
- `kl_categories` - Product categories
- `kl_banners` - Promotional banners
- `kl_promo_codes` - Discount codes
- And more...

### 5. **Google Sign-In Setup**

#### **Android Configuration**
1. Open `android/app/src/main/AndroidManifest.xml`
2. Add your Google Sign-In configuration:
```xml
<manifest>
    <!-- Add this meta-data tag -->
    <application>
        <meta-data
            android:name="com.google.android.gms.version"
            android:value="@integer/google_play_services_version" />
    </application>
</manifest>
```

#### **iOS Configuration**
1. Open `ios/Runner/Info.plist`
2. Add your Google Sign-In configuration:
```xml
<dict>
    <!-- Add these keys -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
            </array>
        </dict>
    </array>
</dict>
```

### 6. **Run the App**
```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
```

## 🔧 **Troubleshooting**

### **Product Card Overflow Issue**
✅ **Fixed**: Updated grid layout with:
- `childAspectRatio: 0.8` (increased from 0.75)
- `mainAxisSpacing: 16` (increased from 12)
- `crossAxisSpacing: 16` (increased from 12)

### **Checkout Database Error**
If you encounter: `"Could not find the 'receiver_name' column"`

**Quick Fix**: Run this simple script in Supabase SQL Editor:
```sql
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS receiver_name TEXT,
ADD COLUMN IF NOT EXISTS receiver_phone TEXT;
```

**Full Solution**: Run the `supabase_migration.sql` script in your Supabase SQL Editor:
1. Go to Supabase Dashboard → SQL Editor
2. Copy the entire `supabase_migration.sql` content
3. Click **Run**

**Alternative**: Use the quick migration script `apply_migration.sql` for minimal changes.

### **Layout Overflow Issues**
✅ **Fixed**: Updated layout to prevent overflow:
- Made quick stats horizontally scrollable
- Improved cart item layout with better spacing
- Added overflow handling for long text
- Reduced padding and margins where needed

The script will:
- Create all required tables
- Add missing columns (`receiver_name`, `receiver_phone`)
- Set up proper indexes and triggers
- Configure Row Level Security policies

### **Common Issues**

#### **Build Errors**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

#### **Supabase Connection Issues**
- Verify your Supabase URL and API key in `lib/config/supabase_config.dart`
- Check your internet connection
- Ensure Supabase project is active

#### **Google Sign-In Issues**
- Verify Google Cloud Console configuration
- Check SHA-1 certificate fingerprint
- Ensure OAuth 2.0 client ID is correct

## 📱 **App Architecture**

### **State Management**
- **Provider Pattern** - For state management
- **MultiProvider** - Wraps the entire app
- **ChangeNotifier** - For reactive UI updates

### **Navigation**
- **GoRouter** - Declarative routing
- **Named Routes** - Clean navigation structure
- **Route Guards** - Authentication-based routing

### **Data Flow**
```
UI → Provider → Supabase → Database
    ↓
UI ← Provider ← Supabase ← Database
```

### **Key Components**
- `AuthProvider` - Authentication management
- `CartProvider` - Shopping cart functionality
- `ThemeProvider` - Theme switching
- `ProductsProvider` - Product data management
- `OrdersProvider` - Order management

## 🎨 **Themes**

### **Light Theme** (Default)
- Clean white background
- Blue primary color (#6B46C1)
- Green secondary color (#10B981)

### **Dark Theme**
- Dark slate background (#0F172A)
- Purple primary color (#8B5CF6)
- Teal secondary color (#34D399)

### **Luxury Theme**
- Elegant gold accents (#D4AF37)
- Deep red secondary color (#B91C1C)
- Premium feel with enhanced shadows

## 📊 **Database Schema**

### **Core Tables**
- `kl_users` - User profiles and authentication
- `kl_products` - Product catalog with pricing
- `kl_orders` - Order management with status tracking
- `kl_order_items` - Order line items
- `kl_categories` - Product categorization
- `kl_banners` - Promotional content

### **Admin Tables**
- `kl_promo_codes` - Discount and promo management
- `kl_stock_opname` - Inventory management
- `kl_product_batch` - Batch product operations

## 🚀 **Deployment**

### **Android APK**
```bash
flutter build apk --release
```

### **iOS App Store**
```bash
flutter build ios --release
```

### **Web Deployment**
```bash
flutter build web --release
```

## 📝 **Development Notes**

### **Code Structure**
```
lib/
├── config/          # Configuration files
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── widgets/         # Reusable widgets
└── main.dart        # App entry point
```

### **Key Files**
- `lib/main.dart` - App initialization and routing
- `lib/config/supabase_config.dart` - Supabase configuration
- `database_schema.sql` - Database schema definition
- `supabase_migration.sql` - Database migration script

### **Best Practices**
- ✅ Clean Architecture
- ✅ Provider for state management
- ✅ Repository pattern for data
- ✅ Error handling
- ✅ Loading states
- ✅ Responsive design

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 **Support**

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the Supabase documentation

---

**🎉 Happy coding with Dalanova Ecommerce!**
