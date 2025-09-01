-- ============================================================================
-- Hey-Bills Comprehensive Database Schema Design
-- ============================================================================
-- Version: 3.0.0
-- Date: August 31, 2025
-- Description: Complete database schema for Hey-Bills receipt organizer
-- Features: Users, Receipts, Categories, Warranties, Reminders, AI Chat, 
--          Vector Embeddings, RLS, Performance Optimization, RAG Search
-- ============================================================================

BEGIN;

-- ============================================================================
-- EXTENSIONS - Enable required PostgreSQL extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "vector" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "unaccent" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "btree_gin" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" SCHEMA public;

-- ============================================================================
-- CUSTOM TYPES AND ENUMS
-- ============================================================================

-- User and system types
CREATE TYPE user_business_type AS ENUM (
    'individual', 'freelancer', 'small_business', 'corporation', 'non_profit'
);

CREATE TYPE subscription_tier AS ENUM (
    'free', 'basic', 'premium', 'enterprise'
);

-- Receipt and financial types
CREATE TYPE receipt_status AS ENUM (
    'pending', 'processing', 'processed', 'failed', 'archived'
);

CREATE TYPE payment_method AS ENUM (
    'cash', 'credit_card', 'debit_card', 'mobile_payment', 
    'check', 'bank_transfer', 'other'
);

-- Warranty and reminder types
CREATE TYPE warranty_status AS ENUM (
    'active', 'expiring_soon', 'expired', 'claimed', 'void'
);

CREATE TYPE reminder_type AS ENUM (
    'warranty_expiring', 'warranty_expired', 'receipt_review', 
    'tax_deadline', 'budget_alert', 'custom'
);

CREATE TYPE reminder_frequency AS ENUM (
    'once', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly'
);

-- Notification and communication types
CREATE TYPE notification_type AS ENUM (
    'warranty_expiring', 'warranty_expired', 'system_alert', 
    'budget_alert', 'receipt_processed', 'ai_insight', 'security_alert'
);

CREATE TYPE delivery_method AS ENUM (
    'push', 'email', 'sms', 'in_app'
);

CREATE TYPE priority_level AS ENUM (
    'low', 'medium', 'high', 'critical'
);

-- AI and conversation types
CREATE TYPE conversation_status AS ENUM (
    'active', 'paused', 'archived', 'deleted'
);

CREATE TYPE message_type AS ENUM (
    'user_message', 'assistant_message', 'system_message', 
    'function_call', 'function_response', 'error_message'
);

CREATE TYPE embedding_model_type AS ENUM (
    'text-embedding-ada-002', 'text-embedding-3-small', 
    'text-embedding-3-large', 'custom'
);

-- ============================================================================
-- CORE USER MANAGEMENT
-- ============================================================================

-- Extended user profiles (extends Supabase auth.users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Basic user information
    full_name TEXT NOT NULL CHECK (length(full_name) >= 2),
    display_name TEXT CHECK (length(display_name) >= 1),
    avatar_url TEXT,
    phone_number TEXT,
    
    -- Business and preferences
    business_type user_business_type DEFAULT 'individual',
    business_name TEXT,
    tax_id TEXT,
    
    -- Localization preferences
    timezone TEXT DEFAULT 'UTC' CHECK (timezone ~ '^[A-Z][a-z_/]+$'),
    currency TEXT DEFAULT 'USD' CHECK (length(currency) = 3),
    date_format TEXT DEFAULT 'MM/DD/YYYY',
    time_format TEXT DEFAULT '12h',
    language TEXT DEFAULT 'en',
    
    -- Subscription and features
    subscription_tier subscription_tier DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    features_enabled JSONB DEFAULT '{
        "ocr": true,
        "ai_chat": false,
        "advanced_analytics": false,
        "unlimited_receipts": false,
        "api_access": false
    }'::jsonb,
    
    -- Notification preferences
    notification_preferences JSONB DEFAULT '{
        "email": true,
        "push": true,
        "sms": false,
        "warranty_alerts": true,
        "budget_alerts": true,
        "receipt_reminders": true,
        "ai_insights": false
    }'::jsonb,
    
    -- Usage statistics and limits
    monthly_receipt_count INTEGER DEFAULT 0 CHECK (monthly_receipt_count >= 0),
    monthly_ai_queries INTEGER DEFAULT 0 CHECK (monthly_ai_queries >= 0),
    storage_used_bytes BIGINT DEFAULT 0 CHECK (storage_used_bytes >= 0),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    onboarding_completed_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT user_profiles_business_name_required 
        CHECK (business_type != 'corporation' OR business_name IS NOT NULL)
);

