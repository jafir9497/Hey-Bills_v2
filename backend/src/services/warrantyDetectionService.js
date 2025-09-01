/**
 * Warranty Detection Service
 * Detects warranty information from receipt text and patterns
 */

const natural = require('natural');
const compromise = require('compromise');
const { parse: parseDate, parseString } = require('chrono-node');
const { addYears, addMonths, addDays, format } = require('date-fns');
const fuzzball = require('fuzzball');
const logger = require('../utils/logger');
const { APIError } = require('../utils/errorHandler');
const { supabase } = require('../../config/supabase');

class WarrantyDetectionService {
  constructor() {
    this.warrantyPatterns = new Map();
    this.productCategories = new Map();
    this.warrantyTerms = new Map();
    this.initializePatterns();
  }

  /**
   * Detect warranty information from receipt data
   */
  async detectWarrantyInfo({
    ocrText,
    items = [],
    merchantName = '',
    receiptDate,
    totalAmount = 0
  }) {
    try {
      logger.info('Starting warranty detection', {
        itemCount: items.length,
        merchantName,
        textLength: ocrText.length
      });

      // Multiple detection approaches
      const detectionResults = await Promise.all([
        this.detectFromText(ocrText),
        this.detectFromItems(items, merchantName),
        this.detectFromMerchant(merchantName, totalAmount),
        this.detectFromPatterns(ocrText),
        this.detectFromProductDatabase(items)
      ]);

      // Combine and process results
      const warrantyInfo = this.combineDetectionResults(detectionResults, receiptDate);
      
      // Validate and enhance warranty data
      const validatedWarranties = this.validateWarrantyData(warrantyInfo, items);
      
      // Calculate confidence scores
      const enhancedWarranties = this.calculateConfidenceScores(validatedWarranties, ocrText);

      return {
        warranties: enhancedWarranties,
        metadata: {
          detectionMethods: detectionResults.length,
          totalWarrantiesFound: enhancedWarranties.length,
          averageConfidence: this.calculateAverageConfidence(enhancedWarranties),
          processingTime: Date.now()
        },
        recommendations: this.generateWarrantyRecommendations(enhancedWarranties, items)
      };

    } catch (error) {
      logger.error('Warranty detection failed:', error);
      throw new APIError('Failed to detect warranty information', 500, 'WARRANTY_DETECTION_FAILED', {
        error: error.message
      });
    }
  }

  /**
   * Detect warranty from raw OCR text
   */
  async detectFromText(ocrText) {
    const warranties = [];
    
    // Warranty term patterns
    const warrantyPatterns = [
      // Explicit warranty statements
      /warranty[:\s]*(\d+)\s*(year|month|day)s?/gi,
      /guaranteed[:\s]*for[:\s]*(\d+)\s*(year|month|day)s?/gi,
      /(\d+)[:\s-]*(year|month|day)s?\s*warranty/gi,
      
      // Extended warranty offers
      /extended[:\s]*warranty[:\s]*available/gi,
      /protection[:\s]*plan[:\s]*(\d+)\s*(year|month)/gi,
      
      // Return/exchange periods (limited warranties)
      /return[:\s]*within[:\s]*(\d+)\s*(day|week|month)s?/gi,
      /exchange[:\s]*period[:\s]*(\d+)\s*(day|week|month)s?/gi,
      
      // Manufacturer warranty
      /manufacturer[:\s]*warranty/gi,
      /limited[:\s]*warranty/gi
    ];

    for (const pattern of warrantyPatterns) {
      let match;
      while ((match = pattern.exec(ocrText)) !== null) {
        const warranty = this.parseWarrantyFromMatch(match, ocrText);
        if (warranty) {
          warranties.push({
            ...warranty,
            source: 'text_pattern',
            confidence: 0.7
          });
        }
      }
    }

    return { approach: 'text', warranties };
  }

