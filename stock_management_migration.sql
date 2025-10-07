-- Stock Management Migration
-- Functions and triggers to manage product stock quantities

-- Function to decrease stock when order items are created
CREATE OR REPLACE FUNCTION decrease_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if there's enough stock
    IF (SELECT stock_quantity FROM kl_products WHERE id = NEW.product_id) < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
    END IF;

    -- Decrease stock
    UPDATE kl_products
    SET stock_quantity = stock_quantity - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to increase stock when order items are deleted (order cancelled)
CREATE OR REPLACE FUNCTION increase_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Only increase stock if the old record exists (not for new inserts)
    IF OLD IS NOT NULL THEN
        UPDATE kl_products
        SET stock_quantity = stock_quantity + OLD.quantity,
            updated_at = NOW()
        WHERE id = OLD.product_id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to handle order status changes (for cancellations)
CREATE OR REPLACE FUNCTION handle_order_cancellation()
RETURNS TRIGGER AS $$
BEGIN
    -- If order status changed to cancelled, restore stock
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        -- Restore stock for all items in this order
        UPDATE kl_products
        SET stock_quantity = stock_quantity + kl_order_items.quantity,
            updated_at = NOW()
        FROM kl_order_items
        WHERE kl_order_items.order_id = NEW.id
        AND kl_products.id = kl_order_items.product_id;
    END IF;

    -- If order status changed from cancelled to something else, decrease stock
    IF NEW.status != 'cancelled' AND OLD.status = 'cancelled' THEN
        -- Decrease stock for all items in this order (check stock first)
        UPDATE kl_products
        SET stock_quantity = stock_quantity - kl_order_items.quantity,
            updated_at = NOW()
        FROM kl_order_items
        WHERE kl_order_items.order_id = NEW.id
        AND kl_products.id = kl_order_items.product_id
        AND kl_products.stock_quantity >= kl_order_items.quantity;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers

-- Trigger to decrease stock when order items are inserted
DROP TRIGGER IF EXISTS trigger_decrease_stock ON kl_order_items;
CREATE TRIGGER trigger_decrease_stock
    AFTER INSERT ON kl_order_items
    FOR EACH ROW
    EXECUTE FUNCTION decrease_product_stock();

-- Trigger to increase stock when order items are deleted
DROP TRIGGER IF EXISTS trigger_increase_stock ON kl_order_items;
CREATE TRIGGER trigger_increase_stock
    AFTER DELETE ON kl_order_items
    FOR EACH ROW
    EXECUTE FUNCTION increase_product_stock();

-- Trigger to handle order status changes for cancellations
DROP TRIGGER IF EXISTS trigger_handle_order_cancellation ON kl_orders;
CREATE TRIGGER trigger_handle_order_cancellation
    AFTER UPDATE ON kl_orders
    FOR EACH ROW
    EXECUTE FUNCTION handle_order_cancellation();

-- Create a function to manually adjust stock (for admin use)
CREATE OR REPLACE FUNCTION adjust_product_stock(
    product_id_param UUID,
    adjustment INTEGER,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    current_stock INTEGER;
    new_stock INTEGER;
BEGIN
    -- Get current stock
    SELECT stock_quantity INTO current_stock
    FROM kl_products WHERE id = product_id_param;

    -- Calculate new stock
    new_stock := current_stock + adjustment;

    -- Ensure stock doesn't go negative
    IF new_stock < 0 THEN
        RAISE EXCEPTION 'Stock adjustment would result in negative stock for product %', product_id_param;
    END IF;

    -- Update stock
    UPDATE kl_products
    SET stock_quantity = new_stock,
        updated_at = NOW()
    WHERE id = product_id_param;

    -- Log the adjustment
    INSERT INTO kl_stock_opname (product_id, previous_stock, current_stock, adjustment_reason, performed_by)
    VALUES (product_id_param, current_stock, new_stock, reason, auth.uid());

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;