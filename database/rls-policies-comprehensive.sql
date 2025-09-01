-- ============================================================================
-- Hey-Bills Comprehensive Row Level Security (RLS) Policies
-- ============================================================================
-- Version: 3.0.0
-- Date: August 31, 2025
-- Description: Complete RLS policies for all tables with proper security
-- Features: User isolation, Admin access, Multi-tenant security
-- ============================================================================

BEGIN;

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================

-- Core user tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Category management
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Receipt management
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_line_items ENABLE ROW LEVEL SECURITY;

-- Warranty management
ALTER TABLE warranties ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_claims ENABLE ROW LEVEL SECURITY;

-- Reminder and notification system
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- AI conversation system
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Vector embeddings
ALTER TABLE receipt_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE vector_search_cache ENABLE ROW LEVEL SECURITY;

-- Analytics
ALTER TABLE user_analytics ENABLE ROW LEVEL SECURITY;
-- Note: system_metrics doesn't need RLS as it's system-wide data

-- ============================================================================
-- UTILITY FUNCTIONS FOR RLS
-- ============================================================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN COALESCE(
        (current_setting('request.jwt.claims', true)::json->>'role')::text = 'admin',
        false
    );
END;
$$;

-- Function to get current user ID from JWT
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN COALESCE(
        (current_setting('request.jwt.claims', true)::json->>'sub')::uuid,
        auth.uid()
    );
END;
$$;

-- Function to check if user owns a receipt
CREATE OR REPLACE FUNCTION user_owns_receipt(receipt_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM receipts 
        WHERE id = receipt_uuid 
        AND user_id = current_user_id()
    );
END;
$$;

-- Function to check if user owns a warranty
CREATE OR REPLACE FUNCTION user_owns_warranty(warranty_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM warranties 
        WHERE id = warranty_uuid 
        AND user_id = current_user_id()
    );
END;
$$;

-- Function to check if user owns a conversation
CREATE OR REPLACE FUNCTION user_owns_conversation(conversation_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM conversations 
        WHERE id = conversation_uuid 
        AND user_id = current_user_id()
    );
END;
$$;

-- ============================================================================
-- USER PROFILE AND SESSION POLICIES
-- ============================================================================

-- User profiles: Users can only access their own profile
CREATE POLICY "Users can view their own profile"
    ON user_profiles FOR SELECT
    USING (id = current_user_id());

CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    USING (id = current_user_id())
    WITH CHECK (id = current_user_id());

CREATE POLICY "Users can insert their own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (id = current_user_id());

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
    ON user_profiles FOR ALL
    USING (is_admin());

-- User sessions: Users can only access their own sessions
CREATE POLICY "Users can view their own sessions"
    ON user_sessions FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can insert their own sessions"
    ON user_sessions FOR INSERT
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can update their own sessions"
    ON user_sessions FOR UPDATE
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can delete their own sessions"
    ON user_sessions FOR DELETE
    USING (user_id = current_user_id());

-- Admins can manage all sessions
CREATE POLICY "Admins can manage all sessions"
    ON user_sessions FOR ALL
    USING (is_admin());

-- ============================================================================
-- CATEGORY POLICIES
-- ============================================================================

-- Categories: Users can only access their own categories or system categories
CREATE POLICY "Users can view their own categories and system categories"
    ON categories FOR SELECT
    USING (
        user_id = current_user_id() OR 
        user_id IS NULL OR 
        is_system_category = true
    );

CREATE POLICY "Users can manage their own categories"
    ON categories FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- Admins can manage all categories
CREATE POLICY "Admins can manage all categories"
    ON categories FOR ALL
    USING (is_admin());

-- ============================================================================
-- RECEIPT POLICIES
-- ============================================================================

-- Receipts: Users can only access their own receipts
CREATE POLICY "Users can view their own receipts"
    ON receipts FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can insert their own receipts"
    ON receipts FOR INSERT
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can update their own receipts"
    ON receipts FOR UPDATE
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can delete their own receipts"
    ON receipts FOR DELETE
    USING (user_id = current_user_id());

-- Admins can manage all receipts
CREATE POLICY "Admins can manage all receipts"
    ON receipts FOR ALL
    USING (is_admin());

-- Receipt line items: Users can access line items for their receipts
CREATE POLICY "Users can view line items for their receipts"
    ON receipt_line_items FOR SELECT
    USING (user_owns_receipt(receipt_id));

CREATE POLICY "Users can manage line items for their receipts"
    ON receipt_line_items FOR ALL
    USING (user_owns_receipt(receipt_id))
    WITH CHECK (user_owns_receipt(receipt_id));

