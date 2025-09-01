const { supabase } = require('../../config/supabase');

/**
 * Vector Search Service for Hey-Bills RAG System
 * Handles vector similarity search using pgvector extension
 */
class VectorSearchService {
  constructor() {
    this.defaultLimit = 5;
    this.similarityThreshold = 0.7;
  }

  /**
   * Search for similar receipts using vector similarity
   * @param {Array} queryEmbedding - Query embedding vector
   * @param {string} userId - User ID for filtering
   * @param {Object} options - Search options
   * @returns {Promise<Array>} Similar receipts with metadata
   */
  async searchSimilarReceipts(queryEmbedding, userId, options = {}) {
    try {
      const limit = options.limit || this.defaultLimit;
      const threshold = options.threshold || this.similarityThreshold;

      // First, search in receipt embeddings
      const { data: receiptEmbeddings, error: embeddingError } = await supabase
        .rpc('search_receipt_embeddings', {
          query_embedding: queryEmbedding,
          match_threshold: threshold,
          match_count: limit,
          user_id: userId
        });

      if (embeddingError) {
        console.error('Vector search error:', embeddingError);
        return [];
      }

      if (!receiptEmbeddings || receiptEmbeddings.length === 0) {
        return [];
      }

      // Get full receipt details for found embeddings
      const receiptIds = receiptEmbeddings.map(item => item.receipt_id);
      
      const { data: receipts, error: receiptError } = await supabase
        .from('receipts')
        .select(`
          id,
          merchant_name,
          total_amount,
          purchase_date,
          category,
          notes,
          receipt_items (
            id,
            name,
            quantity,
            unit_price,
            category
          ),
          warranties (
            id,
            item_name,
            warranty_period_months,
            warranty_start_date,
            warranty_end_date,
            coverage_details,
            status
          )
        `)
        .in('id', receiptIds)
        .eq('user_id', userId);

      if (receiptError) {
        console.error('Receipt fetch error:', receiptError);
        return [];
      }

      // Combine embedding similarity scores with receipt data
      const enrichedResults = receipts.map(receipt => {
        const embedding = receiptEmbeddings.find(e => e.receipt_id === receipt.id);
        return {
          ...receipt,
          similarity: embedding?.similarity || 0,
          items: receipt.receipt_items || [],
          warranties: receipt.warranties || []
        };
      });

      return enrichedResults.sort((a, b) => b.similarity - a.similarity);
    } catch (error) {
      console.error('Vector search error:', error);
      return [];
    }
  }

  /**
   * Search for spending patterns using semantic similarity
   * @param {Array} queryEmbedding - Query embedding vector
   * @param {string} userId - User ID
   * @param {Object} filters - Additional filters
   * @returns {Promise<Array>} Matching spending patterns
   */
  async searchSpendingPatterns(queryEmbedding, userId, filters = {}) {
    try {
      const { dateFrom, dateTo, category, minAmount, maxAmount } = filters;
      
      let query = supabase
        .from('receipts')
        .select(`
          id,
          merchant_name,
          total_amount,
          purchase_date,
          category,
          payment_method,
          receipt_items (
            name,
            quantity,
            unit_price
          )
        `)
        .eq('user_id', userId);

      // Apply filters
      if (dateFrom) {
        query = query.gte('purchase_date', dateFrom);
      }
      if (dateTo) {
        query = query.lte('purchase_date', dateTo);
      }
      if (category) {
        query = query.eq('category', category);
      }
      if (minAmount) {
        query = query.gte('total_amount', minAmount);
      }
      if (maxAmount) {
        query = query.lte('total_amount', maxAmount);
      }

      const { data: receipts, error } = await query
        .order('purchase_date', { ascending: false })
        .limit(50);

      if (error) {
        console.error('Spending pattern search error:', error);
        return [];
      }

      return receipts || [];
    } catch (error) {
      console.error('Spending pattern search error:', error);
      return [];
    }
  }

