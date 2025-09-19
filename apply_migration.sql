-- Quick Migration Script for Dalanova Ecommerce
-- Copy and paste this into Supabase SQL Editor

-- Add missing columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS receiver_name TEXT,
ADD COLUMN IF NOT EXISTS receiver_phone TEXT;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'kl_orders'
AND table_schema = 'public'
AND column_name IN ('receiver_name', 'receiver_phone');

-- Test insert (optional - remove this in production)
-- INSERT INTO public.kl_orders (
--   user_id, order_number, status, total_amount, shipping_address,
--   payment_method, receiver_name, receiver_phone
-- ) VALUES (
--   'test-user-id', 'TEST001', 'not_paid', 100000, 'Test Address',
--   'cash', 'Test Receiver', '+62123456789'
-- ) ON CONFLICT DO NOTHING;