-- =================================================================
-- ENABLE RLS AND APPLY POLICIES FOR KL_PRODUCTS TABLE
-- =================================================================
-- This script enables Row Level Security on kl_products table
-- and applies the comprehensive policies defined in kl_products_policies.sql
-- =================================================================

-- Step 1: Enable RLS on kl_products table
ALTER TABLE public.kl_products ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Anyone can view active products" ON public.kl_products;
DROP POLICY IF EXISTS "Authenticated users can manage products" ON public.kl_products;
DROP POLICY IF EXISTS "Admins can manage products" ON public.kl_products;
DROP POLICY IF EXISTS "System service role has full access" ON public.kl_products;
DROP POLICY IF EXISTS "Admin users have full access to products" ON public.kl_products;
DROP POLICY IF EXISTS "Users can view active products" ON public.kl_products;
DROP POLICY IF EXISTS "Anonymous users can view active products" ON public.kl_products;
DROP POLICY IF EXISTS "Authorized users can create products" ON public.kl_products;
DROP POLICY IF EXISTS "Authorized users can update products" ON public.kl_products;
DROP POLICY IF EXISTS "Authorized users can delete products" ON public.kl_products;

-- Step 3: Apply the comprehensive policies from kl_products_policies.sql
-- (These are the same policies defined in the main policy file)

-- System/Service Role Access
CREATE POLICY "System service role has full access" ON public.kl_products
    FOR ALL
    USING (current_setting('role') = 'service_role');

-- Admin User Access
CREATE POLICY "Admin users have full access to products" ON public.kl_products
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    );

-- Regular User Read Access
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

-- Anonymous User Read Access
CREATE POLICY "Anonymous users can view active products" ON public.kl_products
    FOR SELECT
    USING (
        is_active = true
        AND auth.uid() IS NULL
    );

-- Product Creation for Authorized Users
CREATE POLICY "Authorized users can create products" ON public.kl_products
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
        AND is_active = true
        AND stock_quantity >= 0
        AND price >= 0
    );

-- Product Update for Authorized Users
CREATE POLICY "Authorized users can update products" ON public.kl_products
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
        AND stock_quantity >= 0
        AND price >= 0
        AND (discount_price IS NULL OR discount_price <= price)
        AND (discount_percentage IS NULL OR (discount_percentage >= 0 AND discount_percentage <= 100))
    );

-- Product Deletion for Authorized Users
CREATE POLICY "Authorized users can delete products" ON public.kl_products
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE id = auth.uid()
            AND role = 'Admin'
        )
    );

-- Step 4: Verify RLS is enabled and policies are applied
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    policies.polcount as policy_count
FROM pg_tables t
LEFT JOIN (
    SELECT schemaname, tablename, count(*) as polcount
    FROM pg_policies
    GROUP BY schemaname, tablename
) policies
ON t.schemaname = policies.schemaname AND t.tablename = policies.tablename
WHERE t.tablename = 'kl_products'
AND t.schemaname = 'public';

-- Step 5: Show all policies for kl_products
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'kl_products'
AND schemaname = 'public'
ORDER BY policyname;

-- Success message
SELECT 'RLS enabled and policies applied successfully for kl_products table!' as status;