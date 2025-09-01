-- ============================================================================
-- Hey-Bills Complete Database Schema Deployment
-- ============================================================================
-- This file contains the complete database schema for Hey-Bills application
-- Execute this file in Supabase SQL Editor or via psql to deploy everything
-- 
-- Required Extensions: uuid-ossp, pgcrypto, vector
-- Target: Supabase PostgreSQL with Row Level Security
-- ============================================================================

BEGIN;

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

CREATE TYPE warranty_status AS ENUM ('active', 'expiring_soon', 'expired');
CREATE TYPE notification_type AS ENUM ('warranty_expiring', 'warranty_expired', 'system_alert', 'budget_alert');
CREATE TYPE delivery_method AS ENUM ('push', 'email', 'in_app');
CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'critical');

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- User profiles table (extends Supabase auth.users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    business_type TEXT DEFAULT 'individual',
    timezone TEXT DEFAULT 'UTC',
    currency TEXT DEFAULT 'USD',
    date_format TEXT DEFAULT 'MM/DD/YYYY',
    notification_preferences JSONB DEFAULT '{"email": true, "push": true, "warranty_alerts": true}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories table
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT DEFAULT '#6B7280',
    is_default BOOLEAN DEFAULT FALSE,
    parent_category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT categories_name_user_unique UNIQUE (name, user_id)
);

-- Receipts table
CREATE TABLE receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    
    -- Receipt metadata
    image_url TEXT NOT NULL,
    image_hash TEXT, -- for duplicate detection
    merchant_name TEXT NOT NULL,
    merchant_address TEXT,
    
    -- Financial data
    total_amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2),
    tip_amount DECIMAL(10,2),
    currency TEXT DEFAULT 'USD',
    payment_method TEXT,
    
    -- Date information
    purchase_date DATE NOT NULL,
    purchase_time TIME,
    
    -- OCR and processing data
    ocr_data JSONB, -- Raw OCR results
    ocr_confidence DECIMAL(3,2), -- Overall confidence score 0.00-1.00
    processed_data JSONB, -- Structured data extracted from OCR
    
    -- Location data
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8),
    location_address TEXT,
    
    -- Status and metadata
    is_business_expense BOOLEAN DEFAULT FALSE,
    is_reimbursable BOOLEAN DEFAULT FALSE,
    notes TEXT,
    tags TEXT[], -- User-defined tags
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Receipt items table (for detailed item tracking)
CREATE TABLE receipt_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    item_name TEXT NOT NULL,
    item_category TEXT,
    quantity DECIMAL(10,3) DEFAULT 1,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2),
    
    -- Product information
    sku TEXT,
    barcode TEXT,
    brand TEXT,
    
    -- OCR metadata
    ocr_confidence DECIMAL(3,2),
    line_number INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Warranties table
