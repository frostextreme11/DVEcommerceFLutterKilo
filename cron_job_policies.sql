-- =================================================================
-- CRON JOB POLICIES FOR AUTOMATED ORDER CANCELLATION
-- =================================================================
-- This file contains additional RLS policies specifically for cron jobs
-- that need to cancel unpaid orders and restore product stock quantities
--
-- Cron Job Operations:
-- 1. Cancel orders without payment after 24 hours
-- 2. Restore product stock quantities from cancelled orders
-- 3. Send notifications to customers about cancelled orders
-- =================================================================

-- =================================================================
-- ADDITIONAL POLICIES FOR ORDERS TABLE (CRON JOB ACCESS)
-- =================================================================

-- Allow system/service role to cancel orders for cron jobs
CREATE POLICY "System can cancel unpaid orders" ON public.kl_orders
    FOR UPDATE
    USING (current_setting('role') = 'service_role');

-- Allow system/service role to select orders for cron job processing
CREATE POLICY "System can select orders for cron processing" ON public.kl_orders
    FOR SELECT
    USING (current_setting('role') = 'service_role');

-- =================================================================
-- ADDITIONAL POLICIES FOR PRODUCTS TABLE (CRON JOB ACCESS)
-- =================================================================

-- Allow system/service role to update product stock during order cancellation
CREATE POLICY "System can restore product stock from cancelled orders" ON public.kl_products
    FOR UPDATE
    USING (current_setting('role') = 'service_role');

-- Allow system/service role to select products for stock restoration
CREATE POLICY "System can select products for stock restoration" ON public.kl_products
    FOR SELECT
    USING (current_setting('role') = 'service_role');

-- =================================================================
-- ADDITIONAL POLICIES FOR ORDER ITEMS TABLE (CRON JOB ACCESS)
-- =================================================================

-- Allow system/service role to select order items for stock calculation
CREATE POLICY "System can select order items for stock calculation" ON public.kl_order_items
    FOR SELECT
    USING (current_setting('role') = 'service_role');

-- =================================================================
-- ADDITIONAL POLICIES FOR CUSTOMER NOTIFICATIONS TABLE (CRON JOB ACCESS)
-- =================================================================

-- Allow system/service role to insert notifications for cancelled orders
CREATE POLICY "System can insert notifications for cancelled orders" ON public.kl_customer_notifications
    FOR INSERT
    WITH CHECK (current_setting('role') = 'service_role');

-- Allow system/service role to select notifications for duplicate checking
CREATE POLICY "System can select notifications for duplicate checking" ON public.kl_customer_notifications
    FOR SELECT
    USING (current_setting('role') = 'service_role');

-- =================================================================
-- STORED PROCEDURE FOR CRON JOB
-- =================================================================
-- Creates a stored procedure that encapsulates the entire cron job logic
-- This makes it easier to call from external systems and provides better error handling

CREATE OR REPLACE FUNCTION public.cancel_unpaid_orders_cron_job()
RETURNS TABLE (
    cancelled_orders_count INTEGER,
    restored_products_count INTEGER,
    notifications_sent INTEGER,
    errors TEXT
) AS $$
DECLARE
    cancelled_count INTEGER := 0;
    restored_count INTEGER := 0;
    notifications_count INTEGER := 0;
    error_message TEXT := '';
