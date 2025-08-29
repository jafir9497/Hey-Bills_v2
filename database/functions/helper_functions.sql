-- Helper Functions for Hey-Bills Database
-- Common queries and business logic functions

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to calculate days until warranty expiry
CREATE OR REPLACE FUNCTION get_warranty_days_until_expiry(warranty_end_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN (warranty_end_date - CURRENT_DATE);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get warranty status
CREATE OR REPLACE FUNCTION get_warranty_status(warranty_end_date DATE)
RETURNS warranty_status AS $$
BEGIN
    IF warranty_end_date < CURRENT_DATE THEN
        RETURN 'expired'::warranty_status;
    ELSIF warranty_end_date <= CURRENT_DATE + INTERVAL '30 days' THEN
        RETURN 'expiring_soon'::warranty_status;
    ELSE
        RETURN 'active'::warranty_status;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- USER STATISTICS FUNCTIONS
-- ============================================================================

-- Get user's total spending for a date range
CREATE OR REPLACE FUNCTION get_user_spending_total(
    p_user_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    total_amount DECIMAL(10,2);
BEGIN
    SELECT COALESCE(SUM(total_amount), 0)
    INTO total_amount
    FROM receipts
    WHERE user_id = p_user_id
        AND (p_start_date IS NULL OR purchase_date >= p_start_date)
        AND (p_end_date IS NULL OR purchase_date <= p_end_date);
    
    RETURN total_amount;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Get spending by category for a user
CREATE OR REPLACE FUNCTION get_user_spending_by_category(
    p_user_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    category_name TEXT,
    category_id UUID,
    total_spent DECIMAL(10,2),
    transaction_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(c.name, 'Uncategorized') as category_name,
        c.id as category_id,
        COALESCE(SUM(r.total_amount), 0)::DECIMAL(10,2) as total_spent,
        COUNT(r.id)::INTEGER as transaction_count
    FROM receipts r
    LEFT JOIN categories c ON r.category_id = c.id
    WHERE r.user_id = p_user_id
        AND (p_start_date IS NULL OR r.purchase_date >= p_start_date)
        AND (p_end_date IS NULL OR r.purchase_date <= p_end_date)
    GROUP BY c.id, c.name
    ORDER BY total_spent DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Get monthly spending trend for a user
CREATE OR REPLACE FUNCTION get_user_monthly_spending_trend(
    p_user_id UUID,
    p_months_back INTEGER DEFAULT 12
)
RETURNS TABLE(
    month_year TEXT,
    total_spent DECIMAL(10,2),
    transaction_count INTEGER,
    avg_transaction DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TO_CHAR(r.purchase_date, 'YYYY-MM') as month_year,
        SUM(r.total_amount)::DECIMAL(10,2) as total_spent,
        COUNT(r.id)::INTEGER as transaction_count,
        AVG(r.total_amount)::DECIMAL(10,2) as avg_transaction
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND r.purchase_date >= CURRENT_DATE - INTERVAL '1 month' * p_months_back
    GROUP BY TO_CHAR(r.purchase_date, 'YYYY-MM')
    ORDER BY month_year DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- WARRANTY MANAGEMENT FUNCTIONS
-- ============================================================================

-- Get warranties expiring within specified days
CREATE OR REPLACE FUNCTION get_warranties_expiring_soon(
    p_user_id UUID,
    p_days_ahead INTEGER DEFAULT 30
)
RETURNS TABLE(
    warranty_id UUID,
    product_name TEXT,
    manufacturer TEXT,
    warranty_end_date DATE,
    days_until_expiry INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id as warranty_id,
        w.product_name,
        w.manufacturer,
        w.warranty_end_date,
        (w.warranty_end_date - CURRENT_DATE) as days_until_expiry
    FROM warranties w
    WHERE w.user_id = p_user_id
        AND w.warranty_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '1 day' * p_days_ahead
        AND w.is_active = true
    ORDER BY w.warranty_end_date ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Get warranty statistics for a user
CREATE OR REPLACE FUNCTION get_user_warranty_stats(p_user_id UUID)
RETURNS TABLE(
    total_warranties INTEGER,
    active_warranties INTEGER,
    expiring_soon INTEGER,
    expired_warranties INTEGER,
    total_warranty_value DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_warranties,
        COUNT(*) FILTER (WHERE status = 'active')::INTEGER as active_warranties,
        COUNT(*) FILTER (WHERE status = 'expiring_soon')::INTEGER as expiring_soon,
        COUNT(*) FILTER (WHERE status = 'expired')::INTEGER as expired_warranties,
        COALESCE(SUM(purchase_price), 0)::DECIMAL(10,2) as total_warranty_value
    FROM warranties
    WHERE user_id = p_user_id AND is_active = true;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- NOTIFICATION FUNCTIONS
-- ============================================================================

-- Create warranty expiration notification
CREATE OR REPLACE FUNCTION create_warranty_expiration_notification(
    p_warranty_id UUID,
    p_days_until_expiry INTEGER
)
RETURNS UUID AS $$
DECLARE
    warranty_record warranties;
    notification_id UUID;
    notification_title TEXT;
    notification_message TEXT;
BEGIN
    -- Get warranty details
    SELECT * INTO warranty_record
    FROM warranties
    WHERE id = p_warranty_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Warranty not found: %', p_warranty_id;
    END IF;
    
    -- Prepare notification content
    IF p_days_until_expiry <= 0 THEN
        notification_title := 'Warranty Expired';
        notification_message := format('The warranty for your %s has expired.', warranty_record.product_name);
    ELSIF p_days_until_expiry = 1 THEN
        notification_title := 'Warranty Expires Tomorrow';
        notification_message := format('The warranty for your %s expires tomorrow.', warranty_record.product_name);
    ELSE
        notification_title := 'Warranty Expiring Soon';
        notification_message := format('The warranty for your %s expires in %s days.', 
            warranty_record.product_name, p_days_until_expiry);
    END IF;
    
    -- Create notification
    INSERT INTO notifications (
        user_id,
        type,
        title,
        message,
        priority,
        related_entity_type,
        related_entity_id,
        delivery_method,
        metadata
    ) VALUES (
        warranty_record.user_id,
        CASE WHEN p_days_until_expiry <= 0 THEN 'warranty_expired' ELSE 'warranty_expiring' END,
        notification_title,
        notification_message,
        CASE WHEN p_days_until_expiry <= 1 THEN 'high' ELSE 'medium' END,
        'warranty',
        p_warranty_id,
        ARRAY['in_app', 'push'],
        jsonb_build_object(
            'warranty_id', p_warranty_id,
            'days_until_expiry', p_days_until_expiry,
            'product_name', warranty_record.product_name
        )
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SEARCH FUNCTIONS
-- ============================================================================

-- Search receipts using text similarity
CREATE OR REPLACE FUNCTION search_receipts(
    p_user_id UUID,
    p_search_term TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    similarity_score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        GREATEST(
            similarity(r.merchant_name, p_search_term),
            similarity(COALESCE(r.notes, ''), p_search_term)
        ) as similarity_score
    FROM receipts r
    WHERE r.user_id = p_user_id
        AND (
            r.merchant_name ILIKE '%' || p_search_term || '%'
            OR r.notes ILIKE '%' || p_search_term || '%'
            OR p_search_term = ANY(r.tags)
        )
    ORDER BY similarity_score DESC, r.purchase_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- VECTOR SIMILARITY FUNCTIONS (RAG)
-- ============================================================================

-- Find similar receipts using vector embeddings
CREATE OR REPLACE FUNCTION find_similar_receipts(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_limit INTEGER DEFAULT 10,
    p_similarity_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE(
    receipt_id UUID,
    merchant_name TEXT,
    total_amount DECIMAL(10,2),
    purchase_date DATE,
    similarity_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as receipt_id,
        r.merchant_name,
        r.total_amount,
        r.purchase_date,
        (1 - (re.embedding <=> p_query_embedding)) as similarity_score
    FROM receipts r
    INNER JOIN receipt_embeddings re ON r.id = re.receipt_id
    WHERE r.user_id = p_user_id
        AND (1 - (re.embedding <=> p_query_embedding)) >= p_similarity_threshold
    ORDER BY re.embedding <=> p_query_embedding ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Find similar warranties for recommendations
CREATE OR REPLACE FUNCTION find_similar_warranties(
    p_user_id UUID,
    p_query_embedding VECTOR(1536),
    p_limit INTEGER DEFAULT 5,
    p_similarity_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE(
    warranty_id UUID,
    product_name TEXT,
    manufacturer TEXT,
    warranty_end_date DATE,
    similarity_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id as warranty_id,
        w.product_name,
        w.manufacturer,
        w.warranty_end_date,
        (1 - (we.embedding <=> p_query_embedding)) as similarity_score
    FROM warranties w
    INNER JOIN warranty_embeddings we ON w.id = we.warranty_id
    WHERE w.user_id = p_user_id
        AND w.is_active = true
        AND (1 - (we.embedding <=> p_query_embedding)) >= p_similarity_threshold
    ORDER BY we.embedding <=> p_query_embedding ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- BUDGET FUNCTIONS
-- ============================================================================

-- Check if user is over budget for a category
CREATE OR REPLACE FUNCTION check_budget_status(
    p_user_id UUID,
    p_category_id UUID,
    p_check_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    budget_id UUID,
    budget_amount DECIMAL(10,2),
    spent_amount DECIMAL(10,2),
    remaining_amount DECIMAL(10,2),
    percentage_used DECIMAL(5,2),
    is_over_budget BOOLEAN
) AS $$
DECLARE
    budget_start_date DATE;
    budget_end_date DATE;
BEGIN
    RETURN QUERY
    WITH budget_period AS (
        SELECT 
            b.id,
            b.budget_amount,
            CASE 
                WHEN b.period_type = 'monthly' THEN DATE_TRUNC('month', p_check_date)::DATE
                WHEN b.period_type = 'weekly' THEN DATE_TRUNC('week', p_check_date)::DATE
                WHEN b.period_type = 'yearly' THEN DATE_TRUNC('year', p_check_date)::DATE
                ELSE b.start_date
            END as period_start,
            CASE 
                WHEN b.period_type = 'monthly' THEN (DATE_TRUNC('month', p_check_date) + INTERVAL '1 month - 1 day')::DATE
                WHEN b.period_type = 'weekly' THEN (DATE_TRUNC('week', p_check_date) + INTERVAL '1 week - 1 day')::DATE
                WHEN b.period_type = 'yearly' THEN (DATE_TRUNC('year', p_check_date) + INTERVAL '1 year - 1 day')::DATE
                ELSE COALESCE(b.end_date, CURRENT_DATE + INTERVAL '1 month')
            END as period_end
        FROM budgets b
        WHERE b.user_id = p_user_id 
            AND b.category_id = p_category_id
            AND b.is_active = true
    ),
    spending_in_period AS (
        SELECT 
            bp.id,
            bp.budget_amount,
            COALESCE(SUM(r.total_amount), 0) as spent_amount
        FROM budget_period bp
        LEFT JOIN receipts r ON r.user_id = p_user_id 
            AND r.category_id = p_category_id
            AND r.purchase_date BETWEEN bp.period_start AND bp.period_end
        GROUP BY bp.id, bp.budget_amount
    )
    SELECT 
        sp.id as budget_id,
        sp.budget_amount,
        sp.spent_amount,
        (sp.budget_amount - sp.spent_amount) as remaining_amount,
        CASE 
            WHEN sp.budget_amount > 0 THEN (sp.spent_amount / sp.budget_amount * 100)::DECIMAL(5,2)
            ELSE 0::DECIMAL(5,2)
        END as percentage_used,
        (sp.spent_amount > sp.budget_amount) as is_over_budget
    FROM spending_in_period sp;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- MAINTENANCE FUNCTIONS
-- ============================================================================

-- Clean up old notifications
CREATE OR REPLACE FUNCTION cleanup_old_notifications(
    p_days_old INTEGER DEFAULT 90
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications
    WHERE created_at < CURRENT_DATE - INTERVAL '1 day' * p_days_old
        AND is_read = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update embedding content hash
CREATE OR REPLACE FUNCTION update_embedding_content_hash(
    p_table_name TEXT,
    p_content TEXT
)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(p_content, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION get_user_spending_total(UUID, DATE, DATE) IS 
    'Calculate total spending for a user within optional date range';

COMMENT ON FUNCTION get_user_spending_by_category(UUID, DATE, DATE) IS 
    'Get spending breakdown by category for a user';

COMMENT ON FUNCTION get_warranties_expiring_soon(UUID, INTEGER) IS 
    'Find warranties expiring within specified number of days';

COMMENT ON FUNCTION find_similar_receipts(UUID, VECTOR, INTEGER, FLOAT) IS 
    'Find similar receipts using vector embeddings for RAG functionality';

COMMENT ON FUNCTION check_budget_status(UUID, UUID, DATE) IS 
    'Check if user is over budget for a specific category';