CREATE TABLE warranties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES receipts(id) ON DELETE SET NULL,
    
    -- Product information
    product_name TEXT NOT NULL,
    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,
    category TEXT,
    
    -- Purchase information
    purchase_date DATE NOT NULL,
    purchase_price DECIMAL(10,2),
    retailer TEXT,
    
    -- Warranty information
    warranty_start_date DATE NOT NULL,
    warranty_end_date DATE NOT NULL,
    warranty_period_months INTEGER GENERATED ALWAYS AS (
        EXTRACT(YEAR FROM age(warranty_end_date, warranty_start_date)) * 12 + 
        EXTRACT(MONTH FROM age(warranty_end_date, warranty_start_date))
    ) STORED,
    warranty_type TEXT, -- 'manufacturer', 'extended', 'store'
    warranty_terms TEXT,
    
    -- Registration and documentation
    registration_required BOOLEAN DEFAULT FALSE,
    registration_completed BOOLEAN DEFAULT FALSE,
    registration_date DATE,
    warranty_document_url TEXT,
    
    -- Alert configuration
    alert_preferences JSONB DEFAULT '{"days": [30, 7, 1], "email": true, "push": true}'::jsonb,
    
    -- Status
    status warranty_status GENERATED ALWAYS AS (
        CASE 
            WHEN warranty_end_date < CURRENT_DATE THEN 'expired'::warranty_status
            WHEN warranty_end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_soon'::warranty_status
            ELSE 'active'::warranty_status
        END
    ) STORED,
    
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Notification content
    type notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority priority_level DEFAULT 'medium',
    
    -- Related entity (polymorphic relationship)
    related_entity_type TEXT, -- 'warranty', 'receipt', 'budget', etc.
    related_entity_id UUID,
    
    -- Delivery configuration
    delivery_method delivery_method[] DEFAULT ARRAY['in_app'],
    scheduled_for TIMESTAMPTZ DEFAULT NOW(),
    
    -- Status tracking
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    is_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    delivery_attempts INTEGER DEFAULT 0,
    
    -- Metadata
    metadata JSONB,
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Budgets table for spending limits and alerts
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    budget_amount DECIMAL(10,2) NOT NULL,
    period_type TEXT NOT NULL DEFAULT 'monthly', -- 'weekly', 'monthly', 'quarterly', 'yearly'
    start_date DATE NOT NULL,
    end_date DATE,
    
    -- Alert thresholds
    alert_at_percentage INTEGER DEFAULT 80, -- Alert when 80% of budget used
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Receipt embeddings table for RAG functionality
CREATE TABLE receipt_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Vector embedding (1536 dimensions for OpenAI text-embedding-ada-002)
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL, -- Hash of the content that was embedded
    content_text TEXT NOT NULL, -- The actual text that was embedded
    
    -- Metadata for filtering and search
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT receipt_embeddings_unique UNIQUE (receipt_id)
);

-- Warranty embeddings table for recommendations and search
CREATE TABLE warranty_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warranty_id UUID NOT NULL REFERENCES warranties(id) ON DELETE CASCADE,
    
    -- Vector embedding
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL,
    content_text TEXT NOT NULL,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT warranty_embeddings_unique UNIQUE (warranty_id)
);

-- System settings table for application configuration
CREATE TABLE system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- User profiles indexes
CREATE INDEX idx_user_profiles_business_type ON user_profiles(business_type);

-- Categories indexes
CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_categories_parent ON categories(parent_category_id);
CREATE INDEX idx_categories_active ON categories(is_active) WHERE is_active = true;

-- Receipts indexes
CREATE INDEX idx_receipts_user_id ON receipts(user_id);
CREATE INDEX idx_receipts_category ON receipts(category_id);
CREATE INDEX idx_receipts_merchant ON receipts USING GIN(merchant_name gin_trgm_ops);
CREATE INDEX idx_receipts_purchase_date ON receipts(purchase_date DESC);
CREATE INDEX idx_receipts_total_amount ON receipts(total_amount);
CREATE INDEX idx_receipts_user_date ON receipts(user_id, purchase_date DESC);
CREATE INDEX idx_receipts_tags ON receipts USING GIN(tags);
CREATE INDEX idx_receipts_business ON receipts(is_business_expense) WHERE is_business_expense = true;

-- Receipt items indexes
CREATE INDEX idx_receipt_items_receipt ON receipt_items(receipt_id);
CREATE INDEX idx_receipt_items_name ON receipt_items USING GIN(item_name gin_trgm_ops);

-- Warranties indexes
CREATE INDEX idx_warranties_user_id ON warranties(user_id);
CREATE INDEX idx_warranties_receipt ON warranties(receipt_id);
CREATE INDEX idx_warranties_end_date ON warranties(warranty_end_date);
CREATE INDEX idx_warranties_status ON warranties(status);
CREATE INDEX idx_warranties_user_status ON warranties(user_id, status);
CREATE INDEX idx_warranties_expiring ON warranties(warranty_end_date) 
    WHERE warranty_end_date >= CURRENT_DATE AND warranty_end_date <= CURRENT_DATE + INTERVAL '60 days';

