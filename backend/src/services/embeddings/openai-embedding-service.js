// OpenAI Embedding Service for Hey-Bills
// Replaces hash-based embeddings with transformer models for semantic search

const OpenAI = require('openai');
const { createHash } = require('crypto');
const { supabase } = require('../../config/supabase');

class OpenAIEmbeddingService {
  constructor() {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
    
    // Model configurations for different use cases
    this.models = {
      premium: 'text-embedding-3-large', // 3072 dimensions, highest quality
      standard: 'text-embedding-3-small', // 1536 dimensions, good balance
      budget: 'text-embedding-ada-002'    // 1536 dimensions, cost-effective
    };
    
    this.defaultModel = 'standard';
    this.batchSize = 50; // Process embeddings in batches for efficiency
    this.cacheTimeout = 24 * 60 * 60 * 1000; // 24 hours
  }

  /**
   * Generate embedding for receipt content
   * Combines OCR text, merchant info, and metadata
   */
  async generateReceiptEmbedding(receipt, model = this.defaultModel) {
    try {
      const contentText = this.buildReceiptContentText(receipt);
      const contentHash = this.generateContentHash(contentText);
      
      // Check if we already have this embedding cached
      const cached = await this.getCachedEmbedding('receipt', contentHash);
      if (cached) {
        return {
          embedding: cached.embedding,
          contentText,
          contentHash,
          model: cached.model,
          cached: true
        };
      }
      
      const embedding = await this.generateEmbedding(contentText, model);
      
      // Cache the result
      await this.cacheEmbedding('receipt', receipt.id, embedding, contentText, contentHash, model);
      
      return {
        embedding,
        contentText,
        contentHash,
        model,
        cached: false
      };
    } catch (error) {
      console.error('Error generating receipt embedding:', error);
      throw new Error(`Failed to generate receipt embedding: ${error.message}`);
    }
  }

  /**
   * Generate embedding for warranty content
   */
  async generateWarrantyEmbedding(warranty, model = this.defaultModel) {
    try {
      const contentText = this.buildWarrantyContentText(warranty);
      const contentHash = this.generateContentHash(contentText);
      
      const cached = await this.getCachedEmbedding('warranty', contentHash);
      if (cached) {
        return {
          embedding: cached.embedding,
          contentText,
          contentHash,
          model: cached.model,
          cached: true
        };
      }
      
      const embedding = await this.generateEmbedding(contentText, model);
      
      await this.cacheEmbedding('warranty', warranty.id, embedding, contentText, contentHash, model);
      
      return {
        embedding,
        contentText,
        contentHash,
        model,
        cached: false
      };
    } catch (error) {
      console.error('Error generating warranty embedding:', error);
      throw new Error(`Failed to generate warranty embedding: ${error.message}`);
    }
  }

  /**
   * Generate embedding for conversation messages
   */
  async generateConversationEmbedding(message, context = null, model = this.defaultModel) {
    try {
      const contentText = this.buildConversationContentText(message, context);
      const contentHash = this.generateContentHash(contentText);
      
      const cached = await this.getCachedEmbedding('conversation', contentHash);
      if (cached) {
        return {
          embedding: cached.embedding,
          contentText,
          contentHash,
          model: cached.model,
          cached: true
        };
      }
      
      const embedding = await this.generateEmbedding(contentText, model);
      
      await this.cacheEmbedding('conversation', message.id, embedding, contentText, contentHash, model);
      
      return {
        embedding,
        contentText,
        contentHash,
        model,
        cached: false
      };
    } catch (error) {
      console.error('Error generating conversation embedding:', error);
      throw new Error(`Failed to generate conversation embedding: ${error.message}`);
    }
  }

  /**
   * Generate query embedding for search
   */
  async generateQueryEmbedding(query, model = this.defaultModel) {
    try {
      // Enhance query with context if available
      const enhancedQuery = await this.enhanceSearchQuery(query);
      return await this.generateEmbedding(enhancedQuery, model);
    } catch (error) {
      console.error('Error generating query embedding:', error);
      throw new Error(`Failed to generate query embedding: ${error.message}`);
    }
  }

