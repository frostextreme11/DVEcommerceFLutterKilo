-- Fix User Roles Case Sensitivity
-- This script updates any user roles that are in the wrong case

-- Update any 'Admin' (capital A) to 'admin' (lowercase)
UPDATE public.kl_users
SET role = 'admin'
WHERE role = 'Admin';

-- Update any 'Customer' (capital C) to 'customer' (lowercase)
UPDATE public.kl_users
SET role = 'customer'
WHERE role = 'Customer';

-- Verify the changes
SELECT id, email, role, created_at
FROM public.kl_users
WHERE role IN ('admin', 'customer')
ORDER BY created_at DESC
LIMIT 10;