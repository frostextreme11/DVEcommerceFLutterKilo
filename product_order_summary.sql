-- Product Order Summary Query
-- Shows Product ID, Product Name, and Quantity Ordered

-- Query 1: Basic summary with current product names
SELECT
    p.id as product_id,
    p.name as product_name,
    COALESCE(SUM(oi.quantity), 0) as total_quantity_ordered,
    COUNT(DISTINCT oi.order_id) as total_orders
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name
ORDER BY total_quantity_ordered DESC, product_name;

-- Query 2: Summary with product names as they were at time of order
SELECT
    oi.product_id,
    oi.product_name,
    SUM(oi.quantity) as total_quantity_ordered,
    COUNT(DISTINCT oi.order_id) as total_orders,
    COUNT(*) as total_order_items
FROM public.kl_order_items oi
WHERE oi.product_id IS NOT NULL
GROUP BY oi.product_id, oi.product_name
ORDER BY total_quantity_ordered DESC, oi.product_name;

-- Query 3: Detailed view showing individual order items
SELECT
    oi.id as order_item_id,
    oi.order_id,
    p.id as product_id,
    p.name as current_product_name,
    oi.product_name as product_name_at_order,
    oi.quantity,
    oi.unit_price,
    oi.total_price,
    oi.created_at as order_date
FROM public.kl_order_items oi
LEFT JOIN public.kl_products p ON oi.product_id = p.id
ORDER BY oi.created_at DESC, oi.quantity DESC;

-- Query 4: Summary by product category
SELECT
    p.category,
    p.id as product_id,
    p.name as product_name,
    SUM(oi.quantity) as total_quantity_ordered,
    COUNT(DISTINCT oi.order_id) as total_orders
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
    AND p.category IS NOT NULL
GROUP BY p.category, p.id, p.name
ORDER BY p.category, total_quantity_ordered DESC;

-- Query 5: Top selling products (by quantity)
SELECT
    p.id as product_id,
    p.name as product_name,
    p.category,
    SUM(oi.quantity) as total_quantity_ordered,
    COUNT(DISTINCT oi.order_id) as total_orders,
    SUM(oi.total_price) as total_revenue
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.category
HAVING SUM(oi.quantity) > 0
ORDER BY total_quantity_ordered DESC
LIMIT 10;

-- Query 6: Products with no orders (might need attention)
SELECT
    p.id as product_id,
    p.name as product_name,
    p.category,
    p.stock_quantity,
    p.created_at as product_created_date
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE oi.product_id IS NULL
    AND p.is_active = true
ORDER BY p.created_at DESC;