-- ============================================================================
-- 001_enable_extensions.sql
-- Enable required PostgreSQL extensions for Hey-Bills
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable vector operations for RAG/AI embeddings
CREATE EXTENSION IF NOT EXISTS "vector";

-- Enable trigram matching for fuzzy text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Enable full-text search
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Comment for deployment tracking
COMMENT ON EXTENSION "uuid-ossp" IS 'UUID generation for primary keys';
COMMENT ON EXTENSION "pgcrypto" IS 'Cryptographic functions for security';
COMMENT ON EXTENSION "vector" IS 'Vector operations for AI embeddings and RAG';
COMMENT ON EXTENSION "pg_trgm" IS 'Trigram matching for fuzzy search';
COMMENT ON EXTENSION "unaccent" IS 'Text processing for full-text search';