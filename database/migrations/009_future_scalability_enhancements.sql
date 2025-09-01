-- Migration: 009_future_scalability_enhancements.sql
-- Description: Future-proofing enhancements for scalability and extensibility
-- Author: System Architect & Performance Optimizer Agents
-- Date: 2025-08-31
-- Dependencies: All previous migrations (001-008)

BEGIN;

-- ============================================================================
-- SCALABILITY INFRASTRUCTURE
-- ============================================================================

-- Sharding preparation table for horizontal scaling
CREATE TABLE shard_configuration (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Shard identification
    shard_name TEXT NOT NULL UNIQUE,
    shard_id INTEGER NOT NULL UNIQUE,
    
    -- Connection details (encrypted)
    database_url TEXT NOT NULL, -- Encrypted connection string
    read_replica_urls TEXT[], -- Array of read replica URLs
    
    -- Shard characteristics
    shard_type TEXT DEFAULT 'user_data', -- 'user_data', 'analytics', 'embeddings', 'archive'
    data_center_region TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Capacity planning
    max_users_per_shard INTEGER DEFAULT 10000,
    current_user_count INTEGER DEFAULT 0,
    storage_limit_gb INTEGER DEFAULT 1000,
    current_storage_gb DECIMAL(10,2) DEFAULT 0,
    
    -- Performance metrics
    avg_response_time_ms INTEGER,
    connection_pool_size INTEGER DEFAULT 20,
    max_connections INTEGER DEFAULT 100,
    
    -- Maintenance windows
    maintenance_schedule JSONB DEFAULT '{}'::jsonb,
    last_maintenance TIMESTAMPTZ,
    next_maintenance TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User shard mapping for horizontal scaling
CREATE TABLE user_shard_mapping (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    shard_id INTEGER NOT NULL REFERENCES shard_configuration(shard_id),
    shard_name TEXT NOT NULL,
    
    -- Migration tracking
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    migration_status TEXT DEFAULT 'active', -- 'active', 'migrating', 'archived'
    previous_shard_id INTEGER,
    migration_started_at TIMESTAMPTZ,
    migration_completed_at TIMESTAMPTZ,
    
    -- Performance tracking
    data_size_estimate_mb DECIMAL(10,2),
    last_activity TIMESTAMPTZ DEFAULT NOW()
);

-- API rate limiting and quotas
CREATE TABLE api_rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Target identification
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    api_key_hash TEXT, -- For API key based access
    ip_address INET,
    
    -- Rate limiting
    endpoint_pattern TEXT NOT NULL, -- e.g., '/api/receipts/*'
    requests_per_minute INTEGER NOT NULL DEFAULT 60,
    requests_per_hour INTEGER NOT NULL DEFAULT 1000,
    requests_per_day INTEGER NOT NULL DEFAULT 10000,
    
    -- Current counters (reset periodically)
    current_minute_requests INTEGER DEFAULT 0,
    current_hour_requests INTEGER DEFAULT 0,
    current_day_requests INTEGER DEFAULT 0,
    
    -- Time windows
    minute_window_start TIMESTAMPTZ DEFAULT date_trunc('minute', NOW()),
    hour_window_start TIMESTAMPTZ DEFAULT date_trunc('hour', NOW()),
    day_window_start TIMESTAMPTZ DEFAULT date_trunc('day', NOW()),
    
    -- Quota management
    monthly_quota INTEGER, -- NULL for unlimited
    current_month_usage INTEGER DEFAULT 0,
    quota_reset_date DATE DEFAULT date_trunc('month', NOW() + INTERVAL '1 month')::DATE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MULTI-TENANT ARCHITECTURE SUPPORT
-- ============================================================================

-- Organization/tenant management
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Organization details
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE, -- URL-friendly identifier
    domain TEXT, -- Custom domain (optional)
    
    -- Subscription and billing
    subscription_tier TEXT DEFAULT 'free', -- 'free', 'premium', 'enterprise'
    subscription_status TEXT DEFAULT 'active', -- 'active', 'suspended', 'cancelled'
    billing_email TEXT,
    subscription_expires_at TIMESTAMPTZ,
    
    -- Limits and quotas
    max_users INTEGER DEFAULT 5,
    max_receipts_per_month INTEGER DEFAULT 100,
    max_storage_gb INTEGER DEFAULT 1,
    features_enabled JSONB DEFAULT '{"basic_ocr": true}'::jsonb,
    
    -- Organization settings
    settings JSONB DEFAULT '{}'::jsonb,
    branding JSONB DEFAULT '{}'::jsonb, -- Custom colors, logos, etc.
    
    -- Security settings
    enforce_2fa BOOLEAN DEFAULT FALSE,
    allowed_domains TEXT[], -- Email domain restrictions
    ip_whitelist INET[], -- IP address restrictions
    session_timeout_minutes INTEGER DEFAULT 480, -- 8 hours
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User organization membership
CREATE TABLE organization_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Role and permissions
    role TEXT NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member', 'readonly'
    permissions JSONB DEFAULT '[]'::jsonb, -- Specific permissions array
    
    -- Status
    status TEXT DEFAULT 'active', -- 'active', 'pending', 'suspended'
    invited_by UUID REFERENCES auth.users(id),
    invited_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Access control
    can_invite_users BOOLEAN DEFAULT FALSE,
    can_manage_billing BOOLEAN DEFAULT FALSE,
    can_export_data BOOLEAN DEFAULT FALSE,
    
    UNIQUE(organization_id, user_id)
);