BEGIN
    -- Log the start of cron job execution
    RAISE NOTICE 'Starting cron job execution at %', NOW();

    -- Step 1: Cancel orders that meet the criteria
    -- Orders with status "menunggu_pembayaran", no completed payments, and older than 24 hours
    BEGIN
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
                AND kl_payments.status IN ('completed', 'pending')
            )
            AND kl_orders.created_at < (NOW() - INTERVAL '24 hours');

        GET DIAGNOSTICS cancelled_count = ROW_COUNT;
        RAISE NOTICE 'Cancelled % orders', cancelled_count;

    EXCEPTION WHEN OTHERS THEN
        error_message := error_message || 'Error cancelling orders: ' || SQLERRM || '; ';
        RAISE NOTICE 'Error cancelling orders: %', SQLERRM;
    END;

    -- Step 2: Restore stock quantities for cancelled orders
    -- Increase product stock based on the quantities from cancelled order items
    BEGIN
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

        GET DIAGNOSTICS restored_count = ROW_COUNT;
        RAISE NOTICE 'Restored stock for % products', restored_count;

    EXCEPTION WHEN OTHERS THEN
        error_message := error_message || 'Error restoring stock: ' || SQLERRM || '; ';
        RAISE NOTICE 'Error restoring stock: %', SQLERRM;
    END;

    -- Step 3: Insert notifications for recently cancelled orders
    -- This will only affect orders cancelled in the current execution
    BEGIN
        INSERT INTO public.kl_customer_notifications (
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
            'Order dengan nomor: ' || o.order_number || ' telah dibatalkan oleh sistem, karena tidak ada pembayaran yang masuk selama 24 jam',
            FALSE,
            NOW()
        FROM public.kl_orders o
        WHERE
            o.status = 'cancelled'
            AND o.updated_at >= (NOW() - INTERVAL '1 minute')
            AND NOT EXISTS (
                SELECT 1
                FROM public.kl_customer_notifications n
                WHERE n.order_id = o.id
                AND n.title = 'Pesanan Dibatalkan'
            );

        GET DIAGNOSTICS notifications_count = ROW_COUNT;
        RAISE NOTICE 'Sent % notifications', notifications_count;

    EXCEPTION WHEN OTHERS THEN
        error_message := error_message || 'Error sending notifications: ' || SQLERRM || '; ';
        RAISE NOTICE 'Error sending notifications: %', SQLERRM;
    END;

    -- Log the completion of cron job execution
    RAISE NOTICE 'Cron job completed at %. Cancelled: %, Restored: %, Notifications: %',
                 NOW(), cancelled_count, restored_count, notifications_count;

    -- Return results
    RETURN QUERY SELECT cancelled_count, restored_count, notifications_count, error_message;

EXCEPTION WHEN OTHERS THEN
    -- Return error information if something goes wrong
    RAISE NOTICE 'Cron job failed with error: %', SQLERRM;
    RETURN QUERY SELECT 0, 0, 0, 'Fatal error: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- HELPER FUNCTIONS FOR CRON JOB MONITORING
-- =================================================================

-- Function to get orders eligible for cancellation
CREATE OR REPLACE FUNCTION public.get_orders_eligible_for_cancellation()
RETURNS TABLE (
    order_id UUID,
    order_number TEXT,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    hours_elapsed NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.id,
        o.order_number,
        o.user_id,
        o.created_at,
        EXTRACT(EPOCH FROM (NOW() - o.created_at)) / 3600 as hours_elapsed
    FROM public.kl_orders o
    WHERE
        o.status = 'menunggu_pembayaran'
        AND NOT EXISTS (
            SELECT 1
            FROM public.kl_payments
            WHERE kl_payments.order_id = o.id
            AND kl_payments.status IN ('completed', 'pending')
        )
        AND o.created_at < (NOW() - INTERVAL '24 hours')
    ORDER BY o.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get products that will have stock restored
CREATE OR REPLACE FUNCTION public.get_products_for_stock_restoration()
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    total_quantity_to_restore INTEGER,
    affected_orders INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.name,
        SUM(oi.quantity) as total_quantity_to_restore,
        COUNT(DISTINCT o.id) as affected_orders
    FROM public.kl_products p
    INNER JOIN public.kl_order_items oi ON p.id = oi.product_id
    INNER JOIN public.kl_orders o ON oi.order_id = o.id
    WHERE
        o.status = 'cancelled'
        AND o.updated_at >= (NOW() - INTERVAL '1 minute')
    GROUP BY p.id, p.name
    ORDER BY total_quantity_to_restore DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- CRON JOB SCHEDULING SETUP
-- =================================================================
-- Note: This is a template for setting up the cron job in Supabase
-- You'll need to configure this in your Supabase project settings

/*
-- To set up the cron job in Supabase Dashboard:

1. Go to your Supabase project dashboard
2. Navigate to "Database" > "Functions"
3. Create a new Edge Function or use Database cron

-- Example cron schedule (every hour):
SELECT cron.schedule(
    'cancel-unpaid-orders',              -- job name
    '0 * * * *',                        -- every hour
    'SELECT public.cancel_unpaid_orders_cron_job();'
);

-- To unschedule:
SELECT cron.unschedule('cancel-unpaid-orders');

-- To run manually for testing:
SELECT public.cancel_unpaid_orders_cron_job();
*/

-- =================================================================
-- TESTING QUERIES
-- =================================================================

-- Test 1: Check orders eligible for cancellation
SELECT 'Orders eligible for cancellation:' as info;
SELECT * FROM public.get_orders_eligible_for_cancellation();

-- Test 2: Check products that would have stock restored
SELECT 'Products for stock restoration:' as info;
SELECT * FROM public.get_products_for_stock_restoration();

-- Test 3: Run the cron job function manually (for testing)
SELECT 'Running cron job manually:' as info;
SELECT * FROM public.cancel_unpaid_orders_cron_job();

-- Test 4: Verify the function exists and is accessible
SELECT
    proname as function_name,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'cancel_unpaid_orders_cron_job';

-- =================================================================
-- POLICY SUMMARY FOR CRON JOB
-- =================================================================
/*
CRON JOB POLICY SUMMARY:

1. ORDERS TABLE:
   - System can select orders for cron processing
   - System can update orders to cancel them

2. PRODUCTS TABLE:
   - System can select products for stock restoration
   - System can update product stock quantities

3. ORDER ITEMS TABLE:
   - System can select order items for stock calculation

4. CUSTOMER NOTIFICATIONS TABLE:
   - System can insert notifications for cancelled orders
   - System can select notifications for duplicate checking

STORED PROCEDURE:
- cancel_unpaid_orders_cron_job(): Main function for cron job
- get_orders_eligible_for_cancellation(): Helper for monitoring
- get_products_for_stock_restoration(): Helper for monitoring

TO USE THIS WITH YOUR CRON JOB:
1. Run this SQL file in Supabase SQL Editor
2. Set up cron schedule in Supabase Dashboard
3. Or call the function from your existing cron job script
4. Monitor using the helper functions

The stored procedure approach is recommended because:
- Better error handling
- Transaction safety
- Easier monitoring and logging
- Can be called from various cron job systems
*/

-- =================================================================

-- Success message
SELECT 'Cron job policies and stored procedure created successfully!' as status;