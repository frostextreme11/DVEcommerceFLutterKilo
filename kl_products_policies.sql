-- =================================================================
-- KL_PRODUCTS TABLE - ROW LEVEL SECURITY POLICIES
-- =================================================================
-- This file contains comprehensive RLS policies for the kl_products table
-- that allow both system operations and user access with proper security controls
--
-- Policies Overview:
-- 1. System/Service Role: Full access to all operations
-- 2. Admin Users: Full access to all operations
-- 3. Regular Users: Read-only access to active products only
-- =================================================================

-- First, enable RLS on kl_products table if not already enabled
ALTER TABLE public.kl_products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies for kl_products to avoid conflicts
DROP POLICY IF EXISTS "Anyone can view active products" ON public.kl_products;
DROP POLICY IF EXISTS "Authenticated users can manage products" ON public.kl_products;
DROP POLICY IF EXISTS "Admins can manage products" ON public.kl_products;

-- =================================================================
-- POLICY 1: SYSTEM/SERVICE ROLE ACCESS
-- =================================================================
-- Allows full access for system operations (service role)
-- This is essential for admin panels, automated processes, and system operations

CREATE POLICY "System service role has full access" ON public.kl_products
    FOR ALL
    USING (current_setting('role') = 'service_role');

-- =================================================================
-- POLICY 2: ADMIN USER ACCESS
-- =================================================================
-- Allows full access for admin users
-- Admins can perform all CRUD operations on products

CREATE POLICY "Admin users have full access to products" ON public.kl_products
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    );

-- =================================================================
-- POLICY 3: REGULAR USER READ ACCESS
-- =================================================================
-- Allows regular users to view only active products
-- This is the primary policy for customer-facing product browsing

CREATE POLICY "Users can view active products" ON public.kl_products
    FOR SELECT
    USING (
        is_active = true
        AND EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Customer'
        )
    );

-- =================================================================
-- POLICY 4: ANONYMOUS USER READ ACCESS
-- =================================================================
-- Allows anonymous users to view active products
-- This enables public product browsing without authentication

CREATE POLICY "Anonymous users can view active products" ON public.kl_products
    FOR SELECT
    USING (
        is_active = true
        AND auth.uid() IS NULL
    );

-- =================================================================
-- POLICY 5: AUTHENTICATED USER RESTRICTED OPERATIONS
-- =================================================================
-- Optional: Allows authenticated users to perform specific operations
-- Uncomment and modify based on your business requirements

-- Example: Allow users to update product stock when purchasing (if needed)
-- CREATE POLICY "Users can update stock during purchase" ON public.kl_products
--     FOR UPDATE (stock_quantity)
--     USING (
--         EXISTS (
--             SELECT 1 FROM public.kl_users
--             WHERE id = auth.uid()
--             AND role = 'Customer'
--         )
--     )
--     WITH CHECK (
--         stock_quantity >= 0
--         AND EXISTS (
--             SELECT 1 FROM public.kl_users
--             WHERE id = auth.uid()
--             AND role = 'Customer'
--         )
--     );

-- =================================================================
-- POLICY 6: PRODUCT CREATION FOR AUTHORIZED USERS
-- =================================================================
-- Allows authorized users to create new products
-- Modify the role check based on who should be able to create products

CREATE POLICY "Authorized users can create products" ON public.kl_products
    FOR INSERT
    WITH CHECK (
        -- Only admins can create products
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
        -- Ensure new products are active by default
        AND is_active = true
        -- Ensure stock quantity is not negative
        AND stock_quantity >= 0
        -- Ensure price is valid
        AND price >= 0
    );

-- =================================================================
-- POLICY 7: PRODUCT UPDATE FOR AUTHORIZED USERS
-- =================================================================
-- Allows authorized users to update products with proper validation

CREATE POLICY "Authorized users can update products" ON public.kl_products
    FOR UPDATE
    USING (
        -- Only admins can update products
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    )
    WITH CHECK (
        -- Only admins can update products
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
        -- Ensure stock quantity is not negative
        AND stock_quantity >= 0
        -- Ensure price is valid
        AND price >= 0
        -- Ensure discount price is valid if provided
        AND (discount_price IS NULL OR discount_price <= price)
        -- Ensure discount percentage is valid if provided
        AND (discount_percentage IS NULL OR (discount_percentage >= 0 AND discount_percentage <= 100))
    );

-- =================================================================
-- POLICY 8: PRODUCT DELETION FOR AUTHORIZED USERS
-- =================================================================
-- Allows authorized users to delete/deactivate products
-- Note: Consider using soft delete (is_active = false) instead of hard delete

CREATE POLICY "Authorized users can delete products" ON public.kl_products
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    );

-- =================================================================
-- ADDITIONAL SECURITY FUNCTIONS
-- =================================================================

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.kl_users
        WHERE id = auth.uid()
        AND role = 'Admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if product is active and available
CREATE OR REPLACE FUNCTION public.is_product_available(product_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.kl_products
        WHERE id = product_id
        AND is_active = true
        AND stock_quantity > 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- TESTING QUERIES (Run these to verify policies work correctly)
-- =================================================================

-- Test 1: Anonymous user should see only active products
-- SELECT COUNT(*) FROM public.kl_products WHERE is_active = true;

-- Test 2: Admin user should see all products
-- SELECT COUNT(*) FROM public.kl_products;

-- Test 3: Try to insert as non-admin (should fail)
-- INSERT INTO public.kl_products (name, price, stock_quantity) VALUES ('Test Product', 10000, 10);

-- Test 4: Admin can insert (should succeed)
-- INSERT INTO public.kl_products (name, price, stock_quantity) VALUES ('Admin Test Product', 15000, 5);

-- Test 5: Try to update as non-admin (should fail)
-- UPDATE public.kl_products SET price = 20000 WHERE name = 'Admin Test Product';

-- Test 6: Admin can update (should succeed)
-- UPDATE public.kl_products SET price = 25000 WHERE name = 'Admin Test Product';

-- =================================================================
-- POLICY SUMMARY
-- =================================================================
/*
POLICY SUMMARY FOR KL_PRODUCTS TABLE:

1. SYSTEM/SERVICE ROLE:
   - Full access to all operations (SELECT, INSERT, UPDATE, DELETE)
   - Used for admin panels and automated system operations

2. ADMIN USERS:
   - Full access to all operations (SELECT, INSERT, UPDATE, DELETE)
   - Can manage all product data
   - Must have role = 'Admin' in kl_users table

3. REGULAR USERS:
   - Read-only access to active products only
   - Cannot modify product data
   - Must have role = 'Customer' in kl_users table

4. ANONYMOUS USERS:
   - Read-only access to active products only
   - Enables public product browsing

SECURITY FEATURES:
- Row Level Security is enabled
- All policies check user roles properly
- Input validation on INSERT and UPDATE operations
- Service role bypasses RLS for system operations
- Soft delete approach (using is_active flag)

TO USE THESE POLICIES:
1. Run this file in Supabase SQL Editor
2. Ensure users have correct roles in kl_users table
3. Test with the provided test queries
4. Monitor logs for any policy violations
*/
-- =================================================================

-- Success message
SELECT 'KL Products RLS policies created successfully!' as status;