// Semantic Search Service with Intent Classification
// Provides intelligent search capabilities using vector embeddings and AI

const OpenAIEmbeddingService = require('../embeddings/openai-embedding-service');
const { supabase } = require('../../config/supabase');

class SemanticSearchService {
  constructor() {
    this.embeddingService = new OpenAIEmbeddingService();
    
    // Intent classification patterns
    this.intentPatterns = {
      receipt_search: [
        'find receipt', 'search receipt', 'receipt from', 'purchase at',
        'spent at', 'bought at', 'transaction', 'payment'
      ],
      warranty_query: [
        'warranty', 'guarantee', 'return policy', 'coverage',
        'expires', 'still covered', 'warranty info'
      ],
      budget_analysis: [
        'spending', 'budget', 'total spent', 'monthly expenses',
        'category spending', 'how much', 'analyze spending'
      ],
      category_classification: [
        'what category', 'classify', 'categorize', 'type of expense'
      ],
      duplicate_detection: [
        'duplicate', 'same receipt', 'already added', 'similar purchase'
      ],
      trend_analysis: [
        'trends', 'patterns', 'over time', 'monthly', 'weekly',
        'comparison', 'increase', 'decrease'
      ]
    };

    // Entity extraction patterns
    this.entityPatterns = {
      merchant: /(?:at|from)\s+([A-Za-z\s&-]+)(?:\s+on|\s*$)/i,
      amount: /\$?(\d+(?:\.\d{2})?)/g,
      date: /(?:on|from|since|before|after)\s+([\d\/\-]+|\w+\s+\d+(?:,\s+\d{4})?)/i,
      category: /(?:in|for)\s+(food|gas|groceries|entertainment|healthcare|shopping|utilities|transportation)/i,
      timeRange: /(?:last|past|in the)\s+(week|month|year|\d+\s+(?:days|weeks|months))/i
    };
  }

  /**
   * Main search interface - classifies intent and routes to appropriate search
   */
  async search(query, userId, options = {}) {
    try {
      // Classify the query intent
      const intent = this.classifyIntent(query);
      
      // Extract entities from the query
      const entities = this.extractEntities(query);
      
      // Generate query embedding
      const queryEmbedding = await this.embeddingService.generateQueryEmbedding(query);
      
      // Route to appropriate search method
      let results;
      switch (intent.primary) {
        case 'receipt_search':
          results = await this.searchReceipts(queryEmbedding, userId, entities, options);
          break;
        case 'warranty_query':
          results = await this.searchWarranties(queryEmbedding, userId, entities, options);
          break;
        case 'budget_analysis':
          results = await this.analyzeBudget(queryEmbedding, userId, entities, options);
          break;
        case 'duplicate_detection':
          results = await this.findDuplicates(queryEmbedding, userId, entities, options);
          break;
        default:
          // Hybrid search across all content types
          results = await this.hybridSearch(queryEmbedding, query, userId, entities, options);
      }

      return {
        intent,
        entities,
        results,
        query: query,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('Error in semantic search:', error);
      throw new Error(`Search failed: ${error.message}`);
    }
  }

  /**
   * Advanced receipt search using vector similarity
   */
  async searchReceipts(queryEmbedding, userId, entities = {}, options = {}) {
    try {
      const searchParams = {
        match_threshold: options.threshold || 0.7,
        match_count: options.limit || 10,
        similarity_metric: options.metric || 'cosine'
      };

      // Add entity-based filters
      if (entities.dateRange) {
        searchParams.date_range_start = entities.dateRange.start;
        searchParams.date_range_end = entities.dateRange.end;
      }

      if (entities.amountRange) {
        searchParams.min_amount = entities.amountRange.min;
        searchParams.max_amount = entities.amountRange.max;
      }

      if (entities.merchant) {
        searchParams.merchant_filter = entities.merchant;
      }

      if (entities.category) {
        // Get category ID from name
        const { data: categories } = await supabase
          .from('categories')
          .select('id')
          .eq('name', entities.category)
          .eq('user_id', userId);
        
        if (categories && categories.length > 0) {
          searchParams.category_ids = categories.map(c => c.id);
        }
      }

      // Call the advanced receipt search function
      const { data, error } = await supabase.rpc('search_receipts_advanced', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        ...searchParams
      });

      if (error) {
        throw error;
      }

      return {
        type: 'receipts',
        count: data.length,
        items: data.map(item => ({
          id: item.receipt_id,
          merchant_name: item.merchant_name,
          total_amount: item.total_amount,
          purchase_date: item.purchase_date,
          category_name: item.category_name,
          similarity_score: item.similarity_score,
          confidence_score: item.confidence_score,
          tags: item.tags,
          is_business_expense: item.is_business_expense,
          snippet: item.content_text ? item.content_text.substring(0, 200) + '...' : ''
        }))
      };
    } catch (error) {
      console.error('Error in receipt search:', error);
      throw error;
    }
  }

