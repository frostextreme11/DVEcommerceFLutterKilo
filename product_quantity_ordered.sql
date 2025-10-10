-- Simple Product Quantity Ordered Summary
-- Shows Product ID, Product Name, and Total Quantity Ordered by Customers

SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    COALESCE(SUM(oi.quantity), 0) as "Total Quantity Ordered"
FROM public.kl_products p
LEFT JOIN public.kl_order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY "Total Quantity Ordered" DESC, "Product Name";

-- Alternative using stored product names from orders
SELECT
    oi.product_id as "Product ID",
    oi.product_name as "Product Name",
    SUM(oi.quantity) as "Total Quantity Ordered"
FROM public.kl_order_items oi
WHERE oi.product_id IS NOT NULL
GROUP BY oi.product_id, oi.product_name
ORDER BY "Total Quantity Ordered" DESC, "Product Name";

-- Most popular products by quantity
SELECT
    p.id as "Product ID",
    p.name as "Product Name",
    p.category as "Category",
    SUM(oi.quantity) as "Total Quantity Ordered",
    COUNT(DISTINCT oi.order_id) as "Number of Orders",
    SUM(oi.total_price) as "Total Revenue"
FROM public.kl_products p
INNER JOIN public.kl_order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.category
ORDER BY "Total Quantity Ordered" DESC
LIMIT 20;