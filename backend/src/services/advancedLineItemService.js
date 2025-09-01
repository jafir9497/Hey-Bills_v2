/**
 * Advanced Line Item Extraction Service
 * Sophisticated parsing and extraction of receipt line items
 */

const natural = require('natural');
const compromise = require('compromise');
const { parse: parseDate } = require('chrono-node');
const fuzzball = require('fuzzball');
const logger = require('../utils/logger');
const { APIError } = require('../utils/errorHandler');

class AdvancedLineItemService {
  constructor() {
    this.categoryPatterns = new Map();
    this.productDatabase = new Map();
    this.unitPatterns = new Map();
    this.discountPatterns = [];
    this.taxPatterns = [];
    this.initializePatterns();
  }

  /**
   * Extract and parse line items from OCR text
   */
  async extractLineItems({
    ocrText,
    ocrBlocks = [],
    merchantName = '',
    totalAmount = 0,
    confidence = 0.5
  }) {
    try {
      logger.info('Starting advanced line item extraction', {
        textLength: ocrText.length,
        blocksCount: ocrBlocks.length,
        merchantName
      });

      // Multiple extraction approaches
      const approaches = await Promise.all([
        this.extractFromTextLines(ocrText),
        this.extractFromBlocks(ocrBlocks),
        this.extractFromPatterns(ocrText),
        this.extractFromNLP(ocrText),
        this.extractFromTables(ocrBlocks)
      ]);

      // Combine and deduplicate results
      const combinedItems = this.combineExtractionResults(approaches);
      
      // Enhance items with additional data
      const enhancedItems = await this.enhanceLineItems(combinedItems, merchantName);
      
      // Validate and clean items
      const validatedItems = this.validateLineItems(enhancedItems, totalAmount);
      
      // Calculate extraction confidence
      const extractionConfidence = this.calculateExtractionConfidence(validatedItems, ocrText, confidence);

      return {
        items: validatedItems,
        metadata: {
          extractionConfidence,
          totalItemsFound: validatedItems.length,
          totalValue: validatedItems.reduce((sum, item) => sum + (item.totalPrice || 0), 0),
          extractionMethods: approaches.length,
          processingTime: Date.now()
        },
        suggestions: this.generateSuggestions(validatedItems, totalAmount)
      };

    } catch (error) {
      logger.error('Line item extraction failed:', error);
      throw new APIError('Failed to extract line items', 500, 'LINE_ITEM_EXTRACTION_FAILED', {
        error: error.message
      });
    }
  }

  /**
   * Extract items from text lines
   */
  async extractFromTextLines(ocrText) {
    const lines = ocrText.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    const items = [];

    for (const line of lines) {
      // Skip header/footer lines
      if (this.isHeaderOrFooterLine(line)) continue;

      // Try different line item patterns
      const patterns = [
        // Product name + price at end
        /^(.+?)\s+\$?(\d+\.?\d*)$/,
        // Quantity + product + price
        /^(\d+)\s+(.+?)\s+\$?(\d+\.?\d*)$/,
        // Product + @ price + total
        /^(.+?)\s+@\s*\$?(\d+\.?\d*)\s+\$?(\d+\.?\d*)$/,
        // Complex format with quantity and unit price
        /^(.+?)\s+(\d+)\s*x\s*\$?(\d+\.?\d*)\s+\$?(\d+\.?\d*)$/
      ];

      for (const pattern of patterns) {
        const match = pattern.exec(line);
        if (match) {
          const item = this.parseLineItem(match, pattern, line);
          if (item) {
            items.push(item);
            break; // Found match, move to next line
          }
        }
      }
    }

    return { approach: 'textLines', items };
  }

  /**
   * Extract items from OCR blocks
   */
  async extractFromBlocks(ocrBlocks) {
    if (!ocrBlocks || ocrBlocks.length === 0) {
      return { approach: 'blocks', items: [] };
    }

    const items = [];
    
    // Group blocks by proximity (same line items)
    const groupedBlocks = this.groupBlocksByProximity(ocrBlocks);

    for (const group of groupedBlocks) {
      const item = this.extractItemFromBlockGroup(group);
      if (item) {
        items.push(item);
      }
    }

    return { approach: 'blocks', items };
  }

