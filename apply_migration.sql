-- Quick Migration Script for Dalanova Ecommerce
-- Copy and paste this into Supabase SQL Editor

-- Add missing columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS receiver_name TEXT,
ADD COLUMN IF NOT EXISTS receiver_phone TEXT;

-- Add additional costs and dropship columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS additional_costs DECIMAL(10,2) DEFAULT 0 CHECK (additional_costs >= 0),
ADD COLUMN IF NOT EXISTS additional_costs_notes TEXT,
ADD COLUMN IF NOT EXISTS is_dropship BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS sender_name TEXT,
ADD COLUMN IF NOT EXISTS sender_phone TEXT;

-- Add check constraint to ensure sender info is provided when dropship is true
ALTER TABLE public.kl_orders
ADD CONSTRAINT check_dropship_sender_info
CHECK (
  (is_dropship = false) OR
  (is_dropship = true AND sender_name IS NOT NULL AND sender_phone IS NOT NULL)
);

-- Update existing orders to have default value for additional_costs
UPDATE public.kl_orders
SET additional_costs = 0
WHERE additional_costs IS NULL;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'kl_orders'
AND table_schema = 'public'
AND column_name IN ('receiver_name', 'receiver_phone', 'additional_costs', 'additional_costs_notes', 'is_dropship', 'sender_name', 'sender_phone');

-- Test insert (optional - remove this in production)
-- INSERT INTO public.kl_orders (
--   user_id, order_number, status, total_amount, shipping_address,
--   payment_method, receiver_name, receiver_phone
-- ) VALUES (
--   'test-user-id', 'TEST001', 'not_paid', 100000, 'Test Address',
--   'cash', 'Test Receiver', '+62123456789'
-- ) ON CONFLICT DO NOTHING;