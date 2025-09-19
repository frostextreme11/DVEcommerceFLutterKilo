-- Supabase Migration Script for Dalanova Ecommerce
-- Run this in Supabase SQL Editor to update the database schema

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- Create users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.kl_users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    phone_number TEXT,
    full_address TEXT,
    role TEXT NOT NULL DEFAULT 'Customer' CHECK (role IN ('Admin', 'Customer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create products table
CREATE TABLE IF NOT EXISTS public.kl_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    discount_price DECIMAL(10,2) CHECK (discount_price >= 0 AND discount_price <= price),
    discount_percentage INTEGER CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    image_url TEXT,
    category TEXT,
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    is_best_seller BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create categories table
CREATE TABLE IF NOT EXISTS public.kl_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create orders table with all required columns
CREATE TABLE IF NOT EXISTS public.kl_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.kl_users(id) ON DELETE CASCADE NOT NULL,
    order_number TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'not_paid' CHECK (status IN ('not_paid', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    shipping_address TEXT NOT NULL,
    payment_method TEXT,
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    courier_info TEXT,
    notes TEXT,
    receiver_name TEXT,
    receiver_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Add missing columns if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'kl_orders' AND column_name = 'receiver_name') THEN
        ALTER TABLE public.kl_orders ADD COLUMN receiver_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'kl_orders' AND column_name = 'receiver_phone') THEN
        ALTER TABLE public.kl_orders ADD COLUMN receiver_phone TEXT;
    END IF;
END $$;

-- Create order_items table
CREATE TABLE IF NOT EXISTS public.kl_order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.kl_orders(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.kl_products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_image_url TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    discount_price DECIMAL(10,2) CHECK (discount_price >= 0),
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create banners table
CREATE TABLE IF NOT EXISTS public.kl_banners (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    link_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create promo_codes table
CREATE TABLE IF NOT EXISTS public.kl_promo_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value > 0),
    minimum_purchase DECIMAL(10,2) DEFAULT 0,
    maximum_discount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create user_promo_usage table
CREATE TABLE IF NOT EXISTS public.kl_user_promo_usage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.kl_users(id) ON DELETE CASCADE NOT NULL,
    promo_code_id UUID REFERENCES public.kl_promo_codes(id) ON DELETE CASCADE NOT NULL,
    order_id UUID REFERENCES public.kl_orders(id) ON DELETE CASCADE,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id, promo_code_id, order_id)
);

-- Create stock_opname table
CREATE TABLE IF NOT EXISTS public.kl_stock_opname (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.kl_products(id) ON DELETE CASCADE NOT NULL,
    previous_stock INTEGER NOT NULL,
    current_stock INTEGER NOT NULL,
    adjustment_reason TEXT,
    performed_by UUID REFERENCES public.kl_users(id) ON DELETE SET NULL,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create product_batch table for batch product addition
CREATE TABLE IF NOT EXISTS public.kl_product_batch (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    batch_name TEXT NOT NULL,
    total_products INTEGER NOT NULL DEFAULT 0,
    processed_products INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    created_by UUID REFERENCES public.kl_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON public.kl_users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.kl_users(role);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.kl_products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.kl_products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON public.kl_products(is_featured);
CREATE INDEX IF NOT EXISTS idx_products_is_best_seller ON public.kl_products(is_best_seller);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.kl_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.kl_orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.kl_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.kl_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.kl_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_banners_is_active ON public.kl_banners(is_active);
CREATE INDEX IF NOT EXISTS idx_banners_display_order ON public.kl_banners(display_order);
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON public.kl_promo_codes(code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_is_active ON public.kl_promo_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_stock_opname_product_id ON public.kl_stock_opname(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_opname_performed_at ON public.kl_stock_opname(performed_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON public.kl_users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.kl_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON public.kl_products;
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.kl_products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_categories_updated_at ON public.kl_categories;
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON public.kl_categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON public.kl_orders;
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.kl_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_banners_updated_at ON public.kl_banners;
CREATE TRIGGER update_banners_updated_at BEFORE UPDATE ON public.kl_banners FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_promo_codes_updated_at ON public.kl_promo_codes;
CREATE TRIGGER update_promo_codes_updated_at BEFORE UPDATE ON public.kl_promo_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.kl_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_user_promo_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_stock_opname ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_product_batch ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users table policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.kl_users;
CREATE POLICY "Users can view their own profile" ON public.kl_users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.kl_users;
CREATE POLICY "Users can insert their own profile" ON public.kl_users
    FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.kl_users;
CREATE POLICY "Users can update their own profile" ON public.kl_users
    FOR UPDATE USING (auth.uid() = id);

-- Products table policies
DROP POLICY IF EXISTS "Anyone can view active products" ON public.kl_products;
CREATE POLICY "Anyone can view active products" ON public.kl_products
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can manage products" ON public.kl_products;
CREATE POLICY "Authenticated users can manage products" ON public.kl_products
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Categories table policies
DROP POLICY IF EXISTS "Anyone can view active categories" ON public.kl_categories;
CREATE POLICY "Anyone can view active categories" ON public.kl_categories
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can manage categories" ON public.kl_categories;
CREATE POLICY "Authenticated users can manage categories" ON public.kl_categories
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Orders table policies
DROP POLICY IF EXISTS "Users can view their own orders" ON public.kl_orders;
CREATE POLICY "Users can view their own orders" ON public.kl_orders
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own orders" ON public.kl_orders;
CREATE POLICY "Users can create their own orders" ON public.kl_orders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own orders" ON public.kl_orders;
CREATE POLICY "Users can update their own orders" ON public.kl_orders
    FOR UPDATE USING (auth.uid() = user_id);

-- Order items table policies
DROP POLICY IF EXISTS "Users can view their own order items" ON public.kl_order_items;
CREATE POLICY "Users can view their own order items" ON public.kl_order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.kl_orders
            WHERE kl_orders.id = kl_order_items.order_id
            AND kl_orders.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can create order items for their orders" ON public.kl_order_items;
CREATE POLICY "Users can create order items for their orders" ON public.kl_order_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.kl_orders
            WHERE kl_orders.id = kl_order_items.order_id
            AND kl_orders.user_id = auth.uid()
        )
    );

-- Banners table policies
DROP POLICY IF EXISTS "Anyone can view active banners" ON public.kl_banners;
CREATE POLICY "Anyone can view active banners" ON public.kl_banners
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can manage banners" ON public.kl_banners;
CREATE POLICY "Authenticated users can manage banners" ON public.kl_banners
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Promo codes table policies
DROP POLICY IF EXISTS "Anyone can view active promo codes" ON public.kl_promo_codes;
CREATE POLICY "Anyone can view active promo codes" ON public.kl_promo_codes
    FOR SELECT USING (is_active = true AND (expires_at IS NULL OR expires_at > NOW()));

DROP POLICY IF EXISTS "Authenticated users can manage promo codes" ON public.kl_promo_codes;
CREATE POLICY "Authenticated users can manage promo codes" ON public.kl_promo_codes
    FOR ALL USING (auth.uid() IS NOT NULL);

-- User promo usage policies
DROP POLICY IF EXISTS "Users can view their own promo usage" ON public.kl_user_promo_usage;
CREATE POLICY "Users can view their own promo usage" ON public.kl_user_promo_usage
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own promo usage" ON public.kl_user_promo_usage;
CREATE POLICY "Users can create their own promo usage" ON public.kl_user_promo_usage
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Stock opname policies
DROP POLICY IF EXISTS "Authenticated users can manage stock opname" ON public.kl_stock_opname;
CREATE POLICY "Authenticated users can manage stock opname" ON public.kl_stock_opname
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Product batch policies
DROP POLICY IF EXISTS "Authenticated users can manage product batches" ON public.kl_product_batch;
CREATE POLICY "Authenticated users can manage product batches" ON public.kl_product_batch
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Insert sample data
INSERT INTO public.kl_categories (name, description, is_active) VALUES
('Hijab', 'Various types of hijab for Muslim women', true),
('Abaya', 'Traditional and modern abaya designs', true),
('Dress', 'Modest dresses for various occasions', true),
('Accessories', 'Hijab accessories and complementary items', true)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.kl_products (name, description, price, category, stock_quantity, is_active, is_featured, is_best_seller, created_at, updated_at) VALUES
('Premium Chiffon Hijab', 'Soft and breathable chiffon hijab in elegant designs', 75000, 'Hijab', 50, true, true, true, NOW(), NOW()),
('Modern Abaya Dress', 'Contemporary abaya with modern cuts and designs', 250000, 'Abaya', 25, true, true, false, NOW(), NOW()),
('Elegant Maxi Dress', 'Flowing maxi dress perfect for special occasions', 180000, 'Dress', 30, true, false, true, NOW(), NOW()),
('Hijab Pins Set', 'Beautiful hijab pins and brooches', 25000, 'Accessories', 100, true, false, false, NOW(), NOW()),
('Silk Scarf Collection', 'Premium silk scarves in various colors', 95000, 'Hijab', 75, true, true, false, NOW(), NOW()),
('Embroidered Abaya', 'Beautifully embroidered traditional abaya', 320000, 'Abaya', 15, true, false, true, NOW(), NOW())
ON CONFLICT DO NOTHING;

INSERT INTO public.kl_banners (title, description, image_url, is_active, display_order, created_at, updated_at) VALUES
('Welcome to Dalanova', 'Discover premium Muslim fashion', 'https://example.com/banner1.jpg', true, 1, NOW(), NOW()),
('New Collection', 'Explore our latest arrivals', 'https://example.com/banner2.jpg', true, 2, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Verify the schema is correct
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name LIKE 'kl_%'
ORDER BY table_name, ordinal_position;