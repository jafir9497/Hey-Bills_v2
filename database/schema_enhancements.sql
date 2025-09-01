-- Schema Enhancement Recommendations for Hey-Bills v2
-- These additions improve data validation, performance, and monitoring
-- Execute after main schema deployment

BEGIN;

-- ============================================================================
-- PRIORITY 1: DATA VALIDATION CONSTRAINTS
-- ============================================================================

-- Add check constraints for data integrity
ALTER TABLE receipts 
    ADD CONSTRAINT check_positive_amount CHECK (total_amount > 0),
    ADD CONSTRAINT check_valid_tax_amount CHECK (tax_amount IS NULL OR tax_amount >= 0),
    ADD CONSTRAINT check_valid_tip_amount CHECK (tip_amount IS NULL OR tip_amount >= 0),
    ADD CONSTRAINT check_ocr_confidence_range CHECK (
        ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 1)
    );

ALTER TABLE receipt_items
    ADD CONSTRAINT check_positive_quantity CHECK (quantity > 0),
    ADD CONSTRAINT check_positive_total_price CHECK (total_price >= 0),
    ADD CONSTRAINT check_valid_unit_price CHECK (unit_price IS NULL OR unit_price >= 0);

ALTER TABLE warranties
    ADD CONSTRAINT check_warranty_dates CHECK (warranty_end_date >= warranty_start_date),
    ADD CONSTRAINT check_positive_purchase_price CHECK (
        purchase_price IS NULL OR purchase_price >= 0
    );

ALTER TABLE budgets
    ADD CONSTRAINT check_positive_budget_amount CHECK (budget_amount > 0),
    ADD CONSTRAINT check_valid_alert_percentage CHECK (
        alert_at_percentage > 0 AND alert_at_percentage <= 100
    );

-- ============================================================================
-- PRIORITY 1: PERFORMANCE OPTIMIZATION INDEXES
-- ============================================================================

-- High-value transactions for financial reporting
CREATE INDEX CONCURRENTLY idx_receipts_expensive 
    ON receipts(user_id, total_amount DESC) 
    WHERE total_amount > 100;

-- Recent activity queries for dashboard
CREATE INDEX CONCURRENTLY idx_receipts_recent 
    ON receipts(user_id, created_at DESC);

-- Notification cleanup and expiry management
CREATE INDEX CONCURRENTLY idx_notifications_expired 
    ON notifications(expires_at) 
    WHERE expires_at IS NOT NULL;

-- OCR processing status tracking
CREATE INDEX CONCURRENTLY idx_receipts_ocr_processing 
    ON receipts(user_id, ocr_confidence) 
    WHERE ocr_confidence IS NULL OR ocr_confidence < 0.75;

-- Business expense reporting
CREATE INDEX CONCURRENTLY idx_receipts_business_expenses 
    ON receipts(user_id, purchase_date DESC, total_amount DESC) 
    WHERE is_business_expense = true;

-- ============================================================================
-- PRIORITY 1: EMBEDDING VERSION TRACKING
-- ============================================================================

-- Add version tracking for embedding model updates
ALTER TABLE receipt_embeddings 
    ADD COLUMN embedding_version TEXT DEFAULT 'ada-002-v1',
    ADD COLUMN embedding_dimensions INTEGER DEFAULT 1536;

ALTER TABLE warranty_embeddings 
    ADD COLUMN embedding_version TEXT DEFAULT 'ada-002-v1',
    ADD COLUMN embedding_dimensions INTEGER DEFAULT 1536;

-- Index for finding embeddings by version (for batch updates)
CREATE INDEX idx_receipt_embeddings_version ON receipt_embeddings(embedding_version);
CREATE INDEX idx_warranty_embeddings_version ON warranty_embeddings(embedding_version);

-- ============================================================================
-- PRIORITY 1: ENHANCED HELPER FUNCTIONS
-- ============================================================================