  /**
   * Extract using advanced patterns
   */
  async extractFromPatterns(ocrText) {
    const items = [];
    
    // Define advanced patterns for different receipt formats
    const advancedPatterns = [
      // Multi-line items with continuation
      {
        pattern: /^(.+?)\n\s*(\d+\.?\d*)\s*@\s*\$?(\d+\.?\d*)\s*=?\s*\$?(\d+\.?\d*)$/gm,
        parser: (match) => ({
          name: match[1].trim(),
          quantity: parseFloat(match[2]),
          unitPrice: parseFloat(match[3]),
          totalPrice: parseFloat(match[4])
        })
      },
      // Items with tax indicators
      {
        pattern: /^(.+?)\s+([T]?)\s+\$?(\d+\.?\d*)$/gm,
        parser: (match) => ({
          name: match[1].trim(),
          taxable: match[2] === 'T',
          totalPrice: parseFloat(match[3])
        })
      },
      // Items with department codes
      {
        pattern: /^(\d{3,})\s+(.+?)\s+\$?(\d+\.?\d*)$/gm,
        parser: (match) => ({
          departmentCode: match[1],
          name: match[2].trim(),
          totalPrice: parseFloat(match[3])
        })
      }
    ];

    for (const patternConfig of advancedPatterns) {
      let match;
      while ((match = patternConfig.pattern.exec(ocrText)) !== null) {
        try {
          const item = patternConfig.parser(match);
          if (this.isValidItem(item)) {
            items.push({
              ...item,
              source: 'patterns',
              confidence: 0.7
            });
          }
        } catch (error) {
          logger.debug('Pattern parsing failed:', error);
        }
      }
    }

    return { approach: 'patterns', items };
  }

  /**
   * Extract using NLP
   */
  async extractFromNLP(ocrText) {
    const items = [];

    try {
      const doc = compromise(ocrText);
      
      // Extract potential product names
      const nouns = doc.nouns().out('array');
      const numbers = doc.match('#Value').out('array');
      const money = doc.match('#Money').out('array');

      // Find product-price pairs
      const lines = ocrText.split('\n');
      
      for (const line of lines) {
        const lineDoc = compromise(line);
        const lineNouns = lineDoc.nouns().out('array');
        const lineMoney = lineDoc.match('#Money').out('array');

        if (lineNouns.length > 0 && lineMoney.length > 0) {
          const productName = lineNouns.join(' ');
          const price = this.extractPriceFromText(lineMoney[0]);

          if (productName && price > 0) {
            items.push({
              name: productName,
              totalPrice: price,
              confidence: 0.6,
              source: 'nlp'
            });
          }
        }
      }

    } catch (error) {
      logger.debug('NLP extraction failed:', error);
    }

    return { approach: 'nlp', items };
  }

  /**
   * Extract from table structures
   */
  async extractFromTables(ocrBlocks) {
    if (!ocrBlocks || !Array.isArray(ocrBlocks)) {
      return { approach: 'tables', items: [] };
    }

    // Look for table-like structures in blocks
    const tables = ocrBlocks.filter(block => 
      block.BlockType === 'TABLE' || 
      (block.blocks && Array.isArray(block.blocks))
    );

    const items = [];

    for (const table of tables) {
      const tableItems = this.extractItemsFromTable(table);
      items.push(...tableItems);
    }

    return { approach: 'tables', items };
  }

  /**
   * Parse individual line item
   */
  parseLineItem(match, pattern, originalLine) {
    try {
      const item = {
        originalLine,
        confidence: 0.8,
        source: 'textLines'
      };

      // Different parsing based on pattern structure
      if (match.length === 3) {
        // Simple: product + price
        item.name = this.cleanProductName(match[1]);
        item.totalPrice = parseFloat(match[2]);
        item.quantity = 1;
      } else if (match.length === 4) {
        // Quantity + product + price OR product + @ price + total
        if (pattern.source.includes('@')) {
          item.name = this.cleanProductName(match[1]);
          item.unitPrice = parseFloat(match[2]);
          item.totalPrice = parseFloat(match[3]);
          item.quantity = item.totalPrice / item.unitPrice;
        } else {
          item.quantity = parseInt(match[1]);
          item.name = this.cleanProductName(match[2]);
          item.totalPrice = parseFloat(match[3]);
          item.unitPrice = item.totalPrice / item.quantity;
        }
      } else if (match.length === 5) {
        // Complex: product + quantity + unit price + total
        item.name = this.cleanProductName(match[1]);
        item.quantity = parseInt(match[2]);
        item.unitPrice = parseFloat(match[3]);
        item.totalPrice = parseFloat(match[4]);
      }

      // Validate required fields
      if (!item.name || !item.totalPrice || item.totalPrice <= 0) {
        return null;
      }

      // Set defaults
      if (!item.quantity) item.quantity = 1;
      if (!item.unitPrice) item.unitPrice = item.totalPrice / item.quantity;

      return item;

    } catch (error) {
      logger.debug('Line item parsing failed:', { match, error: error.message });
      return null;
    }
  }

