-- ALL Products - Stock vs Ordered Quantity Report
-- Shows EVERY product with current stock and total quantity ordered by customers

SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "Current Stock",
    COALESCE(SUM(oi.quantity), 0) as "Total Ordered",
    (p.stock_quantity - COALESCE(SUM(oi.quantity), 0)) as "Remaining Stock",
    CASE
        WHEN p.stock_quantity > 0 THEN
            ROUND((COALESCE(SUM(oi.quantity), 0)::decimal / p.stock_quantity * 100), 2)
        ELSE 0
    END as "Ordered % of Stock"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.category, p.stock_quantity
ORDER BY "Product Name";

-- Alternative: Order by most ordered first
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "Current Stock",
    COALESCE(SUM(oi.quantity), 0) as "Total Ordered",
    (p.stock_quantity - COALESCE(SUM(oi.quantity), 0)) as "Remaining Stock"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.category, p.stock_quantity
ORDER BY "Total Ordered" DESC, "Product Name";

-- Simple version - just Product ID, Name, Stock, and Ordered
SELECT
    p.id as "ID",
    p.name as "Product Name",
    p.stock_quantity as "In Stock",
    COALESCE(SUM(oi.quantity), 0) as "Ordered by Customers",
    (p.stock_quantity - COALESCE(SUM(oi.quantity), 0)) as "Remaining Stock"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.stock_quantity
ORDER BY p.name;

-- Complete version with all calculations
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "In Stock",
    COALESCE(SUM(oi.quantity), 0) as "Ordered by Customers",
    (p.stock_quantity - COALESCE(SUM(oi.quantity), 0)) as "Remaining Stock",
    CASE
        WHEN p.stock_quantity > COALESCE(SUM(oi.quantity), 0) THEN 'Available'
        WHEN p.stock_quantity = COALESCE(SUM(oi.quantity), 0) THEN 'Out of Stock'
        ELSE 'Oversold'
    END as "Stock Status"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.category, p.stock_quantity
ORDER BY "Remaining Stock" DESC, "Product Name";