-- User sessions and activity tracking
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Session information
    session_token TEXT UNIQUE,
    device_info JSONB DEFAULT '{}'::jsonb,
    ip_address INET,
    user_agent TEXT,
    location_country TEXT,
    location_city TEXT,
    
    -- Session status
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CATEGORY MANAGEMENT
-- ============================================================================

-- Hierarchical categories with enhanced features
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Category hierarchy
    parent_category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    category_path TEXT[], -- Materialized path for efficient queries
    depth INTEGER DEFAULT 0 CHECK (depth >= 0 AND depth <= 5),
    
    -- Category details
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
    description TEXT CHECK (length(description) <= 500),
    
    -- Visual customization
    icon TEXT CHECK (length(icon) <= 50),
    color TEXT DEFAULT '#6B7280' CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
    emoji TEXT CHECK (length(emoji) <= 10),
    
    -- Category behavior
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_system_category BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    
    -- Budget and limits
    monthly_budget DECIMAL(12,2) CHECK (monthly_budget >= 0),
    budget_alert_threshold DECIMAL(3,2) DEFAULT 0.80 
        CHECK (budget_alert_threshold BETWEEN 0.1 AND 1.0),
    
    -- AI and automation
    auto_categorization_rules JSONB DEFAULT '[]'::jsonb,
    keyword_patterns TEXT[],
    merchant_patterns TEXT[],
    
    -- Statistics
    receipt_count INTEGER DEFAULT 0 CHECK (receipt_count >= 0),
    total_amount DECIMAL(12,2) DEFAULT 0 CHECK (total_amount >= 0),
    avg_amount DECIMAL(12,2) DEFAULT 0 CHECK (avg_amount >= 0),
    last_used_at TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT categories_name_user_unique UNIQUE (name, user_id, parent_category_id),
    CONSTRAINT categories_no_self_reference CHECK (id != parent_category_id)
);

-- ============================================================================
-- RECEIPT MANAGEMENT
-- ============================================================================

