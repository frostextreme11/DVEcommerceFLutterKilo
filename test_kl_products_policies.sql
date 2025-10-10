-- =================================================================
-- TEST KL_PRODUCTS RLS POLICIES
-- =================================================================
-- This script tests the RLS policies for kl_products table
-- Run this after applying the policies to verify they work correctly
--
-- Test Scenarios:
-- 1. Anonymous user access
-- 2. Regular user access
-- 3. Admin user access
-- 4. System/service role access
-- 5. Unauthorized operation attempts
-- =================================================================

-- =================================================================
-- TEST SETUP
-- =================================================================

-- First, ensure we have test data and test users
-- Insert a test product if it doesn't exist
INSERT INTO public.kl_products (name, description, price, stock_quantity, is_active, is_featured, is_best_seller)
VALUES ('RLS Test Product', 'Test product for RLS policy testing', 50000, 10, true, false, false)
ON CONFLICT (name) DO NOTHING;

-- Ensure we have at least one admin user for testing
INSERT INTO public.kl_users (id, email, full_name, role)
VALUES ('11111111-1111-1111-1111-111111111111', 'admin@test.com', 'Test Admin', 'Admin')
ON CONFLICT (id) DO NOTHING;

-- Ensure we have at least one regular user for testing
INSERT INTO public.kl_users (id, email, full_name, role)
VALUES ('22222222-2222-2222-2222-222222222222', 'user@test.com', 'Test User', 'Customer')
ON CONFLICT (id) DO NOTHING;

-- =================================================================
-- TEST 1: ANONYMOUS USER ACCESS
-- =================================================================
-- Anonymous users should only see active products

SELECT '=== TEST 1: Anonymous User Access ===' as test_name;

-- Set role to anon (anonymous)
SET ROLE anon;

-- This should work - anonymous users can view active products
SELECT 'Anonymous user viewing active products:' as info;
SELECT COUNT(*) as active_products_count
FROM public.kl_products
WHERE is_active = true;

-- This should fail - anonymous users cannot insert products
SELECT 'Anonymous user trying to insert product (should fail):' as info;
INSERT INTO public.kl_products (name, price, stock_quantity)
VALUES ('Anonymous Test Product', 25000, 5);

-- Reset role
RESET ROLE;

-- =================================================================
-- TEST 2: REGULAR USER ACCESS
-- =================================================================
-- Regular users should only see active products and cannot modify

SELECT '=== TEST 2: Regular User Access ===' as test_name;

-- Set role to authenticated user (regular customer)
SET ROLE authenticated;

-- Set the user ID to our test customer
SELECT auth.uid() as current_uid;
-- Note: In real testing, you'd need to actually authenticate as the test user

-- This should work - authenticated users can view active products
SELECT 'Regular user viewing active products:' as info;
SELECT COUNT(*) as active_products_count
FROM public.kl_products
WHERE is_active = true;

-- This should fail - regular users cannot insert products
SELECT 'Regular user trying to insert product (should fail):' as info;
INSERT INTO public.kl_products (name, price, stock_quantity)
VALUES ('User Test Product', 30000, 3);

-- This should fail - regular users cannot update products
SELECT 'Regular user trying to update product (should fail):' as info;
UPDATE public.kl_products
SET price = 75000
WHERE name = 'RLS Test Product';

-- Reset role
RESET ROLE;

-- =================================================================
-- TEST 3: ADMIN USER ACCESS
-- =================================================================
-- Admin users should have full access to all products

SELECT '=== TEST 3: Admin User Access ===' as test_name;

-- Set role to service_role for admin operations
SET ROLE service_role;

-- This should work - admins can view all products
SELECT 'Admin viewing all products:' as info;
SELECT COUNT(*) as all_products_count FROM public.kl_products;

-- This should work - admins can insert products
SELECT 'Admin inserting new product:' as info;
INSERT INTO public.kl_products (name, price, stock_quantity, is_active)
VALUES ('Admin Test Product', 100000, 20, true);

-- This should work - admins can update products
SELECT 'Admin updating product:' as info;
UPDATE public.kl_products
SET price = 125000, description = 'Updated by admin test'
WHERE name = 'Admin Test Product';

-- This should work - admins can delete products
SELECT 'Admin deleting product:' as info;
DELETE FROM public.kl_products WHERE name = 'Admin Test Product';

-- Reset role
RESET ROLE;

-- =================================================================
-- TEST 4: VERIFY RLS IS ENABLED
-- =================================================================

SELECT '=== TEST 4: Verify RLS Status ===' as test_name;

-- Check if RLS is enabled on kl_products table
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    'RLS should be enabled (true)' as expected
FROM pg_tables
WHERE tablename = 'kl_products' AND schemaname = 'public';

-- Show all policies for kl_products
SELECT 'Current policies on kl_products table:' as info;
SELECT
    policyname as "Policy Name",
    cmd as "Command",
    permissive as "Permissive",
    'Should have 6 policies' as expected_count
FROM pg_policies
WHERE tablename = 'kl_products' AND schemaname = 'public'
ORDER BY policyname;

-- =================================================================
-- TEST 5: SECURITY FUNCTION TESTS
-- =================================================================

SELECT '=== TEST 5: Security Function Tests ===' as test_name;

-- Test the is_admin() function
SELECT
    'is_admin() function test:' as info,
    public.is_admin() as is_admin_result,
    'Should be false for anonymous' as expected;

-- Test the is_product_available() function
SELECT
    'is_product_available() function test:' as info,
    public.is_product_available((SELECT id FROM public.kl_products WHERE name = 'RLS Test Product' LIMIT 1)) as is_available,
    'Should be true for active product with stock' as expected;

-- =================================================================
-- TEST SUMMARY
-- =================================================================

SELECT '=== TEST SUMMARY ===' as summary;

-- Count total policies
SELECT
    'Total policies on kl_products:' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'kl_products' AND schemaname = 'public';

-- Show RLS status
SELECT
    'RLS enabled on kl_products:' as info,
    rowsecurity as rls_status
FROM pg_tables
WHERE tablename = 'kl_products' AND schemaname = 'public';

-- Show sample products
SELECT 'Sample products in table:' as info;
SELECT
    name,
    is_active,
    stock_quantity,
    price
FROM public.kl_products
ORDER BY name
LIMIT 5;

-- =================================================================
-- CLEANUP TEST DATA (Optional)
-- =================================================================

-- Uncomment the following lines if you want to clean up test data

-- DELETE FROM public.kl_products WHERE name = 'RLS Test Product';
-- DELETE FROM public.kl_users WHERE id = '11111111-1111-1111-1111-111111111111';
-- DELETE FROM public.kl_users WHERE id = '22222222-2222-2222-2222-222222222222';

-- =================================================================
-- FINAL RESULT
-- =================================================================

SELECT '=== RLS POLICY TESTS COMPLETED ===' as final_result;
SELECT 'All tests completed. Check the results above to verify policies are working correctly.' as instructions;