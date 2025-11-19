-- Optimized function to get user order summary without N+1 queries
-- This function aggregates all data in a single query using JOINs and GROUP BY

CREATE OR REPLACE FUNCTION get_user_order_summary(
  p_user_id UUID,
  p_start_date TIMESTAMP WITH TIME ZONE,
  p_end_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
  order_date DATE,
  total_quantity BIGINT,
  total_sales NUMERIC,
  total_ongkir NUMERIC,
  total_payment NUMERIC,
  total_debt NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(o.created_at) as order_date,
    COALESCE(SUM(oi.quantity), 0)::BIGINT as total_quantity,
    COALESCE(SUM(oi.total_price), 0)::NUMERIC as total_sales,
    COALESCE(SUM(o.additional_costs), 0)::NUMERIC as total_ongkir,
    COALESCE(SUM(p.amount), 0)::NUMERIC as total_payment,
    (COALESCE(SUM(oi.total_price), 0) + COALESCE(SUM(o.additional_costs), 0) - COALESCE(SUM(p.amount), 0))::NUMERIC as total_debt
  FROM kl_orders o
  LEFT JOIN kl_order_items oi ON o.id = oi.order_id
  LEFT JOIN kl_payments p ON o.id = p.order_id AND p.status = 'completed'
  WHERE o.user_id = p_user_id
    AND o.status != 'cancelled'
    AND o.created_at >= p_start_date
    AND o.created_at <= p_end_date
  GROUP BY DATE(o.created_at)
  ORDER BY DATE(o.created_at) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_order_summary(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;

-- Example usage:
-- SELECT * FROM get_user_order_summary(
--   'user-uuid-here'::UUID,
--   '2024-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE,
--   '2024-12-31 23:59:59+00'::TIMESTAMP WITH TIME ZONE
-- );
