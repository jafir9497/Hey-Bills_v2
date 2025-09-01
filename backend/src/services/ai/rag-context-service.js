// RAG Context Assembly Service
// Assembles comprehensive context for AI conversations from multiple data sources

const OpenAIEmbeddingService = require('../embeddings/openai-embedding-service');
const { supabase } = require('../../config/supabase');

class RAGContextService {
  constructor() {
    this.embeddingService = new OpenAIEmbeddingService();
    
    // Context weighting for different sources
    this.contextWeights = {
      receipts: 0.4,
      warranties: 0.3,
      conversations: 0.2,
      analytics: 0.1
    };

    // Maximum context lengths
    this.maxContextItems = {
      receipts: 8,
      warranties: 5,
      conversations: 7,
      analytics: 3
    };

    // Relevance thresholds for different context types
    this.relevanceThresholds = {
      receipts: 0.65,
      warranties: 0.70,
      conversations: 0.60,
      analytics: 0.55
    };
  }

  /**
   * Assemble comprehensive RAG context for AI conversations
   */
  async assembleContext(query, userId, conversationId = null, options = {}) {
    try {
      // Generate query embedding
      const queryEmbedding = await this.embeddingService.generateQueryEmbedding(query);
      
      // Determine which context types to include
      const contextTypes = options.contextTypes || ['receipts', 'warranties', 'conversations'];
      
      // Assemble context from multiple sources in parallel
      const contextPromises = [];

      if (contextTypes.includes('receipts')) {
        contextPromises.push(this.getReceiptContext(queryEmbedding, userId, options));
      }

      if (contextTypes.includes('warranties')) {
        contextPromises.push(this.getWarrantyContext(queryEmbedding, userId, options));
      }

      if (contextTypes.includes('conversations')) {
        contextPromises.push(this.getConversationContext(queryEmbedding, userId, conversationId, options));
      }

      if (contextTypes.includes('analytics')) {
        contextPromises.push(this.getAnalyticsContext(queryEmbedding, userId, options));
      }

      const contextResults = await Promise.allSettled(contextPromises);
      
      // Combine and rank all context items
      const allContext = [];
      contextResults.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          allContext.push(...result.value);
        } else {
          console.error(`Error getting ${contextTypes[index]} context:`, result.reason);
        }
      });

      // Sort by relevance and limit total items
      const rankedContext = this.rankAndLimitContext(allContext, options.maxItems || 15);

      // Generate context summary
      const contextSummary = this.generateContextSummary(rankedContext);

      return {
        query,
        context_items: rankedContext,
        context_summary: contextSummary,
        metadata: {
          total_items: rankedContext.length,
          context_types: contextTypes,
          user_id: userId,
          conversation_id: conversationId,
          generated_at: new Date().toISOString()
        }
      };
    } catch (error) {
      console.error('Error assembling RAG context:', error);
      throw new Error(`Failed to assemble context: ${error.message}`);
    }
  }

  /**
   * Get relevant receipt context
   */
  async getReceiptContext(queryEmbedding, userId, options = {}) {
    try {
      const { data, error } = await supabase.rpc('search_receipts_advanced', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        match_threshold: this.relevanceThresholds.receipts,
        match_count: this.maxContextItems.receipts,
        similarity_metric: 'cosine'
      });

      if (error) {
        throw error;
      }

      return data.map(item => ({
        type: 'receipt',
        id: item.receipt_id,
        relevance_score: item.similarity_score * this.contextWeights.receipts,
        content: {
          merchant_name: item.merchant_name,
          total_amount: item.total_amount,
          purchase_date: item.purchase_date,
          category_name: item.category_name,
          tags: item.tags,
          is_business_expense: item.is_business_expense
        },
        summary: `Receipt from ${item.merchant_name} on ${item.purchase_date} for $${item.total_amount}`,
        context_snippet: item.content_text ? item.content_text.substring(0, 200) : null,
        metadata: {
          confidence_score: item.confidence_score,
          similarity_metric: 'cosine'
        }
      }));
    } catch (error) {
      console.error('Error getting receipt context:', error);
      return [];
    }
  }

  /**
   * Get relevant warranty context
   */
  async getWarrantyContext(queryEmbedding, userId, options = {}) {
    try {
      const { data, error } = await supabase.rpc('search_warranties_similarity', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        match_threshold: this.relevanceThresholds.warranties,
        match_count: this.maxContextItems.warranties,
        include_expired: options.includeExpired || false
      });

      if (error) {
        throw error;
      }

      return data.map(item => ({
        type: 'warranty',
        id: item.warranty_id,
        relevance_score: item.similarity_score * this.contextWeights.warranties,
        content: {
          product_name: item.product_name,
          product_brand: item.product_brand,
          product_model: item.product_model,
          warranty_end_date: item.warranty_end_date,
          warranty_status: item.warranty_status,
          days_until_expiry: item.days_until_expiry
        },
        summary: `Warranty for ${item.product_name} (${item.product_brand}) expires ${item.warranty_end_date}`,
        context_snippet: item.content_text ? item.content_text.substring(0, 200) : null,
        metadata: {
          support_contact: item.support_contact,
          warranty_status: item.warranty_status
        }
      }));
    } catch (error) {
      console.error('Error getting warranty context:', error);
      return [];
    }
  }

  /**
   * Get relevant conversation context
   */
  async getConversationContext(queryEmbedding, userId, currentConversationId = null, options = {}) {
    try {
      const { data, error } = await supabase.rpc('get_conversation_context', {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        conversation_id_param: currentConversationId,
        context_window_size: this.maxContextItems.conversations,
        similarity_threshold: this.relevanceThresholds.conversations,
        include_related_conversations: options.includeRelated || true
      });

      if (error) {
        throw error;
      }

      return data.map(item => ({
        type: 'conversation',
        id: item.message_id,
        relevance_score: item.similarity_score * this.contextWeights.conversations,
        content: {
          conversation_id: item.conversation_id,
          message_type: item.message_type,
          content_text: item.content_text,
          sequence_number: item.sequence_number,
          created_at: item.created_at
        },
        summary: `Previous ${item.message_type}: ${item.content_text.substring(0, 100)}...`,
        context_snippet: item.content_text,
        metadata: {
          referenced_receipts: item.referenced_receipts,
          referenced_warranties: item.referenced_warranties,
          is_current_conversation: item.conversation_id === currentConversationId
        }
      }));
    } catch (error) {
      console.error('Error getting conversation context:', error);
      return [];
    }
  }

  /**
   * Get analytics context (spending patterns, insights)
   */
  async getAnalyticsContext(queryEmbedding, userId, options = {}) {
    try {
      // Generate recent spending insights
      const { data, error } = await supabase.rpc('generate_spending_insights', {
        user_id_param: userId,
        analysis_period_days: 90,
        insight_types: ['patterns', 'trends']
      });

      if (error) {
        throw error;
      }

      // Convert insights to context items
      return data.slice(0, this.maxContextItems.analytics).map((insight, index) => ({
        type: 'analytics',
        id: `insight_${index}`,
        relevance_score: insight.confidence_score * this.contextWeights.analytics,
        content: {
          insight_type: insight.insight_type,
          title: insight.insight_title,
          description: insight.insight_description,
          recommendations: insight.action_recommendations
        },
        summary: `${insight.insight_title}: ${insight.insight_description}`,
        context_snippet: insight.insight_description,
        metadata: {
          confidence_score: insight.confidence_score,
          supporting_data: insight.supporting_data
        }
      }));
    } catch (error) {
      console.error('Error getting analytics context:', error);
      return [];
    }
  }

  /**
   * Rank and limit context items by relevance
   */
  rankAndLimitContext(contextItems, maxItems = 15) {
    // Sort by relevance score (descending)
    const sorted = contextItems.sort((a, b) => b.relevance_score - a.relevance_score);
    
    // Ensure diverse context types
    const diverseContext = this.ensureContextDiversity(sorted, maxItems);
    
    // Add ranking information
    return diverseContext.map((item, index) => ({
      ...item,
      rank: index + 1,
      normalized_relevance: item.relevance_score / (sorted[0]?.relevance_score || 1)
    }));
  }

  /**
   * Ensure diversity in context types
   */
  ensureContextDiversity(sortedItems, maxItems) {
    const result = [];
    const typeCounts = {};
    const typeMaxItems = {
      receipt: Math.ceil(maxItems * 0.4),
      warranty: Math.ceil(maxItems * 0.3),
      conversation: Math.ceil(maxItems * 0.2),
      analytics: Math.ceil(maxItems * 0.1)
    };

    for (const item of sortedItems) {
      if (result.length >= maxItems) break;
      
      const currentCount = typeCounts[item.type] || 0;
      const maxForType = typeMaxItems[item.type] || Math.ceil(maxItems / 4);
      
      if (currentCount < maxForType) {
        result.push(item);
        typeCounts[item.type] = currentCount + 1;
      }
    }

    // Fill remaining slots with highest relevance items
    for (const item of sortedItems) {
      if (result.length >= maxItems) break;
      if (!result.includes(item)) {
        result.push(item);
      }
    }

    return result.slice(0, maxItems);
  }

  /**
   * Generate a summary of the assembled context
   */
  generateContextSummary(contextItems) {
    const typeCounts = {};
    let totalRelevance = 0;

    contextItems.forEach(item => {
      typeCounts[item.type] = (typeCounts[item.type] || 0) + 1;
      totalRelevance += item.relevance_score;
    });

    const avgRelevance = totalRelevance / contextItems.length;

    return {
      total_items: contextItems.length,
      items_by_type: typeCounts,
      avg_relevance: avgRelevance,
      context_strength: avgRelevance > 0.7 ? 'high' : avgRelevance > 0.5 ? 'medium' : 'low',
      top_context_types: Object.entries(typeCounts)
        .sort(([,a], [,b]) => b - a)
        .map(([type, count]) => ({ type, count }))
    };
  }

  /**
   * Format context for AI consumption
   */
  formatContextForAI(contextData) {
    const { context_items, context_summary } = contextData;
    
    const sections = {
      receipts: [],
      warranties: [],
      conversations: [],
      analytics: []
    };

    // Group context items by type
    context_items.forEach(item => {
      if (sections[item.type]) {
        sections[item.type].push(item);
      }
    });

    let formattedContext = "## Available Context\n\n";

    // Format receipts
    if (sections.receipts.length > 0) {
      formattedContext += "### Recent Receipts\n";
      sections.receipts.forEach((item, index) => {
        formattedContext += `${index + 1}. ${item.summary}\n`;
        if (item.content.tags && item.content.tags.length > 0) {
          formattedContext += `   Tags: ${item.content.tags.join(', ')}\n`;
        }
      });
      formattedContext += "\n";
    }

    // Format warranties
    if (sections.warranties.length > 0) {
      formattedContext += "### Warranty Information\n";
      sections.warranties.forEach((item, index) => {
        formattedContext += `${index + 1}. ${item.summary}\n`;
        if (item.content.days_until_expiry !== null) {
          formattedContext += `   Expires in ${item.content.days_until_expiry} days\n`;
        }
      });
      formattedContext += "\n";
    }

    // Format conversation history
    if (sections.conversations.length > 0) {
      formattedContext += "### Previous Conversations\n";
      sections.conversations.forEach((item, index) => {
        formattedContext += `${index + 1}. ${item.content.message_type}: ${item.content.content_text.substring(0, 150)}...\n`;
      });
      formattedContext += "\n";
    }

    // Format analytics insights
    if (sections.analytics.length > 0) {
      formattedContext += "### Spending Insights\n";
      sections.analytics.forEach((item, index) => {
        formattedContext += `${index + 1}. ${item.summary}\n`;
      });
      formattedContext += "\n";
    }

    formattedContext += `## Context Summary\n`;
    formattedContext += `Total context items: ${context_summary.total_items}\n`;
    formattedContext += `Context strength: ${context_summary.context_strength}\n`;
    formattedContext += `Average relevance: ${context_summary.avg_relevance.toFixed(2)}\n`;

    return formattedContext;
  }

  /**
   * Store conversation context for future reference
   */
  async storeConversationContext(conversationId, messageId, contextData) {
    try {
      // Generate embedding for the context
      const contextText = this.formatContextForAI(contextData);
      const contextEmbedding = await this.embeddingService.generateEmbedding(contextText);

      // Store in conversation_embeddings table
      const { error } = await supabase
        .from('conversation_embeddings')
        .upsert({
          message_id: messageId,
          embedding: contextEmbedding,
          content_text: contextText,
          content_hash: this.embeddingService.generateContentHash(contextText),
          metadata: {
            context_summary: contextData.context_summary,
            context_items_count: contextData.context_items.length,
            generated_at: new Date().toISOString()
          }
        });

      if (error) {
        console.error('Error storing conversation context:', error);
      }
    } catch (error) {
      console.error('Error storing conversation context:', error);
    }
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
        context_weights: this.contextWeights,
        max_context_items: this.maxContextItems,
        relevance_thresholds: this.relevanceThresholds
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
}

module.exports = RAGContextService;