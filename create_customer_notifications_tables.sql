-- Create customer notifications table
CREATE TABLE IF NOT EXISTS kl_customer_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES kl_users(id) ON DELETE CASCADE,
    order_id UUID REFERENCES kl_orders(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create customer FCM tokens table
CREATE TABLE IF NOT EXISTS kl_customer_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES kl_users(id) ON DELETE CASCADE UNIQUE,
    fcm_token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_customer_notifications_user_id ON kl_customer_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_customer_notifications_order_id ON kl_customer_notifications(order_id);
CREATE INDEX IF NOT EXISTS idx_customer_notifications_created_at ON kl_customer_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_notifications_is_read ON kl_customer_notifications(is_read);

-- Enable RLS (Row Level Security)
ALTER TABLE kl_customer_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE kl_customer_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for customer notifications
CREATE POLICY "Users can view their own notifications" ON kl_customer_notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON kl_customer_notifications
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications" ON kl_customer_notifications
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for customer FCM tokens
CREATE POLICY "Users can view their own FCM tokens" ON kl_customer_fcm_tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM tokens" ON kl_customer_fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens" ON kl_customer_fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own FCM tokens" ON kl_customer_fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for customer FCM tokens
CREATE TRIGGER update_customer_fcm_tokens_updated_at
    BEFORE UPDATE ON kl_customer_fcm_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for admin notifications
CREATE TRIGGER update_admin_notifications_updated_at
    BEFORE UPDATE ON kl_admin_notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for admin FCM tokens
CREATE TRIGGER update_admin_fcm_tokens_updated_at
    BEFORE UPDATE ON kl_admin_fcm_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create admin notifications table
CREATE TABLE IF NOT EXISTS kl_admin_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES kl_users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL, -- Made NOT NULL to match the constraint error
    order_id UUID REFERENCES kl_orders(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'payment',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin notifications
CREATE INDEX IF NOT EXISTS idx_admin_notifications_user_id ON kl_admin_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_order_id ON kl_admin_notifications(order_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_created_at ON kl_admin_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_is_read ON kl_admin_notifications(is_read);

-- Enable RLS for admin notifications
ALTER TABLE kl_admin_notifications ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for admin notifications
CREATE POLICY "Admins can view all notifications" ON kl_admin_notifications
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "Admins can update notifications" ON kl_admin_notifications
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "Admins can delete notifications" ON kl_admin_notifications
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "System can insert admin notifications" ON kl_admin_notifications
    FOR INSERT WITH CHECK (true);

-- Create admin FCM tokens table for push notifications
CREATE TABLE IF NOT EXISTS kl_admin_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES kl_users(id) ON DELETE CASCADE UNIQUE,
    fcm_token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin FCM tokens
CREATE INDEX IF NOT EXISTS idx_admin_fcm_tokens_user_id ON kl_admin_fcm_tokens(user_id);

-- Enable RLS for admin FCM tokens
ALTER TABLE kl_admin_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for admin FCM tokens
CREATE POLICY "Admins can view their own FCM tokens" ON kl_admin_fcm_tokens
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "Admins can insert their own FCM tokens" ON kl_admin_fcm_tokens
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "Admins can update their own FCM tokens" ON kl_admin_fcm_tokens
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );

CREATE POLICY "Admins can delete their own FCM tokens" ON kl_admin_fcm_tokens
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM kl_users
            WHERE id = auth.uid() AND role = 'Admin'
        )
    );