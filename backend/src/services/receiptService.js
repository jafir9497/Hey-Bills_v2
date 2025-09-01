/**
 * Receipt Service
 * Handles receipt database operations and business logic
 */

const { supabase } = require('../../config/supabase');
const { APIError } = require('../../utils/errorHandler');
const logger = require('../utils/logger');
const mlCategorizationService = require('./mlCategorizationService');
const advancedLineItemService = require('./advancedLineItemService');
const warrantyDetectionService = require('./warrantyDetectionService');

class ReceiptService {
  
  /**
   * Create a new receipt with enhanced ML processing
   */
  async createReceipt({
    userId,
    ocrData,
    imageUrl,
    categoryId = null,
    notes = null,
    isBusinessExpense = false,
    isReimbursable = false,
    tags = [],
    enableMLEnhancement = true
  }) {
    try {
      logger.info('Creating new receipt', {
        userId,
        merchantName: ocrData.merchantName,
        totalAmount: ocrData.totalAmount
      });

      // Enhanced ML categorization
      let finalCategoryId = categoryId;
      let mlCategoryResult = null;
      
      if (enableMLEnhancement && !categoryId) {
        try {
          mlCategoryResult = await mlCategorizationService.categorizeReceipt({
            merchantName: ocrData.merchantName,
            items: ocrData.items,
            totalAmount: ocrData.totalAmount,
            ocrText: ocrData.rawText
          });
          
          if (mlCategoryResult.confidence > 0.6) {
            const category = await this.getOrCreateCategory(userId, mlCategoryResult.category);
            finalCategoryId = category.id;
          }
        } catch (error) {
          logger.warn('ML categorization failed, using fallback:', error);
          if (ocrData.category) {
            const category = await this.getOrCreateCategory(userId, ocrData.category);
            finalCategoryId = category.id;
          }
        }
      } else if (!categoryId && ocrData.category) {
        const category = await this.getOrCreateCategory(userId, ocrData.category);
        finalCategoryId = category.id;
      }

      // Insert receipt
      const { data: receipt, error } = await supabase
        .from('receipts')
        .insert({
          user_id: userId,
          category_id: finalCategoryId,
          image_url: imageUrl,
          image_hash: ocrData.processingMetadata?.imageHash,
          merchant_name: ocrData.merchantName,
          total_amount: ocrData.totalAmount,
          currency: 'USD',
          purchase_date: ocrData.date,
          ocr_data: {
            raw_text: ocrData.rawText,
            processing_metadata: ocrData.processingMetadata
          },
          ocr_confidence: ocrData.confidence,
          processed_data: {
            merchant_name: ocrData.merchantName,
            total_amount: ocrData.totalAmount,
            date: ocrData.date,
            items: ocrData.items,
            category: ocrData.category
          },
          is_business_expense: isBusinessExpense,
          is_reimbursable: isReimbursable,
          notes: notes,
          tags: tags
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create receipt:', error);
        throw new APIError('Failed to create receipt', 500, 'DATABASE_ERROR', { error: error.message });
      }

      // Enhanced line item processing
      let enhancedItems = ocrData.items;
      let warrantyInfo = null;
      
      if (enableMLEnhancement) {
        try {
          // Advanced line item extraction
          const lineItemResult = await advancedLineItemService.extractLineItems({
            ocrText: ocrData.rawText,
            ocrBlocks: ocrData.processingMetadata?.ocrBlocks,
            merchantName: ocrData.merchantName,
            totalAmount: ocrData.totalAmount
          });
          
          if (lineItemResult.items.length > enhancedItems.length) {
            enhancedItems = lineItemResult.items;
            logger.info('Enhanced line items extracted', { count: enhancedItems.length });
          }
          
          // Warranty detection
          warrantyInfo = await warrantyDetectionService.detectWarrantyInfo({
            ocrText: ocrData.rawText,
            items: enhancedItems,
            merchantName: ocrData.merchantName,
            receiptDate: ocrData.date,
            totalAmount: ocrData.totalAmount
          });
          
        } catch (error) {
          logger.warn('Enhanced processing failed, using basic items:', error);
        }
      }
      
      // Insert receipt items
      if (enhancedItems && enhancedItems.length > 0) {
        await this.createReceiptItems(receipt.id, enhancedItems);
      }
      
      // Save warranty information
      if (warrantyInfo && warrantyInfo.warranties.length > 0) {
        await this.saveWarrantyInformation(receipt.id, userId, warrantyInfo.warranties);
      }

      logger.info('Receipt created successfully', { receiptId: receipt.id });

      // Return enhanced receipt data
      return {
        ...receipt,
        mlEnhancements: enableMLEnhancement ? {
          categoryResult: mlCategoryResult,
          lineItemCount: enhancedItems?.length || 0,
          warrantyCount: warrantyInfo?.warranties.length || 0
        } : null
      };

    } catch (error) {
      logger.error('Receipt creation failed:', error);
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Failed to create receipt', 500, 'RECEIPT_CREATION_FAILED');
    }
  }

  /**
   * Create receipt items
   */
  async createReceiptItems(receiptId, items) {
    try {
      const receiptItems = items.map((item, index) => ({
        receipt_id: receiptId,
        item_name: item.name,
        item_category: item.category,
        quantity: item.quantity || 1,
        unit_price: item.price / (item.quantity || 1),
        total_price: item.price,
        line_number: index + 1
      }));

      const { error } = await supabase
        .from('receipt_items')
        .insert(receiptItems);

      if (error) {
        logger.error('Failed to create receipt items:', error);
        // Don't fail the entire receipt creation for items
      }

    } catch (error) {
      logger.error('Receipt items creation failed:', error);
    }
  }

  /**
   * Get receipt by ID
   */
  async getReceiptById(receiptId, userId) {
    try {
      const { data: receipt, error } = await supabase
        .from('receipts')
        .select(`
          *,
          categories (
            id,
            name,
            icon,
            color
          ),
          receipt_items (
            *
          )
        `)
        .eq('id', receiptId)
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') {
        logger.error('Failed to get receipt:', error);
        throw new APIError('Failed to retrieve receipt', 500, 'DATABASE_ERROR');
      }

      return receipt;

    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Failed to retrieve receipt', 500, 'RECEIPT_RETRIEVAL_FAILED');
    }
  }

