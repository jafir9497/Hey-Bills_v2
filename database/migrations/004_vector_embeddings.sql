-- Migration: 004_vector_embeddings.sql
-- Description: Add pgvector extension and create embedding tables for RAG functionality
-- Author: System Architect
-- Date: 2024-12-XX

BEGIN;

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS "vector";

-- Receipt embeddings table for RAG functionality
CREATE TABLE receipt_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    
    -- Vector embedding (1536 dimensions for OpenAI text-embedding-ada-002)
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL, -- Hash of the content that was embedded
    content_text TEXT NOT NULL, -- The actual text that was embedded
    
    -- Metadata for filtering and search
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT receipt_embeddings_unique UNIQUE (receipt_id)
);

-- Warranty embeddings table for recommendations and search
CREATE TABLE warranty_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warranty_id UUID NOT NULL REFERENCES warranties(id) ON DELETE CASCADE,
    
    -- Vector embedding
    embedding VECTOR(1536) NOT NULL,
    
    -- Embedding metadata
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding-ada-002',
    content_hash TEXT NOT NULL,
    content_text TEXT NOT NULL,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT warranty_embeddings_unique UNIQUE (warranty_id)
);

-- Vector similarity search indexes (HNSW for fast approximate nearest neighbor)
CREATE INDEX idx_receipt_embeddings_vector ON receipt_embeddings 
    USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
CREATE INDEX idx_warranty_embeddings_vector ON warranty_embeddings 
    USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Content hash indexes for deduplication
CREATE INDEX idx_receipt_embeddings_hash ON receipt_embeddings(content_hash);
CREATE INDEX idx_warranty_embeddings_hash ON warranty_embeddings(content_hash);

-- Apply updated_at triggers
CREATE TRIGGER update_receipt_embeddings_updated_at BEFORE UPDATE ON receipt_embeddings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_warranty_embeddings_updated_at BEFORE UPDATE ON warranty_embeddings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE receipt_embeddings IS 'Vector embeddings for receipt similarity search and RAG';
COMMENT ON TABLE warranty_embeddings IS 'Vector embeddings for warranty recommendations and search';
COMMENT ON COLUMN receipt_embeddings.embedding IS 'Vector embedding for similarity search (1536 dimensions)';
COMMENT ON COLUMN warranty_embeddings.embedding IS 'Vector embedding for warranty matching and recommendations';

COMMIT;