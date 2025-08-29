# Hey-Bills Database Architecture

## Overview

The Hey-Bills database is designed as a comprehensive PostgreSQL schema with pgvector integration for AI-powered features. The architecture supports receipt management, warranty tracking, intelligent categorization, and RAG (Retrieval-Augmented Generation) capabilities for enhanced user experience.

## Architecture Principles

### 1. **Supabase Integration**
- Extends Supabase's built-in `auth.users` table with custom `user_profiles`
- Leverages Supabase RLS (Row Level Security) for multi-tenant data isolation
- Uses UUID primary keys for better distribution and security
- Implements proper foreign key constraints and cascading deletes

### 2. **Scalable Design**
- Normalized schema with proper indexing for performance
- JSONB columns for flexible metadata storage (OCR data, preferences)
- Vector embeddings for AI-powered search and recommendations
- Efficient indexing strategy including composite and partial indexes

### 3. **Security-First Approach**
- Row Level Security (RLS) on all user-data tables
- Separate policies for different access patterns
- Service role bypass for system operations
- Encrypted sensitive data storage patterns

### 4. **AI/RAG Integration**
- pgvector extension for similarity search
- Separate embedding tables for receipts and warranties
- HNSW indexes for fast approximate nearest neighbor search
- Content hashing for deduplication

## Core Entities

### User Management
- **user_profiles**: Extended user information beyond Supabase auth
- **system_settings**: Application configuration and feature flags

### Receipt Management
- **categories**: Hierarchical categorization system with defaults and custom categories
- **receipts**: Main receipt storage with OCR data and metadata
- **receipt_items**: Detailed line items from receipts
- **receipt_embeddings**: Vector embeddings for intelligent search

### Warranty Tracking
- **warranties**: Product warranty information with automated status calculation
- **warranty_embeddings**: Vector embeddings for warranty recommendations
- **notifications**: System notifications and warranty alerts

### Financial Management
- **budgets**: User-defined spending limits with alert thresholds

## Key Features

### 1. **Intelligent Categorization**
```sql
-- Hierarchical categories with parent-child relationships
CREATE TABLE categories (
    id UUID PRIMARY KEY,
    parent_category_id UUID REFERENCES categories(id),
    -- ... other fields
);
```

### 2. **OCR Data Storage**
```sql
-- Flexible OCR data storage
ocr_data JSONB, -- Raw OCR results
processed_data JSONB, -- Structured extracted data
ocr_confidence DECIMAL(3,2) -- Confidence score
```

### 3. **Automated Warranty Status**
```sql
-- Computed warranty status based on dates
status warranty_status GENERATED ALWAYS AS (
    CASE 
        WHEN warranty_end_date < CURRENT_DATE THEN 'expired'
        WHEN warranty_end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_soon'
        ELSE 'active'
    END
) STORED
```

### 4. **Vector Similarity Search**
```sql
-- Find similar receipts using embeddings
SELECT r.*, (1 - (re.embedding <=> $query_vector)) as similarity
FROM receipts r
JOIN receipt_embeddings re ON r.id = re.receipt_id
ORDER BY re.embedding <=> $query_vector
LIMIT 10;
```

## Performance Optimizations

### Indexing Strategy
- **Primary indexes**: UUID PKs with btree indexes
- **Foreign key indexes**: For efficient joins
- **Search indexes**: GIN indexes for text search, trigram indexes for fuzzy matching
- **Vector indexes**: HNSW for fast similarity search
- **Composite indexes**: For common query patterns (user_id + date)
- **Partial indexes**: For filtered queries (active records only)

### Query Optimization
- Generated columns for computed values (warranty status)
- Proper use of JSONB for flexible data with GIN indexes
- Efficient date range queries with btree indexes
- Vector similarity with cosine distance

## Data Relationships

### Core Relationships
```
auth.users (Supabase)
├── user_profiles (1:1)
├── categories (1:N) - custom categories
├── receipts (1:N)
│   ├── receipt_items (1:N)
│   └── receipt_embeddings (1:1)
├── warranties (1:N)
│   └── warranty_embeddings (1:1)
├── notifications (1:N)
└── budgets (1:N)
```

### Association Relationships
- Receipts ←→ Categories (N:1)
- Warranties ←→ Receipts (N:1, optional)
- Budgets ←→ Categories (N:1)
- Notifications ←→ Any Entity (polymorphic)

## Security Model

### Row Level Security (RLS)
All user-data tables implement RLS with policies:

1. **User Isolation**: Users can only access their own data
2. **Category Access**: Users see default categories + their custom categories
3. **System Operations**: Service role can bypass RLS for batch operations
4. **Embedding Access**: Follows parent table security model

### Policy Examples
```sql
-- Users can view their own receipts
CREATE POLICY "Users can view own receipts" 
    ON receipts FOR SELECT 
    USING (user_id = auth.uid());

-- System can create embeddings
CREATE POLICY "System can create receipt embeddings" 
    ON receipt_embeddings FOR INSERT 
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');
```

## Migration Strategy

### Modular Migrations
1. **001_initial_schema**: Basic tables and types
2. **002_receipts_tables**: Receipt management
3. **003_warranties_notifications**: Warranty and notification systems
4. **004_vector_embeddings**: AI/RAG functionality
5. **005_budgets_system_tables**: Budget tracking and system config

### Rollback Support
Each migration is wrapped in transactions and includes rollback procedures.

## Monitoring and Maintenance

### Built-in Monitoring
- **Audit trails**: created_at/updated_at on all tables
- **Soft deletes**: is_active flags where appropriate
- **Notification tracking**: delivery status and retry counts

### Maintenance Functions
- `cleanup_old_notifications()`: Remove old read notifications
- `update_embedding_content_hash()`: Manage embedding deduplication
- Various statistics and reporting functions

## AI/RAG Integration

### Embedding Strategy
- **1536-dimensional vectors**: Compatible with OpenAI embeddings
- **Content-based**: Embed meaningful text content (merchant, product names, etc.)
- **Metadata storage**: Additional context for filtering and ranking
- **Deduplication**: Content hashing prevents duplicate embeddings

### Search Capabilities
- **Semantic similarity**: Find similar receipts/warranties
- **Hybrid search**: Combine vector similarity with traditional filters
- **Recommendation engine**: Suggest related warranties or categories

## Future Extensibility

### Planned Extensions
- **Multi-currency support**: Enhanced currency handling
- **Receipt sharing**: Team/family account features
- **Advanced analytics**: Spending trends and insights
- **Integration APIs**: Third-party service connections

### Schema Evolution
- JSONB columns allow flexible attribute addition
- Modular migration approach supports incremental features
- Vector dimensions can be adjusted for different embedding models
- Polymorphic relationships support new entity types

## Best Practices

### Development Guidelines
1. **Always use transactions** for schema changes
2. **Test RLS policies** thoroughly with different user contexts
3. **Monitor vector index performance** and adjust parameters as needed
4. **Use prepared statements** for vector similarity queries
5. **Implement proper error handling** for constraint violations

### Operational Guidelines
1. **Regular VACUUM** for optimal vector index performance
2. **Monitor embedding quality** and update as needed
3. **Archive old data** to maintain performance
4. **Backup vector indexes** separately if needed
5. **Monitor RLS policy performance** with query analysis

This architecture provides a solid foundation for Hey-Bills' core functionality while remaining flexible for future enhancements and AI-powered features.