-- Migration: Add dropship functionality to orders table
-- Date: 2025-09-22

-- Add dropship columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS is_dropship BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS sender_name TEXT,
ADD COLUMN IF NOT EXISTS sender_phone TEXT;

-- Add index for better performance on dropship queries
CREATE INDEX IF NOT EXISTS idx_orders_is_dropship ON public.kl_orders(is_dropship);

-- Add check constraint to ensure sender info is provided when dropship is true
ALTER TABLE public.kl_orders
ADD CONSTRAINT check_dropship_sender_info
CHECK (
  (is_dropship = false) OR
  (is_dropship = true AND sender_name IS NOT NULL AND sender_phone IS NOT NULL)
);

-- Verify the columns were added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'kl_orders'
AND table_schema = 'public'
AND column_name IN ('is_dropship', 'sender_name', 'sender_phone');

-- Show existing orders (for reference)
SELECT id, order_number, is_dropship, sender_name, sender_phone
FROM public.kl_orders
ORDER BY created_at DESC
LIMIT 5;