-- Comprehensive receipts table with OCR and AI integration
CREATE TABLE receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    
    -- File and storage information
    image_url TEXT NOT NULL,
    image_thumbnail_url TEXT,
    image_hash TEXT UNIQUE, -- SHA-256 hash for duplicate detection
    image_size_bytes BIGINT CHECK (image_size_bytes > 0),
    image_width INTEGER CHECK (image_width > 0),
    image_height INTEGER CHECK (image_height > 0),
    image_format TEXT CHECK (image_format IN ('jpeg', 'jpg', 'png', 'pdf', 'webp')),
    
    -- Merchant information
    merchant_name TEXT NOT NULL CHECK (length(merchant_name) >= 1),
    merchant_address TEXT,
    merchant_phone TEXT,
    merchant_website TEXT,
    merchant_tax_id TEXT,
    
    -- Financial data with enhanced precision
    total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
    subtotal_amount DECIMAL(12,2) CHECK (subtotal_amount >= 0),
    tax_amount DECIMAL(12,2) DEFAULT 0 CHECK (tax_amount >= 0),
    tip_amount DECIMAL(12,2) DEFAULT 0 CHECK (tip_amount >= 0),
    discount_amount DECIMAL(12,2) DEFAULT 0 CHECK (discount_amount >= 0),
    
    -- Currency and payment information
    currency TEXT DEFAULT 'USD' CHECK (length(currency) = 3),
    exchange_rate DECIMAL(10,6) DEFAULT 1.0 CHECK (exchange_rate > 0),
    payment_method payment_method,
    card_last_four TEXT CHECK (card_last_four ~ '^\d{4}$' OR card_last_four IS NULL),
    
    -- Date and time information
    purchase_date DATE NOT NULL,
    purchase_time TIME,
    purchase_timezone TEXT DEFAULT 'UTC',
    created_date DATE GENERATED ALWAYS AS (purchase_date) STORED,
    
    -- OCR processing data
    ocr_status receipt_status DEFAULT 'pending',
    ocr_data JSONB DEFAULT '{}'::jsonb,
    ocr_confidence DECIMAL(4,3) CHECK (ocr_confidence BETWEEN 0 AND 1),
    ocr_processing_time_ms INTEGER,
    ocr_model_version TEXT,
    ocr_error_message TEXT,
    
    -- Structured extraction results
    processed_data JSONB DEFAULT '{}'::jsonb,
    line_items JSONB DEFAULT '[]'::jsonb,
    extracted_fields JSONB DEFAULT '{}'::jsonb,
    
    -- Location and context
    location_lat DECIMAL(10,8) CHECK (location_lat BETWEEN -90 AND 90),
    location_lng DECIMAL(11,8) CHECK (location_lng BETWEEN -180 AND 180),
    location_address TEXT,
    location_accuracy_meters INTEGER CHECK (location_accuracy_meters >= 0),
    
    -- Business and tax information
    is_business_expense BOOLEAN DEFAULT FALSE,
    is_tax_deductible BOOLEAN DEFAULT FALSE,
    expense_account TEXT,
    project_code TEXT,
    client_name TEXT,
    
    -- Status and workflow
    status receipt_status DEFAULT 'pending',
    is_reviewed BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    is_favorite BOOLEAN DEFAULT FALSE,
    
    -- User annotations and notes
    notes TEXT CHECK (length(notes) <= 2000),
    tags TEXT[] DEFAULT '{}',
    custom_fields JSONB DEFAULT '{}'::jsonb,
    
    -- Receipt validation and verification
    is_verified BOOLEAN DEFAULT FALSE,
    verification_method TEXT,
    verification_score DECIMAL(4,3),
    
    -- Audit and timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    
    -- Performance and search optimization
    search_vector TSVECTOR,
    
    -- Constraints and validations
    CONSTRAINT receipts_purchase_date_valid 
        CHECK (purchase_date <= CURRENT_DATE AND purchase_date >= DATE '2000-01-01'),
    CONSTRAINT receipts_amounts_logical 
        CHECK (total_amount >= COALESCE(subtotal_amount, 0) + COALESCE(tax_amount, 0) - COALESCE(discount_amount, 0)),
    CONSTRAINT receipts_location_complete 
        CHECK ((location_lat IS NULL AND location_lng IS NULL) OR 
               (location_lat IS NOT NULL AND location_lng IS NOT NULL))
);

-- Receipt line items for detailed expense tracking
CREATE TABLE receipt_line_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Item details
    line_number INTEGER NOT NULL CHECK (line_number > 0),
    item_name TEXT NOT NULL CHECK (length(item_name) >= 1),
    item_description TEXT,
    item_sku TEXT,
    item_barcode TEXT,
    
    -- Quantity and pricing
    quantity DECIMAL(10,3) DEFAULT 1 CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    total_price DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    
    -- Classification
    category_hint TEXT,
    is_taxable BOOLEAN DEFAULT TRUE,
    tax_rate DECIMAL(5,4) CHECK (tax_rate >= 0 AND tax_rate <= 1),
    
    -- OCR extraction metadata
    ocr_confidence DECIMAL(4,3),
    ocr_bounding_box JSONB,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT receipt_line_items_unique UNIQUE (receipt_id, line_number),
    CONSTRAINT receipt_line_items_price_calc 
        CHECK (total_price = (quantity * unit_price) - COALESCE(discount_amount, 0))
);

-- ============================================================================
-- WARRANTY AND PRODUCT MANAGEMENT
-- ============================================================================

