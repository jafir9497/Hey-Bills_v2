-- ============================================================================
-- Hey-Bills Comprehensive Performance Indexes
-- ============================================================================
-- Version: 3.0.0
-- Date: August 31, 2025
-- Description: Complete indexing strategy for optimal query performance
-- Features: B-tree, GIN, GIST, Vector indexes for all query patterns
-- ============================================================================

BEGIN;

-- ============================================================================
-- USER PROFILE INDEXES
-- ============================================================================

-- Primary access patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_email_lookup 
    ON user_profiles USING btree (id) 
    WHERE subscription_tier != 'free';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_business_type 
    ON user_profiles USING btree (business_type, subscription_tier);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_active_users 
    ON user_profiles USING btree (last_active_at DESC) 
    WHERE last_active_at > NOW() - INTERVAL '30 days';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_subscription 
    ON user_profiles USING btree (subscription_tier, subscription_expires_at);

-- Feature usage tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_features_gin 
    ON user_profiles USING gin (features_enabled);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_notifications_gin 
    ON user_profiles USING gin (notification_preferences);

-- ============================================================================
-- USER SESSION INDEXES
-- ============================================================================

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_user_active 
    ON user_sessions USING btree (user_id, is_active, last_activity_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_cleanup 
    ON user_sessions USING btree (expires_at) 
    WHERE is_active = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_device_tracking 
    ON user_sessions USING gin (device_info);

-- ============================================================================
-- CATEGORY INDEXES
-- ============================================================================

-- Hierarchical and user-specific access
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_user_hierarchy 
    ON categories USING btree (user_id, parent_category_id, sort_order);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_user_active 
    ON categories USING btree (user_id, is_active, name) 
    WHERE is_active = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_system_defaults 
    ON categories USING btree (is_system_category, is_default, name) 
    WHERE is_system_category = true OR is_default = true;

-- Path-based queries for nested categories
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_path_gin 
    ON categories USING gin (category_path);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_depth_performance 
    ON categories USING btree (depth, user_id);

-- Text search and pattern matching
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_name_search 
    ON categories USING gin (name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_keywords_gin 
    ON categories USING gin (keyword_patterns);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_merchants_gin 
    ON categories USING gin (merchant_patterns);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_auto_rules_gin 
    ON categories USING gin (auto_categorization_rules);

-- Statistics and usage tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_usage_stats 
    ON categories USING btree (user_id, last_used_at DESC NULLS LAST, receipt_count DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_categories_budget_monitoring 
    ON categories USING btree (user_id, monthly_budget DESC NULLS LAST) 
    WHERE monthly_budget IS NOT NULL;

-- ============================================================================
-- RECEIPT INDEXES
-- ============================================================================

-- Primary user access patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_date_desc 
    ON receipts USING btree (user_id, purchase_date DESC, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_amount_desc 
    ON receipts USING btree (user_id, total_amount DESC, purchase_date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_merchant 
    ON receipts USING btree (user_id, merchant_name, purchase_date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_user_category 
    ON receipts USING btree (user_id, category_id, purchase_date DESC);

-- Status and workflow indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_processing_status 
    ON receipts USING btree (user_id, status, ocr_status, created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_review_queue 
    ON receipts USING btree (user_id, is_reviewed, created_at) 
    WHERE is_reviewed = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_favorites 
    ON receipts USING btree (user_id, purchase_date DESC) 
    WHERE is_favorite = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_archived 
    ON receipts USING btree (user_id, archived_at DESC) 
    WHERE is_archived = true;

-- Financial and business queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_business_expenses 
    ON receipts USING btree (user_id, purchase_date, total_amount) 
    WHERE is_business_expense = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_tax_deductible 
    ON receipts USING btree (user_id, purchase_date, total_amount) 
    WHERE is_tax_deductible = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_expense_account 
    ON receipts USING btree (user_id, expense_account, purchase_date DESC) 
    WHERE expense_account IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_client_tracking 
    ON receipts USING btree (user_id, client_name, purchase_date DESC) 
    WHERE client_name IS NOT NULL;

-- Date and time-based queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_monthly_summary 
    ON receipts USING btree (user_id, date_trunc('month', purchase_date), total_amount);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_yearly_summary 
    ON receipts USING btree (user_id, date_trunc('year', purchase_date), total_amount);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_date_range_perf 
    ON receipts USING btree (user_id, purchase_date, total_amount) 
    WHERE purchase_date >= CURRENT_DATE - INTERVAL '2 years';

-- Location-based queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_location_gist 
    ON receipts USING gist (
        ll_to_earth(location_lat, location_lng)
    ) WHERE location_lat IS NOT NULL AND location_lng IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_location_btree 
    ON receipts USING btree (user_id, location_lat, location_lng) 
    WHERE location_lat IS NOT NULL;

-- Text search and OCR data
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_merchant_search 
    ON receipts USING gin (merchant_name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_full_text_search 
    ON receipts USING gin (search_vector);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_ocr_data_gin 
    ON receipts USING gin (ocr_data);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_processed_data_gin 
    ON receipts USING gin (processed_data);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_line_items_gin 
    ON receipts USING gin (line_items);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_tags_gin 
    ON receipts USING gin (tags);

-- Duplicate detection and image processing
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_image_hash_unique 
    ON receipts USING btree (image_hash) 
    WHERE image_hash IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_image_processing 
    ON receipts USING btree (user_id, image_size_bytes, image_format);

-- OCR performance and quality tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_ocr_confidence 
    ON receipts USING btree (ocr_confidence DESC, user_id) 
    WHERE ocr_confidence IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_ocr_performance 
    ON receipts USING btree (ocr_processing_time_ms, ocr_status) 
    WHERE ocr_processing_time_ms IS NOT NULL;

-- ============================================================================
-- RECEIPT LINE ITEMS INDEXES
-- ============================================================================

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_line_items_receipt 
    ON receipt_line_items USING btree (receipt_id, line_number);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_line_items_search 
    ON receipt_line_items USING gin (item_name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_line_items_sku_barcode 
    ON receipt_line_items USING btree (item_sku, item_barcode) 
    WHERE item_sku IS NOT NULL OR item_barcode IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_line_items_pricing 
    ON receipt_line_items USING btree (receipt_id, total_price DESC, quantity DESC);

-- ============================================================================
-- WARRANTY INDEXES
-- ============================================================================

-- User access and status tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_user_status 
    ON warranties USING btree (user_id, status, warranty_end_date);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_user_expiry 
    ON warranties USING btree (user_id, warranty_end_date ASC, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_expiring_soon 
    ON warranties USING btree (user_id, warranty_end_date) 
    WHERE is_expiring_soon = true;

-- Product and brand tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_product_brand 
    ON warranties USING btree (user_id, product_brand, product_name);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_product_search 
    ON warranties USING gin (product_name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_serial_sku 
    ON warranties USING btree (product_serial_number, product_sku) 
    WHERE product_serial_number IS NOT NULL OR product_sku IS NOT NULL;

-- Purchase and receipt correlation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_receipt_correlation 
    ON warranties USING btree (receipt_id, user_id) 
    WHERE receipt_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_purchase_date 
    ON warranties USING btree (user_id, purchase_date DESC, purchase_price DESC NULLS LAST);

-- Warranty duration and type analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_duration_analysis 
    ON warranties USING btree (warranty_duration_months, warranty_type, user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_extended 
    ON warranties USING btree (user_id, extended_warranty_end_date DESC) 
    WHERE extended_warranty = true;

-- Value and depreciation tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_value_tracking 
    ON warranties USING btree (user_id, estimated_current_value DESC NULLS LAST, purchase_price DESC NULLS LAST);

-- Notification and reminder management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_reminder_queue 
    ON warranties USING btree (warranty_end_date ASC, last_reminder_sent_at NULLS FIRST) 
    WHERE notification_enabled = true AND status = 'active';

-- Text search capabilities
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_tags_gin 
    ON warranties USING gin (tags);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_notes_search 
    ON warranties USING gin (to_tsvector('english', notes)) 
    WHERE notes IS NOT NULL;

-- ============================================================================
-- WARRANTY CLAIMS INDEXES
-- ============================================================================

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_claims_user_status 
    ON warranty_claims USING btree (user_id, status, claim_date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_claims_warranty 
    ON warranty_claims USING btree (warranty_id, claim_date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_claims_resolution 
    ON warranty_claims USING btree (status, resolution_date NULLS FIRST);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_claims_amount 
    ON warranty_claims USING btree (user_id, approved_amount DESC NULLS LAST, claim_amount DESC NULLS LAST);

-- ============================================================================
-- REMINDER INDEXES
-- ============================================================================

-- Scheduling and execution
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_execution_queue 
    ON reminders USING btree (next_trigger_at ASC, is_active) 
    WHERE is_active = true AND is_completed = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_user_active 
    ON reminders USING btree (user_id, is_active, scheduled_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_user_type 
    ON reminders USING btree (user_id, reminder_type, scheduled_at DESC);

-- Entity relationships
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_receipt_refs 
    ON reminders USING btree (receipt_id, user_id) 
    WHERE receipt_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_warranty_refs 
    ON reminders USING btree (warranty_id, user_id) 
    WHERE warranty_id IS NOT NULL;

-- Frequency and recurrence
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_frequency 
    ON reminders USING btree (frequency, frequency_interval, user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_recurring 
    ON reminders USING btree (user_id, frequency, next_trigger_at) 
    WHERE frequency != 'once';

-- Cleanup and maintenance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reminders_cleanup 
    ON reminders USING btree (is_completed, ends_at NULLS LAST) 
    WHERE is_active = false OR is_completed = true;

-- ============================================================================
-- NOTIFICATION INDEXES
-- ============================================================================

-- Delivery queue and status tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_delivery_queue 
    ON notifications USING btree (scheduled_at ASC, status, priority DESC) 
    WHERE status IN ('pending', 'failed') AND scheduled_at <= NOW();

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_recent 
    ON notifications USING btree (user_id, created_at DESC, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_unread 
    ON notifications USING btree (user_id, read_at NULLS FIRST, created_at DESC) 
    WHERE read_at IS NULL;

-- Delivery method and tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_delivery_method 
    ON notifications USING btree (delivery_method, status, scheduled_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_retry_queue 
    ON notifications USING btree (retry_after ASC, delivery_attempts, status) 
    WHERE status = 'failed' AND retry_after IS NOT NULL;

-- Performance and analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_performance 
    ON notifications USING btree (notification_type, delivery_method, status, sent_at);

-- Cleanup and expiration
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_expired 
    ON notifications USING btree (expires_at ASC) 
    WHERE expires_at IS NOT NULL AND expires_at < NOW();

-- ============================================================================
-- CONVERSATION INDEXES
-- ============================================================================

-- User access and recent activity
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_user_recent 
    ON conversations USING btree (user_id, last_message_at DESC, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_user_active 
    ON conversations USING btree (user_id, status, started_at DESC) 
    WHERE status = 'active';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_user_pinned 
    ON conversations USING btree (user_id, last_message_at DESC) 
    WHERE is_pinned = true;

-- Context and entity relationships
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_context_receipts_gin 
    ON conversations USING gin (context_receipts);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_context_warranties_gin 
    ON conversations USING gin (context_warranties);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_context_categories_gin 
    ON conversations USING gin (context_categories);

-- AI model and usage tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_ai_model 
    ON conversations USING btree (ai_model, user_id, started_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_usage_stats 
    ON conversations USING btree (user_id, total_tokens_used DESC, total_cost DESC);

-- Text search capabilities
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversations_title_search 
    ON conversations USING gin (title gin_trgm_ops) 
    WHERE title IS NOT NULL;

-- ============================================================================
-- MESSAGE INDEXES
-- ============================================================================

-- Conversation threading and ordering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_conversation_sequence 
    ON messages USING btree (conversation_id, sequence_number);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_conversation_recent 
    ON messages USING btree (conversation_id, created_at DESC);

-- User and message type filtering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_user_type 
    ON messages USING btree (user_id, message_type, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_user_recent 
    ON messages USING btree (user_id, created_at DESC);

-- AI processing and token tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_ai_processing 
    ON messages USING btree (ai_model, processing_time_ms NULLS LAST, total_tokens DESC NULLS LAST) 
    WHERE message_type = 'assistant_message';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_token_usage 
    ON messages USING btree (user_id, created_at DESC, total_tokens DESC NULLS LAST) 
    WHERE total_tokens IS NOT NULL;

-- Entity references and context
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_receipt_refs_gin 
    ON messages USING gin (referenced_receipts);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_warranty_refs_gin 
    ON messages USING gin (referenced_warranties);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_category_refs_gin 
    ON messages USING gin (referenced_categories);

-- Quality and feedback tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_user_ratings 
    ON messages USING btree (user_rating DESC, created_at DESC) 
    WHERE user_rating IS NOT NULL;

-- Content search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_content_search 
    ON messages USING gin (to_tsvector('english', content));

-- Cleanup and maintenance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_messages_deleted 
    ON messages USING btree (is_deleted, updated_at) 
    WHERE is_deleted = true;

-- ============================================================================
-- VECTOR EMBEDDING INDEXES
-- ============================================================================

-- Receipt embeddings - Vector similarity and content search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_vector_cosine 
    ON receipt_embeddings USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 1000);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_vector_l2 
    ON receipt_embeddings USING ivfflat (embedding vector_l2_ops) 
    WITH (lists = 1000);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_receipt 
    ON receipt_embeddings USING btree (receipt_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_content_hash 
    ON receipt_embeddings USING btree (content_hash);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_model_type 
    ON receipt_embeddings USING btree (embedding_model, content_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_quality 
    ON receipt_embeddings USING btree (embedding_quality_score DESC NULLS LAST, is_validated);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_keywords_gin 
    ON receipt_embeddings USING gin (search_keywords);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_embeddings_metadata_gin 
    ON receipt_embeddings USING gin (metadata);

-- Warranty embeddings - Vector similarity and content search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_vector_cosine 
    ON warranty_embeddings USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 500);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_vector_l2 
    ON warranty_embeddings USING ivfflat (embedding vector_l2_ops) 
    WITH (lists = 500);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_warranty 
    ON warranty_embeddings USING btree (warranty_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_content_hash 
    ON warranty_embeddings USING btree (content_hash);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_model_type 
    ON warranty_embeddings USING btree (embedding_model, content_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_embeddings_keywords_gin 
    ON warranty_embeddings USING gin (search_keywords);

-- Conversation embeddings - Vector similarity for context retrieval
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversation_embeddings_vector_cosine 
    ON conversation_embeddings USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 500);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversation_embeddings_message 
    ON conversation_embeddings USING btree (message_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversation_embeddings_conversation 
    ON conversation_embeddings USING btree (conversation_id, relevance_score DESC NULLS LAST);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversation_embeddings_content_hash 
    ON conversation_embeddings USING btree (content_hash);

-- Vector search cache - Performance optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_vector_search_cache_user_query 
    ON vector_search_cache USING btree (user_id, query_hash);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_vector_search_cache_cleanup 
    ON vector_search_cache USING btree (expires_at ASC) 
    WHERE expires_at < NOW();

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_vector_search_cache_popular 
    ON vector_search_cache USING btree (cache_hit_count DESC, last_accessed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_vector_search_cache_type_performance 
    ON vector_search_cache USING btree (search_type, user_id, last_accessed_at DESC);

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

-- User analytics - Time-series and aggregation queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_user_date 
    ON user_analytics USING btree (user_id, date_bucket DESC, hour_bucket NULLS LAST);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_daily_summary 
    ON user_analytics USING btree (date_bucket DESC, user_id) 
    WHERE hour_bucket IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_hourly_activity 
    ON user_analytics USING btree (date_bucket DESC, hour_bucket, user_id) 
    WHERE hour_bucket IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_usage_patterns 
    ON user_analytics USING btree (user_id, receipts_uploaded DESC, ai_queries_made DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_engagement 
    ON user_analytics USING btree (user_id, session_duration_seconds DESC, screen_views DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_financial 
    ON user_analytics USING btree (user_id, date_bucket, total_expense_amount DESC);

-- Feature usage analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_analytics_features_gin 
    ON user_analytics USING gin (feature_usage);

-- System metrics - Time-series monitoring and alerting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_metrics_timestamp 
    ON system_metrics USING btree (timestamp_bucket DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_metrics_performance 
    ON system_metrics USING btree (timestamp_bucket DESC, avg_response_time_ms, error_rate);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_metrics_resources 
    ON system_metrics USING btree (timestamp_bucket DESC, cpu_usage_percent, memory_usage_percent);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_system_metrics_api_performance 
    ON system_metrics USING btree (timestamp_bucket DESC, api_requests_per_second DESC);

-- ============================================================================
-- ADDITIONAL COMPOSITE INDEXES FOR COMPLEX QUERIES
-- ============================================================================

-- Multi-table join optimizations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipt_category_user_optimized 
    ON receipts USING btree (user_id, category_id, purchase_date DESC, total_amount DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranty_receipt_user_optimized 
    ON warranties USING btree (user_id, receipt_id, warranty_end_date ASC) 
    WHERE receipt_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conversation_message_user_optimized 
    ON messages USING btree (user_id, conversation_id, created_at DESC, message_type);

-- Reporting and dashboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_monthly_spending 
    ON receipts USING btree (
        user_id, 
        date_trunc('month', purchase_date), 
        category_id, 
        total_amount
    ) WHERE purchase_date >= CURRENT_DATE - INTERVAL '2 years';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_expiry_dashboard 
    ON warranties USING btree (
        user_id, 
        status, 
        warranty_end_date ASC, 
        product_brand, 
        purchase_price DESC NULLS LAST
    ) WHERE status IN ('active', 'expiring_soon');

-- Full-text search composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_merchant_location_search 
    ON receipts USING gin (
        to_tsvector('english', 
            COALESCE(merchant_name, '') || ' ' || 
            COALESCE(location_address, '') || ' ' ||
            COALESCE(notes, '')
        )
    );

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_warranties_product_search 
    ON warranties USING gin (
        to_tsvector('english', 
            COALESCE(product_name, '') || ' ' || 
            COALESCE(product_brand, '') || ' ' ||
            COALESCE(product_model, '') || ' ' ||
            COALESCE(notes, '')
        )
    );

-- ============================================================================
-- MAINTENANCE AND MONITORING INDEXES
-- ============================================================================

-- Performance monitoring indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_processing_performance 
    ON receipts USING btree (ocr_processing_time_ms DESC NULLS LAST, ocr_confidence DESC NULLS LAST, created_at DESC) 
    WHERE ocr_processing_time_ms IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_generation_performance 
    ON receipt_embeddings USING btree (generation_time_ms DESC NULLS LAST, token_count DESC NULLS LAST) 
    WHERE generation_time_ms IS NOT NULL;

-- Data quality monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_receipts_data_quality 
    ON receipts USING btree (
        user_id, 
        ocr_confidence NULLS LAST, 
        is_verified, 
        verification_score NULLS LAST
    );

-- System health and cleanup indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_all_tables_created_at 
    ON receipts USING btree (created_at)
UNION ALL
SELECT 'warranties'::text, created_at FROM warranties
UNION ALL
SELECT 'conversations'::text, created_at FROM conversations;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON INDEX idx_receipts_user_date_desc IS 'Primary index for user receipt listing by date';
COMMENT ON INDEX idx_receipts_full_text_search IS 'Full-text search across receipt content using tsvector';
COMMENT ON INDEX idx_receipt_embeddings_vector_cosine IS 'Vector similarity search using cosine distance';
COMMENT ON INDEX idx_warranties_expiring_soon IS 'Warranty expiration monitoring and alerts';
COMMENT ON INDEX idx_conversations_user_recent IS 'Recent conversation access for chat interface';
COMMENT ON INDEX idx_notifications_delivery_queue IS 'Notification delivery queue processing';

COMMIT;

-- ============================================================================
-- INDEX MAINTENANCE RECOMMENDATIONS
-- ============================================================================

/*
MAINTENANCE SCHEDULE RECOMMENDATIONS:

1. DAILY (Automated):
   - REINDEX CONCURRENTLY vector indexes if data size increases significantly
   - VACUUM ANALYZE on high-activity tables (receipts, messages, notifications)

2. WEEKLY:
   - Review slow query log and pg_stat_statements
   - Check for unused indexes: SELECT * FROM pg_stat_user_indexes WHERE idx_scan = 0;
   - Monitor index bloat and fragmentation

3. MONTHLY:
   - Full ANALYZE on all tables
   - Review and optimize vector index parameters based on data distribution
   - Update IVFFlat lists parameter based on table size growth

4. QUARTERLY:
   - Complete index maintenance and reorganization
   - Review query patterns and add/remove indexes as needed
   - Performance testing with production-like data volumes

MONITORING QUERIES:

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan ASC;

-- Check table and index sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
       pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor vector index performance
SELECT schemaname, indexname, idx_scan, idx_tup_read, idx_tup_fetch,
       idx_tup_read::float / GREATEST(idx_scan, 1) as avg_tuples_per_scan
FROM pg_stat_user_indexes 
WHERE indexname LIKE '%vector%'
ORDER BY idx_scan DESC;
*/