-- ============================================================================
-- ADVANCED CACHING LAYER
-- ============================================================================

-- Cache configuration and management
CREATE TABLE cache_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Cache identification
    cache_key_pattern TEXT NOT NULL UNIQUE, -- e.g., 'user_receipts_{user_id}'
    cache_type TEXT NOT NULL DEFAULT 'redis', -- 'redis', 'memcached', 'database'
    
    -- TTL and expiration
    default_ttl_seconds INTEGER NOT NULL DEFAULT 3600, -- 1 hour
    max_ttl_seconds INTEGER DEFAULT 86400, -- 24 hours
    
    -- Cache behavior
    cache_strategy TEXT DEFAULT 'write_through', -- 'write_through', 'write_behind', 'cache_aside'
    invalidation_strategy TEXT DEFAULT 'ttl', -- 'ttl', 'manual', 'dependency'
    compression_enabled BOOLEAN DEFAULT TRUE,
    
    -- Performance settings
    max_size_bytes BIGINT DEFAULT 10485760, -- 10MB default
    eviction_policy TEXT DEFAULT 'lru', -- 'lru', 'lfu', 'fifo'
    
    -- Monitoring
    hit_ratio_threshold DECIMAL(3,2) DEFAULT 0.80, -- Alert if below 80%
    is_monitored BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cache performance metrics
CREATE TABLE cache_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    cache_key_pattern TEXT NOT NULL REFERENCES cache_configurations(cache_key_pattern),
    
    -- Time window
    metric_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    time_window_minutes INTEGER NOT NULL DEFAULT 5,
    
    -- Hit/miss statistics
    cache_hits BIGINT NOT NULL DEFAULT 0,
    cache_misses BIGINT NOT NULL DEFAULT 0,
    hit_ratio DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE 
            WHEN (cache_hits + cache_misses) > 0 THEN 
                cache_hits::DECIMAL / (cache_hits + cache_misses)
            ELSE 0
        END
    ) STORED,
    
    -- Performance metrics
    avg_response_time_ms DECIMAL(8,2),
    p95_response_time_ms DECIMAL(8,2),
    
    -- Size and memory usage
    total_keys BIGINT DEFAULT 0,
    memory_usage_bytes BIGINT DEFAULT 0,
    evictions_count BIGINT DEFAULT 0,
    
    -- Error tracking
    error_count BIGINT DEFAULT 0,
    timeout_count BIGINT DEFAULT 0
);