-- Admins can manage all receipt line items
CREATE POLICY "Admins can manage all receipt line items"
    ON receipt_line_items FOR ALL
    USING (is_admin());

-- ============================================================================
-- WARRANTY POLICIES
-- ============================================================================

-- Warranties: Users can only access their own warranties
CREATE POLICY "Users can view their own warranties"
    ON warranties FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can insert their own warranties"
    ON warranties FOR INSERT
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can update their own warranties"
    ON warranties FOR UPDATE
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can delete their own warranties"
    ON warranties FOR DELETE
    USING (user_id = current_user_id());

-- Admins can manage all warranties
CREATE POLICY "Admins can manage all warranties"
    ON warranties FOR ALL
    USING (is_admin());

-- Warranty claims: Users can access claims for their warranties
CREATE POLICY "Users can view claims for their warranties"
    ON warranty_claims FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can manage claims for their warranties"
    ON warranty_claims FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- Admins can manage all warranty claims
CREATE POLICY "Admins can manage all warranty claims"
    ON warranty_claims FOR ALL
    USING (is_admin());

-- ============================================================================
-- REMINDER AND NOTIFICATION POLICIES
-- ============================================================================

-- Reminders: Users can only access their own reminders
CREATE POLICY "Users can view their own reminders"
    ON reminders FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can manage their own reminders"
    ON reminders FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- System can create reminders for users (for automated reminders)
CREATE POLICY "System can create reminders"
    ON reminders FOR INSERT
    WITH CHECK (true);

-- Admins can manage all reminders
CREATE POLICY "Admins can manage all reminders"
    ON reminders FOR ALL
    USING (is_admin());

-- Notifications: Users can only access their own notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- System can create and manage notifications
CREATE POLICY "System can manage notifications"
    ON notifications FOR ALL
    USING (true);

-- Admins can manage all notifications
CREATE POLICY "Admins can manage all notifications"
    ON notifications FOR ALL
    USING (is_admin());

-- ============================================================================
-- AI CONVERSATION POLICIES
-- ============================================================================

-- Conversations: Users can only access their own conversations
CREATE POLICY "Users can view their own conversations"
    ON conversations FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can manage their own conversations"
    ON conversations FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- Admins can view all conversations (for support and moderation)
CREATE POLICY "Admins can view all conversations"
    ON conversations FOR SELECT
    USING (is_admin());

-- Messages: Users can access messages in their conversations
CREATE POLICY "Users can view messages in their conversations"
    ON messages FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Users can manage messages in their conversations"
    ON messages FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- System can create AI response messages
CREATE POLICY "System can create AI messages"
    ON messages FOR INSERT
    WITH CHECK (message_type IN ('assistant_message', 'system_message', 'function_response'));

-- Admins can view all messages
CREATE POLICY "Admins can view all messages"
    ON messages FOR SELECT
    USING (is_admin());

-- ============================================================================
-- VECTOR EMBEDDING POLICIES
-- ============================================================================

-- Receipt embeddings: Users can access embeddings for their receipts
CREATE POLICY "Users can view embeddings for their receipts"
    ON receipt_embeddings FOR SELECT
    USING (user_owns_receipt(receipt_id));

CREATE POLICY "System can manage receipt embeddings"
    ON receipt_embeddings FOR ALL
    USING (true);

-- Warranty embeddings: Users can access embeddings for their warranties
CREATE POLICY "Users can view embeddings for their warranties"
    ON warranty_embeddings FOR SELECT
    USING (user_owns_warranty(warranty_id));

CREATE POLICY "System can manage warranty embeddings"
    ON warranty_embeddings FOR ALL
    USING (true);

-- Conversation embeddings: Users can access embeddings for their conversations
CREATE POLICY "Users can view embeddings for their conversations"
    ON conversation_embeddings FOR SELECT
    USING (user_owns_conversation(conversation_id));

CREATE POLICY "System can manage conversation embeddings"
    ON conversation_embeddings FOR ALL
    USING (true);

-- Vector search cache: Users can only access their own search cache
CREATE POLICY "Users can view their own search cache"
    ON vector_search_cache FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "System can manage search cache"
    ON vector_search_cache FOR ALL
    USING (true);

-- ============================================================================
-- ANALYTICS POLICIES
-- ============================================================================

-- User analytics: Users can only view their own analytics
CREATE POLICY "Users can view their own analytics"
    ON user_analytics FOR SELECT
    USING (user_id = current_user_id());

-- System can insert and update analytics
CREATE POLICY "System can manage user analytics"
    ON user_analytics FOR ALL
    USING (true);

-- Admins can view all analytics
CREATE POLICY "Admins can view all analytics"
    ON user_analytics FOR SELECT
    USING (is_admin());

