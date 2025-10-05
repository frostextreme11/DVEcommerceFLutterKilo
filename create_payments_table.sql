-- Create payments table for tracking individual payments per order
CREATE TABLE IF NOT EXISTS public.kl_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.kl_orders(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.kl_users(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    payment_proof_url TEXT, -- URL to uploaded payment proof image in Supabase storage
    payment_method TEXT, -- Bank transfer, credit card, etc.
    notes TEXT, -- Additional notes from customer
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.kl_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON public.kl_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.kl_payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.kl_payments(created_at);

-- Create trigger for updated_at
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.kl_payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies for payments table
ALTER TABLE public.kl_payments DISABLE ROW LEVEL SECURITY;

-- Users can view their own payments
CREATE POLICY "Users can view their own payments" ON public.kl_payments
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create payments for their orders
CREATE POLICY "Users can create payments for their orders" ON public.kl_payments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own payments
CREATE POLICY "Users can update their own payments" ON public.kl_payments
    FOR UPDATE USING (auth.uid() = user_id);

-- Create function to update order payment status when payments are added
CREATE OR REPLACE FUNCTION update_order_payment_status()
RETURNS TRIGGER AS $$
DECLARE
    total_paid DECIMAL(10,2);
    order_total DECIMAL(10,2);
    payment_count INTEGER;
BEGIN
    -- Get order total
    SELECT total_amount + COALESCE(additional_costs, 0)
    INTO order_total
    FROM public.kl_orders
    WHERE id = NEW.order_id;

    -- Calculate total paid for this order
    SELECT COALESCE(SUM(amount), 0)
    INTO total_paid
    FROM public.kl_payments
    WHERE order_id = NEW.order_id AND status = 'completed';

    -- Count total payments
    SELECT COUNT(*)
    INTO payment_count
    FROM public.kl_payments
    WHERE order_id = NEW.order_id;

    -- Update order payment status
    IF total_paid >= order_total AND order_total > 0 THEN
        -- Fully paid
        UPDATE public.kl_orders
        SET payment_status = 'paid', updated_at = NOW()
        WHERE id = NEW.order_id;
    ELSIF total_paid > 0 AND total_paid < order_total THEN
        -- Partially paid
        UPDATE public.kl_orders
        SET payment_status = 'pending', updated_at = NOW()
        WHERE id = NEW.order_id;
    END IF;

    -- Update order status based on payment progress
    IF total_paid > 0 AND total_paid < order_total THEN
        -- Has some payment but not complete
        UPDATE public.kl_orders
        SET status = 'pembayaran_partial', updated_at = NOW()
        WHERE id = NEW.order_id AND status = 'menunggu_pembayaran';
    ELSIF total_paid >= order_total AND order_total > 0 THEN
        -- Fully paid
        UPDATE public.kl_orders
        SET status = 'lunas', updated_at = NOW()
        WHERE id = NEW.order_id AND status IN ('menunggu_pembayaran', 'pembayaran_partial');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update order status when payments are inserted or updated
CREATE TRIGGER trigger_update_order_payment_status
    AFTER INSERT OR UPDATE ON public.kl_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_order_payment_status();

-- Create function to send admin notification when payment is received
CREATE OR REPLACE FUNCTION notify_admin_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    admin_user_id UUID;
    order_number TEXT;
    customer_name TEXT;
BEGIN
    -- Only notify for completed payments
    IF NEW.status = 'completed' AND (OLD IS NULL OR OLD.status != 'completed') THEN
        -- Get order details
        SELECT o.order_number, u.full_name
        INTO order_number, customer_name
        FROM public.kl_orders o
        JOIN public.kl_users u ON o.user_id = u.id
        WHERE o.id = NEW.order_id;

        -- Find admin user (assuming there's at least one admin)
        SELECT id INTO admin_user_id
        FROM public.kl_users
        WHERE role = 'admin'
        LIMIT 1;

        -- Insert notification for admin
        IF admin_user_id IS NOT NULL THEN
            INSERT INTO public.kl_admin_notifications (
                user_id,
                order_id,
                title,
                message,
                type,
                is_read,
                created_at
            ) VALUES (
                admin_user_id,
                NEW.order_id,
                'Payment from: ' || COALESCE(customer_name, 'Customer') || ' - ' || order_number || ' - Rp ' || NEW.amount::text,
                'Payment of Rp ' || NEW.amount::text || ' received for order ' || order_number || ' from ' || COALESCE(customer_name, 'Customer') || '. Please verify the payment.',
                'payment',
                false,
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to notify admin on payment completion
CREATE TRIGGER trigger_notify_admin_on_payment
    AFTER INSERT OR UPDATE ON public.kl_payments
    FOR EACH ROW
    EXECUTE FUNCTION notify_admin_on_payment();