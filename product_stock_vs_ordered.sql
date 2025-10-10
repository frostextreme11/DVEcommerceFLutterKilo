-- Product Stock vs Ordered Quantity Report
-- Shows current stock quantity and total quantity ordered by customers

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
ORDER BY "Total Ordered" DESC, "Product Name";

-- Alternative: Show only products that have been ordered
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "Current Stock",
    SUM(oi.quantity) as "Total Ordered",
    (p.stock_quantity - SUM(oi.quantity)) as "Remaining Stock",
    CASE
        WHEN p.stock_quantity > 0 THEN
            ROUND((SUM(oi.quantity)::decimal / p.stock_quantity * 100), 2)
        ELSE 0
    END as "Ordered % of Stock"
FROM public.kl_products p
INNER JOIN public.kl_order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.category, p.stock_quantity
ORDER BY "Total Ordered" DESC, "Product Name";

-- Products running low on stock (less than 20% remaining)
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "Current Stock",
    COALESCE(SUM(oi.quantity), 0) as "Total Ordered",
    (p.stock_quantity - COALESCE(SUM(oi.quantity), 0)) as "Remaining Stock",
    ROUND(((p.stock_quantity - COALESCE(SUM(oi.quantity), 0))::decimal / p.stock_quantity * 100), 2) as "Stock % Remaining"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
WHERE p.is_active = true
    AND p.stock_quantity > 0
GROUP BY p.id, p.name, p.category, p.stock_quantity
HAVING (p.stock_quantity - COALESCE(SUM(oi.quantity), 0))::decimal / p.stock_quantity < 0.2
ORDER BY "Stock % Remaining", "Total Ordered" DESC;

-- Products with more orders than stock (oversold items)
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    p.stock_quantity as "Current Stock",
    SUM(oi.quantity) as "Total Ordered",
    (SUM(oi.quantity) - p.stock_quantity) as "Oversold By"
FROM public.kl_products p
INNER JOIN public.kl_order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.category, p.stock_quantity
HAVING p.stock_quantity < SUM(oi.quantity)
ORDER BY "Oversold By" DESC;