  /**
   * Group OCR blocks by spatial proximity
   */
  groupBlocksByProximity(blocks) {
    // This is a simplified grouping - in reality would use spatial coordinates
    const groups = [];
    let currentGroup = [];

    for (const block of blocks) {
      if (block.BlockType === 'LINE' || block.text) {
        currentGroup.push(block);
        
        // End group on significant spatial gap (simplified)
        if (currentGroup.length >= 3) {
          groups.push([...currentGroup]);
          currentGroup = [];
        }
      }
    }

    if (currentGroup.length > 0) {
      groups.push(currentGroup);
    }

    return groups;
  }

  /**
   * Extract item from block group
   */
  extractItemFromBlockGroup(blockGroup) {
    try {
      const texts = blockGroup.map(block => block.Text || block.text || '').filter(t => t.trim());
      const combinedText = texts.join(' ');

      // Try to find product name and price
      const priceMatch = combinedText.match(/\$?(\d+\.?\d*)$/);
      if (!priceMatch) return null;

      const price = parseFloat(priceMatch[1]);
      const productName = combinedText.replace(/\$?(\d+\.?\d*)$/, '').trim();

      if (!productName || price <= 0) return null;

      return {
        name: this.cleanProductName(productName),
        totalPrice: price,
        quantity: 1,
        confidence: 0.7,
        source: 'blocks'
      };

    } catch (error) {
      return null;
    }
  }

  /**
   * Extract items from table structure
   */
  extractItemsFromTable(table) {
    const items = [];
    
    try {
      // This would parse actual table structures from OCR providers
      // Simplified implementation for demo
      if (table.blocks && Array.isArray(table.blocks)) {
        for (const block of table.blocks) {
          if (block.BlockType === 'CELL') {
            // Process table cells to extract items
            const item = this.extractItemFromTableCell(block);
            if (item) items.push(item);
          }
        }
      }
    } catch (error) {
      logger.debug('Table extraction failed:', error);
    }

    return items;
  }

  /**
   * Extract item from table cell
   */
  extractItemFromTableCell(cell) {
    // Simplified table cell processing
    const text = cell.Text || cell.text || '';
    const priceMatch = text.match(/\$?(\d+\.?\d*)$/);
    
    if (priceMatch) {
      const price = parseFloat(priceMatch[1]);
      const productName = text.replace(/\$?(\d+\.?\d*)$/, '').trim();
      
      if (productName && price > 0) {
        return {
          name: this.cleanProductName(productName),
          totalPrice: price,
          quantity: 1,
          source: 'table',
          confidence: 0.6
        };
      }
    }
    
    return null;
  }

  /**
   * Combine results from all extraction approaches
   */
  combineExtractionResults(approaches) {
    const allItems = [];
    
    for (const approach of approaches) {
      for (const item of approach.items) {
        item.extractionMethod = approach.approach;
        allItems.push(item);
      }
    }

    // Deduplicate similar items
    return this.deduplicateItems(allItems);
  }

  /**
   * Deduplicate similar items
   */
  deduplicateItems(items) {
    const deduplicated = [];
    
    for (const item of items) {
      const similar = deduplicated.find(existing => 
        this.areItemsSimilar(item, existing)
      );
      
      if (similar) {
        // Merge with higher confidence item
        if (item.confidence > similar.confidence) {
          const index = deduplicated.indexOf(similar);
          deduplicated[index] = { ...similar, ...item, confidence: item.confidence };
        }
      } else {
        deduplicated.push(item);
      }
    }

    return deduplicated;
  }

  /**
   * Check if two items are similar (potential duplicates)
   */
  areItemsSimilar(item1, item2) {
    // Name similarity
    const nameSimilarity = fuzzball.ratio(
      item1.name.toLowerCase(),
      item2.name.toLowerCase()
    );
    
    // Price similarity (within 5%)
    const priceDiff = Math.abs(item1.totalPrice - item2.totalPrice);
    const avgPrice = (item1.totalPrice + item2.totalPrice) / 2;
    const priceThreshold = avgPrice * 0.05;
    
    return nameSimilarity > 80 && priceDiff <= priceThreshold;
  }

