-- ============================================================================
-- 002_create_rls_policies.sql
-- Row Level Security (RLS) policies for Hey-Bills tables
-- ============================================================================

-- Enable RLS on all user-specific tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranties ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_embeddings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- USER PROFILES POLICIES
-- ============================================================================

-- Users can view and update their own profile
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================================================
-- CATEGORIES POLICIES
-- ============================================================================

-- Users can manage their own categories and view default ones
CREATE POLICY "Users can view own categories" ON categories
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own categories" ON categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON categories
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- RECEIPTS POLICIES
-- ============================================================================

-- Users can only access their own receipts
CREATE POLICY "Users can view own receipts" ON receipts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own receipts" ON receipts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own receipts" ON receipts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own receipts" ON receipts
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- RECEIPT ITEMS POLICIES
-- ============================================================================

-- Users can only access receipt items for their own receipts
CREATE POLICY "Users can view own receipt items" ON receipt_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM receipts 
            WHERE receipts.id = receipt_items.receipt_id 
            AND receipts.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own receipt items" ON receipt_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM receipts 
            WHERE receipts.id = receipt_items.receipt_id 
            AND receipts.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own receipt items" ON receipt_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM receipts 
            WHERE receipts.id = receipt_items.receipt_id 
            AND receipts.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own receipt items" ON receipt_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM receipts 
            WHERE receipts.id = receipt_items.receipt_id 
            AND receipts.user_id = auth.uid()
        )
    );

-- ============================================================================
-- WARRANTIES POLICIES
-- ============================================================================

-- Users can only access their own warranties
CREATE POLICY "Users can view own warranties" ON warranties
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own warranties" ON warranties
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own warranties" ON warranties
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own warranties" ON warranties
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- NOTIFICATIONS POLICIES
-- ============================================================================

-- Users can only access their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- System can insert notifications (service role only)
CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR 
        auth.uid() = user_id
    );

-- ============================================================================
-- BUDGETS POLICIES
-- ============================================================================

-- Users can only access their own budgets
CREATE POLICY "Users can view own budgets" ON budgets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budgets" ON budgets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budgets" ON budgets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets" ON budgets
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- EMBEDDINGS POLICIES
-- ============================================================================

-- Users can view embeddings for their own receipts
CREATE POLICY "Users can view own receipt embeddings" ON receipt_embeddings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM receipts 
            WHERE receipts.id = receipt_embeddings.receipt_id 
            AND receipts.user_id = auth.uid()
        )
    );

-- System can manage embeddings (service role only)
CREATE POLICY "System can manage receipt embeddings" ON receipt_embeddings
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Users can view own warranty embeddings" ON warranty_embeddings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM warranties 
            WHERE warranties.id = warranty_embeddings.warranty_id 
            AND warranties.user_id = auth.uid()
        )
    );

CREATE POLICY "System can manage warranty embeddings" ON warranty_embeddings
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('receipts', 'receipts', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('warranties', 'warranties', false, 20971520, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('profiles', 'profiles', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Receipts bucket policies (private)
CREATE POLICY "Users can upload own receipts" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'receipts' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own receipts" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'receipts' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own receipts" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'receipts' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own receipts" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'receipts' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Warranties bucket policies (private)
CREATE POLICY "Users can upload own warranties" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'warranties' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own warranties" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'warranties' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own warranties" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'warranties' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own warranties" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'warranties' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Profiles bucket policies (public read, private write)
CREATE POLICY "Anyone can view profiles" ON storage.objects
    FOR SELECT USING (bucket_id = 'profiles');

CREATE POLICY "Users can upload own profile" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profiles' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own profile" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'profiles' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own profile" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profiles' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

-- Create audit log table for sensitive operations
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, operation, user_id, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, operation, user_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, operation, user_id, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to sensitive tables
CREATE TRIGGER audit_receipts_trigger
    AFTER INSERT OR UPDATE OR DELETE ON receipts
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_warranties_trigger
    AFTER INSERT OR UPDATE OR DELETE ON warranties
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_user_profiles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- RLS for audit logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT USING (auth.uid() = user_id);

-- Only service role can manage audit logs
CREATE POLICY "System can manage audit logs" ON audit_logs
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');