  /**
   * Detect warranty from line items
   */
  async detectFromItems(items, merchantName) {
    const warranties = [];

    for (const item of items) {
      // Check if item category typically has warranties
      const category = await this.categorizeProduct(item.name, merchantName);
      const defaultWarranty = this.getDefaultWarrantyForCategory(category);

      if (defaultWarranty) {
        warranties.push({
          itemName: item.name,
          category: category,
          warrantyPeriod: defaultWarranty.period,
          warrantyType: defaultWarranty.type,
          coverage: defaultWarranty.coverage,
          source: 'item_category',
          confidence: 0.6
        });
      }

      // Check item name for warranty keywords
      const itemWarranty = this.extractWarrantyFromItemName(item.name);
      if (itemWarranty) {
        warranties.push({
          ...itemWarranty,
          itemName: item.name,
          source: 'item_name',
          confidence: 0.8
        });
      }
    }

    return { approach: 'items', warranties };
  }

  /**
   * Detect warranty based on merchant
   */
  async detectFromMerchant(merchantName, totalAmount) {
    const warranties = [];
    
    if (!merchantName) {
      return { approach: 'merchant', warranties };
    }

    const merchant = merchantName.toLowerCase();
    
    // Electronics stores often provide warranties
    if (this.isElectronicsStore(merchant)) {
      warranties.push({
        merchantName: merchantName,
        warrantyType: 'manufacturer',
        warrantyPeriod: { years: 1 },
        coverage: 'defects and malfunctions',
        source: 'merchant_category',
        confidence: 0.5
      });
    }

    // High-value purchases often have extended warranty offers
    if (totalAmount > 500) {
      warranties.push({
        merchantName: merchantName,
        warrantyType: 'extended_available',
        notes: 'Extended warranty may be available for high-value purchase',
        source: 'purchase_amount',
        confidence: 0.4
      });
    }

    // Specific merchant warranties
    const merchantWarranties = this.getMerchantSpecificWarranties(merchant);
    warranties.push(...merchantWarranties);

    return { approach: 'merchant', warranties };
  }

  /**
   * Detect using advanced NLP patterns
   */
  async detectFromPatterns(ocrText) {
    const warranties = [];

    try {
      const doc = compromise(ocrText);
      
      // Extract warranty-related sentences
      const warrantyPhrases = doc.match('warranty|guarantee|return|exchange|protection|coverage');
      
      for (const phrase of warrantyPhrases.json()) {
        const warranty = this.analyzeWarrantyPhrase(phrase.text);
        if (warranty) {
          warranties.push({
            ...warranty,
            source: 'nlp_pattern',
            confidence: 0.6
          });
        }
      }

      // Look for serial numbers (often indicate warranty-eligible products)
      const serialNumbers = this.extractSerialNumbers(ocrText);
      for (const serial of serialNumbers) {
        warranties.push({
          serialNumber: serial,
          warrantyType: 'manufacturer',
          notes: 'Product with serial number likely has manufacturer warranty',
          source: 'serial_number',
          confidence: 0.5
        });
      }

    } catch (error) {
      logger.debug('NLP pattern detection failed:', error);
    }

    return { approach: 'patterns', warranties };
  }

  /**
   * Detect from product database lookup
   */
  async detectFromProductDatabase(items) {
    const warranties = [];

    for (const item of items) {
      // Look up product in database (simulated)
      const productInfo = await this.lookupProduct(item.name);
      
      if (productInfo && productInfo.warranty) {
        warranties.push({
          itemName: item.name,
          productModel: productInfo.model,
          warrantyPeriod: productInfo.warranty.period,
          warrantyType: productInfo.warranty.type,
          coverage: productInfo.warranty.coverage,
          manufacturer: productInfo.manufacturer,
          source: 'product_database',
          confidence: 0.9
        });
      }
    }

    return { approach: 'database', warranties };
  }

  /**
   * Parse warranty information from regex match
   */
  parseWarrantyFromMatch(match, fullText) {
    try {
      const warranty = {};
      
      // Extract period and unit
      if (match[1] && match[2]) {
        const period = parseInt(match[1]);
        const unit = match[2].toLowerCase();
        
        warranty.warrantyPeriod = { [unit + 's']: period };
      }

      // Determine warranty type from context
      const context = fullText.substring(
        Math.max(0, match.index - 50),
        Math.min(fullText.length, match.index + match[0].length + 50)
      );

      warranty.warrantyType = this.determineWarrantyType(context);
      warranty.originalText = match[0];

      return warranty;

    } catch (error) {
      logger.debug('Warranty parsing failed:', { match, error: error.message });
      return null;
    }
  }

