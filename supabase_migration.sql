-- Migration: Add additional costs to orders table
-- Date: 2025-09-21

-- Add additional_costs and additional_costs_notes columns to kl_orders table
ALTER TABLE public.kl_orders
ADD COLUMN IF NOT EXISTS additional_costs DECIMAL(10,2) DEFAULT 0 CHECK (additional_costs >= 0),
ADD COLUMN IF NOT EXISTS additional_costs_notes TEXT;

-- Add index for better performance on additional_costs
CREATE INDEX IF NOT EXISTS idx_orders_additional_costs ON public.kl_orders(additional_costs);

-- Update existing orders to have default value for additional_costs
UPDATE public.kl_orders
SET additional_costs = 0
WHERE additional_costs IS NULL;