  /**
   * Batch process embeddings for multiple items
   */
  async batchGenerateEmbeddings(items, type, model = this.defaultModel) {
    const results = [];
    const batches = this.chunkArray(items, this.batchSize);
    
    for (const batch of batches) {
      const batchPromises = batch.map(item => {
        switch (type) {
          case 'receipt':
            return this.generateReceiptEmbedding(item, model);
          case 'warranty':
            return this.generateWarrantyEmbedding(item, model);
          case 'conversation':
            return this.generateConversationEmbedding(item, null, model);
          default:
            throw new Error(`Unknown embedding type: ${type}`);
        }
      });
      
      const batchResults = await Promise.allSettled(batchPromises);
      results.push(...batchResults.map((result, index) => ({
        item: batch[index],
        success: result.status === 'fulfilled',
        embedding: result.status === 'fulfilled' ? result.value : null,
        error: result.status === 'rejected' ? result.reason : null
      })));
      
      // Rate limiting - wait between batches
      if (batches.indexOf(batch) < batches.length - 1) {
        await this.delay(100);
      }
    }
    
    return results;
  }

  /**
   * Core embedding generation using OpenAI API
   */
  async generateEmbedding(text, model = this.defaultModel) {
    try {
      const response = await this.openai.embeddings.create({
        model: this.models[model] || this.models[this.defaultModel],
        input: text.substring(0, 8000), // OpenAI limit is 8191 tokens
        encoding_format: 'float',
      });
      
      return response.data[0].embedding;
    } catch (error) {
      if (error.status === 429) {
        // Rate limit hit - wait and retry
        await this.delay(1000);
        return this.generateEmbedding(text, model);
      }
      throw error;
    }
  }

  /**
   * Build comprehensive content text for receipt embedding
   */
  buildReceiptContentText(receipt) {
    const parts = [];
    
    // Merchant information
    if (receipt.merchant_name) {
      parts.push(`Merchant: ${receipt.merchant_name}`);
    }
    
    // Purchase details
    if (receipt.total_amount) {
      parts.push(`Amount: $${receipt.total_amount}`);
    }
    
    if (receipt.purchase_date) {
      parts.push(`Date: ${receipt.purchase_date}`);
    }
    
    // Category
    if (receipt.category_name) {
      parts.push(`Category: ${receipt.category_name}`);
    }
    
    // OCR text content
    if (receipt.ocr_text) {
      parts.push(`Receipt text: ${receipt.ocr_text}`);
    }
    
    // Line items
    if (receipt.line_items && receipt.line_items.length > 0) {
      const itemsText = receipt.line_items
        .map(item => `${item.description} $${item.amount}`)
        .join(', ');
      parts.push(`Items: ${itemsText}`);
    }
    
    // Tags
    if (receipt.tags && receipt.tags.length > 0) {
      parts.push(`Tags: ${receipt.tags.join(', ')}`);
    }
    
    // Notes
    if (receipt.notes) {
      parts.push(`Notes: ${receipt.notes}`);
    }
    
    // Location
    if (receipt.location_address) {
      parts.push(`Location: ${receipt.location_address}`);
    }
    
    return parts.join('\n');
  }

  /**
   * Build content text for warranty embedding
   */
  buildWarrantyContentText(warranty) {
    const parts = [];
    
    if (warranty.product_name) {
      parts.push(`Product: ${warranty.product_name}`);
    }
    
    if (warranty.product_brand) {
      parts.push(`Brand: ${warranty.product_brand}`);
    }
    
    if (warranty.product_model) {
      parts.push(`Model: ${warranty.product_model}`);
    }
    
    if (warranty.product_category) {
      parts.push(`Category: ${warranty.product_category}`);
    }
    
    if (warranty.warranty_terms) {
      parts.push(`Warranty terms: ${warranty.warranty_terms}`);
    }
    
    if (warranty.purchase_price) {
      parts.push(`Purchase price: $${warranty.purchase_price}`);
    }
    
    if (warranty.purchase_location) {
      parts.push(`Purchase location: ${warranty.purchase_location}`);
    }
    
    if (warranty.warranty_end_date) {
      parts.push(`Warranty expires: ${warranty.warranty_end_date}`);
    }
    
    return parts.join('\n');
  }