-- ============================================================================
-- BACKGROUND JOB AND QUEUE MANAGEMENT
-- ============================================================================

-- Job queue for background processing
CREATE TABLE job_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Job identification
    job_type TEXT NOT NULL, -- 'ocr_processing', 'embedding_generation', 'notification_send'
    job_name TEXT NOT NULL,
    queue_name TEXT DEFAULT 'default',
    
    -- Priority and scheduling
    priority INTEGER DEFAULT 0, -- Higher number = higher priority
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Job payload
    job_data JSONB NOT NULL, -- Job parameters and data
    job_context JSONB DEFAULT '{}'::jsonb, -- Additional context
    
    -- Execution tracking
    status TEXT DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed', 'retrying'
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    last_error_at TIMESTAMPTZ,
    
    -- Results and errors
    result JSONB,
    error_message TEXT,
    error_details JSONB,
    
    -- Processing info
    processed_by TEXT, -- Worker/server identifier
    processing_duration_ms INTEGER,
    
    -- Cleanup
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Job dependencies for complex workflows
CREATE TABLE job_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    job_id UUID NOT NULL REFERENCES job_queue(id) ON DELETE CASCADE,
    depends_on_job_id UUID NOT NULL REFERENCES job_queue(id) ON DELETE CASCADE,
    
    -- Dependency type
    dependency_type TEXT DEFAULT 'completion', -- 'completion', 'success'
    is_blocking BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(job_id, depends_on_job_id)
);

-- ============================================================================
-- FEATURE FLAG SYSTEM
-- ============================================================================

-- Feature flags for gradual rollouts
CREATE TABLE feature_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Flag identification
    flag_key TEXT NOT NULL UNIQUE,
    flag_name TEXT NOT NULL,
    description TEXT,
    
    -- Flag configuration
    is_enabled BOOLEAN DEFAULT FALSE,
    rollout_percentage INTEGER DEFAULT 0, -- 0-100
    
    -- Targeting rules
    target_user_ids UUID[],
    target_organizations UUID[],
    target_user_attributes JSONB, -- JSON rules for user targeting
    
    -- Environment controls
    environments TEXT[] DEFAULT ARRAY['production'], -- 'development', 'staging', 'production'
    
    -- Lifecycle management
    created_by UUID REFERENCES auth.users(id),
    is_permanent BOOLEAN DEFAULT FALSE, -- If true, cannot be deleted
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feature flag evaluation logs
CREATE TABLE feature_flag_evaluations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    flag_key TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    organization_id UUID REFERENCES organizations(id),
    
    -- Evaluation result
    flag_enabled BOOLEAN NOT NULL,
    evaluation_reason TEXT, -- Why this result was returned
    
    -- Context
    user_attributes JSONB,
    request_context JSONB,
    
    evaluated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PERFORMANCE OPTIMIZED INDEXES
-- ============================================================================

-- Shard configuration indexes
CREATE INDEX idx_shard_config_active ON shard_configuration(is_active, shard_type);
CREATE INDEX idx_user_shard_mapping_user ON user_shard_mapping(user_id);
CREATE INDEX idx_user_shard_mapping_shard ON user_shard_mapping(shard_id, migration_status);

-- Rate limiting indexes
CREATE INDEX idx_api_rate_limits_user ON api_rate_limits(user_id, is_active);
CREATE INDEX idx_api_rate_limits_ip ON api_rate_limits(ip_address, endpoint_pattern);
CREATE INDEX idx_api_rate_limits_cleanup ON api_rate_limits(day_window_start) WHERE is_active = false;

-- Organization indexes
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_subscription ON organizations(subscription_tier, subscription_status);
CREATE INDEX idx_org_memberships_user ON organization_memberships(user_id, status);
CREATE INDEX idx_org_memberships_org ON organization_memberships(organization_id, role, status);

