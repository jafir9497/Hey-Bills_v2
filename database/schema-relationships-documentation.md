# Hey-Bills Database Schema Relationships Documentation

## Version: 3.0.0
**Date:** August 31, 2025  
**Purpose:** Complete documentation of table relationships, foreign keys, and data flow

---

## Table of Contents
1. [Core Entity Relationships](#core-entity-relationships)
2. [Primary Foreign Key Relationships](#primary-foreign-key-relationships)
3. [Secondary Relationships](#secondary-relationships)
4. [Vector Embedding Relationships](#vector-embedding-relationships)
5. [Many-to-Many Relationships](#many-to-many-relationships)
6. [Polymorphic Relationships](#polymorphic-relationships)
7. [Data Flow Diagrams](#data-flow-diagrams)
8. [Referential Integrity Rules](#referential-integrity-rules)

---

## Core Entity Relationships

### User-Centric Design
The schema follows a **user-centric design** where almost all data is owned by and isolated to specific users:

```
auth.users (Supabase Auth)
├── user_profiles (1:1 extension)
├── user_sessions (1:many)
├── categories (1:many)
├── receipts (1:many)
├── warranties (1:many)
├── reminders (1:many)
├── notifications (1:many)
├── conversations (1:many)
├── user_analytics (1:many)
└── vector_search_cache (1:many)
```

### Primary Entity Hierarchy

```
User
├── Categories
│   ├── Parent-Child Categories (hierarchical)
│   └── Receipt Categorization
├── Receipts
│   ├── Receipt Line Items (1:many)
│   ├── Warranties (1:many optional)
│   └── Receipt Embeddings (1:1)
├── Warranties
│   ├── Warranty Claims (1:many)
│   └── Warranty Embeddings (1:1)
├── Conversations
│   ├── Messages (1:many)
│   └── Conversation Embeddings (many:many via messages)
└── Reminders
    └── Notifications (1:many)
```

---

## Primary Foreign Key Relationships

### 1. User Profile Extensions
```sql
user_profiles.id → auth.users.id (CASCADE DELETE)
user_sessions.user_id → auth.users.id (CASCADE DELETE)
```
**Relationship:** 1:1 (profiles), 1:many (sessions)  
**Cascade Behavior:** Full deletion of user data when auth user deleted

### 2. Category Management
```sql
categories.user_id → auth.users.id (CASCADE DELETE)
categories.parent_category_id → categories.id (SET NULL)
```
**Relationship:** Hierarchical self-referencing with unlimited depth  
**Special Features:** Materialized path for efficient queries, depth tracking

### 3. Receipt Management
```sql
receipts.user_id → auth.users.id (CASCADE DELETE)
receipts.category_id → categories.id (SET NULL)
receipt_line_items.receipt_id → receipts.id (CASCADE DELETE)
```
**Relationship:** Strong ownership model  
**Business Rules:** 
- Receipts can exist without categories
- Line items cannot exist without receipt
- Deleting receipt removes all line items

### 4. Warranty System
```sql
warranties.user_id → auth.users.id (CASCADE DELETE)
warranties.receipt_id → receipts.id (SET NULL)
warranties.category_id → categories.id (SET NULL)
warranty_claims.warranty_id → warranties.id (CASCADE DELETE)
warranty_claims.user_id → auth.users.id (CASCADE DELETE)
```
**Relationship:** Warranties can be linked to receipts but exist independently  
**Business Rules:**
- Warranties survive receipt deletion (receipt_id becomes NULL)
- Claims are tied to both warranty and user for security

### 5. Reminder and Notification System
```sql
reminders.user_id → auth.users.id (CASCADE DELETE)
reminders.receipt_id → receipts.id (CASCADE DELETE)
reminders.warranty_id → warranties.id (CASCADE DELETE)
reminders.category_id → categories.id (SET NULL)
notifications.user_id → auth.users.id (CASCADE DELETE)
notifications.reminder_id → reminders.id (SET NULL)
```
**Relationship:** Polymorphic reminders with cascade cleanup  
**Business Rules:**
- Reminders reference one entity type only
- Notifications can exist independently of reminders

---

## Secondary Relationships

### Conversation System
```sql
conversations.user_id → auth.users.id (CASCADE DELETE)
messages.conversation_id → conversations.id (CASCADE DELETE)
messages.user_id → auth.users.id (CASCADE DELETE)
```
**Features:**
- Strong conversation ownership
- Messages cannot exist without conversation
- Array-based entity references in conversations

### Analytics and Tracking
```sql
user_analytics.user_id → auth.users.id (CASCADE DELETE)
vector_search_cache.user_id → auth.users.id (CASCADE DELETE)
```
**Purpose:** Performance tracking and optimization

---

## Vector Embedding Relationships

### Embedding-to-Entity Mapping
```sql
receipt_embeddings.receipt_id → receipts.id (CASCADE DELETE)
warranty_embeddings.warranty_id → warranties.id (CASCADE DELETE)
conversation_embeddings.message_id → messages.id (CASCADE DELETE)
conversation_embeddings.conversation_id → conversations.id (CASCADE DELETE)
```

**Relationship Type:** 1:1 for receipt/warranty embeddings, many:many for conversations  
**Key Features:**
- Automatic embedding cleanup when source deleted
- Content hash ensures no duplicate embeddings
- Multiple embedding types per entity supported

### Vector Search Optimization
```
vector_search_cache
├── Stores frequently accessed searches
├── User-specific caching
└── Automatic expiration and cleanup
```

---

## Many-to-Many Relationships

### Context Arrays (Pseudo Many-to-Many)
Several tables use PostgreSQL arrays to store references, creating flexible many-to-many relationships:

#### Conversation Context
```sql
conversations.context_receipts → receipts.id[]
conversations.context_warranties → warranties.id[]
conversations.context_categories → categories.id[]
```

#### Message References
```sql
messages.referenced_receipts → receipts.id[]
messages.referenced_warranties → warranties.id[]
messages.referenced_categories → categories.id[]
```

#### Reminder Delivery
```sql
notifications.delivery_methods → delivery_method[]
```

**Advantages:**
- Flexible relationship definition
- No junction table overhead
- Efficient GIN indexing support

---

## Polymorphic Relationships

### 1. Reminder Entity References
Reminders can reference different entity types:
```sql
-- Only one of these should be non-NULL
reminders.receipt_id → receipts.id
reminders.warranty_id → warranties.id
-- category_id is always optional
reminders.category_id → categories.id
```

**Constraint:** Enforced via CHECK constraint ensuring only one entity reference

### 2. Vector Search Cache
```sql
vector_search_cache.search_type ∈ {'receipts', 'warranties', 'conversations'}
vector_search_cache.result_ids → Various entity IDs based on search_type
```

---

## Data Flow Diagrams

### Receipt Processing Flow
```
User uploads receipt image
    ↓
Receipt record created (status: pending)
    ↓
OCR processing (async)
    ↓
Receipt updated (status: processed, OCR data populated)
    ↓
Vector embedding generation (async)
    ↓
Receipt embedding created
    ↓
Auto-categorization suggestion (if enabled)
    ↓
Category assignment (manual or auto)
```

### AI Conversation Flow
```
User starts conversation
    ↓
Conversation record created
    ↓
User sends message
    ↓
Message record created (sequence_number assigned)
    ↓
RAG context assembly (vector search across user data)
    ↓
AI response generation
    ↓
Assistant message created
    ↓
Conversation embedding generation (async)
    ↓
Usage statistics updated
```

### Warranty Monitoring Flow
```
Warranty created (manual or from receipt)
    ↓
Warranty embedding generated
    ↓
Reminder created (auto, based on expiry date)
    ↓
System monitors warranty status (daily job)
    ↓
Notification created when expiring
    ↓
Notification delivered via preferred method
    ↓
User interaction tracked
```

---

## Referential Integrity Rules

### Cascade Delete Patterns
1. **User Deletion:** Complete data cleanup
   - All user-owned data deleted
   - Analytics and caching cleared
   - Session cleanup

2. **Receipt Deletion:** Controlled cleanup
   - Line items deleted (CASCADE)
   - Embeddings deleted (CASCADE)
   - Warranties unlinked (SET NULL)
   - Reminders deleted (CASCADE)

3. **Category Deletion:** Flexible unlinking
   - Child categories orphaned (SET NULL)
   - Receipts unlinked (SET NULL)
   - Warranties unlinked (SET NULL)

### Data Consistency Rules

#### 1. Financial Data Integrity
```sql
-- Receipt amounts must be logical
CHECK (total_amount >= COALESCE(subtotal_amount, 0) + COALESCE(tax_amount, 0) - COALESCE(discount_amount, 0))

-- Line item pricing must match
CHECK (total_price = (quantity * unit_price) - COALESCE(discount_amount, 0))
```

#### 2. Date Logic Validation
```sql
-- Purchase dates must be reasonable
CHECK (purchase_date <= CURRENT_DATE AND purchase_date >= DATE '2000-01-01')

-- Warranty dates must be logical
CHECK (warranty_start_date <= warranty_end_date)
CHECK (purchase_date <= warranty_start_date)
```

#### 3. Location Data Completeness
```sql
-- Lat/lng must be provided together
CHECK ((location_lat IS NULL AND location_lng IS NULL) OR 
       (location_lat IS NOT NULL AND location_lng IS NOT NULL))
```

#### 4. Embedding Consistency
```sql
-- Content hash uniqueness
UNIQUE (content_hash) -- per embedding table

-- Receipt-embedding relationship
UNIQUE (receipt_id, content_type) -- per receipt
```

---

## Relationship Optimization Features

### 1. Materialized Paths
Categories use materialized paths for efficient hierarchy queries:
```sql
category_path TEXT[] -- e.g., ['root', 'business', 'office-supplies']
```

### 2. Computed Columns
Several tables include computed columns for performance:
```sql
-- Warranties
days_until_expiry INTEGER GENERATED ALWAYS AS (warranty_end_date - CURRENT_DATE) STORED
is_expiring_soon BOOLEAN GENERATED ALWAYS AS (warranty_end_date - CURRENT_DATE <= reminder_before_expiry_days) STORED

-- Receipts
created_date DATE GENERATED ALWAYS AS (purchase_date) STORED
```

### 3. Denormalization for Performance
Strategic denormalization improves query performance:
```sql
-- Category statistics
categories.receipt_count INTEGER DEFAULT 0
categories.total_amount DECIMAL(12,2) DEFAULT 0
categories.avg_amount DECIMAL(12,2) DEFAULT 0

-- Conversation statistics
conversations.message_count INTEGER DEFAULT 0
conversations.total_tokens_used INTEGER DEFAULT 0
```

---

## Security and Access Patterns

### Row-Level Security (RLS)
All user tables implement RLS ensuring:
1. Users can only access their own data
2. Admins can access all data
3. System processes can manage data as needed

### Cross-Reference Security
When following foreign key relationships:
```sql
-- Example: Accessing receipt via line item
-- RLS ensures user can only access their receipts
-- Even if line_item_id is known, receipt access is validated
```

### Embedding Access Control
Vector embeddings inherit security from their parent entities:
- Receipt embeddings: Secured by receipt ownership
- Warranty embeddings: Secured by warranty ownership
- Conversation embeddings: Secured by conversation ownership

---

## Performance Considerations

### Index Strategy
1. **Primary Access Patterns:** User + Date/Status
2. **Search Patterns:** Full-text + Vector similarity
3. **Analytics Patterns:** Time-series aggregation
4. **Foreign Key Performance:** All foreign keys indexed

### Query Optimization
1. **Materialized Views:** Consider for complex reporting
2. **Partial Indexes:** Used extensively for status-based queries
3. **GIN Indexes:** Optimized for JSONB and array operations
4. **Vector Indexes:** IVFFlat optimized for similarity search

---

## Migration and Evolution Strategy

### Schema Versioning
- Each major change increments version
- Backward compatibility maintained where possible
- Migration scripts handle data transformation

### Relationship Changes
- Foreign key changes use safe migration patterns
- Constraint additions use NOT VALID initially
- Data migration occurs before constraint validation

### Performance Evolution
- Index additions are CONCURRENT
- Column additions are non-blocking
- Table partitioning strategy prepared for scale

---

This documentation provides a comprehensive view of all relationships within the Hey-Bills database schema, ensuring proper understanding for development, maintenance, and optimization activities.