  /**
   * Update receipt OCR data
   */
  async updateReceiptOCR({ receiptId, ocrData, userId }) {
    try {
      logger.info('Updating receipt OCR data', { receiptId });

      const { data: receipt, error } = await supabase
        .from('receipts')
        .update({
          merchant_name: ocrData.merchantName,
          total_amount: ocrData.totalAmount,
          purchase_date: ocrData.date,
          ocr_data: {
            raw_text: ocrData.rawText,
            processing_metadata: ocrData.processingMetadata
          },
          ocr_confidence: ocrData.confidence,
          processed_data: {
            merchant_name: ocrData.merchantName,
            total_amount: ocrData.totalAmount,
            date: ocrData.date,
            items: ocrData.items,
            category: ocrData.category
          },
          updated_at: new Date().toISOString()
        })
        .eq('id', receiptId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        logger.error('Failed to update receipt OCR:', error);
        throw new APIError('Failed to update receipt', 500, 'DATABASE_ERROR');
      }

      // Update receipt items
      if (ocrData.items && ocrData.items.length > 0) {
        // Delete existing items
        await supabase
          .from('receipt_items')
          .delete()
          .eq('receipt_id', receiptId);

        // Create new items
        await this.createReceiptItems(receiptId, ocrData.items);
      }

      return receipt;

    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Failed to update receipt OCR', 500, 'RECEIPT_UPDATE_FAILED');
    }
  }

