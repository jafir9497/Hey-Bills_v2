-- Migration: 005_budgets_system_tables.sql
-- Description: Add budgets and system configuration tables
-- Author: System Architect
-- Date: 2024-12-XX

BEGIN;

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

-- System settings table for application configuration
CREATE TABLE system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create indexes for budgets
CREATE INDEX idx_budgets_user_id ON budgets(user_id);
CREATE INDEX idx_budgets_category ON budgets(category_id);
CREATE INDEX idx_budgets_active ON budgets(is_active) WHERE is_active = true;

-- Apply updated_at trigger to budgets
CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default system settings
INSERT INTO system_settings (key, value, description) VALUES
    ('ocr_confidence_threshold', '0.75', 'Minimum OCR confidence score for automatic processing'),
    ('warranty_alert_days', '[30, 7, 1]', 'Default days before warranty expiry to send alerts'),
    ('max_receipt_size_mb', '10', 'Maximum receipt image size in megabytes'),
    ('embedding_batch_size', '100', 'Number of items to process in embedding batches'),
    ('notification_retry_attempts', '3', 'Maximum retry attempts for failed notifications');

-- Add comments
COMMENT ON TABLE budgets IS 'User-defined spending budgets and limits';
COMMENT ON TABLE system_settings IS 'Application configuration and feature flags';

COMMIT;