  /**
   * Enhance line items with additional data
   */
  async enhanceLineItems(items, merchantName) {
    const enhanced = [];
    
    for (const item of items) {
      const enhancedItem = {
        ...item,
        category: await this.categorizeItem(item, merchantName),
        brand: this.extractBrand(item.name),
        unit: this.extractUnit(item.name),
        barcode: this.extractBarcode(item.name),
        taxable: this.determineTaxability(item, merchantName),
        tags: this.generateItemTags(item)
      };
      
      enhanced.push(enhancedItem);
    }
    
    return enhanced;
  }

  /**
   * Categorize individual item
   */
  async categorizeItem(item, merchantName) {
    const itemName = item.name.toLowerCase();
    
    // Category patterns
    const categories = {
      'Food': ['food', 'meal', 'snack', 'bread', 'milk', 'cheese', 'meat', 'vegetable', 'fruit'],
      'Beverage': ['drink', 'coffee', 'tea', 'soda', 'juice', 'water', 'beer', 'wine'],
      'Personal Care': ['shampoo', 'soap', 'toothpaste', 'deodorant', 'lotion'],
      'Household': ['cleaner', 'detergent', 'paper', 'towel', 'bag', 'foil'],
      'Electronics': ['phone', 'computer', 'cable', 'battery', 'charger'],
      'Clothing': ['shirt', 'pants', 'shoes', 'dress', 'jacket', 'hat'],
      'Automotive': ['oil', 'filter', 'tire', 'gas', 'fuel'],
      'Health': ['medicine', 'vitamin', 'supplement', 'prescription']
    };
    
    for (const [category, keywords] of Object.entries(categories)) {
      for (const keyword of keywords) {
        if (itemName.includes(keyword)) {
          return category;
        }
      }
    }
    
    // Fallback to merchant-based categorization
    return this.categorizeByMerchant(merchantName);
  }

  /**
   * Extract brand from item name
   */
  extractBrand(itemName) {
    const knownBrands = [
      'coca cola', 'pepsi', 'nike', 'adidas', 'apple', 'samsung',
      'sony', 'microsoft', 'google', 'amazon', 'walmart'
    ];
    
    const lowerName = itemName.toLowerCase();
    return knownBrands.find(brand => lowerName.includes(brand)) || null;
  }

  /**
   * Extract unit information
   */
  extractUnit(itemName) {
    const unitPatterns = [
      /(\d+)\s*(oz|ounce|lb|pound|kg|gram|ml|liter)/i,
      /(\d+)\s*(pack|count|ct|ea|each)/i
    ];
    
    for (const pattern of unitPatterns) {
      const match = pattern.exec(itemName);
      if (match) {
        return {
          quantity: parseInt(match[1]),
          unit: match[2].toLowerCase()
        };
      }
    }
    
    return null;
  }

  /**
   * Extract barcode if present
   */
  extractBarcode(itemName) {
    const barcodePattern = /(\d{12,14})/;
    const match = barcodePattern.exec(itemName);
    return match ? match[1] : null;
  }

  /**
   * Determine if item is taxable
   */
  determineTaxability(item, merchantName) {
    const nonTaxableKeywords = [
      'food', 'grocery', 'bread', 'milk', 'meat', 'vegetable', 'fruit'
    ];
    
    const itemName = item.name.toLowerCase();
    const isNonTaxable = nonTaxableKeywords.some(keyword => 
      itemName.includes(keyword)
    );
    
    // Food items at grocery stores are often non-taxable
    if (isNonTaxable && this.isGroceryStore(merchantName)) {
      return false;
    }
    
    return true; // Default to taxable
  }

  /**
   * Generate tags for item
   */
  generateItemTags(item) {
    const tags = [];
    
    if (item.totalPrice > 50) tags.push('expensive');
    if (item.quantity > 1) tags.push('multiple');
    if (item.unitPrice && item.unitPrice < 1) tags.push('cheap');
    if (item.name.length > 30) tags.push('detailed-description');
    
    return tags;
  }

  /**
   * Validate line items
   */
  validateLineItems(items, expectedTotal) {
    const validated = items.filter(item => this.isValidItem(item));
    
    // Check if total matches (within 10% tolerance)
    const calculatedTotal = validated.reduce((sum, item) => sum + item.totalPrice, 0);
    const tolerance = expectedTotal * 0.1;
    
    if (expectedTotal > 0 && Math.abs(calculatedTotal - expectedTotal) > tolerance) {
      logger.warn('Item total mismatch', {
        calculated: calculatedTotal,
        expected: expectedTotal,
        difference: Math.abs(calculatedTotal - expectedTotal)
      });
    }
    
    return validated;
  }