  /**
   * Build content text for conversation embedding
   */
  buildConversationContentText(message, context = null) {
    const parts = [];
    
    if (message.content) {
      parts.push(message.content);
    }
    
    // Add context if available
    if (context && context.previousMessages) {
      const contextText = context.previousMessages
        .slice(-3) // Last 3 messages for context
        .map(msg => `${msg.message_type}: ${msg.content}`)
        .join('\n');
      parts.push(`Context: ${contextText}`);
    }
    
    // Add referenced entities
    if (message.referenced_receipts && message.referenced_receipts.length > 0) {
      parts.push(`References receipts: ${message.referenced_receipts.length} items`);
    }
    
    if (message.referenced_warranties && message.referenced_warranties.length > 0) {
      parts.push(`References warranties: ${message.referenced_warranties.length} items`);
    }
    
    return parts.join('\n');
  }

  /**
   * Enhance search query with context and synonyms
   */
  async enhanceSearchQuery(query) {
    // Add common synonyms and variations
    const enhancements = {
      'restaurant': 'restaurant dining food meal',
      'gas': 'gas fuel gasoline petrol station',
      'grocery': 'grocery store food shopping market',
      'pharmacy': 'pharmacy drug store medicine health',
      'electronics': 'electronics technology computer phone',
    };
    
    let enhanced = query.toLowerCase();
    
    for (const [key, expansion] of Object.entries(enhancements)) {
      if (enhanced.includes(key)) {
        enhanced += ` ${expansion}`;
      }
    }
    
    return enhanced;
  }

  /**
   * Generate content hash for caching
   */
  generateContentHash(content) {
    return createHash('sha256').update(content).digest('hex');
  }

  /**
   * Cache embedding to avoid regeneration
   */
  async cacheEmbedding(type, itemId, embedding, contentText, contentHash, model) {
    try {
      const tableName = `${type}_embeddings`;
      const { error } = await supabase
        .from(tableName)
        .upsert({
          [`${type}_id`]: itemId,
          embedding,
          content_text: contentText,
          content_hash: contentHash,
          embedding_model: this.models[model] || model,
          metadata: {
            generated_at: new Date().toISOString(),
            model_type: model
          }
        });
      
      if (error) {
        console.error(`Error caching ${type} embedding:`, error);
      }
    } catch (error) {
      console.error(`Error caching ${type} embedding:`, error);
    }
  }

  /**
   * Retrieve cached embedding
   */
  async getCachedEmbedding(type, contentHash) {
    try {
      const tableName = `${type}_embeddings`;
      const { data, error } = await supabase
        .from(tableName)
        .select('embedding, embedding_model, created_at')
        .eq('content_hash', contentHash)
        .single();
      
      if (error || !data) {
        return null;
      }
      
      // Check if cache is still valid
      const cacheAge = Date.now() - new Date(data.created_at).getTime();
      if (cacheAge > this.cacheTimeout) {
        return null;
      }
      
      return {
        embedding: data.embedding,
        model: data.embedding_model
      };
    } catch (error) {
      console.error(`Error retrieving cached ${type} embedding:`, error);
      return null;
    }
  }

  /**
   * Utility functions
   */
  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Health check for the service
   */
  async healthCheck() {
    try {
      // Test with a simple embedding
      const testEmbedding = await this.generateEmbedding('test', 'budget');
      return {
        status: 'healthy',
        model: this.models[this.defaultModel],
        embeddingLength: testEmbedding.length
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
}

module.exports = OpenAIEmbeddingService;