-- Migration script to update order status constraint for Indonesian language support
-- Simplified version that focuses on the core issue

-- Step 1: First, map existing status values to new Indonesian values
-- Update old English statuses to new Indonesian equivalents
UPDATE public.kl_orders
SET status = CASE
  WHEN status = 'not_paid' THEN 'menunggu_ongkir'
  WHEN status = 'paid' THEN 'menunggu_pembayaran'
  WHEN status = 'processing' THEN 'pembayaran_partial'
  WHEN status = 'shipped' THEN 'lunas'
  WHEN status = 'delivered' THEN 'barang_dikirim'
  WHEN status = 'cancelled' THEN 'cancelled'
  ELSE 'menunggu_ongkir'  -- Default fallback for any other values
END
WHERE status IN ('not_paid', 'paid', 'processing', 'shipped', 'delivered', 'cancelled');

-- Step 2: Try to drop existing constraint by common names
ALTER TABLE public.kl_orders DROP CONSTRAINT IF EXISTS kl_orders_status_check;
ALTER TABLE public.kl_orders DROP CONSTRAINT IF EXISTS kl_orders_status_check1;
ALTER TABLE public.kl_orders DROP CONSTRAINT IF EXISTS kl_orders_status_check2;

-- Step 3: Try to find and drop any remaining status-related constraints using a different approach

DECLARE
    constraint_name TEXT;
BEGIN
    -- Find constraint names related to status
    SELECT INTO constraint_name
    (SELECT conname FROM pg_constraint
     WHERE conrelid = 'public.kl_orders'::regclass
     AND pg_get_constraintdef(oid) LIKE '%status%IN%'
     LIMIT 1);

    -- If found, drop it
    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.kl_orders DROP CONSTRAINT IF EXISTS ' || constraint_name;
    END IF;
END $$;

-- Step 4: Add the new constraint with Indonesian status values
ALTER TABLE public.kl_orders ADD CONSTRAINT kl_orders_status_check
CHECK (status IN ('menunggu_ongkir', 'menunggu_pembayaran', 'pembayaran_partial', 'lunas', 'barang_dikirim', 'cancelled'));

-- Step 5: Verify the migration was successful
SELECT
  'Migration completed successfully!' as status,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN status IN ('menunggu_ongkir', 'menunggu_pembayaran', 'pembayaran_partial', 'lunas', 'barang_dikirim', 'cancelled') THEN 1 END) as valid_orders
FROM public.kl_orders;

-- Step 6: Show a sample of current orders to verify status values
SELECT id, order_number, status, created_at
FROM public.kl_orders
ORDER BY created_at DESC
LIMIT 5;