  /**
   * Validate individual item
   */
  isValidItem(item) {
    return (
      item &&
      item.name &&
      typeof item.name === 'string' &&
      item.name.length > 0 &&
      item.totalPrice &&
      typeof item.totalPrice === 'number' &&
      item.totalPrice > 0 &&
      item.totalPrice < 10000 // Reasonable upper limit
    );
  }

  /**
   * Calculate extraction confidence
   */
  calculateExtractionConfidence(items, ocrText, baseConfidence) {
    let confidence = baseConfidence * 0.5; // Base from OCR
    
    // Items found bonus
    if (items.length > 0) {
      confidence += 0.2;
    }
    
    // Multiple items bonus
    if (items.length > 3) {
      confidence += 0.1;
    }
    
    // Price format consistency
    const pricesValid = items.every(item => 
      item.totalPrice > 0 && !isNaN(item.totalPrice)
    );
    if (pricesValid) {
      confidence += 0.2;
    }
    
    return Math.min(confidence, 1.0);
  }

  /**
   * Generate suggestions for improvements
   */
  generateSuggestions(items, expectedTotal) {
    const suggestions = [];
    
    if (items.length === 0) {
      suggestions.push('No line items detected - consider manual entry');
    }
    
    const calculatedTotal = items.reduce((sum, item) => sum + item.totalPrice, 0);
    if (expectedTotal > 0 && Math.abs(calculatedTotal - expectedTotal) > expectedTotal * 0.1) {
      suggestions.push('Item total doesn\'t match receipt total - verify accuracy');
    }
    
    const lowConfidenceItems = items.filter(item => item.confidence < 0.5);
    if (lowConfidenceItems.length > 0) {
      suggestions.push(`${lowConfidenceItems.length} items have low confidence - consider review`);
    }
    
    return suggestions;
  }

  /**
   * Helper methods
   */
  
  cleanProductName(name) {
    return name
      .trim()
      .replace(/^\d+\s*/, '') // Remove leading numbers
      .replace(/\s+/g, ' ') // Normalize spaces
      .substring(0, 100); // Limit length
  }

  isHeaderOrFooterLine(line) {
    const patterns = [
      /^(receipt|invoice|bill|order|subtotal|tax|total|thank you|visit|welcome)/i,
      /^\d{3}[-\s]\d{3}[-\s]\d{4}/, // Phone numbers
      /www\.|\.com|@/, // Websites and emails
      /^\d+:\d+\s*(am|pm)?$/i, // Times
      /^\d{1,2}\/\d{1,2}\/\d{2,4}$/ // Dates
    ];
    
    return patterns.some(pattern => pattern.test(line));
  }

  extractPriceFromText(text) {
    const priceMatch = text.match(/\$?(\d+\.?\d*)/);
    return priceMatch ? parseFloat(priceMatch[1]) : 0;
  }

  categorizeByMerchant(merchantName) {
    if (!merchantName) return 'Other';
    
    const merchant = merchantName.toLowerCase();
    
    if (/(restaurant|cafe|coffee|food)/.test(merchant)) return 'Food';
    if (/(gas|fuel|station)/.test(merchant)) return 'Automotive';
    if (/(pharmacy|cvs|walgreens)/.test(merchant)) return 'Health';
    if (/(grocery|market|store)/.test(merchant)) return 'Food';
    
    return 'Other';
  }

  isGroceryStore(merchantName) {
    if (!merchantName) return false;
    return /(grocery|market|walmart|target|kroger|safeway)/.test(merchantName.toLowerCase());
  }

  /**
   * Initialize patterns and data
   */
  initializePatterns() {
    // Initialize category patterns for better classification
    this.categoryPatterns.set('Food', [
      'bread', 'milk', 'cheese', 'meat', 'chicken', 'beef', 'pork',
      'vegetable', 'fruit', 'apple', 'banana', 'orange', 'tomato'
    ]);
    
    this.categoryPatterns.set('Beverage', [
      'coffee', 'tea', 'soda', 'juice', 'water', 'beer', 'wine', 'drink'
    ]);
    
    // Initialize unit patterns for extraction
    this.unitPatterns.set('weight', ['oz', 'ounce', 'lb', 'pound', 'kg', 'gram']);
    this.unitPatterns.set('volume', ['ml', 'liter', 'gallon', 'quart', 'pint']);
    this.unitPatterns.set('count', ['pack', 'count', 'ct', 'ea', 'each', 'dozen']);
  }
}

// Export singleton instance
const advancedLineItemService = new AdvancedLineItemService();
module.exports = advancedLineItemService;