-- Migration: 002_receipts_tables.sql
-- Description: Create receipts and receipt_items tables
-- Author: System Architect
-- Date: 2024-12-XX

BEGIN;

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

-- Create indexes for receipts
CREATE INDEX idx_receipts_user_id ON receipts(user_id);
CREATE INDEX idx_receipts_category ON receipts(category_id);
CREATE INDEX idx_receipts_merchant ON receipts USING GIN(merchant_name gin_trgm_ops);
CREATE INDEX idx_receipts_purchase_date ON receipts(purchase_date DESC);
CREATE INDEX idx_receipts_total_amount ON receipts(total_amount);
CREATE INDEX idx_receipts_user_date ON receipts(user_id, purchase_date DESC);
CREATE INDEX idx_receipts_tags ON receipts USING GIN(tags);
CREATE INDEX idx_receipts_business ON receipts(is_business_expense) WHERE is_business_expense = true;

-- Create indexes for receipt items
CREATE INDEX idx_receipt_items_receipt ON receipt_items(receipt_id);
CREATE INDEX idx_receipt_items_name ON receipt_items USING GIN(item_name gin_trgm_ops);

-- Apply updated_at trigger to receipts
CREATE TRIGGER update_receipts_updated_at BEFORE UPDATE ON receipts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE receipts IS 'Main receipt storage with OCR data and metadata';
COMMENT ON TABLE receipt_items IS 'Individual line items from receipts';
COMMENT ON COLUMN receipts.ocr_data IS 'Raw OCR results from image processing';
COMMENT ON COLUMN receipts.processed_data IS 'Structured data extracted and validated from OCR';
COMMENT ON COLUMN receipts.image_hash IS 'Hash for duplicate image detection';

COMMIT;