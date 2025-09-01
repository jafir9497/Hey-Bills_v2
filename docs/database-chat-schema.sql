-- Chat System Schema for Hey-Bills RAG Assistant
-- This extends the existing database schema with chat functionality

-- Chat Conversations Table
CREATE TABLE IF NOT EXISTS chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL DEFAULT 'New Conversation',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_chat_conversations_user FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_chat_messages_conversation FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id),
  CONSTRAINT fk_chat_messages_user FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- Vector Search Function for Receipt Embeddings
CREATE OR REPLACE FUNCTION search_receipt_embeddings(
  query_embedding vector(384),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 5,
  user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  receipt_id uuid,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    re.receipt_id,
    1 - (re.embedding <=> query_embedding) AS similarity
  FROM receipt_embeddings re
  JOIN receipts r ON r.id = re.receipt_id
  WHERE 
    (user_id IS NULL OR r.user_id = search_receipt_embeddings.user_id)
    AND (1 - (re.embedding <=> query_embedding)) > match_threshold
  ORDER BY re.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_chat_conversations_user_id ON chat_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_message_at ON chat_conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id ON chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_role ON chat_messages(role);

-- RLS (Row Level Security) Policies for Chat Tables
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Chat Conversations Policies
CREATE POLICY "Users can view their own conversations" ON chat_conversations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own conversations" ON chat_conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own conversations" ON chat_conversations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own conversations" ON chat_conversations
  FOR DELETE USING (auth.uid() = user_id);

-- Chat Messages Policies
CREATE POLICY "Users can view their own messages" ON chat_messages
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own messages" ON chat_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own messages" ON chat_messages
  FOR DELETE USING (auth.uid() = user_id);

-- Function to update conversation last_message_at automatically
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_conversations 
  SET 
    last_message_at = NEW.timestamp,
    updated_at = NOW()
  WHERE id = NEW.conversation_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update last_message_at
CREATE TRIGGER trigger_update_conversation_last_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_last_message();

-- Function to get conversation message count
CREATE OR REPLACE FUNCTION get_conversation_message_count(conv_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer 
    FROM chat_messages 
    WHERE conversation_id = conv_id
  );
END;
$$ LANGUAGE plpgsql;

-- Enhanced receipt search with text similarity for fallback
CREATE OR REPLACE FUNCTION search_receipts_hybrid(
  search_query text,
  user_id_param uuid,
  match_count int DEFAULT 10
)
RETURNS TABLE (
  receipt_id uuid,
  merchant_name text,
  total_amount numeric,
  purchase_date date,
  similarity_score float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id as receipt_id,
    r.merchant_name,
    r.total_amount,
    r.purchase_date,
    CASE 
      WHEN r.merchant_name ILIKE '%' || search_query || '%' THEN 0.9
      WHEN r.category ILIKE '%' || search_query || '%' THEN 0.8
      WHEN r.notes ILIKE '%' || search_query || '%' THEN 0.7
      ELSE 0.5
    END as similarity_score
  FROM receipts r
  WHERE 
    r.user_id = user_id_param
    AND (
      r.merchant_name ILIKE '%' || search_query || '%'
      OR r.category ILIKE '%' || search_query || '%'
      OR r.notes ILIKE '%' || search_query || '%'
      OR EXISTS (
        SELECT 1 FROM receipt_items ri 
        WHERE ri.receipt_id = r.id 
        AND ri.name ILIKE '%' || search_query || '%'
      )
    )
  ORDER BY similarity_score DESC, r.purchase_date DESC
  LIMIT match_count;
END;
$$;