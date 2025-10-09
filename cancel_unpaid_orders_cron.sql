-- SQL Script for Supabase Cron Job
-- Cancels orders with status "menunggu_pembayaran" that have no completed payments and are older than 6 hours
-- Also sends notifications to customers when orders are cancelled

-- Step 1: Update orders that meet the criteria
-- Orders with status "menunggu_pembayaran", no completed payments, and older than 6 hours
UPDATE public.kl_orders
SET
    status = 'cancelled',
    updated_at = NOW()
WHERE
    status = 'menunggu_pembayaran'
    AND NOT EXISTS (
        SELECT 1
        FROM public.kl_payments
        WHERE kl_payments.order_id = kl_orders.id
        AND kl_payments.status = 'completed' OR 'pending'
    )
    AND kl_orders.created_at < (NOW() - INTERVAL '6 hours');

-- Step 2: Restore stock quantities for cancelled orders
-- Increase product stock based on the quantities from cancelled order items
UPDATE public.kl_products
SET
    stock_quantity = stock_quantity + order_items.quantity,
    updated_at = NOW()
FROM (
    SELECT
        oi.product_id,
        SUM(oi.quantity) as quantity
    FROM public.kl_order_items oi
    INNER JOIN public.kl_orders o ON oi.order_id = o.id
    WHERE
        o.status = 'cancelled'
        AND o.updated_at >= (NOW() - INTERVAL '1 minute')
    GROUP BY oi.product_id
) order_items
WHERE kl_products.id = order_items.product_id;

-- Step 3: Insert notifications for recently cancelled orders
-- This will only affect orders cancelled in the current execution
INSERT INTO kl_customer_notifications (
    user_id,
    order_id,
    title,
    message,
    is_read,
    created_at
)
SELECT
    o.user_id,
    o.id,
    'Pesanan Dibatalkan',
    'Order dengan id: ' || o.id::text || ' telah dibatalkan oleh sistem, karena tidak ada pembayaran yang masuk selama 6 jam',
    FALSE,
    NOW()
FROM public.kl_orders o
WHERE
    o.status = 'cancelled'
    AND o.updated_at >= (NOW() - INTERVAL '1 minute')
    AND NOT EXISTS (
        SELECT 1
        FROM kl_customer_notifications n
        WHERE n.order_id = o.id
        AND n.message LIKE '%Order dengan id: ' || o.id::text || '%'
    );

-- Optional: Log the cancelled orders for monitoring purposes
-- You can create a separate table to track cancelled orders if needed
/*
INSERT INTO public.kl_order_cancellation_log (
    order_id,
    order_number,
    user_id,
    cancelled_at,
    reason
)
SELECT
    id,
    order_number,
    user_id,
    NOW(),
    'Auto-cancelled: No payment after 6 hours'
FROM public.kl_orders
WHERE
    status = 'menunggu_pembayaran'
    AND NOT EXISTS (
        SELECT 1
        FROM public.kl_payments
        WHERE kl_payments.order_id = kl_orders.id
        AND kl_payments.status = 'completed'
    )
    AND kl_orders.created_at < (NOW() - INTERVAL '6 hours');
*/