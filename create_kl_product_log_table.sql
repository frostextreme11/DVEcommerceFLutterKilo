-- Migration: Create kl_product_log table for tracking product stock changes
-- Date: 2025-11-20

-- Create kl_product_log table
CREATE TABLE IF NOT EXISTS public.kl_product_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.kl_products(id) ON DELETE CASCADE,
    date_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_value INTEGER,
    new_value INTEGER NOT NULL,
    edited_by_email TEXT NOT NULL,
    edited_by_username TEXT NOT NULL
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_product_log_product_id ON public.kl_product_log(product_id);
CREATE INDEX IF NOT EXISTS idx_product_log_date_created ON public.kl_product_log(date_created DESC);
CREATE INDEX IF NOT EXISTS idx_product_log_edited_by_email ON public.kl_product_log(edited_by_email);

-- Enable Row Level Security
ALTER TABLE public.kl_product_log ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Allow admins to read all logs
CREATE POLICY "Allow admins to read product logs" ON public.kl_product_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE kl_users.id = auth.uid()
            AND kl_users.role = 'admin'
        )
    );

-- Allow admins to insert logs
CREATE POLICY "Allow admins to insert product logs" ON public.kl_product_log
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE kl_users.id = auth.uid()
            AND kl_users.role = 'admin'
        )
    );

-- Allow admins to update logs (if needed)
CREATE POLICY "Allow admins to update product logs" ON public.kl_product_log
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE kl_users.id = auth.uid()
            AND kl_users.role = 'admin'
        )
    );

-- Allow admins to delete logs (if needed)
CREATE POLICY "Allow admins to delete product logs" ON public.kl_product_log
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.kl_users
            WHERE kl_users.id = auth.uid()
            AND kl_users.role = 'admin'
        )
    );