  /**
   * Categorize product for warranty detection
   */
  async categorizeProduct(productName, merchantName) {
    const product = productName.toLowerCase();
    const merchant = merchantName.toLowerCase();

    // Electronics categories
    if (/phone|tablet|computer|laptop|tv|camera|headphone|speaker/.test(product)) {
      return 'electronics';
    }

    // Appliances
    if (/refrigerator|washer|dryer|dishwasher|microwave|oven/.test(product)) {
      return 'appliances';
    }

    // Automotive
    if (/tire|battery|oil|part|filter/.test(product) || /auto|car|mechanic/.test(merchant)) {
      return 'automotive';
    }

    // Tools
    if (/tool|drill|saw|hammer|wrench/.test(product)) {
      return 'tools';
    }

    // Clothing/Shoes
    if (/shirt|pants|dress|shoe|boot|jacket/.test(product) || /clothing|apparel/.test(merchant)) {
      return 'clothing';
    }

    return 'general';
  }

  /**
   * Get default warranty for product category
   */
  getDefaultWarrantyForCategory(category) {
    const defaults = {
      'electronics': {
        period: { years: 1 },
        type: 'manufacturer',
        coverage: 'defects in materials and workmanship'
      },
      'appliances': {
        period: { years: 1 },
        type: 'manufacturer',
        coverage: 'parts and labor for defects'
      },
      'automotive': {
        period: { months: 6 },
        type: 'parts',
        coverage: 'defects and premature failure'
      },
      'tools': {
        period: { years: 1 },
        type: 'manufacturer',
        coverage: 'defects in materials and workmanship'
      },
      'clothing': {
        period: { days: 30 },
        type: 'return_policy',
        coverage: 'defects and sizing issues'
      }
    };

    return defaults[category] || null;
  }

  /**
   * Extract warranty info from item name
   */
  extractWarrantyFromItemName(itemName) {
    const patterns = [
      /(\d+)\s*yr\s*warranty/i,
      /(\d+)\s*year\s*warranty/i,
      /warranty\s*(\d+)\s*yr/i,
      /extended\s*warranty/i
    ];

    for (const pattern of patterns) {
      const match = pattern.exec(itemName);
      if (match) {
        return {
          warrantyPeriod: match[1] ? { years: parseInt(match[1]) } : { years: 1 },
          warrantyType: 'extended',
          originalText: match[0]
        };
      }
    }

    return null;
  }

  /**
   * Check if merchant is electronics store
   */
  isElectronicsStore(merchant) {
    const electronicsKeywords = [
      'best buy', 'circuit city', 'radio shack', 'fry', 'micro center',
      'apple store', 'microsoft store', 'electronics', 'computer'
    ];
    
    return electronicsKeywords.some(keyword => merchant.includes(keyword));
  }

  /**
   * Get merchant-specific warranty information
   */
  getMerchantSpecificWarranties(merchant) {
    const merchantWarranties = {
      'best buy': [{
        warrantyType: 'geek_squad',
        notes: 'Geek Squad protection plans available',
        confidence: 0.7
      }],
      'home depot': [{
        warrantyType: 'return_policy',
        warrantyPeriod: { days: 90 },
        notes: '90-day return policy on most items',
        confidence: 0.8
      }],
      'costco': [{
        warrantyType: 'satisfaction_guarantee',
        notes: 'Satisfaction guarantee and extended return periods',
        confidence: 0.8
      }]
    };

    const found = Object.keys(merchantWarranties).find(key => merchant.includes(key));
    return found ? merchantWarranties[found] : [];
  }

  /**
   * Analyze warranty phrase using NLP
   */
  analyzeWarrantyPhrase(phraseText) {
    const doc = compromise(phraseText);
    
    // Extract numbers that might be warranty periods
    const numbers = doc.match('#Value').out('array');
    const timeWords = doc.match('(year|month|day|week)').out('array');

    if (numbers.length > 0 && timeWords.length > 0) {
      const period = parseInt(numbers[0]);
      const unit = timeWords[0].toLowerCase();
      
      return {
        warrantyPeriod: { [unit + 's']: period },
        originalText: phraseText,
        warrantyType: this.determineWarrantyType(phraseText)
      };
    }

    return null;
  }

