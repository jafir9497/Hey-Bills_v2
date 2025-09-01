const axios = require('axios');

/**
 * OpenRouter LLM Service for Hey-Bills RAG Assistant
 * Provides integration with OpenRouter API for AI chat functionality
 */
class OpenRouterService {
  constructor() {
    this.apiKey = process.env.OPENROUTER_API_KEY;
    this.baseURL = 'https://openrouter.ai/api/v1';
    this.defaultModel = 'meta-llama/llama-3.1-8b-instruct:free'; // Free tier model
    this.maxTokens = 1000;
    this.temperature = 0.7;
    
    if (!this.apiKey) {
      console.warn('OpenRouter API key not configured. RAG functionality will be limited.');
    }
  }

  /**
   * Generate chat completion with context
   * @param {string} userQuery - User's question
   * @param {Array} context - Retrieved context from vector search
   * @param {Array} conversationHistory - Previous messages
   * @returns {Promise<string>} AI response
   */
  async generateResponse(userQuery, context = [], conversationHistory = []) {
    try {
      if (!this.apiKey) {
        return "I'm sorry, but the AI service is not configured. Please contact support.";
      }

      const systemPrompt = this.buildSystemPrompt(context);
      const messages = this.buildMessages(systemPrompt, userQuery, conversationHistory);

      const response = await axios.post(
        `${this.baseURL}/chat/completions`,
        {
          model: this.defaultModel,
          messages,
          max_tokens: this.maxTokens,
          temperature: this.temperature,
          stream: false
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://heybills.app',
            'X-Title': 'Hey Bills Assistant'
          },
          timeout: 30000
        }
      );

      return response.data.choices[0]?.message?.content || 'I apologize, but I could not generate a response.';
    } catch (error) {
      console.error('OpenRouter API error:', error.response?.data || error.message);
      return this.getErrorResponse(error);
    }
  }

  /**
   * Build system prompt with context
   * @param {Array} context - Retrieved context
   * @returns {string} System prompt
   */
  buildSystemPrompt(context) {
    const contextText = context.length > 0 
      ? context.map(item => this.formatContextItem(item)).join('\n\n')
      : 'No specific receipt data found for this query.';

    return `You are Hey Bills Assistant, an AI helper for managing receipts, warranties, and spending patterns.

CONTEXT FROM USER'S RECEIPTS:
${contextText}

INSTRUCTIONS:
1. Answer questions about receipts, warranties, spending patterns, and financial data
2. Use the provided context to give accurate, specific answers
3. If no relevant context is found, acknowledge this and provide general guidance
4. Be helpful, concise, and friendly
5. Format monetary amounts clearly (e.g., $123.45)
6. Include dates in a readable format (e.g., March 15, 2024)
7. If asked about specific receipts, reference the merchant, amount, and date
8. For warranty questions, mention expiration dates and coverage details
9. For spending analysis, provide insights and trends when possible

RESPONSE STYLE:
- Be conversational but professional
- Use bullet points for lists
- Include relevant details from the context
- Suggest actions when appropriate (e.g., "You might want to check if this warranty is still valid")`;
  }

  /**
   * Format context item for system prompt
   * @param {Object} item - Context item from vector search
   * @returns {string} Formatted context
   */
  formatContextItem(item) {
    const parts = [];
    
    if (item.merchant_name) {
      parts.push(`Merchant: ${item.merchant_name}`);
    }
    
    if (item.total_amount) {
      parts.push(`Amount: $${item.total_amount}`);
    }
    
    if (item.purchase_date) {
      parts.push(`Date: ${new Date(item.purchase_date).toLocaleDateString()}`);
    }
    
    if (item.category) {
      parts.push(`Category: ${item.category}`);
    }
    
    if (item.items && item.items.length > 0) {
      parts.push(`Items: ${item.items.map(i => i.name).join(', ')}`);
    }
    
    if (item.warranty_end_date) {
      const warrantyDate = new Date(item.warranty_end_date);
      const isExpired = warrantyDate < new Date();
      parts.push(`Warranty: ${warrantyDate.toLocaleDateString()} ${isExpired ? '(EXPIRED)' : '(Active)'}`);
    }

    return parts.join(' | ');
  }

  /**
   * Build messages array for API
   * @param {string} systemPrompt - System prompt
   * @param {string} userQuery - User query
   * @param {Array} conversationHistory - Previous messages
   * @returns {Array} Messages array
   */
  buildMessages(systemPrompt, userQuery, conversationHistory) {
    const messages = [
      { role: 'system', content: systemPrompt }
    ];

    // Add conversation history (limit to last 6 messages for context)
    const recentHistory = conversationHistory.slice(-6);
    messages.push(...recentHistory);

    // Add current user query
    messages.push({ role: 'user', content: userQuery });

    return messages;
  }

  /**
   * Get appropriate error response
   * @param {Error} error - Error object
   * @returns {string} Error response
   */
  getErrorResponse(error) {
    if (error.code === 'ECONNABORTED') {
      return "I'm taking longer than usual to respond. Please try again.";
    }
    
    if (error.response?.status === 401) {
      return "There's an authentication issue with the AI service. Please contact support.";
    }
    
    if (error.response?.status === 429) {
      return "I'm receiving too many requests right now. Please wait a moment and try again.";
    }
    
    if (error.response?.status >= 500) {
      return "The AI service is temporarily unavailable. Please try again later.";
    }
    
    return "I encountered an error processing your request. Please try rephrasing your question.";
  }

  /**
   * Generate embeddings for text (using a simpler approach for free tier)
   * @param {string} text - Text to embed
   * @returns {Promise<Array>} Embedding vector
   */
  async generateEmbedding(text) {
    try {
      // For free tier, we'll use a simple text processing approach
      // In production, consider upgrading to use actual embedding models
      const words = text.toLowerCase().split(/\W+/).filter(w => w.length > 2);
      const uniqueWords = [...new Set(words)];
      
      // Create a simple hash-based embedding (384 dimensions for compatibility)
      const embedding = new Array(384).fill(0);
      
      uniqueWords.forEach((word, index) => {
        const hash = this.simpleHash(word);
        for (let i = 0; i < 384; i++) {
          embedding[i] += Math.sin(hash * (i + 1)) * 0.1;
        }
      });
      
      // Normalize the vector
      const magnitude = Math.sqrt(embedding.reduce((sum, val) => sum + val * val, 0));
      return embedding.map(val => val / (magnitude || 1));
    } catch (error) {
      console.error('Embedding generation error:', error);
      return new Array(384).fill(0); // Return zero vector on error
    }
  }

  /**
   * Simple hash function for text
   * @param {string} str - String to hash
   * @returns {number} Hash value
   */
  simpleHash(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  /**
   * Test connection to OpenRouter API
   * @returns {Promise<boolean>} Connection status
   */
  async testConnection() {
    try {
      if (!this.apiKey) {
        return false;
      }

      const response = await axios.get(`${this.baseURL}/models`, {
        headers: {
          'Authorization': `Bearer ${this.apiKey}`
        },
        timeout: 10000
      });

      return response.status === 200;
    } catch (error) {
      console.error('OpenRouter connection test failed:', error.message);
      return false;
    }
  }
}

module.exports = new OpenRouterService();