-- Comprehensive warranties with product information
CREATE TABLE warranties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receipt_id UUID REFERENCES receipts(id) ON DELETE SET NULL,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    
    -- Product information
    product_name TEXT NOT NULL CHECK (length(product_name) >= 1),
    product_brand TEXT,
    product_model TEXT,
    product_serial_number TEXT,
    product_sku TEXT,
    product_barcode TEXT,
    
    -- Purchase information
    purchase_price DECIMAL(10,2) CHECK (purchase_price >= 0),
    purchase_date DATE NOT NULL,
    merchant_name TEXT,
    
    -- Warranty details
    warranty_type TEXT DEFAULT 'manufacturer',
    warranty_duration_months INTEGER NOT NULL CHECK (warranty_duration_months > 0),
    warranty_start_date DATE NOT NULL,
    warranty_end_date DATE NOT NULL,
    warranty_terms TEXT,
    
    -- Extended warranty information
    extended_warranty BOOLEAN DEFAULT FALSE,
    extended_warranty_provider TEXT,
    extended_warranty_cost DECIMAL(10,2),
    extended_warranty_end_date DATE,
    
    -- Status and tracking
    status warranty_status DEFAULT 'active',
    is_transferable BOOLEAN DEFAULT FALSE,
    claim_history JSONB DEFAULT '[]'::jsonb,
    
    -- Contact and support information
    support_phone TEXT,
    support_email TEXT CHECK (support_email ~ '^[^@]+@[^@]+\.[^@]+$' OR support_email IS NULL),
    support_website TEXT,
    warranty_certificate_url TEXT,
    
    -- Product condition and value
    current_condition TEXT,
    estimated_current_value DECIMAL(10,2),
    depreciation_rate DECIMAL(5,4) DEFAULT 0.10,
    
    -- User annotations
    notes TEXT CHECK (length(notes) <= 2000),
    tags TEXT[] DEFAULT '{}',
    
    -- Reminder and notification settings
    reminder_before_expiry_days INTEGER DEFAULT 30 CHECK (reminder_before_expiry_days >= 0),
    notification_enabled BOOLEAN DEFAULT TRUE,
    last_reminder_sent_at TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Computed fields
    days_until_expiry INTEGER GENERATED ALWAYS AS (
        warranty_end_date - CURRENT_DATE
    ) STORED,
    
    is_expiring_soon BOOLEAN GENERATED ALWAYS AS (
        warranty_end_date - CURRENT_DATE <= reminder_before_expiry_days AND
        warranty_end_date >= CURRENT_DATE
    ) STORED,
    
    -- Constraints
    CONSTRAINT warranties_dates_valid 
        CHECK (warranty_start_date <= warranty_end_date),
    CONSTRAINT warranties_purchase_warranty_dates 
        CHECK (purchase_date <= warranty_start_date),
    CONSTRAINT warranties_extended_dates 
        CHECK (extended_warranty = FALSE OR extended_warranty_end_date > warranty_end_date)
);

-- Warranty claims tracking
CREATE TABLE warranty_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warranty_id UUID NOT NULL REFERENCES warranties(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Claim details
    claim_number TEXT UNIQUE,
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    claim_reason TEXT NOT NULL,
    claim_description TEXT NOT NULL CHECK (length(claim_description) >= 10),
    
    -- Claim status and resolution
    status TEXT DEFAULT 'submitted' CHECK (status IN (
        'submitted', 'under_review', 'approved', 'denied', 'completed', 'cancelled'
    )),
    resolution_date DATE,
    resolution_notes TEXT,
    
    -- Financial information
    claim_amount DECIMAL(10,2) CHECK (claim_amount >= 0),
    approved_amount DECIMAL(10,2) CHECK (approved_amount >= 0),
    
    -- Documents and evidence
    supporting_documents JSONB DEFAULT '[]'::jsonb,
    photos JSONB DEFAULT '[]'::jsonb,
    
    -- Contact and communication
    contact_person TEXT,
    contact_phone TEXT,
    contact_email TEXT CHECK (contact_email ~ '^[^@]+@[^@]+\.[^@]+$' OR contact_email IS NULL),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT warranty_claims_dates_valid 
        CHECK (resolution_date IS NULL OR resolution_date >= claim_date)
);

-- ============================================================================
-- REMINDER AND NOTIFICATION SYSTEM
-- ============================================================================

