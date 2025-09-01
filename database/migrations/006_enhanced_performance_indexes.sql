-- Migration: 006_enhanced_performance_indexes.sql
-- Description: Advanced performance optimizations and enhanced indexing strategy
-- Author: Database Performance Optimizer Agent
-- Date: 2025-08-31
-- Dependencies: All previous migrations (001-005)

BEGIN;

-- ============================================================================
-- ADVANCED PERFORMANCE INDEXES
-- ============================================================================

-- High-performance composite indexes for common query patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_date_amount 
    ON receipts(user_id, purchase_date DESC, total_amount DESC);

-- Time-series analytics (monthly/yearly reporting)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_time_series 
    ON receipts(user_id, EXTRACT(YEAR FROM purchase_date), EXTRACT(MONTH FROM purchase_date), total_amount);

-- Business expense reporting with category filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_business_category 
    ON receipts(user_id, is_business_expense, category_id, purchase_date DESC) 
    WHERE is_business_expense = true;

-- Recent activity dashboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_recent_activity 
    ON receipts(user_id, created_at DESC, total_amount DESC);

-- OCR processing queue optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_ocr_queue 
    ON receipts(user_id, ocr_confidence NULLS FIRST, created_at DESC) 
    WHERE ocr_confidence IS NULL OR ocr_confidence < 0.75;

-- Merchant search and analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_merchant_analytics 
    ON receipts(user_id, merchant_name, purchase_date DESC, total_amount DESC);

-- Location-based queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_location 
    ON receipts(user_id, location_lat, location_lng) 
    WHERE location_lat IS NOT NULL AND location_lng IS NOT NULL;

-- ============================================================================
-- WARRANTY-SPECIFIC PERFORMANCE INDEXES
-- ============================================================================

-- Warranty expiration monitoring (critical for notifications)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_expiration_monitoring 
    ON warranties(user_id, warranty_end_date, status, is_active) 
    WHERE is_active = true;

-- Product-based warranty lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_product_search 
    ON warranties USING GIN(
        to_tsvector('english', 
            COALESCE(product_name, '') || ' ' || 
            COALESCE(manufacturer, '') || ' ' || 
            COALESCE(model_number, '')
        )
    ) WHERE is_active = true;

-- Registration tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_registration 
    ON warranties(user_id, registration_required, registration_completed) 
    WHERE registration_required = true;

-- ============================================================================
-- NOTIFICATION SYSTEM OPTIMIZATION
-- ============================================================================

-- Notification delivery queue processing
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_delivery_queue 
    ON notifications(scheduled_for, is_sent, delivery_attempts) 
    WHERE is_sent = false AND delivery_attempts < 3;

-- User notification dashboard
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_dashboard 
    ON notifications(user_id, is_read, priority, created_at DESC);

-- Notification cleanup and archival
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_cleanup 
    ON notifications(expires_at, is_read, created_at) 
    WHERE expires_at IS NOT NULL;

-- Related entity tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_entity_tracking 
    ON notifications(related_entity_type, related_entity_id, created_at DESC);

-- ============================================================================
-- EMBEDDING AND RAG OPTIMIZATION
-- ============================================================================

-- Enhanced vector search with metadata filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_metadata 
    ON receipt_embeddings USING GIN(metadata);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_metadata 
    ON warranty_embeddings USING GIN(metadata);