  /**
   * Extract serial numbers from text
   */
  extractSerialNumbers(text) {
    const patterns = [
      /serial[:\s]*([A-Z0-9]{8,})/gi,
      /s\/n[:\s]*([A-Z0-9]{8,})/gi,
      /model[:\s]*([A-Z0-9]{6,})/gi
    ];

    const serials = [];
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(text)) !== null) {
        serials.push(match[1]);
      }
    }

    return [...new Set(serials)]; // Remove duplicates
  }

  /**
   * Lookup product information (simulated database lookup)
   */
  async lookupProduct(productName) {
    // In a real implementation, this would query a product database
    // For now, simulate some common products
    const productDatabase = {
      'iphone': {
        model: 'iPhone',
        manufacturer: 'Apple',
        warranty: {
          period: { years: 1 },
          type: 'limited',
          coverage: 'manufacturing defects'
        }
      },
      'samsung': {
        model: 'Samsung Device',
        manufacturer: 'Samsung',
        warranty: {
          period: { years: 1 },
          type: 'manufacturer',
          coverage: 'parts and labor'
        }
      }
    };

    const product = productName.toLowerCase();
    const found = Object.keys(productDatabase).find(key => product.includes(key));
    return found ? productDatabase[found] : null;
  }

  /**
   * Determine warranty type from context
   */
  determineWarrantyType(context) {
    const contextLower = context.toLowerCase();
    
    if (contextLower.includes('manufacturer')) return 'manufacturer';
    if (contextLower.includes('extended')) return 'extended';
    if (contextLower.includes('limited')) return 'limited';
    if (contextLower.includes('return')) return 'return_policy';
    if (contextLower.includes('exchange')) return 'exchange_policy';
    if (contextLower.includes('protection')) return 'protection_plan';
    
    return 'general';
  }

  /**
   * Combine detection results from all approaches
   */
  combineDetectionResults(detectionResults, receiptDate) {
    const allWarranties = [];
    
    for (const result of detectionResults) {
      for (const warranty of result.warranties) {
        warranty.detectionMethod = result.approach;
        
        // Calculate expiration date if warranty period is provided
        if (warranty.warrantyPeriod && receiptDate) {
          warranty.expirationDate = this.calculateExpirationDate(receiptDate, warranty.warrantyPeriod);
        }
        
        allWarranties.push(warranty);
      }
    }

    // Deduplicate similar warranties
    return this.deduplicateWarranties(allWarranties);
  }

  /**
   * Calculate warranty expiration date
   */
  calculateExpirationDate(startDate, period) {
    try {
      let date = new Date(startDate);
      
      if (period.years) {
        date = addYears(date, period.years);
      }
      if (period.months) {
        date = addMonths(date, period.months);
      }
      if (period.days) {
        date = addDays(date, period.days);
      }

      return date;
    } catch (error) {
      logger.debug('Date calculation failed:', error);
      return null;
    }
  }

  /**
   * Deduplicate similar warranties
   */
  deduplicateWarranties(warranties) {
    const deduplicated = [];
    
    for (const warranty of warranties) {
      const similar = deduplicated.find(existing => 
        this.areWarrantiesSimilar(warranty, existing)
      );
      
      if (similar) {
        // Merge with higher confidence warranty
        if (warranty.confidence > similar.confidence) {
          const index = deduplicated.indexOf(similar);
          deduplicated[index] = { ...similar, ...warranty };
        }
      } else {
        deduplicated.push(warranty);
      }
    }

    return deduplicated;
  }

  /**
   * Check if two warranties are similar
   */
  areWarrantiesSimilar(warranty1, warranty2) {
    // Same item
    if (warranty1.itemName && warranty2.itemName) {
      const similarity = fuzzball.ratio(warranty1.itemName, warranty2.itemName);
      if (similarity > 80) return true;
    }

    // Same warranty type and similar period
    if (warranty1.warrantyType === warranty2.warrantyType) {
      if (warranty1.warrantyPeriod && warranty2.warrantyPeriod) {
        return JSON.stringify(warranty1.warrantyPeriod) === JSON.stringify(warranty2.warrantyPeriod);
      }
      return true;
    }

    return false;
  }

  /**
   * Validate warranty data
   */
  validateWarrantyData(warranties, items) {
    return warranties.filter(warranty => {
      // Must have some warranty information
      if (!warranty.warrantyType && !warranty.warrantyPeriod) {
        return false;
      }

      // Reasonable warranty periods
      if (warranty.warrantyPeriod) {
        const period = warranty.warrantyPeriod;
        if (period.years && period.years > 10) return false;
        if (period.months && period.months > 120) return false;
        if (period.days && period.days > 3650) return false;
      }

      return true;
    });
  }

  /**
   * Calculate confidence scores
   */
  calculateConfidenceScores(warranties, ocrText) {
    return warranties.map(warranty => {
      let confidence = warranty.confidence || 0.5;
      
      // Boost confidence for explicit warranty text
      if (warranty.originalText && ocrText.includes(warranty.originalText)) {
        confidence += 0.2;
      }

      // Boost for specific warranty periods
      if (warranty.warrantyPeriod && Object.keys(warranty.warrantyPeriod).length > 0) {
        confidence += 0.1;
      }

      // Boost for known warranty types
      const knownTypes = ['manufacturer', 'extended', 'limited'];
      if (knownTypes.includes(warranty.warrantyType)) {
        confidence += 0.1;
      }

      return {
        ...warranty,
        confidence: Math.min(confidence, 1.0)
      };
    });
  }

  /**
   * Calculate average confidence
   */
  calculateAverageConfidence(warranties) {
    if (warranties.length === 0) return 0;
    
    const totalConfidence = warranties.reduce((sum, warranty) => sum + warranty.confidence, 0);
    return totalConfidence / warranties.length;
  }

  /**
   * Generate warranty recommendations
   */
  generateWarrantyRecommendations(warranties, items) {
    const recommendations = [];
    
    if (warranties.length === 0) {
      recommendations.push('No warranties detected - consider checking product documentation');
    }

    // Check for items without warranties
    const itemsWithoutWarranty = items.filter(item => 
      !warranties.some(warranty => warranty.itemName === item.name)
    );

    if (itemsWithoutWarranty.length > 0) {
      recommendations.push(`${itemsWithoutWarranty.length} items may not have warranty coverage`);
    }

    // Check for expiring warranties
    const expiringWarranties = warranties.filter(warranty => {
      if (warranty.expirationDate) {
        const daysUntilExpiry = (new Date(warranty.expirationDate) - new Date()) / (1000 * 60 * 60 * 24);
        return daysUntilExpiry > 0 && daysUntilExpiry < 90; // Within 90 days
      }
      return false;
    });

    if (expiringWarranties.length > 0) {
      recommendations.push(`${expiringWarranties.length} warranties expiring within 90 days`);
    }

    return recommendations;
  }

  /**
   * Save warranty to database
   */
  async saveWarranty(userId, receiptId, warrantyData) {
    try {
      const { data: warranty, error } = await supabase
        .from('warranties')
        .insert({
          user_id: userId,
          receipt_id: receiptId,
          product_name: warrantyData.itemName,
          manufacturer: warrantyData.manufacturer,
          model_number: warrantyData.productModel,
          serial_number: warrantyData.serialNumber,
          warranty_type: warrantyData.warrantyType,
          coverage_details: warrantyData.coverage,
          start_date: warrantyData.startDate || new Date(),
          expiration_date: warrantyData.expirationDate,
          warranty_document: warrantyData.originalText,
          detection_confidence: warrantyData.confidence,
          detection_method: warrantyData.detectionMethod,
          status: 'active'
        })
        .select()
        .single();

      if (error) {
        throw new APIError('Failed to save warranty', 500, 'WARRANTY_SAVE_FAILED', { error: error.message });
      }

      return warranty;

    } catch (error) {
      logger.error('Warranty save failed:', error);
      throw error;
    }
  }

  /**
   * Initialize patterns and data
   */
  initializePatterns() {
    // Initialize warranty terms mapping
    this.warrantyTerms.set('manufacturer', ['manufacturer warranty', 'factory warranty', 'original warranty']);
    this.warrantyTerms.set('extended', ['extended warranty', 'protection plan', 'service plan']);
    this.warrantyTerms.set('limited', ['limited warranty', 'limited guarantee']);
    this.warrantyTerms.set('return_policy', ['return policy', 'satisfaction guarantee']);

    logger.info('Warranty detection service initialized');
  }
}

// Export singleton instance
const warrantyDetectionService = new WarrantyDetectionService();
module.exports = warrantyDetectionService;