-- Comprehensive reminder system
CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Related entities (polymorphic references)
    receipt_id UUID REFERENCES receipts(id) ON DELETE CASCADE,
    warranty_id UUID REFERENCES warranties(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    
    -- Reminder details
    title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 200),
    description TEXT CHECK (length(description) <= 1000),
    reminder_type reminder_type NOT NULL,
    
    -- Scheduling and frequency
    scheduled_at TIMESTAMPTZ NOT NULL,
    frequency reminder_frequency DEFAULT 'once',
    frequency_interval INTEGER DEFAULT 1 CHECK (frequency_interval > 0),
    max_occurrences INTEGER CHECK (max_occurrences > 0),
    occurrence_count INTEGER DEFAULT 0 CHECK (occurrence_count >= 0),
    
    -- End conditions
    ends_at TIMESTAMPTZ,
    ends_after_occurrences INTEGER CHECK (ends_after_occurrences > 0),
    
    -- Status and execution
    is_active BOOLEAN DEFAULT TRUE,
    is_completed BOOLEAN DEFAULT FALSE,
    priority priority_level DEFAULT 'medium',
    
    -- Delivery preferences
    delivery_methods delivery_method[] DEFAULT ARRAY['in_app'],
    custom_message TEXT CHECK (length(custom_message) <= 500),
    
    -- Execution tracking
    last_triggered_at TIMESTAMPTZ,
    next_trigger_at TIMESTAMPTZ,
    trigger_history JSONB DEFAULT '[]'::jsonb,
    
    -- Advanced settings
    timezone TEXT DEFAULT 'UTC',
    business_days_only BOOLEAN DEFAULT FALSE,
    custom_schedule_rules JSONB DEFAULT '{}'::jsonb,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT reminders_dates_valid 
        CHECK (ends_at IS NULL OR ends_at > scheduled_at),
    CONSTRAINT reminders_entity_reference 
        CHECK (
            (receipt_id IS NOT NULL AND warranty_id IS NULL) OR
            (receipt_id IS NULL AND warranty_id IS NOT NULL) OR
            (receipt_id IS NULL AND warranty_id IS NULL)
        )
);

-- Notification delivery tracking
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reminder_id UUID REFERENCES reminders(id) ON DELETE SET NULL,
    
    -- Notification content
    title TEXT NOT NULL CHECK (length(title) <= 200),
    message TEXT NOT NULL CHECK (length(message) <= 2000),
    notification_type notification_type NOT NULL,
    
    -- Delivery information
    delivery_method delivery_method NOT NULL,
    recipient_address TEXT, -- email address, phone number, or device token
    
    -- Status tracking
    status TEXT DEFAULT 'pending' CHECK (status IN (
        'pending', 'sent', 'delivered', 'read', 'failed', 'cancelled'
    )),
    priority priority_level DEFAULT 'medium',
    
    -- Scheduling
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    
    -- Delivery tracking
    delivery_attempts INTEGER DEFAULT 0 CHECK (delivery_attempts >= 0),
    max_attempts INTEGER DEFAULT 3 CHECK (max_attempts > 0),
    last_attempt_at TIMESTAMPTZ,
    
    -- Error handling
    error_message TEXT,
    retry_after TIMESTAMPTZ,
    
    -- Metadata and tracking
    metadata JSONB DEFAULT '{}'::jsonb,
    tracking_data JSONB DEFAULT '{}'::jsonb,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT notifications_delivery_times 
        CHECK (
            sent_at IS NULL OR sent_at >= scheduled_at AND
            (delivered_at IS NULL OR delivered_at >= sent_at) AND
            (read_at IS NULL OR read_at >= delivered_at)
        )
);

-- ============================================================================
-- AI CONVERSATION AND CHAT SYSTEM
-- ============================================================================

