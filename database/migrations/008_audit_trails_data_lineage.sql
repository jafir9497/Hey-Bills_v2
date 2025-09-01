-- Migration: 008_audit_trails_data_lineage.sql
-- Description: Comprehensive audit trails and data lineage tracking system
-- Author: Database Architect & Schema Validator Agents
-- Date: 2025-08-31
-- Dependencies: All previous migrations (001-007)

BEGIN;

-- ============================================================================
-- AUDIT TRAIL INFRASTRUCTURE
-- ============================================================================

-- Audit operation types
CREATE TYPE audit_operation AS ENUM (
    'INSERT', 'UPDATE', 'DELETE', 'SELECT', 'BULK_INSERT', 'BULK_UPDATE', 'BULK_DELETE'
);

-- Data sensitivity levels
CREATE TYPE data_sensitivity AS ENUM ('public', 'internal', 'confidential', 'restricted');

-- Main audit log table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Core audit information
    table_name TEXT NOT NULL,
    record_id UUID, -- The primary key of the affected record
    operation audit_operation NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    
    -- Session and context information
    session_id TEXT,
    ip_address INET,
    user_agent TEXT,
    application_context JSONB DEFAULT '{}'::jsonb,
    
    -- Data changes
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[], -- Array of field names that were changed
    
    -- Metadata
    transaction_id BIGINT DEFAULT txid_current(),
    sensitivity_level data_sensitivity DEFAULT 'internal',
    retention_policy TEXT DEFAULT '7_years',
    
    -- Timestamps
    executed_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Additional context
    reason TEXT, -- Reason for the change (optional)
    batch_id UUID, -- For bulk operations
    parent_audit_id UUID REFERENCES audit_logs(id), -- For related operations
    
    -- Index optimization
    created_date DATE GENERATED ALWAYS AS (executed_at::date) STORED,
    created_month TEXT GENERATED ALWAYS AS (to_char(executed_at, 'YYYY-MM')) STORED
);

-- Data lineage tracking table
CREATE TABLE data_lineage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Source and destination
    source_table TEXT NOT NULL,
    source_id UUID NOT NULL,
    destination_table TEXT NOT NULL,
    destination_id UUID NOT NULL,
    
    -- Transformation information
    transformation_type TEXT NOT NULL, -- 'derived', 'aggregated', 'copied', 'processed'
    transformation_logic TEXT, -- Description or code of transformation
    transformation_metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Quality metrics
    data_quality_score DECIMAL(3,2), -- 0.00 to 1.00
    completeness_score DECIMAL(3,2),
    accuracy_indicators JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    
    -- Context
    created_by UUID REFERENCES auth.users(id),
    process_name TEXT,
    batch_id UUID
);

-- Data retention policies table
CREATE TABLE data_retention_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    table_name TEXT NOT NULL UNIQUE,
    retention_period_days INTEGER NOT NULL,
    archival_strategy TEXT DEFAULT 'hard_delete', -- 'hard_delete', 'soft_delete', 'archive'
    
    -- Policy details
    policy_description TEXT,
    compliance_requirements TEXT[],
    exceptions JSONB DEFAULT '{}'::jsonb,
    
    -- Management
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- ============================================================================
-- RECEIPT-SPECIFIC AUDIT ENHANCEMENTS
-- ============================================================================

-- Receipt processing audit trail
CREATE TABLE receipt_processing_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Processing stages
    stage TEXT NOT NULL, -- 'uploaded', 'ocr_processing', 'ocr_completed', 'embedding_created', 'validated'
    status TEXT NOT NULL, -- 'started', 'in_progress', 'completed', 'failed', 'retrying'
    
    -- Processing details
    processor_version TEXT,
    processing_duration_ms INTEGER,
    confidence_scores JSONB,
    error_details JSONB,
    
    -- OCR specific data
    ocr_provider TEXT,
    ocr_model_version TEXT,
    raw_ocr_response JSONB,
    extracted_entities JSONB,
    
    -- Embedding specific data
    embedding_model TEXT,
    embedding_dimensions INTEGER,
    embedding_cost DECIMAL(10,4),
    
    -- Quality metrics
    data_quality_flags JSONB DEFAULT '{}'::jsonb,
    validation_results JSONB,
    
    -- Context
    processed_by UUID REFERENCES auth.users(id),
    processing_node TEXT, -- Server/instance that processed
    batch_id UUID,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Receipt data quality metrics
