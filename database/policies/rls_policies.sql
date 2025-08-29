-- Row Level Security (RLS) Policies for Hey-Bills
-- Ensures users can only access their own data

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================

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
CREATE POLICY "Users can view own profile" 
    ON user_profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
    ON user_profiles FOR UPDATE 
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" 
    ON user_profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);

-- ============================================================================
-- CATEGORIES POLICIES
-- ============================================================================

-- Users can view default categories and their own custom categories
CREATE POLICY "Users can view categories" 
    ON categories FOR SELECT 
    USING (
        is_default = true OR 
        user_id = auth.uid()
    );

-- Users can create their own custom categories
CREATE POLICY "Users can create own categories" 
    ON categories FOR INSERT 
    WITH CHECK (user_id = auth.uid());

-- Users can update their own custom categories
CREATE POLICY "Users can update own categories" 
    ON categories FOR UPDATE 
    USING (user_id = auth.uid());

-- Users can delete their own custom categories
CREATE POLICY "Users can delete own categories" 
    ON categories FOR DELETE 
    USING (user_id = auth.uid() AND is_default = false);

-- ============================================================================
-- RECEIPTS POLICIES
-- ============================================================================

-- Users can only access their own receipts
CREATE POLICY "Users can view own receipts" 
    ON receipts FOR SELECT 
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own receipts" 
    ON receipts FOR INSERT 
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own receipts" 
    ON receipts FOR UPDATE 
    USING (user_id = auth.uid());

CREATE POLICY "Users can delete own receipts" 
    ON receipts FOR DELETE 
    USING (user_id = auth.uid());

-- ============================================================================
-- RECEIPT ITEMS POLICIES
-- ============================================================================

-- Users can only access receipt items for their own receipts
CREATE POLICY "Users can view own receipt items" 
    ON receipt_items FOR SELECT 
    USING (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create receipt items for own receipts" 
    ON receipt_items FOR INSERT 
    WITH CHECK (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own receipt items" 
    ON receipt_items FOR UPDATE 
    USING (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own receipt items" 
    ON receipt_items FOR DELETE 
    USING (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- WARRANTIES POLICIES
-- ============================================================================

-- Users can only access their own warranties
CREATE POLICY "Users can view own warranties" 
    ON warranties FOR SELECT 
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own warranties" 
    ON warranties FOR INSERT 
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own warranties" 
    ON warranties FOR UPDATE 
    USING (user_id = auth.uid());

CREATE POLICY "Users can delete own warranties" 
    ON warranties FOR DELETE 
    USING (user_id = auth.uid());

-- ============================================================================
-- NOTIFICATIONS POLICIES
-- ============================================================================

-- Users can only access their own notifications
CREATE POLICY "Users can view own notifications" 
    ON notifications FOR SELECT 
    USING (user_id = auth.uid());

-- System can create notifications for users (via service role)
CREATE POLICY "System can create notifications" 
    ON notifications FOR INSERT 
    WITH CHECK (true);

-- Users can update their own notifications (mainly for marking as read)
CREATE POLICY "Users can update own notifications" 
    ON notifications FOR UPDATE 
    USING (user_id = auth.uid());

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications" 
    ON notifications FOR DELETE 
    USING (user_id = auth.uid());

-- ============================================================================
-- BUDGETS POLICIES
-- ============================================================================

-- Users can only access their own budgets
CREATE POLICY "Users can view own budgets" 
    ON budgets FOR SELECT 
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own budgets" 
    ON budgets FOR INSERT 
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own budgets" 
    ON budgets FOR UPDATE 
    USING (user_id = auth.uid());

CREATE POLICY "Users can delete own budgets" 
    ON budgets FOR DELETE 
    USING (user_id = auth.uid());

-- ============================================================================
-- RECEIPT EMBEDDINGS POLICIES
-- ============================================================================

-- Users can access embeddings for their own receipts
CREATE POLICY "Users can view own receipt embeddings" 
    ON receipt_embeddings FOR SELECT 
    USING (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        )
    );

-- System can create embeddings (via service role)
CREATE POLICY "System can create receipt embeddings" 
    ON receipt_embeddings FOR INSERT 
    WITH CHECK (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        ) OR auth.jwt() ->> 'role' = 'service_role'
    );

-- System can update embeddings
CREATE POLICY "System can update receipt embeddings" 
    ON receipt_embeddings FOR UPDATE 
    USING (
        receipt_id IN (
            SELECT id FROM receipts WHERE user_id = auth.uid()
        ) OR auth.jwt() ->> 'role' = 'service_role'
    );

-- Embeddings are deleted when parent receipt is deleted (CASCADE)

-- ============================================================================
-- WARRANTY EMBEDDINGS POLICIES
-- ============================================================================

-- Users can access embeddings for their own warranties
CREATE POLICY "Users can view own warranty embeddings" 
    ON warranty_embeddings FOR SELECT 
    USING (
        warranty_id IN (
            SELECT id FROM warranties WHERE user_id = auth.uid()
        )
    );

-- System can create warranty embeddings (via service role)
CREATE POLICY "System can create warranty embeddings" 
    ON warranty_embeddings FOR INSERT 
    WITH CHECK (
        warranty_id IN (
            SELECT id FROM warranties WHERE user_id = auth.uid()
        ) OR auth.jwt() ->> 'role' = 'service_role'
    );

-- System can update warranty embeddings
CREATE POLICY "System can update warranty embeddings" 
    ON warranty_embeddings FOR UPDATE 
    USING (
        warranty_id IN (
            SELECT id FROM warranties WHERE user_id = auth.uid()
        ) OR auth.jwt() ->> 'role' = 'service_role'
    );

-- ============================================================================
-- SERVICE ROLE BYPASS
-- ============================================================================

-- Allow service role to bypass RLS for batch operations, migrations, etc.
-- This is handled by Supabase automatically when using the service role key

-- ============================================================================
-- HELPER FUNCTIONS FOR COMMON RLS PATTERNS
-- ============================================================================

-- Function to check if current user owns a receipt
CREATE OR REPLACE FUNCTION auth.user_owns_receipt(receipt_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM receipts 
        WHERE id = receipt_uuid AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user owns a warranty
CREATE OR REPLACE FUNCTION auth.user_owns_warranty(warranty_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM warranties 
        WHERE id = warranty_uuid AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Create partial indexes to optimize RLS policy checks
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_id_rls 
    ON receipts(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_user_id_rls 
    ON warranties(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_id_rls 
    ON notifications(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_user_id_rls 
    ON categories(user_id) WHERE user_id IS NOT NULL;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON POLICY "Users can view own profile" ON user_profiles IS 
    'Users can only view their own profile data';

COMMENT ON POLICY "Users can view categories" ON categories IS 
    'Users can see default categories and their own custom categories';

COMMENT ON POLICY "Users can view own receipts" ON receipts IS 
    'Users can only access receipts they uploaded';

COMMENT ON FUNCTION auth.user_owns_receipt(UUID) IS 
    'Helper function to check receipt ownership for RLS policies';

COMMENT ON FUNCTION auth.user_owns_warranty(UUID) IS 
    'Helper function to check warranty ownership for RLS policies';