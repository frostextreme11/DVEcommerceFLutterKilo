-- Migration: Add display_order field to categories table
-- Date: 2025-09-22
-- Description: Add display_order field for category ordering functionality

-- Add display_order column to existing categories table
ALTER TABLE public.kl_categories
ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_categories_display_order ON public.kl_categories(display_order);

-- Update existing categories with sequential order values
-- This ensures existing categories get proper ordering
UPDATE public.kl_categories
SET display_order = sub.row_number
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC) as row_number
    FROM public.kl_categories
) sub
WHERE public.kl_categories.id = sub.id;

-- Update the categories provider to order by display_order
-- Note: This will be handled in the Dart code, but we can add a comment here
-- The admin categories provider should be updated to order by display_order instead of created_at