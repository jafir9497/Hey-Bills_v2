-- Migration: 003_warranties_notifications.sql
-- Description: Create warranties and notifications tables
-- Author: System Architect
-- Date: 2024-12-XX

BEGIN;

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

-- Create indexes for warranties
CREATE INDEX idx_warranties_user_id ON warranties(user_id);
CREATE INDEX idx_warranties_receipt ON warranties(receipt_id);
CREATE INDEX idx_warranties_end_date ON warranties(warranty_end_date);
CREATE INDEX idx_warranties_status ON warranties(status);
CREATE INDEX idx_warranties_user_status ON warranties(user_id, status);
CREATE INDEX idx_warranties_expiring ON warranties(warranty_end_date) 
    WHERE warranty_end_date >= CURRENT_DATE AND warranty_end_date <= CURRENT_DATE + INTERVAL '60 days';

-- Create indexes for notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_for) WHERE is_sent = false;
CREATE INDEX idx_notifications_related ON notifications(related_entity_type, related_entity_id);

-- Apply updated_at trigger to warranties
CREATE TRIGGER update_warranties_updated_at BEFORE UPDATE ON warranties 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE warranties IS 'Product warranty tracking with automated alerts';
COMMENT ON TABLE notifications IS 'System notifications and warranty alerts';
COMMENT ON COLUMN warranties.status IS 'Computed warranty status based on expiration date';

COMMIT;