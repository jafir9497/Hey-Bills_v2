const openRouterService = require('./openRouterService');
const vectorSearchService = require('./vectorSearchService');
const { supabase } = require('../../config/supabase');

/**
 * RAG (Retrieval-Augmented Generation) Service for Hey-Bills
 * Combines vector search with LLM generation for intelligent chat responses
 */
class RAGService {
  constructor() {
    this.maxContextItems = 5;
    this.searchTimeout = 10000;
  }

  /**
   * Process user query and generate intelligent response
   * @param {string} userId - User ID
   * @param {string} query - User's question
   * @param {string} conversationId - Conversation ID
   * @param {Array} conversationHistory - Previous messages
   * @returns {Promise<Object>} Response with answer and metadata
   */
  async processQuery(userId, query, conversationId, conversationHistory = []) {
    try {
      const startTime = Date.now();
      
      // Step 1: Analyze query to determine search strategy
      const queryAnalysis = await this.analyzeQuery(query);
      
      // Step 2: Retrieve relevant context based on query type
      const context = await this.retrieveContext(userId, query, queryAnalysis);
      
      // Step 3: Generate response using LLM with retrieved context
      const response = await openRouterService.generateResponse(
        query,
        context.items,
        conversationHistory
      );
      
      // Step 4: Store conversation in database
      await this.storeConversation(userId, conversationId, query, response, context);
      
      const processingTime = Date.now() - startTime;
      
      return {
        answer: response,
        context_used: context.items.length,
        search_strategy: queryAnalysis.strategy,
        processing_time_ms: processingTime,
        confidence: context.confidence,
        sources: context.sources
      };
    } catch (error) {
      console.error('RAG processing error:', error);
      return {
        answer: "I'm sorry, but I encountered an error processing your question. Please try again or rephrase your query.",
        error: true,
        processing_time_ms: 0,
        context_used: 0
      };
    }
  }

  /**
   * Analyze user query to determine search strategy
   * @param {string} query - User query
   * @returns {Promise<Object>} Query analysis
   */
  async analyzeQuery(query) {
    const lowerQuery = query.toLowerCase();
    
    // Detect query patterns
    const patterns = {
      receipt_search: [
        'receipt', 'bought', 'purchased', 'paid', 'spend', 'cost',
        'store', 'shop', 'merchant', 'transaction'
      ],
      warranty_search: [
        'warranty', 'guarantee', 'coverage', 'expire', 'protection',
        'valid', 'claim', 'return'
      ],
      spending_analysis: [
        'total', 'sum', 'average', 'most', 'least', 'trend', 'pattern',
        'monthly', 'yearly', 'category', 'budget'
      ],
      date_search: [
        'when', 'date', 'time', 'ago', 'last', 'this', 'month', 'year',
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ],
      amount_search: [
        '$', 'dollar', 'price', 'amount', 'expensive', 'cheap',
        'cost', 'total', 'sum'
      ]
    };

    const scores = {};
    for (const [type, keywords] of Object.entries(patterns)) {
      scores[type] = keywords.reduce((score, keyword) => {
        return score + (lowerQuery.includes(keyword) ? 1 : 0);
      }, 0);
    }

    // Determine primary strategy
    const maxScore = Math.max(...Object.values(scores));
    const primaryStrategy = Object.entries(scores)
      .find(([, score]) => score === maxScore)?.[0] || 'general';

    // Extract specific entities
    const entities = this.extractEntities(query);

    return {
      strategy: primaryStrategy,
      scores,
      entities,
      query_length: query.length,
      has_numbers: /\d/.test(query),
      has_dates: /\d{1,2}\/\d{1,2}\/\d{2,4}|\d{4}-\d{2}-\d{2}/.test(query)
    };
  }

  /**
   * Extract entities from query (dates, amounts, merchants, etc.)
   * @param {string} query - User query
   * @returns {Object} Extracted entities
   */
  extractEntities(query) {
    const entities = {
      dates: [],
      amounts: [],
      merchants: [],
      categories: [],
      items: []
    };

    // Extract dates
    const dateRegex = /\d{1,2}\/\d{1,2}\/\d{2,4}|\d{4}-\d{2}-\d{2}|january|february|march|april|may|june|july|august|september|october|november|december/gi;
    entities.dates = [...query.matchAll(dateRegex)].map(match => match[0]);

    // Extract amounts
    const amountRegex = /\$\d+\.?\d*|\d+\.?\d*\s*dollars?/gi;
    entities.amounts = [...query.matchAll(amountRegex)].map(match => match[0]);

    // Common merchants (expandable)
    const commonMerchants = [
      'amazon', 'walmart', 'target', 'costco', 'safeway', 'kroger',
      'home depot', 'lowes', 'starbucks', 'mcdonalds', 'subway',
      'gas station', 'grocery store', 'restaurant', 'pharmacy'
    ];
    
    entities.merchants = commonMerchants.filter(merchant => 
      query.toLowerCase().includes(merchant)
    );

    // Common categories
    const commonCategories = [
      'food', 'grocery', 'gas', 'entertainment', 'shopping', 'utilities',
      'healthcare', 'travel', 'dining', 'electronics', 'clothing'
    ];
    
    entities.categories = commonCategories.filter(category => 
      query.toLowerCase().includes(category)
    );

    return entities;
  }

