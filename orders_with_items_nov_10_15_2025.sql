-- Query to select kl_orders and kl_order_items from November 10-15, 2025
-- Date range: 2025-11-10 00:00:00 to 2025-11-15 23:59:59

WITH orders_with_items AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY o.created_at) as row_num,
        o.id as order_id,
        o.order_number,
        u.email as user_email,
        u.full_name as user_name,
        o.user_id,
        o.status,
        o.total_amount,
        o.shipping_address,
        o.payment_method,
        o.payment_status,
        o.courier_info,
        o.notes,
        o.receiver_name,
        o.receiver_phone,
        o.additional_costs,
        o.additional_costs_notes,
        o.is_dropship,
        o.sender_name,
        o.sender_phone,
        o.created_at as order_created_at,
        o.updated_at as order_updated_at,
        oi.id as order_item_id,
        oi.product_id,
        oi.product_name,
        oi.product_image_url,
        oi.quantity,
        oi.unit_price,
        oi.discount_price,
        oi.total_price as item_total_price,
        oi.created_at as item_created_at
    FROM public.kl_orders o
    LEFT JOIN public.kl_users u ON o.user_id = u.id
    LEFT JOIN public.kl_order_items oi ON o.id = oi.order_id
    WHERE o.created_at >= '2025-11-10 00:00:00+00'
      AND o.created_at <= '2025-11-15 23:59:59+00'
    ORDER BY o.created_at, oi.created_at
)
SELECT
    row_num,
    user_email,
    user_name,
    order_id,
    order_number,
    user_id,
    status,
    total_amount,
    shipping_address,
    payment_method,
    payment_status,
    courier_info,
    notes,
    receiver_name,
    receiver_phone,
    additional_costs,
    additional_costs_notes,
    is_dropship,
    sender_name,
    sender_phone,
    order_created_at,
    order_updated_at,
    order_item_id,
    product_id,
    product_name,
    product_image_url,
    quantity,
    unit_price,
    discount_price,
    item_total_price,
    item_created_at
FROM orders_with_items
ORDER BY row_num;

-- Alternative shorter version focusing on essential fields:

WITH orders_with_items AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY o.created_at) as row_num,
        u.email as user_email,
        u.full_name as user_name,
        o.order_number,
        o.status,
        o.total_amount,
        o.created_at as order_date,
        oi.product_name,
        oi.quantity,
        oi.unit_price,
        oi.total_price as item_total
    FROM public.kl_orders o
    LEFT JOIN public.kl_users u ON o.user_id = u.id
    LEFT JOIN public.kl_order_items oi ON o.id = oi.order_id
    WHERE o.created_at >= '2025-11-10 00:00:00+00'
      AND o.created_at <= '2025-11-15 23:59:59+00'
    ORDER BY o.created_at, oi.created_at
)
SELECT
    row_num,
    user_email,
    user_name,
    order_number,
    status,
    total_amount,
    order_date,
    product_name,
    quantity,
    unit_price,
    item_total
FROM orders_with_items
ORDER BY row_num;