-- System metrics: Only admins and system can access
CREATE POLICY "Admins can view system metrics"
    ON system_metrics FOR SELECT
    USING (is_admin());

CREATE POLICY "System can manage system metrics"
    ON system_metrics FOR ALL
    USING (true);

-- ============================================================================
-- SECURITY FUNCTIONS FOR APPLICATION USE
-- ============================================================================

-- Function to validate user access to receipt
CREATE OR REPLACE FUNCTION validate_receipt_access(receipt_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Allow if admin or owner
    RETURN is_admin() OR user_owns_receipt(receipt_uuid);
END;
$$;

-- Function to validate user access to warranty
CREATE OR REPLACE FUNCTION validate_warranty_access(warranty_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Allow if admin or owner
    RETURN is_admin() OR user_owns_warranty(warranty_uuid);
END;
$$;

-- Function to validate user access to conversation
CREATE OR REPLACE FUNCTION validate_conversation_access(conversation_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Allow if admin or owner
    RETURN is_admin() OR user_owns_conversation(conversation_uuid);
END;
$$;

-- Function to check user feature access
CREATE OR REPLACE FUNCTION user_has_feature(feature_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_features JSONB;
BEGIN
    SELECT features_enabled INTO user_features
    FROM user_profiles 
    WHERE id = current_user_id();
    
    RETURN COALESCE((user_features->>feature_name)::boolean, false);
END;
$$;

-- Function to check subscription limits
CREATE OR REPLACE FUNCTION check_subscription_limit(limit_type TEXT, current_count INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_tier subscription_tier;
    limit_value INTEGER;
BEGIN
    SELECT subscription_tier INTO user_tier
    FROM user_profiles 
    WHERE id = current_user_id();
    
    -- Define limits based on subscription tier
    CASE user_tier
        WHEN 'free' THEN
            CASE limit_type
                WHEN 'monthly_receipts' THEN limit_value := 50;
                WHEN 'monthly_ai_queries' THEN limit_value := 10;
                WHEN 'storage_mb' THEN limit_value := 100;
                ELSE limit_value := 0;
            END CASE;
        WHEN 'basic' THEN
            CASE limit_type
                WHEN 'monthly_receipts' THEN limit_value := 500;
                WHEN 'monthly_ai_queries' THEN limit_value := 100;
                WHEN 'storage_mb' THEN limit_value := 1000;
                ELSE limit_value := 0;
            END CASE;
        WHEN 'premium' THEN
            CASE limit_type
                WHEN 'monthly_receipts' THEN limit_value := 5000;
                WHEN 'monthly_ai_queries' THEN limit_value := 1000;
                WHEN 'storage_mb' THEN limit_value := 10000;
                ELSE limit_value := 0;
            END CASE;
        WHEN 'enterprise' THEN
            -- Unlimited for enterprise
            RETURN true;
    END CASE;
    
    RETURN current_count < limit_value;
END;
$$;

-- ============================================================================
-- AUDIT AND LOGGING POLICIES
-- ============================================================================

-- Create audit log table (if not exists)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit logs: Users can view their own actions, admins can view all
CREATE POLICY "Users can view their own audit logs"
    ON audit_logs FOR SELECT
    USING (user_id = current_user_id());

CREATE POLICY "Admins can view all audit logs"
    ON audit_logs FOR ALL
    USING (is_admin());

CREATE POLICY "System can insert audit logs"
    ON audit_logs FOR INSERT
    WITH CHECK (true);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE user_profiles IS 'Extended user profiles with RLS - users can only access their own data';
COMMENT ON TABLE receipts IS 'Receipt data with RLS - users can only access their own receipts';
COMMENT ON TABLE warranties IS 'Warranty information with RLS - users can only access their own warranties';
COMMENT ON TABLE conversations IS 'AI conversations with RLS - users can only access their own conversations';
COMMENT ON TABLE messages IS 'Chat messages with RLS - users can only access messages in their conversations';
COMMENT ON TABLE receipt_embeddings IS 'Vector embeddings with RLS - users can only access embeddings for their receipts';

COMMENT ON FUNCTION current_user_id() IS 'Helper function to get current authenticated user ID';
COMMENT ON FUNCTION is_admin() IS 'Helper function to check if current user has admin privileges';
COMMENT ON FUNCTION validate_receipt_access(UUID) IS 'Validates user access to a specific receipt';
COMMENT ON FUNCTION user_has_feature(TEXT) IS 'Checks if user has access to a specific feature based on subscription';
COMMENT ON FUNCTION check_subscription_limit(TEXT, INTEGER) IS 'Validates if user has not exceeded subscription limits';

COMMIT;