CREATE TABLE receipt_data_quality (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Quality scores (0.0 to 1.0)
    overall_quality_score DECIMAL(3,2) NOT NULL,
    completeness_score DECIMAL(3,2) NOT NULL,
    accuracy_score DECIMAL(3,2) NOT NULL,
    consistency_score DECIMAL(3,2) NOT NULL,
    
    -- Specific quality checks
    quality_checks JSONB NOT NULL, -- Detailed results of quality checks
    validation_rules_passed TEXT[],
    validation_rules_failed TEXT[],
    
    -- Issue tracking
    data_issues JSONB DEFAULT '[]'::jsonb, -- Array of identified issues
    severity_level TEXT DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    requires_manual_review BOOLEAN DEFAULT FALSE,
    
    -- Resolution tracking
    issues_resolved JSONB DEFAULT '[]'::jsonb,
    resolution_notes TEXT,
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    
    -- Audit trail
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- ============================================================================
-- PERFORMANCE OPTIMIZED INDEXES
-- ============================================================================

-- Audit logs indexes (partitioned by date for performance)
CREATE INDEX idx_audit_logs_table_operation ON audit_logs(table_name, operation, executed_at DESC);
CREATE INDEX idx_audit_logs_user_date ON audit_logs(user_id, executed_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_logs_record_tracking ON audit_logs(table_name, record_id, executed_at DESC);
CREATE INDEX idx_audit_logs_transaction ON audit_logs(transaction_id);
CREATE INDEX idx_audit_logs_batch ON audit_logs(batch_id) WHERE batch_id IS NOT NULL;
CREATE INDEX idx_audit_logs_monthly ON audit_logs(created_month, table_name);

-- Data lineage indexes
CREATE INDEX idx_data_lineage_source ON data_lineage(source_table, source_id);
CREATE INDEX idx_data_lineage_destination ON data_lineage(destination_table, destination_id);
CREATE INDEX idx_data_lineage_transformation ON data_lineage(transformation_type, created_at DESC);
CREATE INDEX idx_data_lineage_batch ON data_lineage(batch_id) WHERE batch_id IS NOT NULL;

-- Receipt processing audit indexes
CREATE INDEX idx_receipt_processing_receipt ON receipt_processing_audit(receipt_id, created_at DESC);
CREATE INDEX idx_receipt_processing_stage ON receipt_processing_audit(stage, status, created_at DESC);
CREATE INDEX idx_receipt_processing_failed ON receipt_processing_audit(receipt_id) 
    WHERE status = 'failed';

-- Data quality indexes
CREATE INDEX idx_receipt_quality_score ON receipt_data_quality(receipt_id, overall_quality_score DESC);
CREATE INDEX idx_receipt_quality_issues ON receipt_data_quality(requires_manual_review, severity_level) 
    WHERE requires_manual_review = true;

-- ============================================================================
-- AUDIT TRIGGER FUNCTIONS
-- ============================================================================

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    audit_user_id UUID;
    old_data JSONB;
    new_data JSONB;
    excluded_columns TEXT[] := ARRAY['updated_at', 'last_modified'];
    changed_fields TEXT[] := ARRAY[]::TEXT[];
    column_name TEXT;
BEGIN
    -- Get current user ID from session
    audit_user_id := COALESCE(
        current_setting('app.current_user_id', true)::UUID,
        auth.uid()
    );
    
    -- Prepare data based on operation
    IF TG_OP = 'DELETE' THEN
        old_data := to_jsonb(OLD);
        new_data := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        old_data := NULL;
        new_data := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
        
        -- Identify changed fields (excluding metadata columns)
        FOR column_name IN 
            SELECT key FROM jsonb_each(old_data)
            WHERE key NOT IN (SELECT unnest(excluded_columns))
        LOOP
            IF old_data->column_name IS DISTINCT FROM new_data->column_name THEN
                changed_fields := array_append(changed_fields, column_name);
            END IF;
        END LOOP;
    END IF;
    
    -- Insert audit record
    INSERT INTO audit_logs (
        table_name,
        record_id,
        operation,
        user_id,
        session_id,
        old_values,
        new_values,
        changed_fields
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE((new_data->>'id')::UUID, (old_data->>'id')::UUID),
        TG_OP::audit_operation,
        audit_user_id,
        current_setting('app.session_id', true),
        old_data,
        new_data,
        changed_fields
    );
    
    -- Return appropriate record
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- DATA LINEAGE TRACKING FUNCTIONS
-- ============================================================================

-- Function to track data lineage automatically
CREATE OR REPLACE FUNCTION track_data_lineage(
    p_source_table TEXT,
    p_source_id UUID,
    p_destination_table TEXT,
    p_destination_id UUID,
    p_transformation_type TEXT,
    p_transformation_logic TEXT DEFAULT NULL,
    p_quality_score DECIMAL(3,2) DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    lineage_id UUID;
BEGIN
    INSERT INTO data_lineage (
        source_table,
        source_id,
        destination_table,
        destination_id,
        transformation_type,
        transformation_logic,
        data_quality_score,
        transformation_metadata,
        created_by,
        processed_at
    ) VALUES (
        p_source_table,
        p_source_id,
        p_destination_table,
        p_destination_id,
        p_transformation_type,
        p_transformation_logic,
        p_quality_score,
        p_metadata,
        COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
        NOW()
    ) RETURNING id INTO lineage_id;
    
    RETURN lineage_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to trace data lineage backwards
CREATE OR REPLACE FUNCTION trace_data_lineage_backwards(
    p_table_name TEXT,
    p_record_id UUID,
    p_max_depth INTEGER DEFAULT 10
)
RETURNS TABLE(
    level INTEGER,
    source_table TEXT,
    source_id UUID,
    transformation_type TEXT,
    transformation_logic TEXT,
    created_at TIMESTAMPTZ,
    quality_score DECIMAL(3,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE lineage_trace AS (
        -- Base case: direct sources
        SELECT 
            1 as level,
            dl.source_table,
            dl.source_id,
            dl.transformation_type,
            dl.transformation_logic,
            dl.created_at,
            dl.data_quality_score as quality_score
        FROM data_lineage dl
        WHERE dl.destination_table = p_table_name 
            AND dl.destination_id = p_record_id
        
        UNION ALL
        
        -- Recursive case: sources of sources
        SELECT 
            lt.level + 1,
            dl.source_table,
            dl.source_id,
            dl.transformation_type,
            dl.transformation_logic,
            dl.created_at,
            dl.data_quality_score
        FROM data_lineage dl
        JOIN lineage_trace lt ON dl.destination_table = lt.source_table 
            AND dl.destination_id = lt.source_id
        WHERE lt.level < p_max_depth
    )
    SELECT * FROM lineage_trace ORDER BY level, created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- DATA QUALITY ASSESSMENT FUNCTIONS
-- ============================================================================

-- Comprehensive receipt data quality assessment
CREATE OR REPLACE FUNCTION assess_receipt_data_quality(
    p_receipt_id UUID
)
RETURNS UUID AS $$
DECLARE
    quality_id UUID;
    receipt_data RECORD;
    completeness_score DECIMAL(3,2) := 0;
    accuracy_score DECIMAL(3,2) := 0;
    consistency_score DECIMAL(3,2) := 0;
    overall_score DECIMAL(3,2);
    quality_issues JSONB := '[]'::jsonb;
    validation_passed TEXT[] := ARRAY[]::TEXT[];
    validation_failed TEXT[] := ARRAY[]::TEXT[];
    requires_review BOOLEAN := false;
BEGIN
    -- Get receipt data
    SELECT r.*, re.ocr_confidence 
    INTO receipt_data
    FROM receipts r
    LEFT JOIN receipt_embeddings re ON r.id = re.receipt_id
    WHERE r.id = p_receipt_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receipt not found: %', p_receipt_id;
    END IF;
    
    -- Assess completeness (required fields present)
    completeness_score := 0;
    IF receipt_data.merchant_name IS NOT NULL AND length(trim(receipt_data.merchant_name)) > 0 THEN
        completeness_score := completeness_score + 0.25;
        validation_passed := array_append(validation_passed, 'merchant_name_present');
    ELSE
        quality_issues := quality_issues || jsonb_build_object('field', 'merchant_name', 'issue', 'missing_or_empty');
        validation_failed := array_append(validation_failed, 'merchant_name_present');
    END IF;
    
    IF receipt_data.total_amount > 0 THEN
        completeness_score := completeness_score + 0.25;
        validation_passed := array_append(validation_passed, 'total_amount_positive');
    ELSE
        quality_issues := quality_issues || jsonb_build_object('field', 'total_amount', 'issue', 'invalid_amount');
        validation_failed := array_append(validation_failed, 'total_amount_positive');
    END IF;
    
    IF receipt_data.purchase_date IS NOT NULL THEN
        completeness_score := completeness_score + 0.25;
        validation_passed := array_append(validation_passed, 'purchase_date_present');
    ELSE
        quality_issues := quality_issues || jsonb_build_object('field', 'purchase_date', 'issue', 'missing_date');
        validation_failed := array_append(validation_failed, 'purchase_date_present');
    END IF;
    
    IF receipt_data.image_url IS NOT NULL AND length(trim(receipt_data.image_url)) > 0 THEN
        completeness_score := completeness_score + 0.25;
        validation_passed := array_append(validation_passed, 'image_url_present');
    ELSE
        quality_issues := quality_issues || jsonb_build_object('field', 'image_url', 'issue', 'missing_image');
        validation_failed := array_append(validation_failed, 'image_url_present');
    END IF;
    
    -- Assess accuracy (based on OCR confidence and data validation)
    accuracy_score := COALESCE(receipt_data.ocr_confidence, 0.5);
    
    -- Date validation
    IF receipt_data.purchase_date > CURRENT_DATE THEN
        accuracy_score := accuracy_score * 0.8; -- Reduce score for future dates
        quality_issues := quality_issues || jsonb_build_object('field', 'purchase_date', 'issue', 'future_date');
        validation_failed := array_append(validation_failed, 'purchase_date_not_future');
        requires_review := true;
    ELSE
        validation_passed := array_append(validation_passed, 'purchase_date_not_future');
    END IF;
    
    -- Amount validation
    IF receipt_data.tax_amount IS NOT NULL AND receipt_data.tax_amount > receipt_data.total_amount THEN
        accuracy_score := accuracy_score * 0.7;
        quality_issues := quality_issues || jsonb_build_object('field', 'tax_amount', 'issue', 'tax_exceeds_total');
        validation_failed := array_append(validation_failed, 'tax_amount_reasonable');
        requires_review := true;
    ELSE
        validation_passed := array_append(validation_passed, 'tax_amount_reasonable');
    END IF;
    
    -- Assess consistency
    consistency_score := 1.0;
    
    -- Check if receipt items total matches receipt total
    WITH items_total AS (
        SELECT COALESCE(SUM(total_price), 0) as calculated_total
        FROM receipt_items 
        WHERE receipt_id = p_receipt_id
    )
    SELECT calculated_total INTO STRICT receipt_data.items_total FROM items_total;
    
    IF receipt_data.items_total > 0 AND 
       ABS(receipt_data.items_total - receipt_data.total_amount) > 0.50 THEN
        consistency_score := consistency_score * 0.8;
        quality_issues := quality_issues || jsonb_build_object(
            'field', 'total_amount', 
            'issue', 'items_total_mismatch',
            'details', jsonb_build_object(
                'receipt_total', receipt_data.total_amount,
                'items_total', receipt_data.items_total
            )
        );
        validation_failed := array_append(validation_failed, 'items_total_matches');
    ELSE
        validation_passed := array_append(validation_passed, 'items_total_matches');
    END IF;
    
    -- Calculate overall quality score
    overall_score := (completeness_score + accuracy_score + consistency_score) / 3.0;
    
    -- Determine if manual review is needed
    IF overall_score < 0.7 OR array_length(validation_failed, 1) > 2 THEN
        requires_review := true;
    END IF;
    
    -- Insert quality assessment
    INSERT INTO receipt_data_quality (
        receipt_id,
        overall_quality_score,
        completeness_score,
        accuracy_score,
        consistency_score,
        quality_checks,
        validation_rules_passed,
        validation_rules_failed,
        data_issues,
        requires_manual_review,
        created_by
    ) VALUES (
        p_receipt_id,
        overall_score,
        completeness_score,
        accuracy_score,
        consistency_score,
        jsonb_build_object(
            'completeness', completeness_score,
            'accuracy', accuracy_score,
            'consistency', consistency_score,
            'assessment_timestamp', NOW(),
            'assessment_version', '1.0'
        ),
        validation_passed,
        validation_failed,
        quality_issues,
        requires_review,
        COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid())
    ) RETURNING id INTO quality_id;
    
    RETURN quality_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INSTALL AUDIT TRIGGERS ON KEY TABLES
-- ============================================================================

-- Enable auditing on core tables
CREATE TRIGGER audit_user_profiles 
    AFTER INSERT OR UPDATE OR DELETE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_categories 
    AFTER INSERT OR UPDATE OR DELETE ON categories
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_receipts 
    AFTER INSERT OR UPDATE OR DELETE ON receipts
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_receipt_items 
    AFTER INSERT OR UPDATE OR DELETE ON receipt_items
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_warranties 
    AFTER INSERT OR UPDATE OR DELETE ON warranties
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_budgets 
    AFTER INSERT OR UPDATE OR DELETE ON budgets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ============================================================================
-- ROW LEVEL SECURITY FOR AUDIT TABLES
-- ============================================================================

-- Enable RLS on audit tables
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_processing_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_data_quality ENABLE ROW LEVEL SECURITY;

-- Audit logs policies (users can only see their own audit records)
CREATE POLICY "Users can view own audit logs" 
    ON audit_logs FOR SELECT 
    USING (user_id = auth.uid() OR auth.jwt() ->> 'role' = 'service_role');

-- Data lineage policies
CREATE POLICY "Users can view related data lineage" 
    ON data_lineage FOR SELECT 
    USING (created_by = auth.uid() OR auth.jwt() ->> 'role' = 'service_role');

-- Receipt processing audit policies
CREATE POLICY "Users can view own receipt processing audit" 
    ON receipt_processing_audit FOR SELECT 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));

-- Receipt data quality policies
CREATE POLICY "Users can view own receipt quality data" 
    ON receipt_data_quality FOR SELECT 
    USING (receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid()));

-- ============================================================================
-- DEFAULT RETENTION POLICIES
-- ============================================================================

INSERT INTO data_retention_policies (table_name, retention_period_days, policy_description) VALUES
('audit_logs', 2555, '7 years retention for audit compliance'), -- 7 years
('receipt_processing_audit', 1095, '3 years retention for operational analysis'), -- 3 years
('receipt_data_quality', 1825, '5 years retention for quality tracking'), -- 5 years
('data_lineage', 1825, '5 years retention for data governance'), -- 5 years
('notifications', 365, '1 year retention for notification history'), -- 1 year
('receipts', -1, 'Permanent retention unless user requests deletion'),
('warranties', -1, 'Permanent retention unless user requests deletion');

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all database operations';
COMMENT ON TABLE data_lineage IS 'Tracks data transformation and movement between tables';
COMMENT ON TABLE receipt_processing_audit IS 'Detailed audit trail for receipt processing pipeline';
COMMENT ON TABLE receipt_data_quality IS 'Data quality assessments and metrics for receipts';
COMMENT ON TABLE data_retention_policies IS 'Defines retention policies for different data types';

COMMENT ON FUNCTION audit_trigger_function() IS 'Generic trigger function for capturing data changes';
COMMENT ON FUNCTION track_data_lineage(TEXT, UUID, TEXT, UUID, TEXT, TEXT, DECIMAL, JSONB) IS 'Tracks data lineage between entities';
COMMENT ON FUNCTION trace_data_lineage_backwards(TEXT, UUID, INTEGER) IS 'Traces data lineage backwards through transformations';
COMMENT ON FUNCTION assess_receipt_data_quality(UUID) IS 'Comprehensive data quality assessment for receipts';

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
/*
-- Test audit trigger
INSERT INTO categories (user_id, name) VALUES (auth.uid(), 'Test Category');

-- Check audit log was created
SELECT * FROM audit_logs WHERE table_name = 'categories' ORDER BY executed_at DESC LIMIT 1;

-- Test data quality assessment
SELECT assess_receipt_data_quality('receipt_id_here'::UUID);

-- Check retention policies
SELECT * FROM data_retention_policies;
*/