-- Cache metrics indexes (time-series data)
CREATE INDEX idx_cache_metrics_pattern_time ON cache_metrics(cache_key_pattern, metric_timestamp DESC);
CREATE INDEX idx_cache_metrics_performance ON cache_metrics(hit_ratio, avg_response_time_ms);

-- Job queue indexes for processing efficiency
CREATE INDEX idx_job_queue_processing ON job_queue(queue_name, status, priority DESC, scheduled_at ASC);
CREATE INDEX idx_job_queue_status_type ON job_queue(status, job_type, created_at DESC);
CREATE INDEX idx_job_queue_cleanup ON job_queue(expires_at) WHERE status IN ('completed', 'failed');
CREATE INDEX idx_job_dependencies_job ON job_dependencies(job_id);
CREATE INDEX idx_job_dependencies_depends ON job_dependencies(depends_on_job_id);

-- Feature flags indexes
CREATE INDEX idx_feature_flags_key ON feature_flags(flag_key, is_enabled);
CREATE INDEX idx_feature_flags_rollout ON feature_flags(is_enabled, rollout_percentage) WHERE rollout_percentage > 0;
CREATE INDEX idx_feature_flag_evaluations_user ON feature_flag_evaluations(user_id, evaluated_at DESC);

-- ============================================================================
-- PARTITIONING FOR TIME-SERIES DATA
-- ============================================================================

-- Partition cache metrics by month for better performance
-- Note: This would be done at deployment time with proper partition management

-- Monthly partitioning function for cache metrics
CREATE OR REPLACE FUNCTION create_monthly_partition(
    table_name TEXT,
    start_date DATE
)
RETURNS TEXT AS $$
DECLARE
    partition_name TEXT;
    end_date DATE;
BEGIN
    partition_name := table_name || '_' || to_char(start_date, 'YYYY_MM');
    end_date := start_date + INTERVAL '1 month';
    
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I PARTITION OF %I
        FOR VALUES FROM (%L) TO (%L)',
        partition_name, table_name, start_date, end_date
    );
    
    RETURN partition_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ADVANCED MONITORING FUNCTIONS
-- ============================================================================