-- AI conversation sessions
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Conversation metadata
    title TEXT CHECK (length(title) <= 200),
    description TEXT CHECK (length(description) <= 500),
    conversation_type TEXT DEFAULT 'general_chat',
    
    -- Context and scope
    context_receipts UUID[] DEFAULT '{}', -- Array of receipt IDs for context
    context_warranties UUID[] DEFAULT '{}', -- Array of warranty IDs for context
    context_categories UUID[] DEFAULT '{}', -- Array of category IDs for context
    context_metadata JSONB DEFAULT '{}'::jsonb,
    
    -- AI model and configuration
    ai_model TEXT DEFAULT 'gpt-4',
    model_config JSONB DEFAULT '{
        "temperature": 0.7,
        "max_tokens": 2000,
        "system_prompt": "You are a helpful assistant for managing receipts and expenses."
    }'::jsonb,
    
    -- Status and state
    status conversation_status DEFAULT 'active',
    is_pinned BOOLEAN DEFAULT FALSE,
    message_count INTEGER DEFAULT 0 CHECK (message_count >= 0),
    
    -- Usage and statistics
    total_tokens_used INTEGER DEFAULT 0 CHECK (total_tokens_used >= 0),
    total_cost DECIMAL(10,4) DEFAULT 0 CHECK (total_cost >= 0),
    
    -- Timestamps
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual messages within conversations
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Message identification
    sequence_number INTEGER NOT NULL CHECK (sequence_number > 0),
    message_type message_type NOT NULL,
    
    -- Message content
    content TEXT NOT NULL CHECK (length(content) >= 1),
    formatted_content JSONB, -- For rich formatting, attachments, etc.
    
    -- AI processing information
    ai_model TEXT,
    prompt_tokens INTEGER CHECK (prompt_tokens >= 0),
    completion_tokens INTEGER CHECK (completion_tokens >= 0),
    total_tokens INTEGER CHECK (total_tokens >= 0),
    processing_time_ms INTEGER CHECK (processing_time_ms >= 0),
    
    -- Message metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    attachments JSONB DEFAULT '[]'::jsonb,
    
    -- Context and references
    referenced_receipts UUID[] DEFAULT '{}',
    referenced_warranties UUID[] DEFAULT '{}',
    referenced_categories UUID[] DEFAULT '{}',
    
    -- Status and interaction
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    edit_history JSONB DEFAULT '[]'::jsonb,
    
    -- Ratings and feedback
    user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
    user_feedback TEXT CHECK (length(user_feedback) <= 1000),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT messages_sequence_unique UNIQUE (conversation_id, sequence_number),
    CONSTRAINT messages_token_calculation 
        CHECK (total_tokens = COALESCE(prompt_tokens, 0) + COALESCE(completion_tokens, 0))
);

-- ============================================================================
-- VECTOR EMBEDDINGS AND RAG SYSTEM
-- ============================================================================

-- Receipt embeddings for semantic search
CREATE TABLE receipt_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Vector embedding (1536 dimensions for OpenAI text-embedding-ada-002)
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding source and metadata
    embedding_model embedding_model_type DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL,
    content_text TEXT NOT NULL CHECK (length(content_text) >= 1),
    content_type TEXT DEFAULT 'receipt_full',
    
    -- Embedding generation
    token_count INTEGER CHECK (token_count > 0),
    generation_cost DECIMAL(8,6),
    generation_time_ms INTEGER CHECK (generation_time_ms >= 0),
    
    -- Quality and validation
    embedding_quality_score DECIMAL(4,3) CHECK (embedding_quality_score BETWEEN 0 AND 1),
    is_validated BOOLEAN DEFAULT FALSE,
    
    -- Search optimization
    metadata JSONB DEFAULT '{}'::jsonb,
    search_keywords TEXT[],
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT receipt_embeddings_unique UNIQUE (receipt_id, content_type),
    CONSTRAINT receipt_embeddings_content_hash_unique UNIQUE (content_hash)
);

-- Warranty embeddings for intelligent matching
CREATE TABLE warranty_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warranty_id UUID NOT NULL REFERENCES warranties(id) ON DELETE CASCADE,
    
    -- Vector embedding
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model embedding_model_type DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL UNIQUE,
    content_text TEXT NOT NULL CHECK (length(content_text) >= 1),
    content_type TEXT DEFAULT 'warranty_full',
    
    -- Generation metadata
    token_count INTEGER CHECK (token_count > 0),
    generation_cost DECIMAL(8,6),
    generation_time_ms INTEGER CHECK (generation_time_ms >= 0),
    
    -- Quality metrics
    embedding_quality_score DECIMAL(4,3),
    is_validated BOOLEAN DEFAULT FALSE,
    
    -- Search metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    search_keywords TEXT[],
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT warranty_embeddings_unique UNIQUE (warranty_id, content_type)
);