  /**
   * Search warranty information
   * @param {string} query - Search query
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Warranty information
   */
  async searchWarranties(query, userId) {
    try {
      const searchTerms = query.toLowerCase();
      
      const { data: warranties, error } = await supabase
        .from('warranties')
        .select(`
          id,
          item_name,
          warranty_period_months,
          warranty_start_date,
          warranty_end_date,
          coverage_details,
          status,
          receipts (
            id,
            merchant_name,
            purchase_date,
            total_amount
          )
        `)
        .eq('user_id', userId)
        .or(`item_name.ilike.%${searchTerms}%,coverage_details.ilike.%${searchTerms}%`)
        .order('warranty_end_date', { ascending: true });

      if (error) {
        console.error('Warranty search error:', error);
        return [];
      }

      return warranties || [];
    } catch (error) {
      console.error('Warranty search error:', error);
      return [];
    }
  }

  /**
   * Get spending analytics for context
   * @param {string} userId - User ID
   * @param {Object} options - Analysis options
   * @returns {Promise<Object>} Spending analytics
   */
  async getSpendingAnalytics(userId, options = {}) {
    try {
      const { months = 6 } = options;
      const dateFrom = new Date();
      dateFrom.setMonth(dateFrom.getMonth() - months);

      const { data: receipts, error } = await supabase
        .from('receipts')
        .select('total_amount, purchase_date, category, merchant_name')
        .eq('user_id', userId)
        .gte('purchase_date', dateFrom.toISOString())
        .order('purchase_date', { ascending: false });

      if (error) {
        console.error('Spending analytics error:', error);
        return {};
      }

      if (!receipts || receipts.length === 0) {
        return {
          total_spent: 0,
          transaction_count: 0,
          categories: {},
          monthly_totals: {},
          top_merchants: []
        };
      }

      // Calculate analytics
      const totalSpent = receipts.reduce((sum, r) => sum + parseFloat(r.total_amount), 0);
      const transactionCount = receipts.length;

      // Category breakdown
      const categories = {};
      receipts.forEach(receipt => {
        const category = receipt.category || 'Other';
        categories[category] = (categories[category] || 0) + parseFloat(receipt.total_amount);
      });

      // Monthly totals
      const monthlyTotals = {};
      receipts.forEach(receipt => {
        const month = new Date(receipt.purchase_date).toISOString().substring(0, 7);
        monthlyTotals[month] = (monthlyTotals[month] || 0) + parseFloat(receipt.total_amount);
      });

      // Top merchants
      const merchantTotals = {};
      receipts.forEach(receipt => {
        const merchant = receipt.merchant_name || 'Unknown';
        merchantTotals[merchant] = (merchantTotals[merchant] || 0) + parseFloat(receipt.total_amount);
      });

      const topMerchants = Object.entries(merchantTotals)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 5)
        .map(([name, amount]) => ({ name, amount }));

      return {
        total_spent: totalSpent,
        transaction_count: transactionCount,
        categories,
        monthly_totals: monthlyTotals,
        top_merchants: topMerchants,
        average_transaction: totalSpent / transactionCount
      };
    } catch (error) {
      console.error('Spending analytics error:', error);
      return {};
    }
  }

  /**
   * Store receipt embedding
   * @param {string} receiptId - Receipt ID
   * @param {Array} embedding - Embedding vector
   * @param {string} contentType - Type of content
   * @returns {Promise<boolean>} Success status
   */
  async storeEmbedding(receiptId, embedding, contentType = 'receipt_full') {
    try {
      const { error } = await supabase
        .from('receipt_embeddings')
        .upsert({
          receipt_id: receiptId,
          embedding,
          content_type: contentType,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

      if (error) {
        console.error('Embedding storage error:', error);
        return false;
      }

      return true;
    } catch (error) {
      console.error('Embedding storage error:', error);
      return false;
    }
  }

  /**
   * Get receipt embedding by ID
   * @param {string} receiptId - Receipt ID
   * @returns {Promise<Object|null>} Embedding data
   */
  async getEmbedding(receiptId) {
    try {
      const { data, error } = await supabase
        .from('receipt_embeddings')
        .select('*')
        .eq('receipt_id', receiptId)
        .single();

      if (error && error.code !== 'PGRST116') {
        console.error('Embedding fetch error:', error);
        return null;
      }

      return data;
    } catch (error) {
      console.error('Embedding fetch error:', error);
      return null;
    }
  }
}

module.exports = new VectorSearchService();