-- Notifications indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_for) WHERE is_sent = false;
CREATE INDEX idx_notifications_related ON notifications(related_entity_type, related_entity_id);

-- Budget indexes
CREATE INDEX idx_budgets_user_id ON budgets(user_id);
CREATE INDEX idx_budgets_category ON budgets(category_id);
CREATE INDEX idx_budgets_active ON budgets(is_active) WHERE is_active = true;

-- Vector similarity search indexes (HNSW for fast approximate nearest neighbor)
CREATE INDEX idx_receipt_embeddings_vector ON receipt_embeddings 
    USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
CREATE INDEX idx_warranty_embeddings_vector ON warranty_embeddings 
    USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Content hash indexes for deduplication
CREATE INDEX idx_receipt_embeddings_hash ON receipt_embeddings(content_hash);
CREATE INDEX idx_warranty_embeddings_hash ON warranty_embeddings(content_hash);

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_receipts_updated_at BEFORE UPDATE ON receipts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_warranties_updated_at BEFORE UPDATE ON warranties 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_receipt_embeddings_updated_at BEFORE UPDATE ON receipt_embeddings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_warranty_embeddings_updated_at BEFORE UPDATE ON warranty_embeddings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranties ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_embeddings ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view own profile" 
    ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" 
    ON user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" 
    ON user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Categories policies
CREATE POLICY "Users can view categories" 
    ON categories FOR SELECT USING (is_default = true OR user_id = auth.uid());
CREATE POLICY "Users can create own categories" 
    ON categories FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own categories" 
    ON categories FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own categories" 
    ON categories FOR DELETE USING (user_id = auth.uid() AND is_default = false);

-- Receipts policies
CREATE POLICY "Users can view own receipts" 
    ON receipts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can create own receipts" 
    ON receipts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own receipts" 
    ON receipts FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own receipts" 
    ON receipts FOR DELETE USING (user_id = auth.uid());

-- Receipt items policies
CREATE POLICY "Users can view own receipt items" 
    ON receipt_items FOR SELECT 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));
CREATE POLICY "Users can create receipt items for own receipts" 
    ON receipt_items FOR INSERT 
    WITH CHECK (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));
CREATE POLICY "Users can update own receipt items" 
    ON receipt_items FOR UPDATE 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));
CREATE POLICY "Users can delete own receipt items" 
    ON receipt_items FOR DELETE 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));

-- Warranties policies
CREATE POLICY "Users can view own warranties" 
    ON warranties FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can create own warranties" 
    ON warranties FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own warranties" 
    ON warranties FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own warranties" 
    ON warranties FOR DELETE USING (user_id = auth.uid());

-- Notifications policies
CREATE POLICY "Users can view own notifications" 
    ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "System can create notifications" 
    ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own notifications" 
    ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own notifications" 
    ON notifications FOR DELETE USING (user_id = auth.uid());

-- Budgets policies
CREATE POLICY "Users can view own budgets" 
    ON budgets FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can create own budgets" 
    ON budgets FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own budgets" 
    ON budgets FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own budgets" 
    ON budgets FOR DELETE USING (user_id = auth.uid());

-- Receipt embeddings policies
CREATE POLICY "Users can view own receipt embeddings" 
    ON receipt_embeddings FOR SELECT 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));
CREATE POLICY "System can create receipt embeddings" 
    ON receipt_embeddings FOR INSERT 
    WITH CHECK (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()) 
               OR auth.jwt() ->> 'role' = 'service_role');
CREATE POLICY "System can update receipt embeddings" 
    ON receipt_embeddings FOR UPDATE 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()) 
          OR auth.jwt() ->> 'role' = 'service_role');

-- Warranty embeddings policies
CREATE POLICY "Users can view own warranty embeddings" 
    ON warranty_embeddings FOR SELECT 
    USING (warranty_id IN (SELECT id FROM warranties WHERE user_id = auth.uid()));