  /**
   * Warranty similarity search
   */
  async searchWarranties(queryEmbedding, userId, entities = {}, options = {}) {
    try {
      const { data, error } = await supabase.rpc('search_warranties_similarity', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        match_threshold: options.threshold || 0.75,
        match_count: options.limit || 5,
        include_expired: options.includeExpired || false,
        product_brand_filter: entities.brand || null
      });

      if (error) {
        throw error;
      }

      return {
        type: 'warranties',
        count: data.length,
        items: data.map(item => ({
          id: item.warranty_id,
          product_name: item.product_name,
          product_brand: item.product_brand,
          product_model: item.product_model,
          warranty_end_date: item.warranty_end_date,
          warranty_status: item.warranty_status,
          similarity_score: item.similarity_score,
          days_until_expiry: item.days_until_expiry,
          support_contact: item.support_contact
        }))
      };
    } catch (error) {
      console.error('Error in warranty search:', error);
      throw error;
    }
  }

  /**
   * Hybrid search combining vector and text search
   */
  async hybridSearch(queryEmbedding, queryText, userId, entities = {}, options = {}) {
    try {
      const { data, error } = await supabase.rpc('hybrid_search_receipts', {
        query_text: queryText,
        query_embedding: queryEmbedding,
        user_id_param: userId,
        vector_weight: options.vectorWeight || 0.7,
        text_weight: options.textWeight || 0.3,
        match_count: options.limit || 10,
        date_range_months: entities.timeRange ? this.parseTimeRange(entities.timeRange) : null
      });

      if (error) {
        throw error;
      }

      return {
        type: 'hybrid',
        count: data.length,
        items: data.map(item => ({
          id: item.receipt_id,
          merchant_name: item.merchant_name,
          total_amount: item.total_amount,
          purchase_date: item.purchase_date,
          category_name: item.category_name,
          combined_score: item.combined_score,
          vector_score: item.vector_score,
          text_score: item.text_score,
          snippet: item.content_snippet,
          rank_explanation: item.rank_explanation
        }))
      };
    } catch (error) {
      console.error('Error in hybrid search:', error);
      throw error;
    }
  }

  /**
   * Budget analysis with spending insights
   */
  async analyzeBudget(queryEmbedding, userId, entities = {}, options = {}) {
    try {
      const timeframe = entities.timeRange ? this.parseTimeRange(entities.timeRange) : 90;
      
      const { data, error } = await supabase.rpc('generate_spending_insights', {
        user_id_param: userId,
        analysis_period_days: timeframe * 30, // Convert to days
        insight_types: options.insightTypes || ['patterns', 'anomalies', 'trends']
      });

      if (error) {
        throw error;
      }

      return {
        type: 'budget_analysis',
        timeframe: `${timeframe} months`,
        insights: data.map(insight => ({
          type: insight.insight_type,
          title: insight.insight_title,
          description: insight.insight_description,
          confidence: insight.confidence_score,
          data: insight.supporting_data,
          recommendations: insight.action_recommendations
        }))
      };
    } catch (error) {
      console.error('Error in budget analysis:', error);
      throw error;
    }
  }

  /**
   * Find potential duplicate receipts
   */
  async findDuplicates(queryEmbedding, userId, entities = {}, options = {}) {
    try {
      // This would need a specific receipt ID to find duplicates of
      // For now, we'll return similar high-similarity receipts
      const { data, error } = await supabase.rpc('search_receipts_advanced', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        match_threshold: 0.85, // High threshold for duplicate detection
        match_count: 20,
        similarity_metric: 'cosine'
      });

      if (error) {
        throw error;
      }

      // Group by potential duplicates (same merchant, similar amount, close dates)
      const duplicateGroups = this.groupPotentialDuplicates(data);

      return {
        type: 'duplicate_detection',
        groups: duplicateGroups
      };
    } catch (error) {
      console.error('Error in duplicate detection:', error);
      throw error;
    }
  }

  /**
   * Classify the intent of a search query
   */
  classifyIntent(query) {
    const normalizedQuery = query.toLowerCase();
    const intentScores = {};

    // Calculate scores for each intent
    for (const [intent, patterns] of Object.entries(this.intentPatterns)) {
      let score = 0;
      for (const pattern of patterns) {
        if (normalizedQuery.includes(pattern.toLowerCase())) {
          score += 1;
        }
      }
      intentScores[intent] = score;
    }

    // Find the highest scoring intent
    const primaryIntent = Object.keys(intentScores).reduce((a, b) => 
      intentScores[a] > intentScores[b] ? a : b
    );

    // Get secondary intents (above threshold)
    const secondaryIntents = Object.keys(intentScores)
      .filter(intent => intent !== primaryIntent && intentScores[intent] > 0)
      .sort((a, b) => intentScores[b] - intentScores[a]);

    return {
      primary: intentScores[primaryIntent] > 0 ? primaryIntent : 'general_search',
      secondary: secondaryIntents,
      confidence: intentScores[primaryIntent] / Math.max(1, patterns.length),
      scores: intentScores
    };
  }

  /**
   * Extract entities from search query
   */
  extractEntities(query) {
    const entities = {};

    // Extract merchant
    const merchantMatch = query.match(this.entityPatterns.merchant);
    if (merchantMatch) {
      entities.merchant = merchantMatch[1].trim();
    }

    // Extract amounts
    const amountMatches = Array.from(query.matchAll(this.entityPatterns.amount));
    if (amountMatches.length > 0) {
      const amounts = amountMatches.map(m => parseFloat(m[1]));
      if (amounts.length === 1) {
        entities.targetAmount = amounts[0];
      } else {
        entities.amountRange = {
          min: Math.min(...amounts),
          max: Math.max(...amounts)
        };
      }
    }

    // Extract dates
    const dateMatch = query.match(this.entityPatterns.date);
    if (dateMatch) {
      entities.dateFilter = dateMatch[1];
      entities.dateRange = this.parseDate(dateMatch[1]);
    }

    // Extract category
    const categoryMatch = query.match(this.entityPatterns.category);
    if (categoryMatch) {
      entities.category = categoryMatch[1];
    }

    // Extract time range
    const timeRangeMatch = query.match(this.entityPatterns.timeRange);
    if (timeRangeMatch) {
      entities.timeRange = timeRangeMatch[1];
    }

    return entities;
  }

  /**
   * Parse time range expressions
   */
  parseTimeRange(timeRange) {
    const normalized = timeRange.toLowerCase();
    
    if (normalized.includes('week')) {
      return 0.25; // weeks to months
    } else if (normalized.includes('month')) {
      const numberMatch = timeRange.match(/(\d+)/);
      return numberMatch ? parseInt(numberMatch[1]) : 1;
    } else if (normalized.includes('year')) {
      return 12;
    } else if (normalized.includes('day')) {
      const numberMatch = timeRange.match(/(\d+)/);
      return numberMatch ? parseInt(numberMatch[1]) / 30 : 1;
    }
    
    return 1; // Default to 1 month
  }

  /**
   * Parse date expressions
   */
  parseDate(dateString) {
    // Simple date parsing - would need more sophisticated parsing in production
    const today = new Date();
    
    if (dateString.toLowerCase().includes('today')) {
      return {
        start: today,
        end: today
      };
    } else if (dateString.toLowerCase().includes('yesterday')) {
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      return {
        start: yesterday,
        end: yesterday
      };
    }
    
    // Try to parse as date
    const parsed = new Date(dateString);
    if (!isNaN(parsed)) {
      return {
        start: parsed,
        end: parsed
      };
    }
    
    return null;
  }

  /**
   * Group receipts by potential duplicates
   */
  groupPotentialDuplicates(receipts) {
    const groups = [];
    const processed = new Set();

    for (let i = 0; i < receipts.length; i++) {
      if (processed.has(i)) continue;

      const current = receipts[i];
      const group = [current];

      for (let j = i + 1; j < receipts.length; j++) {
        if (processed.has(j)) continue;

        const other = receipts[j];
        
        // Check if they could be duplicates
        if (this.arePotentialDuplicates(current, other)) {
          group.push(other);
          processed.add(j);
        }
      }

      if (group.length > 1) {
        groups.push({
          confidence: 'high',
          receipts: group,
          reason: 'Similar merchant, amount, and date'
        });
      }

      processed.add(i);
    }

    return groups;
  }

  /**
   * Check if two receipts are potential duplicates
   */
  arePotentialDuplicates(receipt1, receipt2) {
    // Same merchant
    if (receipt1.merchant_name !== receipt2.merchant_name) {
      return false;
    }

    // Similar amount (within $1)
    const amountDiff = Math.abs(receipt1.total_amount - receipt2.total_amount);
    if (amountDiff > 1.0) {
      return false;
    }

    // Close dates (within 1 day)
    const date1 = new Date(receipt1.purchase_date);
    const date2 = new Date(receipt2.purchase_date);
    const daysDiff = Math.abs((date1 - date2) / (1000 * 60 * 60 * 24));
    if (daysDiff > 1) {
      return false;
    }

    return true;
  }

  /**
   * Health check for the service
   */
  async healthCheck() {
    try {
      const embeddingHealth = await this.embeddingService.healthCheck();
      
      return {
        status: 'healthy',
        embedding_service: embeddingHealth,
        intent_patterns: Object.keys(this.intentPatterns).length,
        entity_patterns: Object.keys(this.entityPatterns).length
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
}

module.exports = SemanticSearchService;