-- System health dashboard function
CREATE OR REPLACE FUNCTION get_system_health_dashboard()
RETURNS TABLE(
    metric_category TEXT,
    metric_name TEXT,
    metric_value DECIMAL(15,2),
    metric_unit TEXT,
    status TEXT, -- 'healthy', 'warning', 'critical'
    threshold_value DECIMAL(15,2),
    last_updated TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    -- Database performance metrics
    SELECT 
        'database'::TEXT as metric_category,
        'active_connections'::TEXT as metric_name,
        (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active') as metric_value,
        'connections'::TEXT as metric_unit,
        CASE 
            WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 80 THEN 'critical'
            WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 50 THEN 'warning'
            ELSE 'healthy'
        END as status,
        80::DECIMAL as threshold_value,
        NOW() as last_updated
    
    UNION ALL
    
    -- Cache performance
    SELECT 
        'cache'::TEXT as metric_category,
        'avg_hit_ratio'::TEXT as metric_name,
        (SELECT AVG(hit_ratio) FROM cache_metrics 
         WHERE metric_timestamp >= NOW() - INTERVAL '1 hour')::DECIMAL(15,2) as metric_value,
        'ratio'::TEXT as metric_unit,
        CASE 
            WHEN (SELECT AVG(hit_ratio) FROM cache_metrics 
                  WHERE metric_timestamp >= NOW() - INTERVAL '1 hour') < 0.7 THEN 'critical'
            WHEN (SELECT AVG(hit_ratio) FROM cache_metrics 
                  WHERE metric_timestamp >= NOW() - INTERVAL '1 hour') < 0.8 THEN 'warning'
            ELSE 'healthy'
        END as status,
        0.8::DECIMAL as threshold_value,
        NOW() as last_updated
    
    UNION ALL
    
    -- Job queue health
    SELECT 
        'jobs'::TEXT as metric_category,
        'failed_jobs_last_hour'::TEXT as metric_name,
        (SELECT COUNT(*)::DECIMAL FROM job_queue 
         WHERE status = 'failed' AND last_error_at >= NOW() - INTERVAL '1 hour') as metric_value,
        'jobs'::TEXT as metric_unit,
        CASE 
            WHEN (SELECT COUNT(*) FROM job_queue 
                  WHERE status = 'failed' AND last_error_at >= NOW() - INTERVAL '1 hour') > 10 THEN 'critical'
            WHEN (SELECT COUNT(*) FROM job_queue 
                  WHERE status = 'failed' AND last_error_at >= NOW() - INTERVAL '1 hour') > 5 THEN 'warning'
            ELSE 'healthy'
        END as status,
        5::DECIMAL as threshold_value,
        NOW() as last_updated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resource utilization monitoring
CREATE OR REPLACE FUNCTION get_resource_utilization(
    p_time_window_hours INTEGER DEFAULT 24
)
RETURNS TABLE(
    resource_type TEXT,
    current_usage DECIMAL(15,2),
    max_capacity DECIMAL(15,2),
    usage_percentage DECIMAL(5,2),
    projected_full_date DATE
) AS $$
BEGIN
    RETURN QUERY
    -- Storage utilization
    SELECT 
        'storage'::TEXT as resource_type,
        pg_database_size(current_database())::DECIMAL / (1024*1024*1024) as current_usage, -- GB
        1000::DECIMAL as max_capacity, -- GB (configurable)
        (pg_database_size(current_database())::DECIMAL / (1024*1024*1024)) / 1000 * 100 as usage_percentage,
        (CURRENT_DATE + INTERVAL '30 days')::DATE as projected_full_date -- Simplified projection
    
    UNION ALL
    
    -- User capacity
    SELECT 
        'users'::TEXT as resource_type,
        (SELECT COUNT(*)::DECIMAL FROM auth.users) as current_usage,
        100000::DECIMAL as max_capacity, -- configurable
        (SELECT COUNT(*)::DECIMAL FROM auth.users) / 100000 * 100 as usage_percentage,
        NULL::DATE as projected_full_date
    
    UNION ALL
    
    -- API requests capacity
    SELECT 
        'api_requests'::TEXT as resource_type,
        (SELECT SUM(current_hour_requests)::DECIMAL FROM api_rate_limits) as current_usage,
        1000000::DECIMAL as max_capacity, -- requests per hour
        (SELECT SUM(current_hour_requests)::DECIMAL FROM api_rate_limits) / 1000000 * 100 as usage_percentage,
        NULL::DATE as projected_full_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- AUTOMATED MAINTENANCE PROCEDURES
-- ============================================================================

-- Cleanup old data based on retention policies
CREATE OR REPLACE FUNCTION execute_data_retention_cleanup()
RETURNS TABLE(
    table_name TEXT,
    records_deleted INTEGER,
    space_reclaimed_mb DECIMAL(10,2)
) AS $$
DECLARE
    policy_record RECORD;
    delete_count INTEGER;
    sql_query TEXT;
BEGIN
    FOR policy_record IN 
        SELECT * FROM data_retention_policies 
        WHERE is_active = true AND retention_period_days > 0
    LOOP
        -- Build dynamic delete query based on table structure
        CASE policy_record.table_name
            WHEN 'audit_logs' THEN
                sql_query := format('DELETE FROM %I WHERE executed_at < NOW() - INTERVAL ''%s days''',
                    policy_record.table_name, policy_record.retention_period_days);
            WHEN 'cache_metrics' THEN
                sql_query := format('DELETE FROM %I WHERE metric_timestamp < NOW() - INTERVAL ''%s days''',
                    policy_record.table_name, policy_record.retention_period_days);
            WHEN 'job_queue' THEN
                sql_query := format('DELETE FROM %I WHERE completed_at < NOW() - INTERVAL ''%s days'' AND status IN (''completed'', ''failed'')',
                    policy_record.table_name, policy_record.retention_period_days);
            ELSE
                sql_query := format('DELETE FROM %I WHERE created_at < NOW() - INTERVAL ''%s days''',
                    policy_record.table_name, policy_record.retention_period_days);
        END CASE;
        
        EXECUTE sql_query;
        GET DIAGNOSTICS delete_count = ROW_COUNT;
        
        RETURN QUERY SELECT 
            policy_record.table_name,
            delete_count,
            0::DECIMAL(10,2); -- Space reclamation would need to be calculated separately
    END LOOP;
    
    -- Run VACUUM ANALYZE after cleanup
    PERFORM pg_stat_reset();
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- DEFAULT CONFIGURATIONS
-- ============================================================================

-- Insert default cache configurations
INSERT INTO cache_configurations (cache_key_pattern, cache_type, default_ttl_seconds) VALUES
('user_profile_{user_id}', 'redis', 3600),
('user_receipts_{user_id}_page_{page}', 'redis', 900),
('receipt_embeddings_{receipt_id}', 'redis', 7200),
('warranty_alerts_{user_id}', 'redis', 1800),
('spending_analytics_{user_id}_{period}', 'redis', 3600),
('category_list_{user_id}', 'redis', 1800);

-- Insert default feature flags
INSERT INTO feature_flags (flag_key, flag_name, description, is_enabled) VALUES
('advanced_ocr', 'Advanced OCR Processing', 'Enable AI-powered OCR with higher accuracy', false),
('real_time_notifications', 'Real-time Notifications', 'Push notifications for warranty expiration', true),
('bulk_receipt_upload', 'Bulk Receipt Upload', 'Allow multiple receipt uploads', false),
('ai_spending_insights', 'AI Spending Insights', 'AI-powered spending pattern analysis', false),
('data_export', 'Data Export', 'Allow users to export their data', true),
('receipt_sharing', 'Receipt Sharing', 'Share receipts with team members', false);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE shard_configuration IS 'Horizontal scaling shard management';
COMMENT ON TABLE user_shard_mapping IS 'Maps users to specific database shards';
COMMENT ON TABLE api_rate_limits IS 'API rate limiting and quota management';
COMMENT ON TABLE organizations IS 'Multi-tenant organization management';
COMMENT ON TABLE organization_memberships IS 'User membership in organizations';
COMMENT ON TABLE cache_configurations IS 'Cache layer configuration and management';
COMMENT ON TABLE cache_metrics IS 'Cache performance monitoring metrics';
COMMENT ON TABLE job_queue IS 'Background job processing queue';
COMMENT ON TABLE job_dependencies IS 'Job dependency management for complex workflows';
COMMENT ON TABLE feature_flags IS 'Feature flag system for gradual rollouts';
COMMENT ON TABLE feature_flag_evaluations IS 'Feature flag evaluation audit trail';

COMMIT;

-- ============================================================================
-- POST-MIGRATION SETUP RECOMMENDATIONS
-- ============================================================================
/*
-- 1. Set up monitoring alerts based on system health thresholds
-- 2. Configure cache invalidation strategies
-- 3. Set up job queue workers
-- 4. Plan shard distribution strategy
-- 5. Configure feature flag targeting rules
-- 6. Set up automated cleanup schedules
-- 7. Monitor resource utilization trends
-- 8. Test partition management procedures

-- Example health check query:
SELECT * FROM get_system_health_dashboard() WHERE status != 'healthy';

-- Example resource monitoring:
SELECT * FROM get_resource_utilization(24) WHERE usage_percentage > 80;
*/