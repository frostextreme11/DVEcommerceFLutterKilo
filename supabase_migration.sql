-- Migration: Add additional costs and dropship functionality to orders table
-- Date: 2025-09-22

-- Add additional_costs and additional_costs_notes columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS additional_costs DECIMAL(10,2) DEFAULT 0 CHECK (additional_costs >= 0),
ADD COLUMN IF NOT EXISTS additional_costs_notes TEXT,
ADD COLUMN IF NOT EXISTS is_dropship BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS sender_name TEXT,
ADD COLUMN IF NOT EXISTS sender_phone TEXT;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_additional_costs ON public.kl_orders(additional_costs);
CREATE INDEX IF NOT EXISTS idx_orders_is_dropship ON public.kl_orders(is_dropship);

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