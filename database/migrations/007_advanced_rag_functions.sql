-- Migration: 007_advanced_rag_functions.sql
-- Description: Advanced RAG functions and vector similarity search capabilities
-- Author: Vector Embedding Specialist Agent
-- Date: 2025-08-31
-- Dependencies: 004_vector_embeddings.sql, 006_enhanced_performance_indexes.sql

BEGIN;

-- ============================================================================
-- RAG HELPER FUNCTIONS
-- ============================================================================

-- Function to find similar receipts using vector similarity
CREATE OR REPLACE FUNCTION find_similar_receipts(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_similarity_threshold FLOAT DEFAULT 0.8,
    p_limit INTEGER DEFAULT 10,
    p_category_filter UUID[] DEFAULT NULL,
    p_date_range_days INTEGER DEFAULT NULL
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    category_name TEXT,
    similarity_score FLOAT,
    content_text TEXT,
    tags TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        COALESCE(c.name, 'Uncategorized') as category_name,
        (1 - (re.embedding <=> p_query_embedding))::FLOAT as similarity_score,
        re.content_text,
        r.tags
    FROM receipt_embeddings re
    JOIN receipts r ON re.receipt_id = r.id
    LEFT JOIN categories c ON r.category_id = c.id
    WHERE r.user_id = p_user_id
        AND (1 - (re.embedding <=> p_query_embedding)) >= p_similarity_threshold
        AND (p_category_filter IS NULL OR r.category_id = ANY(p_category_filter))
        AND (p_date_range_days IS NULL OR r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * p_date_range_days)
    ORDER BY re.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to find similar warranties for recommendations
CREATE OR REPLACE FUNCTION find_similar_warranties(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_similarity_threshold FLOAT DEFAULT 0.8,
    p_limit INTEGER DEFAULT 5,
    p_status_filter warranty_status[] DEFAULT NULL
)
RETURNS TABLE(
    warranty_id UUID,
    product_name TEXT,
    manufacturer TEXT,
    warranty_end_date DATE,
    warranty_status warranty_status,
    similarity_score FLOAT,
    content_text TEXT,
    days_until_expiry INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id as warranty_id,
        w.product_name,
        w.manufacturer,
        w.warranty_end_date,
        w.status as warranty_status,
        (1 - (we.embedding <=> p_query_embedding))::FLOAT as similarity_score,
        we.content_text,
        (w.warranty_end_date - CURRENT_DATE)::INTEGER as days_until_expiry
    FROM warranty_embeddings we
    JOIN warranties w ON we.warranty_id = w.id
    WHERE w.user_id = p_user_id
        AND w.is_active = true
        AND (1 - (we.embedding <=> p_query_embedding)) >= p_similarity_threshold
        AND (p_status_filter IS NULL OR w.status = ANY(p_status_filter))
    ORDER BY we.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Hybrid search combining vector similarity with text search
CREATE OR REPLACE FUNCTION hybrid_receipt_search(
    p_user_id UUID,
    p_text_query TEXT,
    p_query_embedding VECTOR(1536) DEFAULT NULL,
    p_vector_weight FLOAT DEFAULT 0.6,
    p_text_weight FLOAT DEFAULT 0.4,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    category_name TEXT,
    combined_score FLOAT,
    vector_score FLOAT,
    text_score FLOAT,
    content_text TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH vector_search AS (
        SELECT 
            r.id as receipt_id,
            r.merchant_name,
            r.total_amount,
            r.purchase_date,
            COALESCE(c.name, 'Uncategorized') as category_name,
            re.content_text,
            CASE 
                WHEN p_query_embedding IS NOT NULL THEN 
                    (1 - (re.embedding <=> p_query_embedding))::FLOAT
                ELSE 0.0
            END as vector_score
        FROM receipts r
        JOIN receipt_embeddings re ON r.id = re.receipt_id
        LEFT JOIN categories c ON r.category_id = c.id
        WHERE r.user_id = p_user_id
    ),
    text_search AS (
        SELECT 
            vs.*,
            COALESCE(
                ts_rank(
                    to_tsvector('english', 
                        COALESCE(vs.merchant_name, '') || ' ' || 
                        COALESCE(vs.content_text, '')
                    ),
                    plainto_tsquery('english', p_text_query)
                ), 0
            )::FLOAT as text_score
        FROM vector_search vs
    )
    SELECT 
        ts.receipt_id,
        ts.merchant_name,
        ts.total_amount,
        ts.purchase_date,
        ts.category_name,
        (ts.vector_score * p_vector_weight + ts.text_score * p_text_weight)::FLOAT as combined_score,
        ts.vector_score,
        ts.text_score,
        ts.content_text
    FROM text_search ts
    WHERE (ts.vector_score > 0 OR ts.text_score > 0)
    ORDER BY combined_score DESC, ts.purchase_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- EMBEDDING BATCH PROCESSING FUNCTIONS
-- ============================================================================

-- Function to find receipts without embeddings
CREATE OR REPLACE FUNCTION get_receipts_needing_embeddings(
    p_user_id UUID DEFAULT NULL,
    p_batch_size INTEGER DEFAULT 50,
    p_embedding_model TEXT DEFAULT 'text-embedding-ada-002'
)
RETURNS TABLE(
    receipt_id UUID,
    user_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    content_for_embedding TEXT,
    tags TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.user_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        -- Create comprehensive content for embedding
        CONCAT(
            'Merchant: ', COALESCE(r.merchant_name, ''), ' ',
            'Amount: $', r.total_amount, ' ',
            'Date: ', r.purchase_date, ' ',
            'Category: ', COALESCE(c.name, 'Uncategorized'), ' ',
            'Notes: ', COALESCE(r.notes, ''), ' ',
            'Tags: ', array_to_string(COALESCE(r.tags, ARRAY[]::TEXT[]), ', '), ' ',
            'Items: ', COALESCE(STRING_AGG(ri.item_name, ', '), '')
        ) as content_for_embedding,
        r.tags
    FROM receipts r
    LEFT JOIN categories c ON r.category_id = c.id
    LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
    LEFT JOIN receipt_embeddings re ON r.id = re.receipt_id
    WHERE re.receipt_id IS NULL  -- No existing embedding
        AND (p_user_id IS NULL OR r.user_id = p_user_id)
    GROUP BY r.id, r.user_id, r.merchant_name, r.total_amount, r.purchase_date, c.name, r.notes, r.tags
    ORDER BY r.created_at DESC
    LIMIT p_batch_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to find warranties without embeddings
CREATE OR REPLACE FUNCTION get_warranties_needing_embeddings(
    p_user_id UUID DEFAULT NULL,
    p_batch_size INTEGER DEFAULT 50
)
RETURNS TABLE(
    warranty_id UUID,
    user_id UUID,
    product_name TEXT,
    manufacturer TEXT,
    warranty_end_date DATE,
    content_for_embedding TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id as warranty_id,
        w.user_id,
        w.product_name,
        w.manufacturer,
        w.warranty_end_date,
        CONCAT(
            'Product: ', COALESCE(w.product_name, ''), ' ',
            'Manufacturer: ', COALESCE(w.manufacturer, ''), ' ',
            'Model: ', COALESCE(w.model_number, ''), ' ',
            'Category: ', COALESCE(w.category, ''), ' ',
            'Warranty Period: ', w.warranty_period_months, ' months ',
            'Purchase Date: ', w.purchase_date, ' ',
            'Retailer: ', COALESCE(w.retailer, ''), ' ',
            'Terms: ', COALESCE(w.warranty_terms, ''), ' ',
            'Notes: ', COALESCE(w.notes, '')
        ) as content_for_embedding
    FROM warranties w
    LEFT JOIN warranty_embeddings we ON w.id = we.warranty_id
    WHERE we.warranty_id IS NULL  -- No existing embedding
        AND w.is_active = true
        AND (p_user_id IS NULL OR w.user_id = p_user_id)
    ORDER BY w.created_at DESC
    LIMIT p_batch_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RAG CONTEXT BUILDING FUNCTIONS
-- ============================================================================

-- Build context for RAG queries about spending patterns
CREATE OR REPLACE FUNCTION build_spending_context(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_context_limit INTEGER DEFAULT 5,
    p_date_range_days INTEGER DEFAULT 90
)
RETURNS TABLE(
    context_type TEXT,
    context_data JSONB,
    relevance_score FLOAT,
    source_id UUID
) AS $$
BEGIN
    RETURN QUERY
    -- Get relevant receipts
    SELECT 
        'receipt'::TEXT as context_type,
        jsonb_build_object(
            'merchant', r.merchant_name,
            'amount', r.total_amount,
            'date', r.purchase_date,
            'category', c.name,
            'items', (
                SELECT json_agg(
                    json_build_object(
                        'name', ri.item_name,
                        'price', ri.total_price,
                        'quantity', ri.quantity
                    )
                )
                FROM receipt_items ri 
                WHERE ri.receipt_id = r.id
            )
        ) as context_data,
        (1 - (re.embedding <=> p_query_embedding))::FLOAT as relevance_score,
        r.id as source_id
    FROM receipt_embeddings re
    JOIN receipts r ON re.receipt_id = r.id
    LEFT JOIN categories c ON r.category_id = c.id
    WHERE r.user_id = p_user_id
        AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 day' * p_date_range_days
        AND (1 - (re.embedding <=> p_query_embedding)) > 0.7
    ORDER BY re.embedding <=> p_query_embedding
    LIMIT p_context_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Build context for warranty-related queries
CREATE OR REPLACE FUNCTION build_warranty_context(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_context_limit INTEGER DEFAULT 3
)
RETURNS TABLE(
    context_type TEXT,
    context_data JSONB,
    relevance_score FLOAT,
    source_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'warranty'::TEXT as context_type,
        jsonb_build_object(
            'product', w.product_name,
            'manufacturer', w.manufacturer,
            'model', w.model_number,
            'warranty_end', w.warranty_end_date,
            'status', w.status,
            'days_remaining', (w.warranty_end_date - CURRENT_DATE),
            'purchase_price', w.purchase_price,
            'retailer', w.retailer,
            'registration_required', w.registration_required,
            'registration_completed', w.registration_completed
        ) as context_data,
        (1 - (we.embedding <=> p_query_embedding))::FLOAT as relevance_score,
        w.id as source_id
    FROM warranty_embeddings we
    JOIN warranties w ON we.warranty_id = w.id
    WHERE w.user_id = p_user_id
        AND w.is_active = true
        AND (1 - (we.embedding <=> p_query_embedding)) > 0.7
    ORDER BY we.embedding <=> p_query_embedding
    LIMIT p_context_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- EMBEDDING ANALYTICS FUNCTIONS
-- ============================================================================

-- Analyze embedding cluster patterns for insights
CREATE OR REPLACE FUNCTION analyze_spending_clusters(
    p_user_id UUID,
    p_cluster_threshold FLOAT DEFAULT 0.85,
    p_min_cluster_size INTEGER DEFAULT 3
)
RETURNS TABLE(
    cluster_id INTEGER,
    cluster_center VECTOR(1536),
    cluster_size INTEGER,
    avg_amount DECIMAL(10,2),
    top_merchants TEXT[],
    common_categories TEXT[],
    date_range DATERANGE
) AS $$
DECLARE
    cluster_counter INTEGER := 0;
BEGIN
    -- This is a simplified clustering approach
    -- In production, you might want to use more sophisticated clustering algorithms
    RETURN QUERY
    WITH receipt_similarities AS (
        SELECT 
            re1.receipt_id as receipt1_id,
            re2.receipt_id as receipt2_id,
            (1 - (re1.embedding <=> re2.embedding)) as similarity
        FROM receipt_embeddings re1
        JOIN receipt_embeddings re2 ON re1.receipt_id != re2.receipt_id
        JOIN receipts r1 ON re1.receipt_id = r1.id
        JOIN receipts r2 ON re2.receipt_id = r2.id
        WHERE r1.user_id = p_user_id 
            AND r2.user_id = p_user_id
            AND (1 - (re1.embedding <=> re2.embedding)) >= p_cluster_threshold
    ),
    clusters AS (
        -- Basic clustering logic - groups highly similar receipts
        SELECT 
            dense_rank() OVER (ORDER BY receipt1_id) as cluster_id,
            array_agg(DISTINCT receipt1_id) || array_agg(DISTINCT receipt2_id) as receipt_ids
        FROM receipt_similarities
        GROUP BY receipt1_id
        HAVING COUNT(*) >= p_min_cluster_size - 1
    )
    SELECT 
        c.cluster_id::INTEGER,
        -- Compute cluster center (average of embeddings)
        (
            SELECT AVG(re.embedding)
            FROM receipt_embeddings re
            WHERE re.receipt_id = ANY(c.receipt_ids)
        )::VECTOR(1536) as cluster_center,
        array_length(c.receipt_ids, 1)::INTEGER as cluster_size,
        (
            SELECT AVG(r.total_amount)::DECIMAL(10,2)
            FROM receipts r
            WHERE r.id = ANY(c.receipt_ids)
        ) as avg_amount,
        (
            SELECT array_agg(DISTINCT r.merchant_name ORDER BY r.merchant_name)
            FROM receipts r
            WHERE r.id = ANY(c.receipt_ids)
        )::TEXT[] as top_merchants,
        (
            SELECT array_agg(DISTINCT cat.name ORDER BY cat.name)
            FROM receipts r
            JOIN categories cat ON r.category_id = cat.id
            WHERE r.id = ANY(c.receipt_ids)
        )::TEXT[] as common_categories,
        (
            SELECT daterange(MIN(r.purchase_date), MAX(r.purchase_date), '[]')
            FROM receipts r
            WHERE r.id = ANY(c.receipt_ids)
        ) as date_range
    FROM clusters c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- EMBEDDING MAINTENANCE FUNCTIONS
-- ============================================================================

-- Function to update stale embeddings when content changes
CREATE OR REPLACE FUNCTION update_stale_embeddings(
    p_embedding_model TEXT DEFAULT 'text-embedding-ada-002',
    p_batch_size INTEGER DEFAULT 100
)
RETURNS TABLE(
    entity_type TEXT,
    entity_id UUID,
    needs_update BOOLEAN,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Find receipt embeddings that need updates
    SELECT 
        'receipt'::TEXT as entity_type,
        r.id as entity_id,
        true as needs_update,
        'Content hash mismatch'::TEXT as reason
    FROM receipts r
    JOIN receipt_embeddings re ON r.id = re.receipt_id
    WHERE re.content_hash != md5(
        CONCAT(
            COALESCE(r.merchant_name, ''), 
            COALESCE(r.notes, ''),
            COALESCE(r.total_amount::TEXT, ''),
            array_to_string(COALESCE(r.tags, ARRAY[]::TEXT[]), '')
        )
    )
    
    UNION ALL
    
    -- Find warranty embeddings that need updates
    SELECT 
        'warranty'::TEXT as entity_type,
        w.id as entity_id,
        true as needs_update,
        'Content hash mismatch'::TEXT as reason
    FROM warranties w
    JOIN warranty_embeddings we ON w.id = we.warranty_id
    WHERE we.content_hash != md5(
        CONCAT(
            COALESCE(w.product_name, ''),
            COALESCE(w.manufacturer, ''),
            COALESCE(w.model_number, ''),
            COALESCE(w.notes, '')
        )
    )
    
    ORDER BY entity_type, entity_id
    LIMIT p_batch_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION find_similar_receipts(UUID, VECTOR, FLOAT, INTEGER, UUID[], INTEGER) IS 
    'Find receipts similar to a query embedding using vector cosine similarity';

COMMENT ON FUNCTION find_similar_warranties(UUID, VECTOR, FLOAT, INTEGER, warranty_status[]) IS 
    'Find warranties similar to a query embedding for recommendations';

COMMENT ON FUNCTION hybrid_receipt_search(UUID, TEXT, VECTOR, FLOAT, FLOAT, INTEGER) IS 
    'Combine vector similarity and text search with weighted scoring';

COMMENT ON FUNCTION build_spending_context(UUID, VECTOR, INTEGER, INTEGER) IS 
    'Build context for RAG queries about user spending patterns';

COMMENT ON FUNCTION build_warranty_context(UUID, VECTOR, INTEGER) IS 
    'Build context for RAG queries about user warranties';

COMMENT ON FUNCTION analyze_spending_clusters(UUID, FLOAT, INTEGER) IS 
    'Analyze embedding clusters to identify spending patterns and habits';

COMMENT ON FUNCTION get_receipts_needing_embeddings(UUID, INTEGER, TEXT) IS 
    'Find receipts that need vector embeddings generated';

COMMENT ON FUNCTION get_warranties_needing_embeddings(UUID, INTEGER) IS 
    'Find warranties that need vector embeddings generated';

COMMENT ON FUNCTION update_stale_embeddings(TEXT, INTEGER) IS 
    'Find embeddings that need updates due to content changes';

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
/*
-- Test vector similarity search
SELECT * FROM find_similar_receipts(
    'user_id_here'::UUID, 
    array_fill(0.1, ARRAY[1536])::VECTOR(1536), 
    0.8, 
    5
);

-- Test hybrid search
SELECT * FROM hybrid_receipt_search(
    'user_id_here'::UUID,
    'coffee shop',
    array_fill(0.1, ARRAY[1536])::VECTOR(1536)
);

-- Check for receipts needing embeddings
SELECT COUNT(*) FROM get_receipts_needing_embeddings();
*/