-- ============================================================================
-- vector_search_functions.sql
-- Vector similarity search functions for RAG and intelligent search
-- ============================================================================

-- Function to search receipts using vector similarity
CREATE OR REPLACE FUNCTION search_receipts(
    query_embedding VECTOR(1536),
    user_id_param UUID,
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    similarity FLOAT,
    content_text TEXT,
    category_name TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        1 - (re.embedding <=> query_embedding) as similarity,
        re.content_text,
        c.name as category_name
    FROM receipt_embeddings re
    JOIN receipts r ON re.receipt_id = r.id
    LEFT JOIN categories c ON r.category_id = c.id
    WHERE r.user_id = user_id_param
    AND 1 - (re.embedding <=> query_embedding) > match_threshold
    ORDER BY re.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to search warranties using vector similarity
CREATE OR REPLACE FUNCTION search_warranties(
    query_embedding VECTOR(1536),
    user_id_param UUID,
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    product_name TEXT,
    manufacturer TEXT,
    warranty_end_date DATE,
    status warranty_status,
    similarity FLOAT,
    content_text TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.product_name,
        w.manufacturer,
        w.warranty_end_date,
        w.status,
        1 - (we.embedding <=> query_embedding) as similarity,
        we.content_text
    FROM warranty_embeddings we
    JOIN warranties w ON we.warranty_id = w.id
    WHERE w.user_id = user_id_param
    AND 1 - (we.embedding <=> query_embedding) > match_threshold
    ORDER BY we.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to find similar receipts (for duplicate detection)
CREATE OR REPLACE FUNCTION find_similar_receipts(
    receipt_id_param UUID,
    user_id_param UUID,
    similarity_threshold FLOAT DEFAULT 0.85,
    max_results INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    similarity FLOAT,
    is_potential_duplicate BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_embedding VECTOR(1536);
BEGIN
    -- Get the embedding for the target receipt
    SELECT embedding INTO target_embedding
    FROM receipt_embeddings
    WHERE receipt_id = receipt_id_param;
    
    IF target_embedding IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        r.id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        1 - (re.embedding <=> target_embedding) as similarity,
        (1 - (re.embedding <=> target_embedding)) > similarity_threshold as is_potential_duplicate
    FROM receipt_embeddings re
    JOIN receipts r ON re.receipt_id = r.id
    WHERE r.user_id = user_id_param
    AND r.id != receipt_id_param  -- Exclude the original receipt
    AND 1 - (re.embedding <=> target_embedding) > 0.5  -- Minimum threshold for consideration
    ORDER BY re.embedding <=> target_embedding
    LIMIT max_results;
END;
$$;

-- Function for hybrid text + vector search
CREATE OR REPLACE FUNCTION hybrid_search_receipts(
    search_text TEXT,
    query_embedding VECTOR(1536),
    user_id_param UUID,
    text_weight FLOAT DEFAULT 0.3,
    vector_weight FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    combined_score FLOAT,
    text_rank FLOAT,
    vector_similarity FLOAT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH text_search AS (
        SELECT 
            r.id,
            r.merchant_name,
            r.total_amount,
            r.purchase_date,
            ts_rank(
                setweight(to_tsvector('english', r.merchant_name), 'A') ||
                setweight(to_tsvector('english', COALESCE(r.notes, '')), 'B') ||
                setweight(to_tsvector('english', COALESCE(array_to_string(r.tags, ' '), '')), 'C'),
                plainto_tsquery('english', search_text)
            ) as text_rank
        FROM receipts r
        WHERE r.user_id = user_id_param
        AND (
            to_tsvector('english', r.merchant_name) @@ plainto_tsquery('english', search_text) OR
            to_tsvector('english', COALESCE(r.notes, '')) @@ plainto_tsquery('english', search_text) OR
            to_tsvector('english', COALESCE(array_to_string(r.tags, ' '), '')) @@ plainto_tsquery('english', search_text)
        )
    ),
    vector_search AS (
        SELECT 
            r.id,
            1 - (re.embedding <=> query_embedding) as vector_similarity
        FROM receipt_embeddings re
        JOIN receipts r ON re.receipt_id = r.id
        WHERE r.user_id = user_id_param
        AND 1 - (re.embedding <=> query_embedding) > 0.5
    )
    SELECT 
        COALESCE(ts.id, vs.id),
        ts.merchant_name,
        ts.total_amount,
        ts.purchase_date,
        (COALESCE(ts.text_rank, 0) * text_weight + COALESCE(vs.vector_similarity, 0) * vector_weight) as combined_score,
        COALESCE(ts.text_rank, 0) as text_rank,
        COALESCE(vs.vector_similarity, 0) as vector_similarity
    FROM text_search ts
    FULL OUTER JOIN vector_search vs ON ts.id = vs.id
    ORDER BY combined_score DESC
    LIMIT match_count;
END;
$$;

-- Function to recommend warranty actions based on similar products
CREATE OR REPLACE FUNCTION recommend_warranty_actions(
    warranty_id_param UUID,
    user_id_param UUID,
    max_recommendations INT DEFAULT 5
)
RETURNS TABLE (
    recommendation_type TEXT,
    description TEXT,
    priority priority_level,
    related_warranty_id UUID,
    related_product_name TEXT,
    confidence_score FLOAT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_embedding VECTOR(1536);
    target_warranty RECORD;
BEGIN
    -- Get target warranty details
    SELECT * INTO target_warranty
    FROM warranties w
    WHERE w.id = warranty_id_param AND w.user_id = user_id_param;
    
    IF target_warranty IS NULL THEN
        RETURN;
    END IF;
    
    -- Get the embedding for the target warranty
    SELECT embedding INTO target_embedding
    FROM warranty_embeddings
    WHERE warranty_id = warranty_id_param;
    
    IF target_embedding IS NULL THEN
        RETURN;
    END IF;
    
    -- Find similar warranties and generate recommendations
    RETURN QUERY
    WITH similar_warranties AS (
        SELECT 
            w.id,
            w.product_name,
            w.manufacturer,
            w.status,
            w.warranty_end_date,
            1 - (we.embedding <=> target_embedding) as similarity
        FROM warranty_embeddings we
        JOIN warranties w ON we.warranty_id = w.id
        WHERE w.user_id = user_id_param
        AND w.id != warranty_id_param
        AND 1 - (we.embedding <=> target_embedding) > 0.7
        ORDER BY similarity DESC
        LIMIT max_recommendations * 2
    )
    SELECT 
        CASE 
            WHEN sw.status = 'expired' AND target_warranty.status = 'active' THEN 'prepare_for_expiry'
            WHEN sw.status = 'expiring_soon' THEN 'check_renewal_options'
            WHEN sw.warranty_end_date > target_warranty.warranty_end_date THEN 'consider_extended_warranty'
            ELSE 'monitor_similar_product'
        END as recommendation_type,
        CASE 
            WHEN sw.status = 'expired' AND target_warranty.status = 'active' THEN 
                'Similar product warranty has expired. Consider preparing documentation for potential claims.'
            WHEN sw.status = 'expiring_soon' THEN 
                'Similar product warranty is expiring soon. Check if renewal options are available.'
            WHEN sw.warranty_end_date > target_warranty.warranty_end_date THEN 
                'Consider extended warranty options based on similar product coverage.'
            ELSE 
                'Monitor this similar product for warranty management insights.'
        END as description,
        CASE 
            WHEN sw.status = 'expiring_soon' THEN 'high'::priority_level
            WHEN sw.status = 'expired' THEN 'medium'::priority_level
            ELSE 'low'::priority_level
        END as priority,
        sw.id as related_warranty_id,
        sw.product_name as related_product_name,
        sw.similarity as confidence_score
    FROM similar_warranties sw
    ORDER BY 
        CASE 
            WHEN sw.status = 'expiring_soon' THEN 1
            WHEN sw.status = 'expired' THEN 2
            ELSE 3
        END,
        sw.similarity DESC
    LIMIT max_recommendations;
END;
$$;

-- Function to update embeddings in batch
CREATE OR REPLACE FUNCTION update_embeddings_batch(
    embedding_data JSONB
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    updated_count INT := 0;
    item JSONB;
BEGIN
    -- Process receipt embeddings
    FOR item IN SELECT * FROM jsonb_array_elements(embedding_data->'receipts')
    LOOP
        INSERT INTO receipt_embeddings (receipt_id, embedding, content_text, content_hash, embedding_model, metadata)
        VALUES (
            (item->>'receipt_id')::UUID,
            (item->>'embedding')::VECTOR(1536),
            item->>'content_text',
            item->>'content_hash',
            COALESCE(item->>'embedding_model', 'text-embedding-ada-002'),
            COALESCE(item->'metadata', '{}'::jsonb)
        )
        ON CONFLICT (receipt_id) DO UPDATE SET
            embedding = EXCLUDED.embedding,
            content_text = EXCLUDED.content_text,
            content_hash = EXCLUDED.content_hash,
            embedding_model = EXCLUDED.embedding_model,
            metadata = EXCLUDED.metadata,
            updated_at = NOW();
        
        updated_count := updated_count + 1;
    END LOOP;
    
    -- Process warranty embeddings
    FOR item IN SELECT * FROM jsonb_array_elements(embedding_data->'warranties')
    LOOP
        INSERT INTO warranty_embeddings (warranty_id, embedding, content_text, content_hash, embedding_model, metadata)
        VALUES (
            (item->>'warranty_id')::UUID,
            (item->>'embedding')::VECTOR(1536),
            item->>'content_text',
            item->>'content_hash',
            COALESCE(item->>'embedding_model', 'text-embedding-ada-002'),
            COALESCE(item->'metadata', '{}'::jsonb)
        )
        ON CONFLICT (warranty_id) DO UPDATE SET
            embedding = EXCLUDED.embedding,
            content_text = EXCLUDED.content_text,
            content_hash = EXCLUDED.content_hash,
            embedding_model = EXCLUDED.embedding_model,
            metadata = EXCLUDED.metadata,
            updated_at = NOW();
        
        updated_count := updated_count + 1;
    END LOOP;
    
    RETURN updated_count;
END;
$$;

-- Function to clean up orphaned embeddings
CREATE OR REPLACE FUNCTION cleanup_orphaned_embeddings()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INT := 0;
BEGIN
    -- Clean up receipt embeddings with no corresponding receipts
    WITH deleted_receipt_embeddings AS (
        DELETE FROM receipt_embeddings re
        WHERE NOT EXISTS (
            SELECT 1 FROM receipts r WHERE r.id = re.receipt_id
        )
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted_receipt_embeddings;
    
    -- Clean up warranty embeddings with no corresponding warranties
    WITH deleted_warranty_embeddings AS (
        DELETE FROM warranty_embeddings we
        WHERE NOT EXISTS (
            SELECT 1 FROM warranties w WHERE w.id = we.warranty_id
        )
        RETURNING 1
    )
    SELECT deleted_count + COUNT(*) INTO deleted_count FROM deleted_warranty_embeddings;
    
    RETURN deleted_count;
END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION search_receipts TO authenticated;
GRANT EXECUTE ON FUNCTION search_warranties TO authenticated;
GRANT EXECUTE ON FUNCTION find_similar_receipts TO authenticated;
GRANT EXECUTE ON FUNCTION hybrid_search_receipts TO authenticated;
GRANT EXECUTE ON FUNCTION recommend_warranty_actions TO authenticated;

-- Grant service role permissions for batch operations
GRANT EXECUTE ON FUNCTION update_embeddings_batch TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_orphaned_embeddings TO service_role;