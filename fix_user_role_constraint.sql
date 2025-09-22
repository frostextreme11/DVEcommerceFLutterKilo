-- Migration: Fix user role constraint to accept lowercase values
-- Date: 2025-09-22
-- Description: Update the kl_users table role constraint to accept 'admin' and 'customer' instead of 'Admin' and 'Customer'
-- This fixes the issue where role updates were failing due to case mismatch

-- First, let's check what role values currently exist
-- SELECT DISTINCT role FROM public.kl_users;

-- Temporarily drop the constraint to allow updates
ALTER TABLE public.kl_users
DROP CONSTRAINT IF EXISTS kl_users_role_check;

-- Update the default value to use lowercase
ALTER TABLE public.kl_users
ALTER COLUMN role SET DEFAULT 'customer';

-- Update existing users with capitalized roles to lowercase
UPDATE public.kl_users
SET role = LOWER(role)
WHERE role IN ('Admin', 'Customer');

-- Fix any users with invalid role values (set them to 'customer')
UPDATE public.kl_users
SET role = 'customer'
WHERE role NOT IN ('admin', 'customer');

-- Now recreate the constraint with lowercase values
ALTER TABLE public.kl_users
ADD CONSTRAINT kl_users_role_check CHECK (role IN ('admin', 'customer'));

-- Update the is_user_admin function to check for lowercase 'admin'
CREATE OR REPLACE FUNCTION is_user_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.kl_users
        WHERE id = user_id AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;