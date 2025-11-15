-- Optimize All Users Order Summary Report
-- This function replaces the N+1 query problem with a single optimized SQL query

CREATE OR REPLACE FUNCTION public.get_all_users_order_summary(
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  email TEXT,
  total_quantity BIGINT,
  total_sales DECIMAL,
  total_ongkir DECIMAL,
  total_payment DECIMAL,
  total_debt DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  WITH customer_orders AS (
    -- Get all customer order data with items in date range
    SELECT 
      u.id as user_id,
      u.full_name,
      u.email,
      COALESCE(SUM(oi.quantity), 0) as total_quantity,
      COALESCE(SUM(oi.total_price), 0) as total_sales,
      COALESCE(SUM(o.additional_costs), 0) as total_ongkir
    FROM kl_users u
    LEFT JOIN kl_orders o ON u.id = o.user_id 
      AND o.status != 'cancelled'
      AND o.created_at >= start_date 
      AND o.created_at <= end_date
    LEFT JOIN kl_order_items oi ON o.id = oi.order_id
    WHERE u.role = 'customer'
      AND (o.id IS NULL OR o.status != 'cancelled')
    GROUP BY u.id, u.full_name, u.email
    HAVING COUNT(o.id) > 0 OR COALESCE(SUM(oi.quantity), 0) > 0
  ),
  customer_payments AS (
    -- Get all customer payments in date range
    SELECT 
      u.id as user_id,
      COALESCE(SUM(p.amount), 0) as total_payment
    FROM kl_users u
    LEFT JOIN kl_payments p ON u.id = p.user_id 
      AND p.status = 'completed'
      AND p.created_at >= start_date 
      AND p.created_at <= end_date
    WHERE u.role = 'customer'
    GROUP BY u.id
  )
  SELECT 
    co.user_id,
    co.full_name,
    co.email,
    co.total_quantity,
    co.total_sales,
    co.total_ongkir,
    cp.total_payment,
    (co.total_sales + co.total_ongkir - cp.total_payment) as total_debt
  FROM customer_orders co
  INNER JOIN customer_payments cp ON co.user_id = cp.user_id
  WHERE co.total_quantity > 0 OR cp.total_payment > 0
  ORDER BY co.total_sales DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes to optimize the function performance
CREATE INDEX IF NOT EXISTS idx_orders_user_created ON kl_orders(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON kl_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_created ON kl_payments(user_id, created_at, status);
CREATE INDEX IF NOT EXISTS idx_users_role ON kl_users(role);

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_all_users_order_summary(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;