CREATE POLICY "System can create warranty embeddings" 
    ON warranty_embeddings FOR INSERT 
    WITH CHECK (warranty_id IN (SELECT id FROM warranties WHERE user_id = auth.uid()) 
               OR auth.jwt() ->> 'role' = 'service_role');
CREATE POLICY "System can update warranty embeddings" 
    ON warranty_embeddings FOR UPDATE 
    USING (warranty_id IN (SELECT id FROM warranties WHERE user_id = auth.uid()) 
          OR auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- HELPER FUNCTIONS
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
-- DEFAULT DATA
-- ============================================================================

-- Insert default categories
INSERT INTO categories (id, name, description, icon, is_default, sort_order) VALUES
    (uuid_generate_v4(), 'Food & Dining', 'Restaurants, groceries, and food delivery', '🍽️', true, 1),
    (uuid_generate_v4(), 'Transportation', 'Gas, parking, rideshare, and public transport', '🚗', true, 2),
    (uuid_generate_v4(), 'Office Supplies', 'Business supplies, stationery, and equipment', '🏢', true, 3),
    (uuid_generate_v4(), 'Technology', 'Electronics, software, and digital services', '💻', true, 4),
    (uuid_generate_v4(), 'Healthcare', 'Medical expenses, prescriptions, and health services', '🏥', true, 5),
    (uuid_generate_v4(), 'Entertainment', 'Movies, events, subscriptions, and leisure', '🎬', true, 6),
    (uuid_generate_v4(), 'Home & Garden', 'Home improvement, furniture, and garden supplies', '🏠', true, 7),
    (uuid_generate_v4(), 'Clothing', 'Apparel, shoes, and accessories', '👕', true, 8),
    (uuid_generate_v4(), 'Travel', 'Hotels, flights, and travel-related expenses', '✈️', true, 9),
    (uuid_generate_v4(), 'Utilities', 'Phone, internet, electricity, and other utilities', '⚡', true, 10),
    (uuid_generate_v4(), 'Professional Services', 'Consulting, legal, accounting, and other services', '👔', true, 11),
    (uuid_generate_v4(), 'Other', 'Miscellaneous expenses', '📋', true, 99);

-- Insert default system settings
INSERT INTO system_settings (key, value, description) VALUES
    ('ocr_confidence_threshold', '0.75', 'Minimum OCR confidence score for automatic processing'),
    ('warranty_alert_days', '[30, 7, 1]', 'Default days before warranty expiry to send alerts'),
    ('max_receipt_size_mb', '10', 'Maximum receipt image size in megabytes'),
    ('embedding_batch_size', '100', 'Number of items to process in embedding batches'),
    ('notification_retry_attempts', '3', 'Maximum retry attempts for failed notifications');

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE user_profiles IS 'Extended user information beyond Supabase auth.users';
COMMENT ON TABLE categories IS 'Receipt and expense categories with hierarchical support';
COMMENT ON TABLE receipts IS 'Main receipt storage with OCR data and metadata';
COMMENT ON TABLE receipt_items IS 'Individual line items from receipts';
COMMENT ON TABLE warranties IS 'Product warranty tracking with automated alerts';
COMMENT ON TABLE notifications IS 'System notifications and warranty alerts';
COMMENT ON TABLE budgets IS 'User-defined spending budgets and limits';
COMMENT ON TABLE receipt_embeddings IS 'Vector embeddings for receipt similarity search and RAG';
COMMENT ON TABLE warranty_embeddings IS 'Vector embeddings for warranty recommendations and search';
COMMENT ON TABLE system_settings IS 'Application configuration and feature flags';

COMMIT;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
-- 
-- Next Steps:
-- 1. Verify all tables were created: SELECT tablename FROM pg_tables WHERE schemaname='public';
-- 2. Check RLS is enabled: SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='public';
-- 3. Verify default data: SELECT count(*) FROM categories WHERE is_default=true;
-- 4. Create storage buckets in Supabase dashboard (receipts, warranties, profiles)
-- 5. Test with verification script: node scripts/verify-database.js
-- 
-- ============================================================================