-- Batch OCR confidence calculation
CREATE OR REPLACE FUNCTION calculate_batch_ocr_confidence(
    p_user_id UUID,
    p_confidence_threshold DECIMAL(3,2) DEFAULT 0.75
)
RETURNS TABLE(
    receipt_id UUID,
    current_confidence DECIMAL(3,2),
    needs_review BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.ocr_confidence as current_confidence,
        (r.ocr_confidence IS NULL OR r.ocr_confidence < p_confidence_threshold) as needs_review
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND (r.ocr_confidence IS NULL OR r.ocr_confidence < p_confidence_threshold)
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Duplicate receipt detection by image hash
CREATE OR REPLACE FUNCTION find_duplicate_receipts(
    p_user_id UUID,
    p_image_hash TEXT
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        r.created_at
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND r.image_hash = p_image_hash
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enhanced spending analytics with trends
CREATE OR REPLACE FUNCTION get_spending_analytics(
    p_user_id UUID,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE(
    total_spent DECIMAL(10,2),
    transaction_count INTEGER,
    avg_transaction DECIMAL(10,2),
    top_category TEXT,
    trend_percentage DECIMAL(5,2)
) AS $$
DECLARE
    current_period_total DECIMAL(10,2);
    previous_period_total DECIMAL(10,2);
    trend_calc DECIMAL(5,2);
BEGIN
    -- Current period spending
    SELECT COALESCE(SUM(r.total_amount), 0)
    INTO current_period_total
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * p_days_back;
    
    -- Previous period spending for trend calculation
    SELECT COALESCE(SUM(r.total_amount), 0)
    INTO previous_period_total
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * (p_days_back * 2)
        AND r.purchase_date < CURRENT_DATE - INTERVAL '1 day' * p_days_back;
    
    -- Calculate trend percentage
    trend_calc := CASE 
        WHEN previous_period_total > 0 THEN 
            ((current_period_total - previous_period_total) / previous_period_total * 100)::DECIMAL(5,2)
        ELSE 0
    END;
    
    RETURN QUERY
    WITH analytics AS (
        SELECT 
            current_period_total as total_spent,
            COUNT(r.id)::INTEGER as transaction_count,
            CASE WHEN COUNT(r.id) > 0 THEN current_period_total / COUNT(r.id) ELSE 0 END as avg_transaction,
            trend_calc as trend_percentage
        FROM receipts r
        WHERE r.user_id = p_user_id
            AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * p_days_back
    ),
    top_category AS (
        SELECT c.name as category_name
        FROM receipts r
        LEFT JOIN categories c ON r.category_id = c.id
        WHERE r.user_id = p_user_id
            AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * p_days_back
        GROUP BY c.name
        ORDER BY SUM(r.total_amount) DESC
        LIMIT 1
    )
    SELECT 
        a.total_spent,
        a.transaction_count,
        a.avg_transaction,
        COALESCE(tc.category_name, 'Uncategorized') as top_category,
        a.trend_percentage
    FROM analytics a
    CROSS JOIN top_category tc;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PRIORITY 2: MONITORING AND MAINTENANCE
-- ============================================================================

-- System health monitoring function
CREATE OR REPLACE FUNCTION get_system_health_metrics()
RETURNS TABLE(
    total_users INTEGER,
    total_receipts INTEGER,
    total_warranties INTEGER,
    avg_embeddings_per_day DECIMAL(10,2),
    failed_ocr_percentage DECIMAL(5,2),
    storage_size_mb DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH metrics AS (
        SELECT 
            COUNT(DISTINCT up.id)::INTEGER as total_users,
            COUNT(DISTINCT r.id)::INTEGER as total_receipts,
            COUNT(DISTINCT w.id)::INTEGER as total_warranties,
            (COUNT(DISTINCT re.id) + COUNT(DISTINCT we.id))::DECIMAL(10,2) / 
                GREATEST(EXTRACT(DAYS FROM (MAX(COALESCE(re.created_at, we.created_at)) - MIN(COALESCE(re.created_at, we.created_at)))), 1) as avg_embeddings_per_day,
            CASE 
                WHEN COUNT(r.id) > 0 THEN 
                    (COUNT(r.id) FILTER (WHERE r.ocr_confidence < 0.75 OR r.ocr_confidence IS NULL))::DECIMAL(5,2) / COUNT(r.id) * 100
                ELSE 0
            END as failed_ocr_percentage,
            0::DECIMAL(10,2) as storage_size_mb -- Would need custom implementation
        FROM user_profiles up
        LEFT JOIN receipts r ON up.id = r.user_id
        LEFT JOIN warranties w ON up.id = w.user_id
        LEFT JOIN receipt_embeddings re ON r.id = re.receipt_id
        LEFT JOIN warranty_embeddings we ON w.id = we.warranty_id
    )
    SELECT * FROM metrics;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup function for old notifications
CREATE OR REPLACE FUNCTION cleanup_old_data(
    p_notification_days INTEGER DEFAULT 90,
    p_embedding_orphan_check BOOLEAN DEFAULT true
)
RETURNS TABLE(
    notifications_deleted INTEGER,
    orphaned_embeddings_deleted INTEGER
) AS $$
DECLARE
    notif_deleted INTEGER := 0;
    embed_deleted INTEGER := 0;
BEGIN
    -- Clean up old read notifications
    DELETE FROM notifications
    WHERE created_at < CURRENT_DATE - INTERVAL '1 day' * p_notification_days
        AND is_read = true;
    GET DIAGNOSTICS notif_deleted = ROW_COUNT;
    
    -- Clean up orphaned embeddings (if enabled)
    IF p_embedding_orphan_check THEN
        DELETE FROM receipt_embeddings 
        WHERE receipt_id NOT IN (SELECT id FROM receipts);
        
        DELETE FROM warranty_embeddings 
        WHERE warranty_id NOT IN (SELECT id FROM warranties);
        
        GET DIAGNOSTICS embed_deleted = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT notif_deleted, embed_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PRIORITY 2: ADDITIONAL SEARCH ENHANCEMENTS
-- ============================================================================

-- Advanced receipt search with multiple criteria
CREATE OR REPLACE FUNCTION advanced_receipt_search(
    p_user_id UUID,
    p_search_text TEXT DEFAULT NULL,
    p_category_ids UUID[] DEFAULT NULL,
    p_min_amount DECIMAL(10,2) DEFAULT NULL,
    p_max_amount DECIMAL(10,2) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL,
    p_is_business BOOLEAN DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    category_name TEXT,
    tags TEXT[],
    relevance_score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        COALESCE(c.name, 'Uncategorized') as category_name,
        r.tags,
        CASE 
            WHEN p_search_text IS NOT NULL THEN
                GREATEST(
                    similarity(r.merchant_name, p_search_text),
                    similarity(COALESCE(r.notes, ''), p_search_text)
                )
            ELSE 1.0
        END as relevance_score
    FROM receipts r
    LEFT JOIN categories c ON r.category_id = c.id
    WHERE r.user_id = p_user_id
        AND (p_search_text IS NULL OR (
            r.merchant_name ILIKE '%' || p_search_text || '%'
            OR r.notes ILIKE '%' || p_search_text || '%'
            OR p_search_text = ANY(r.tags)
        ))
        AND (p_category_ids IS NULL OR r.category_id = ANY(p_category_ids))
        AND (p_min_amount IS NULL OR r.total_amount >= p_min_amount)
        AND (p_max_amount IS NULL OR r.total_amount <= p_max_amount)
        AND (p_start_date IS NULL OR r.purchase_date >= p_start_date)
        AND (p_end_date IS NULL OR r.purchase_date <= p_end_date)
        AND (p_tags IS NULL OR r.tags && p_tags)
        AND (p_is_business IS NULL OR r.is_business_expense = p_is_business)
    ORDER BY relevance_score DESC, r.purchase_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS AND DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION calculate_batch_ocr_confidence(UUID, DECIMAL) IS 
    'Identify receipts needing OCR review based on confidence threshold';

COMMENT ON FUNCTION find_duplicate_receipts(UUID, TEXT) IS 
    'Find potentially duplicate receipts using image hash comparison';

COMMENT ON FUNCTION get_spending_analytics(UUID, INTEGER) IS 
    'Comprehensive spending analytics with trend analysis';

COMMENT ON FUNCTION get_system_health_metrics() IS 
    'System-wide health and performance metrics for monitoring';

COMMENT ON FUNCTION cleanup_old_data(INTEGER, BOOLEAN) IS 
    'Maintenance function to clean up old notifications and orphaned data';

COMMENT ON FUNCTION advanced_receipt_search(UUID, TEXT, UUID[], DECIMAL, DECIMAL, DATE, DATE, TEXT[], BOOLEAN, INTEGER) IS 
    'Advanced multi-criteria receipt search with relevance scoring';

COMMIT;

-- ============================================================================
-- POST-DEPLOYMENT VERIFICATION QUERIES
-- ============================================================================

-- Verify constraints are working
-- INSERT INTO receipts (user_id, merchant_name, total_amount) VALUES (uuid_generate_v4(), 'Test', -10); -- Should fail

-- Verify new indexes exist
-- SELECT indexname FROM pg_indexes WHERE tablename IN ('receipts', 'notifications', 'receipt_embeddings', 'warranty_embeddings');

-- Test new functions
-- SELECT * FROM get_system_health_metrics();
-- SELECT * FROM cleanup_old_data();