  /**
   * Retrieve relevant context for the query
   * @param {string} userId - User ID
   * @param {string} query - User query
   * @param {Object} analysis - Query analysis
   * @returns {Promise<Object>} Retrieved context
   */
  async retrieveContext(userId, query, analysis) {
    try {
      let contextItems = [];
      let confidence = 0;
      const sources = [];

      // Generate query embedding
      const queryEmbedding = await openRouterService.generateEmbedding(query);

      switch (analysis.strategy) {
        case 'receipt_search':
          contextItems = await vectorSearchService.searchSimilarReceipts(
            queryEmbedding, 
            userId,
            { limit: this.maxContextItems }
          );
          sources.push('receipts');
          confidence = contextItems.length > 0 ? 0.8 : 0.3;
          break;

        case 'warranty_search':
          contextItems = await vectorSearchService.searchWarranties(query, userId);
          sources.push('warranties');
          confidence = contextItems.length > 0 ? 0.9 : 0.2;
          break;

        case 'spending_analysis':
          const analytics = await vectorSearchService.getSpendingAnalytics(userId);
          contextItems = [{ analytics, type: 'spending_summary' }];
          sources.push('analytics');
          confidence = analytics.transaction_count > 0 ? 0.7 : 0.1;
          break;

        default:
          // General search - combine multiple sources
          const [receipts, warranties] = await Promise.all([
            vectorSearchService.searchSimilarReceipts(
              queryEmbedding, 
              userId,
              { limit: 3, threshold: 0.6 }
            ),
            vectorSearchService.searchWarranties(query, userId)
          ]);

          contextItems = [...receipts, ...warranties.slice(0, 2)];
          sources.push('receipts', 'warranties');
          confidence = contextItems.length > 0 ? 0.6 : 0.2;
          break;
      }

      return {
        items: contextItems.slice(0, this.maxContextItems),
        confidence,
        sources,
        total_found: contextItems.length
      };
    } catch (error) {
      console.error('Context retrieval error:', error);
      return {
        items: [],
        confidence: 0,
        sources: [],
        total_found: 0
      };
    }
  }

  /**
   * Store conversation in database
   * @param {string} userId - User ID
   * @param {string} conversationId - Conversation ID
   * @param {string} userMessage - User's message
   * @param {string} assistantResponse - Assistant's response
   * @param {Object} context - Retrieved context
   * @returns {Promise<boolean>} Success status
   */
  async storeConversation(userId, conversationId, userMessage, assistantResponse, context) {
    try {
      // Store user message
      await supabase.from('chat_messages').insert({
        conversation_id: conversationId,
        user_id: userId,
        role: 'user',
        content: userMessage,
        timestamp: new Date().toISOString()
      });

      // Store assistant response with metadata
      await supabase.from('chat_messages').insert({
        conversation_id: conversationId,
        user_id: userId,
        role: 'assistant',
        content: assistantResponse,
        metadata: {
          context_used: context.items.length,
          confidence: context.confidence,
          sources: context.sources
        },
        timestamp: new Date().toISOString()
      });

      // Update conversation last activity
      await supabase
        .from('chat_conversations')
        .upsert({
          id: conversationId,
          user_id: userId,
          title: this.generateConversationTitle(userMessage),
          last_message_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

      return true;
    } catch (error) {
      console.error('Conversation storage error:', error);
      return false;
    }
  }

  /**
   * Generate conversation title from first message
   * @param {string} message - First message
   * @returns {string} Generated title
   */
  generateConversationTitle(message) {
    const words = message.split(' ').slice(0, 6);
    let title = words.join(' ');
    
    if (message.length > 30) {
      title += '...';
    }
    
    return title || 'New Conversation';
  }

  /**
   * Get conversation history
   * @param {string} conversationId - Conversation ID
   * @param {number} limit - Message limit
   * @returns {Promise<Array>} Conversation messages
   */
  async getConversationHistory(conversationId, limit = 20) {
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('role, content, timestamp, metadata')
        .eq('conversation_id', conversationId)
        .order('timestamp', { ascending: true })
        .limit(limit);

      if (error) {
        console.error('Conversation history error:', error);
        return [];
      }

      return (data || []).map(msg => ({
        role: msg.role,
        content: msg.content
      }));
    } catch (error) {
      console.error('Conversation history error:', error);
      return [];
    }
  }

  /**
   * Generate embedding for receipt content
   * @param {Object} receipt - Receipt object
   * @returns {Promise<Array>} Embedding vector
   */
  async generateReceiptEmbedding(receipt) {
    try {
      // Create comprehensive text representation of receipt
      const textParts = [
        receipt.merchant_name || '',
        receipt.category || '',
        `$${receipt.total_amount}`,
        new Date(receipt.purchase_date).toLocaleDateString(),
        receipt.notes || ''
      ];

      // Add item information
      if (receipt.receipt_items) {
        receipt.receipt_items.forEach(item => {
          textParts.push(item.name || '');
          textParts.push(item.category || '');
        });
      }

      const combinedText = textParts.filter(text => text).join(' ');
      return await openRouterService.generateEmbedding(combinedText);
    } catch (error) {
      console.error('Receipt embedding generation error:', error);
      return new Array(384).fill(0);
    }
  }

  /**
   * Process new receipt for embedding storage
   * @param {Object} receipt - Receipt data
   * @returns {Promise<boolean>} Success status
   */
  async processNewReceipt(receipt) {
    try {
      const embedding = await this.generateReceiptEmbedding(receipt);
      return await vectorSearchService.storeEmbedding(receipt.id, embedding);
    } catch (error) {
      console.error('Receipt processing error:', error);
      return false;
    }
  }
}

module.exports = new RAGService();