-- Conversation embeddings for context retrieval
CREATE TABLE conversation_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    
    -- Vector embedding
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model embedding_model_type DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL UNIQUE,
    content_text TEXT NOT NULL CHECK (length(content_text) >= 1),
    
    -- Context and relevance
    context_window INTEGER DEFAULT 1 CHECK (context_window > 0),
    relevance_score DECIMAL(4,3),
    
    -- Generation metadata
    token_count INTEGER CHECK (token_count > 0),
    generation_cost DECIMAL(8,6),
    
    -- Search optimization
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vector search cache for performance
CREATE TABLE vector_search_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Query information
    query_hash TEXT NOT NULL,
    query_text TEXT NOT NULL,
    query_embedding VECTOR(1536) NOT NULL,
    
    -- Search parameters
    search_type TEXT NOT NULL CHECK (search_type IN ('receipts', 'warranties', 'conversations')),
    search_params JSONB DEFAULT '{}'::jsonb,
    
    -- Cached results
    result_ids UUID[] NOT NULL,
    similarity_scores DECIMAL(4,3)[] NOT NULL,
    total_results INTEGER NOT NULL CHECK (total_results >= 0),
    
    -- Cache metadata
    cache_hit_count INTEGER DEFAULT 0 CHECK (cache_hit_count >= 0),
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 hour'),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT vector_search_cache_arrays_length 
        CHECK (array_length(result_ids, 1) = array_length(similarity_scores, 1))
);

-- ============================================================================
-- ANALYTICS AND REPORTING
-- ============================================================================

-- User activity and usage analytics
CREATE TABLE user_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Date and time bucketing
    date_bucket DATE NOT NULL,
    hour_bucket INTEGER CHECK (hour_bucket BETWEEN 0 AND 23),
    
    -- Usage metrics
    receipts_uploaded INTEGER DEFAULT 0 CHECK (receipts_uploaded >= 0),
    receipts_processed INTEGER DEFAULT 0 CHECK (receipts_processed >= 0),
    ai_queries_made INTEGER DEFAULT 0 CHECK (ai_queries_made >= 0),
    search_queries_made INTEGER DEFAULT 0 CHECK (search_queries_made >= 0),
    
    -- Engagement metrics
    session_duration_seconds INTEGER DEFAULT 0 CHECK (session_duration_seconds >= 0),
    screen_views INTEGER DEFAULT 0 CHECK (screen_views >= 0),
    feature_usage JSONB DEFAULT '{}'::jsonb,
    
    -- Financial metrics
    total_expense_amount DECIMAL(12,2) DEFAULT 0 CHECK (total_expense_amount >= 0),
    categories_used INTEGER DEFAULT 0 CHECK (categories_used >= 0),
    
    -- Quality metrics
    ocr_accuracy_avg DECIMAL(4,3),
    user_corrections_made INTEGER DEFAULT 0 CHECK (user_corrections_made >= 0),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT user_analytics_unique UNIQUE (user_id, date_bucket, hour_bucket)
);

-- System performance and health metrics
CREATE TABLE system_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Time bucketing
    timestamp_bucket TIMESTAMPTZ NOT NULL,
    bucket_size INTERVAL DEFAULT '5 minutes',
    
    -- System performance
    avg_response_time_ms DECIMAL(8,2) CHECK (avg_response_time_ms >= 0),
    max_response_time_ms INTEGER CHECK (max_response_time_ms >= 0),
    error_rate DECIMAL(5,4) CHECK (error_rate BETWEEN 0 AND 1),
    
    -- Resource usage
    cpu_usage_percent DECIMAL(5,2) CHECK (cpu_usage_percent BETWEEN 0 AND 100),
    memory_usage_percent DECIMAL(5,2) CHECK (memory_usage_percent BETWEEN 0 AND 100),
    storage_used_gb DECIMAL(10,2) CHECK (storage_used_gb >= 0),
    
    -- API and database metrics
    api_requests_per_second DECIMAL(8,2) CHECK (api_requests_per_second >= 0),
    database_connections INTEGER CHECK (database_connections >= 0),
    cache_hit_rate DECIMAL(5,4) CHECK (cache_hit_rate BETWEEN 0 AND 1),
    
    -- OCR and AI metrics
    ocr_processing_time_avg_ms INTEGER CHECK (ocr_processing_time_avg_ms >= 0),
    ai_response_time_avg_ms INTEGER CHECK (ai_response_time_avg_ms >= 0),
    vector_search_time_avg_ms INTEGER CHECK (vector_search_time_avg_ms >= 0),
    
    -- Quality and reliability
    uptime_percentage DECIMAL(5,4) CHECK (uptime_percentage BETWEEN 0 AND 1),
    data_quality_score DECIMAL(4,3) CHECK (data_quality_score BETWEEN 0 AND 1),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;