-- Model version tracking for embedding updates
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_model_version 
    ON receipt_embeddings(embedding_model, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_model_version 
    ON warranty_embeddings(embedding_model, created_at DESC);

-- Content deduplication optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_dedup 
    ON receipt_embeddings(content_hash, embedding_model);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_dedup 
    ON warranty_embeddings(content_hash, embedding_model);

-- ============================================================================
-- BUDGET AND ANALYTICS INDEXES
-- ============================================================================

-- Budget monitoring and alerts
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_budgets_monitoring 
    ON budgets(user_id, is_active, period_type, start_date, end_date) 
    WHERE is_active = true;

-- Category spending analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_budgets_category_analysis 
    ON budgets(user_id, category_id, is_active, period_type);

-- ============================================================================
-- PARTIAL INDEXES FOR COMMON FILTERS
-- ============================================================================

-- Active records only (reduces index size significantly)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_active_only 
    ON categories(user_id, sort_order) 
    WHERE is_active = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_active_only 
    ON warranties(user_id, warranty_end_date DESC) 
    WHERE is_active = true;

-- Reimbursable expenses tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_reimbursable 
    ON receipts(user_id, purchase_date DESC, total_amount DESC) 
    WHERE is_reimbursable = true;

-- High-value transactions (for alerts and reporting)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_high_value 
    ON receipts(user_id, purchase_date DESC, total_amount DESC) 
    WHERE total_amount > 100;

-- ============================================================================
-- TEXT SEARCH OPTIMIZATION
-- ============================================================================

-- Full-text search on receipt notes and tags
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_fulltext_search 
    ON receipts USING GIN(
        to_tsvector('english', 
            COALESCE(merchant_name, '') || ' ' || 
            COALESCE(notes, '') || ' ' || 
            array_to_string(COALESCE(tags, ARRAY[]::TEXT[]), ' ')
        )
    );

-- Item-level search within receipts
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_items_fulltext 
    ON receipt_items USING GIN(
        to_tsvector('english',
            COALESCE(item_name, '') || ' ' ||
            COALESCE(item_category, '') || ' ' ||
            COALESCE(brand, '')
        )
    );

-- ============================================================================
-- STATISTICAL AND ANALYTICAL INDEXES
-- ============================================================================

-- Monthly spending patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_monthly_stats 
    ON receipts(user_id, date_trunc('month', purchase_date), category_id, total_amount);

-- Merchant frequency analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_merchant_frequency 
    ON receipts(user_id, merchant_name, purchase_date DESC);

-- Tag popularity analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_tag_analysis 
    ON receipts USING GIN(tags) WHERE array_length(tags, 1) > 0;

-- ============================================================================
-- FOREIGN KEY OPTIMIZATION
-- ============================================================================

-- Optimize join performance for foreign key relationships
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_items_receipt_fk 
    ON receipt_items(receipt_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_receipt_fk 
    ON warranties(receipt_id) WHERE receipt_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_category_fk 
    ON receipts(category_id) WHERE category_id IS NOT NULL;

-- ============================================================================
-- PERFORMANCE MONITORING INDEXES
-- ============================================================================

-- System health monitoring queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_health_receipts 
    ON receipts(created_at::date, user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_health_embeddings 
    ON receipt_embeddings(created_at::date, embedding_model);

-- ============================================================================
-- COMMENTS FOR INDEX DOCUMENTATION
-- ============================================================================

COMMENT ON INDEX idx_receipts_user_date_amount IS 
    'Primary index for user receipt queries sorted by date and amount';

COMMENT ON INDEX idx_receipts_time_series IS 
    'Optimizes monthly/yearly spending analytics and reporting queries';

COMMENT ON INDEX idx_receipts_business_category IS 
    'Specialized index for business expense reporting with category filtering';

COMMENT ON INDEX idx_warranties_expiration_monitoring IS 
    'Critical index for warranty expiration alerts and notification system';

COMMENT ON INDEX idx_notifications_delivery_queue IS 
    'Optimizes notification delivery processing and retry logic';

COMMENT ON INDEX idx_receipt_embeddings_metadata IS 
    'Enables efficient metadata filtering in vector similarity searches';

COMMENT ON INDEX idx_receipts_fulltext_search IS 
    'Full-text search across receipt merchant names, notes, and tags';

-- ============================================================================
-- ANALYZE STATISTICS UPDATE
-- ============================================================================

-- Update table statistics for query planner optimization
ANALYZE user_profiles;
ANALYZE categories;
ANALYZE receipts;
ANALYZE receipt_items;
ANALYZE warranties;
ANALYZE notifications;
ANALYZE budgets;
ANALYZE receipt_embeddings;
ANALYZE warranty_embeddings;

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
/*
-- Verify new indexes were created successfully
SELECT 
    schemaname, 
    tablename, 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE schemaname = 'public' 
    AND indexname LIKE 'idx_%' 
    AND indexname NOT IN (
        -- Exclude pre-existing indexes from previous migrations
        SELECT indexname FROM pg_indexes WHERE tablename IN ('receipts', 'warranties', 'notifications')
    )
ORDER BY tablename, indexname;

-- Check index usage statistics (after some queries have been run)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND indexname LIKE 'idx_%'
ORDER BY idx_scan DESC;
*/