  /**
   * Get or create category by name
   */
  async getOrCreateCategory(userId, categoryName) {
    try {
      // First try to get existing category
      const { data: existingCategories } = await supabase
        .from('categories')
        .select('*')
        .or(`user_id.eq.${userId},is_default.eq.true`)
        .ilike('name', categoryName);

      if (existingCategories && existingCategories.length > 0) {
        return existingCategories[0];
      }

      // Create new user category
      const { data: newCategory, error } = await supabase
        .from('categories')
        .insert({
          user_id: userId,
          name: categoryName,
          description: `Auto-created category for ${categoryName}`,
          is_default: false
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create category:', error);
        // Return a default category on error
        const { data: defaultCategory } = await supabase
          .from('categories')
          .select('*')
          .eq('is_default', true)
          .eq('name', 'Other')
          .single();
        
        return defaultCategory;
      }

      return newCategory;

    } catch (error) {
      logger.error('Category creation/retrieval failed:', error);
      // Return null to skip category assignment
      return null;
    }
  }

  /**
   * Get OCR statistics for user
   */
  async getOCRStats(userId) {
    try {
      // Get basic stats
      const { data: statsData, error: statsError } = await supabase.rpc('get_user_ocr_stats', {
        p_user_id: userId
      });

      if (statsError) {
        logger.error('Failed to get OCR stats:', statsError);
        // Return basic stats from direct queries as fallback
        return await this.getBasicOCRStats(userId);
      }

      return statsData;

    } catch (error) {
      logger.error('OCR stats retrieval failed:', error);
      return await this.getBasicOCRStats(userId);
    }
  }

  /**
   * Get basic OCR statistics (fallback)
   */
  async getBasicOCRStats(userId) {
    try {
      const { data: receipts } = await supabase
        .from('receipts')
        .select('ocr_confidence, merchant_name, total_amount, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (!receipts || receipts.length === 0) {
        return {
          total_receipts: 0,
          avg_confidence: 0,
          high_confidence_count: 0,
          low_confidence_count: 0,
          reprocessed_count: 0,
          top_merchants: [],
          monthly_processing: []
        };
      }

      const totalReceipts = receipts.length;
      const avgConfidence = receipts
        .filter(r => r.ocr_confidence)
        .reduce((sum, r) => sum + r.ocr_confidence, 0) / receipts.length;
      
      const highConfidenceCount = receipts.filter(r => r.ocr_confidence >= 0.8).length;
      const lowConfidenceCount = receipts.filter(r => r.ocr_confidence < 0.6).length;

      // Get top merchants
      const merchantCounts = receipts.reduce((acc, receipt) => {
        const merchant = receipt.merchant_name || 'Unknown';
        acc[merchant] = (acc[merchant] || 0) + 1;
        return acc;
      }, {});

      const topMerchants = Object.entries(merchantCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([merchant, count]) => ({ merchant, count }));

      return {
        total_receipts: totalReceipts,
        avg_confidence: Math.round(avgConfidence * 100) / 100,
        high_confidence_count: highConfidenceCount,
        low_confidence_count: lowConfidenceCount,
        reprocessed_count: 0, // Would need additional tracking
        top_merchants: topMerchants,
        monthly_processing: [] // Would need date grouping
      };

    } catch (error) {
      logger.error('Basic OCR stats failed:', error);
      return {
        total_receipts: 0,
        avg_confidence: 0,
        high_confidence_count: 0,
        low_confidence_count: 0,
        reprocessed_count: 0,
        top_merchants: [],
        monthly_processing: []
      };
    }
  }

  /**
   * Search receipts by text
   */
  async searchReceipts({ userId, query, categoryId, dateFrom, dateTo, minAmount, maxAmount, limit = 50, offset = 0 }) {
    try {
      let queryBuilder = supabase
        .from('receipts')
        .select(`
          *,
          categories (
            id,
            name,
            icon,
            color
          )
        `)
        .eq('user_id', userId);

      // Text search in merchant name or OCR data
      if (query) {
        queryBuilder = queryBuilder.or(
          `merchant_name.ilike.%${query}%,ocr_data->>raw_text.ilike.%${query}%`
        );
      }

      // Category filter
      if (categoryId) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      // Date range filter
      if (dateFrom) {
        queryBuilder = queryBuilder.gte('purchase_date', dateFrom);
      }
      if (dateTo) {
        queryBuilder = queryBuilder.lte('purchase_date', dateTo);
      }

      // Amount range filter
      if (minAmount) {
        queryBuilder = queryBuilder.gte('total_amount', minAmount);
      }
      if (maxAmount) {
        queryBuilder = queryBuilder.lte('total_amount', maxAmount);
      }

      const { data: receipts, error } = await queryBuilder
        .order('purchase_date', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        logger.error('Receipt search failed:', error);
        throw new APIError('Failed to search receipts', 500, 'SEARCH_FAILED');
      }

      return receipts || [];

    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Receipt search failed', 500, 'SEARCH_ERROR');
    }
  }

  /**
   * Get user's receipts with pagination
   */
  async getUserReceipts({ userId, limit = 20, offset = 0, sortBy = 'purchase_date', sortOrder = 'desc' }) {
    try {
      const { data: receipts, error } = await supabase
        .from('receipts')
        .select(`
          *,
          categories (
            id,
            name,
            icon,
            color
          )
        `)
        .eq('user_id', userId)
        .order(sortBy, { ascending: sortOrder === 'asc' })
        .range(offset, offset + limit - 1);

      if (error) {
        logger.error('Failed to get user receipts:', error);
        throw new APIError('Failed to retrieve receipts', 500, 'DATABASE_ERROR');
      }

      return receipts || [];

    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Failed to retrieve user receipts', 500, 'RECEIPTS_RETRIEVAL_FAILED');
    }
  }

  /**
   * Delete receipt
   */
  async deleteReceipt(receiptId, userId) {
    try {
      const { error } = await supabase
        .from('receipts')
        .delete()
        .eq('id', receiptId)
        .eq('user_id', userId);

      if (error) {
        logger.error('Failed to delete receipt:', error);
        throw new APIError('Failed to delete receipt', 500, 'DATABASE_ERROR');
      }

      return { success: true };

    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      throw new APIError('Failed to delete receipt', 500, 'RECEIPT_DELETION_FAILED');
    }
  }

  /**
   * Save warranty information for receipt
   */
  async saveWarrantyInformation(receiptId, userId, warranties) {
    try {
      for (const warranty of warranties) {
        await warrantyDetectionService.saveWarranty(userId, receiptId, warranty);
      }
      logger.info(`Saved ${warranties.length} warranties for receipt ${receiptId}`);
    } catch (error) {
      logger.error('Failed to save warranty information:', error);
      // Don't fail receipt creation for warranty save errors
    }
  }

  /**
   * Enhanced receipt analysis with ML insights
   */
  async analyzeReceiptWithML({ receiptId, userId, forceReanalysis = false }) {
    try {
      const receipt = await this.getReceiptById(receiptId, userId);
      if (!receipt) {
        throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
      }

      // Get analysis from ML services
      const [categoryAnalysis, itemAnalysis, warrantyAnalysis] = await Promise.all([
        mlCategorizationService.categorizeReceipt({
          merchantName: receipt.merchant_name,
          items: receipt.receipt_items || [],
          totalAmount: receipt.total_amount,
          ocrText: receipt.ocr_data?.raw_text,
          existingCategory: receipt.categories?.name
        }),
        
        advancedLineItemService.extractLineItems({
          ocrText: receipt.ocr_data?.raw_text || '',
          merchantName: receipt.merchant_name,
          totalAmount: receipt.total_amount
        }),
        
        warrantyDetectionService.detectWarrantyInfo({
          ocrText: receipt.ocr_data?.raw_text || '',
          items: receipt.receipt_items || [],
          merchantName: receipt.merchant_name,
          receiptDate: receipt.purchase_date,
          totalAmount: receipt.total_amount
        })
      ]);

      return {
        receiptId,
        analysis: {
          category: categoryAnalysis,
          lineItems: itemAnalysis,
          warranties: warrantyAnalysis
        },
        recommendations: this.generateReceiptRecommendations({
          categoryAnalysis,
          itemAnalysis,
          warrantyAnalysis,
          receipt
        }),
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      logger.error('ML receipt analysis failed:', error);
      throw new APIError('Failed to analyze receipt', 500, 'RECEIPT_ANALYSIS_FAILED', {
        error: error.message
      });
    }
  }

  /**
   * Generate recommendations based on analysis
   */
  generateReceiptRecommendations({ categoryAnalysis, itemAnalysis, warrantyAnalysis, receipt }) {
    const recommendations = [];

    // Category recommendations
    if (categoryAnalysis.confidence < 0.7) {
      recommendations.push({
        type: 'category',
        priority: 'medium',
        message: 'Category classification has low confidence - consider manual review',
        action: 'review_category'
      });
    }

    // Line item recommendations
    if (itemAnalysis.metadata.extractionConfidence < 0.6) {
      recommendations.push({
        type: 'line_items',
        priority: 'low',
        message: 'Line item extraction has low confidence - verify item details',
        action: 'review_items'
      });
    }

    // Warranty recommendations
    if (warrantyAnalysis.warranties.length > 0) {
      const highValueWarranties = warrantyAnalysis.warranties.filter(w => 
        receipt.total_amount > 100 && w.confidence > 0.7
      );
      
      if (highValueWarranties.length > 0) {
        recommendations.push({
          type: 'warranty',
          priority: 'high',
          message: `Found ${highValueWarranties.length} potential warranties for high-value items`,
          action: 'review_warranties'
        });
      }
    }

    // Expense recommendations
    if (receipt.total_amount > 500 && !receipt.is_business_expense) {
      recommendations.push({
        type: 'expense',
        priority: 'medium',
        message: 'High-value purchase - consider if this is a business expense',
        action: 'review_business_expense'
      });
    }

    return recommendations;
  }

  /**
   * Get receipt insights and analytics
   */
  async getReceiptInsights({ userId, dateFrom, dateTo, categoryId }) {
    try {
      let query = supabase
        .from('receipts')
        .select(`
          id,
          merchant_name,
          total_amount,
          purchase_date,
          category_id,
          categories (name),
          receipt_items (*)
        `)
        .eq('user_id', userId);

      if (dateFrom) query = query.gte('purchase_date', dateFrom);
      if (dateTo) query = query.lte('purchase_date', dateTo);
      if (categoryId) query = query.eq('category_id', categoryId);

      const { data: receipts, error } = await query.order('purchase_date', { ascending: false });

      if (error) {
        throw new APIError('Failed to fetch receipts for insights', 500, 'INSIGHTS_FETCH_FAILED');
      }

      return this.generateInsights(receipts);

    } catch (error) {
      logger.error('Receipt insights generation failed:', error);
      throw new APIError('Failed to generate insights', 500, 'INSIGHTS_GENERATION_FAILED');
    }
  }

  /**
   * Generate insights from receipt data
   */
  generateInsights(receipts) {
    const insights = {
      summary: {
        totalReceipts: receipts.length,
        totalAmount: receipts.reduce((sum, r) => sum + r.total_amount, 0),
        averageAmount: receipts.length > 0 ? receipts.reduce((sum, r) => sum + r.total_amount, 0) / receipts.length : 0,
        dateRange: {
          from: receipts.length > 0 ? receipts[receipts.length - 1].purchase_date : null,
          to: receipts.length > 0 ? receipts[0].purchase_date : null
        }
      },
      
      categoryBreakdown: this.calculateCategoryBreakdown(receipts),
      merchantFrequency: this.calculateMerchantFrequency(receipts),
      spendingTrends: this.calculateSpendingTrends(receipts),
      topExpenses: this.getTopExpenses(receipts),
      
      mlInsights: {
        categorizationAccuracy: this.calculateCategorizationAccuracy(receipts),
        itemExtractionStats: this.calculateItemExtractionStats(receipts),
        warrantyOpportunities: this.identifyWarrantyOpportunities(receipts)
      }
    };

    return insights;
  }

  /**
   * Calculate category breakdown
   */
  calculateCategoryBreakdown(receipts) {
    const breakdown = {};
    
    for (const receipt of receipts) {
      const category = receipt.categories?.name || 'Uncategorized';
      if (!breakdown[category]) {
        breakdown[category] = { count: 0, amount: 0 };
      }
      breakdown[category].count += 1;
      breakdown[category].amount += receipt.total_amount;
    }

    return Object.entries(breakdown)
      .map(([category, data]) => ({ category, ...data }))
      .sort((a, b) => b.amount - a.amount);
  }

  /**
   * Calculate merchant frequency
   */
  calculateMerchantFrequency(receipts) {
    const frequency = {};
    
    for (const receipt of receipts) {
      const merchant = receipt.merchant_name || 'Unknown';
      if (!frequency[merchant]) {
        frequency[merchant] = { count: 0, amount: 0 };
      }
      frequency[merchant].count += 1;
      frequency[merchant].amount += receipt.total_amount;
    }

    return Object.entries(frequency)
      .map(([merchant, data]) => ({ merchant, ...data }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10); // Top 10
  }

  /**
   * Calculate spending trends
   */
  calculateSpendingTrends(receipts) {
    const monthly = {};
    
    for (const receipt of receipts) {
      const month = receipt.purchase_date.substring(0, 7); // YYYY-MM
      if (!monthly[month]) {
        monthly[month] = { count: 0, amount: 0 };
      }
      monthly[month].count += 1;
      monthly[month].amount += receipt.total_amount;
    }

    return Object.entries(monthly)
      .map(([month, data]) => ({ month, ...data }))
      .sort((a, b) => a.month.localeCompare(b.month));
  }

  /**
   * Get top expenses
   */
  getTopExpenses(receipts) {
    return receipts
      .sort((a, b) => b.total_amount - a.total_amount)
      .slice(0, 10)
      .map(receipt => ({
        id: receipt.id,
        merchant: receipt.merchant_name,
        amount: receipt.total_amount,
        date: receipt.purchase_date,
        category: receipt.categories?.name
      }));
  }

  /**
   * Calculate categorization accuracy (placeholder)
   */
  calculateCategorizationAccuracy(receipts) {
    // This would compare ML predictions with user corrections
    return {
      totalCategorized: receipts.filter(r => r.category_id).length,
      mlCategorized: receipts.length, // Placeholder
      accuracyRate: 0.85 // Placeholder
    };
  }

  /**
   * Calculate item extraction statistics
   */
  calculateItemExtractionStats(receipts) {
    const receiptsWithItems = receipts.filter(r => r.receipt_items && r.receipt_items.length > 0);
    
    return {
      receiptsWithItems: receiptsWithItems.length,
      totalItems: receiptsWithItems.reduce((sum, r) => sum + r.receipt_items.length, 0),
      averageItemsPerReceipt: receiptsWithItems.length > 0 ? 
        receiptsWithItems.reduce((sum, r) => sum + r.receipt_items.length, 0) / receiptsWithItems.length : 0
    };
  }

  /**
   * Identify warranty opportunities
   */
  identifyWarrantyOpportunities(receipts) {
    const highValueReceipts = receipts.filter(r => r.total_amount > 100);
    const electronicsKeywords = ['electronics', 'computer', 'phone', 'appliance'];
    
    const warrantyOpportunities = highValueReceipts.filter(receipt => {
      const merchant = receipt.merchant_name?.toLowerCase() || '';
      return electronicsKeywords.some(keyword => merchant.includes(keyword));
    });

    return {
      totalOpportunities: warrantyOpportunities.length,
      potentialValue: warrantyOpportunities.reduce((sum, r) => sum + r.total_amount, 0)
    };
  }
}

// Export singleton instance
const receiptService = new ReceiptService();

module.exports = receiptService;