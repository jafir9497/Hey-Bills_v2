/**
 * ML-Based Receipt Categorization Service
 * Implements machine learning for automatic receipt categorization
 */

const natural = require('natural');
const compromise = require('compromise');
const { Matrix } = require('ml-matrix');
const logger = require('../utils/logger');
const { APIError } = require('../utils/errorHandler');

class MLCategorizationService {
  constructor() {
    this.classifier = null;
    this.merchantPatterns = new Map();
    this.categoryWeights = new Map();
    this.isInitialized = false;
    this.initializeService();
  }

  /**
   * Initialize the ML categorization service
   */
  async initializeService() {
    try {
      logger.info('Initializing ML Categorization Service...');

      // Initialize Natural NLP classifier
      this.classifier = new natural.BayesClassifier();

      // Load pre-trained patterns and weights
      await this.loadCategoryPatterns();
      await this.loadMerchantPatterns();
      await this.trainInitialModel();

      this.isInitialized = true;
      logger.info('ML Categorization Service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize ML Categorization Service:', error);
      this.isInitialized = false;
    }
  }

  /**
   * Categorize receipt using multiple ML approaches
   */
  async categorizeReceipt({
    merchantName,
    items = [],
    totalAmount,
    ocrText,
    existingCategory = null
  }) {
    try {
      if (!this.isInitialized) {
        await this.initializeService();
      }

      // Multiple categorization approaches
      const approaches = await Promise.all([
        this.categorizeByMerchant(merchantName),
        this.categorizeByItems(items),
        this.categorizeByTextPatterns(ocrText),
        this.categorizeByAmount(totalAmount),
        this.categorizeByNLP(ocrText, merchantName)
      ]);

      // Combine results with confidence weighting
      const categoryScores = this.combineCategorizationResults(approaches);
      
      // Get top category with confidence
      const topCategory = this.getBestCategory(categoryScores);
      
      // Learn from existing category if provided
      if (existingCategory) {
        await this.learnFromFeedback(existingCategory, {
          merchantName,
          items,
          ocrText,
          totalAmount
        });
      }

      return {
        category: topCategory.name,
        confidence: topCategory.confidence,
        alternativeCategories: categoryScores.slice(0, 3),
        reasoning: topCategory.reasoning,
        mlMetadata: {
          approaches: approaches.length,
          totalScores: categoryScores.length,
          processingTime: Date.now()
        }
      };

    } catch (error) {
      logger.error('ML Categorization failed:', error);
      return {
        category: 'Other',
        confidence: 0.1,
        alternativeCategories: [],
        reasoning: 'ML categorization failed, using fallback',
        error: error.message
      };
    }
  }

  /**
   * Categorize by merchant name patterns
   */
  async categorizeByMerchant(merchantName) {
    if (!merchantName) return { approach: 'merchant', scores: new Map() };

    const merchant = merchantName.toLowerCase().trim();
    const scores = new Map();

    // Direct merchant pattern matching
    for (const [category, patterns] of this.merchantPatterns) {
      let score = 0;
      for (const pattern of patterns) {
        if (merchant.includes(pattern)) {
          score += 0.8;
        }
        // Fuzzy matching for similar names
        const similarity = natural.JaroWinklerDistance(merchant, pattern);
        if (similarity > 0.7) {
          score += similarity * 0.6;
        }
      }
      if (score > 0) {
        scores.set(category, Math.min(score, 1.0));
      }
    }

    return { approach: 'merchant', scores };
  }

  /**
   * Categorize by line items
   */
  async categorizeByItems(items) {
    if (!items || items.length === 0) {
      return { approach: 'items', scores: new Map() };
    }

    const scores = new Map();
    const itemKeywords = this.extractItemKeywords(items);

    // Analyze item patterns
    for (const [category, keywords] of this.getCategoryKeywords()) {
      let score = 0;
      let matches = 0;

      for (const keyword of keywords) {
        for (const itemKeyword of itemKeywords) {
          const similarity = natural.JaroWinklerDistance(itemKeyword, keyword);
          if (similarity > 0.6) {
            score += similarity * 0.3;
            matches++;
          }
        }
      }

      if (matches > 0) {
        // Normalize by number of items and matches
        const normalizedScore = (score / items.length) * (matches / keywords.length);
        scores.set(category, Math.min(normalizedScore, 1.0));
      }
    }

    return { approach: 'items', scores };
  }

  /**
   * Categorize using text pattern analysis
   */
  async categorizeByTextPatterns(ocrText) {
    if (!ocrText) return { approach: 'patterns', scores: new Map() };

    const doc = compromise(ocrText);
    const scores = new Map();

    // Extract relevant terms
    const nouns = doc.nouns().out('array');
    const brands = doc.match('#Organization').out('array');
    const products = doc.match('#Product').out('array');

    // Pattern matching
    const patterns = {
      'Food & Dining': [
        /restaurant|cafe|coffee|food|dining|meal|lunch|dinner|breakfast/i,
        /pizza|burger|sandwich|salad|drink|beverage/i
      ],
      'Transportation': [
        /gas|fuel|parking|toll|uber|lyft|taxi|transport/i,
        /station|pump|vehicle|car|auto/i
      ],
      'Shopping': [
        /store|shop|retail|market|walmart|target|amazon/i,
        /clothing|electronics|home|garden|grocery/i
      ],
      'Healthcare': [
        /pharmacy|hospital|clinic|medical|health|doctor/i,
        /prescription|medicine|treatment|visit/i
      ],
      'Entertainment': [
        /movie|theater|concert|show|entertainment|ticket/i,
        /subscription|streaming|music|game/i
      ],
      'Utilities': [
        /electric|water|gas|internet|phone|utility/i,
        /bill|payment|service|monthly/i
      ]
    };

    for (const [category, categoryPatterns] of Object.entries(patterns)) {
      let score = 0;
      for (const pattern of categoryPatterns) {
        const matches = ocrText.match(pattern);
        if (matches) {
          score += 0.4 * matches.length;
        }
      }
      if (score > 0) {
        scores.set(category, Math.min(score, 1.0));
      }
    }

    return { approach: 'patterns', scores };
  }

  /**
   * Categorize by amount patterns
   */
  async categorizeByAmount(totalAmount) {
    if (!totalAmount || totalAmount <= 0) {
      return { approach: 'amount', scores: new Map() };
    }

    const scores = new Map();

    // Amount-based heuristics
    if (totalAmount < 10) {
      scores.set('Food & Dining', 0.3); // Coffee, snacks
      scores.set('Transportation', 0.2); // Parking
    } else if (totalAmount < 50) {
      scores.set('Food & Dining', 0.4); // Meals
      scores.set('Shopping', 0.3); // Small purchases
    } else if (totalAmount < 200) {
      scores.set('Shopping', 0.4); // Regular shopping
      scores.set('Healthcare', 0.3); // Medical visits
    } else {
      scores.set('Shopping', 0.3); // Major purchases
      scores.set('Utilities', 0.2); // Monthly bills
      scores.set('Healthcare', 0.2); // Procedures
    }

    return { approach: 'amount', scores };
  }

  /**
   * Advanced NLP categorization
   */
  async categorizeByNLP(ocrText, merchantName) {
    try {
      if (!this.classifier) {
        return { approach: 'nlp', scores: new Map() };
      }

      const combinedText = `${merchantName || ''} ${ocrText || ''}`.toLowerCase();
      
      // Process text for classification
      const features = this.extractNLPFeatures(combinedText);
      const classification = this.classifier.classify(features);
      const probabilities = this.classifier.getClassifications(features);

      const scores = new Map();
      for (const prob of probabilities) {
        scores.set(prob.label, prob.value);
      }

      return { approach: 'nlp', scores };
    } catch (error) {
      logger.warn('NLP categorization failed:', error);
      return { approach: 'nlp', scores: new Map() };
    }
  }

  /**
   * Combine results from all approaches
   */
  combineCategorizationResults(approaches) {
    const combinedScores = new Map();
    const approachWeights = {
      'merchant': 0.35,
      'items': 0.25,
      'patterns': 0.20,
      'nlp': 0.15,
      'amount': 0.05
    };

    // Combine scores with weighted approach
    for (const approach of approaches) {
      const weight = approachWeights[approach.approach] || 0.1;
      
      for (const [category, score] of approach.scores) {
        const currentScore = combinedScores.get(category) || 0;
        combinedScores.set(category, currentScore + (score * weight));
      }
    }

    // Convert to sorted array
    return Array.from(combinedScores.entries())
      .map(([category, score]) => ({
        name: category,
        confidence: Math.min(score, 1.0)
      }))
      .sort((a, b) => b.confidence - a.confidence);
  }

  /**
   * Get best category with reasoning
   */
  getBestCategory(categoryScores) {
    if (categoryScores.length === 0) {
      return {
        name: 'Other',
        confidence: 0.1,
        reasoning: 'No clear categorization patterns found'
      };
    }

    const best = categoryScores[0];
    const reasoning = this.generateReasoning(best, categoryScores);

    return {
      ...best,
      reasoning
    };
  }

  /**
   * Generate reasoning for categorization
   */
  generateReasoning(bestCategory, allScores) {
    const confidence = bestCategory.confidence;
    
    if (confidence > 0.8) {
      return `High confidence match based on multiple indicators`;
    } else if (confidence > 0.6) {
      return `Good match with ${Math.round(confidence * 100)}% confidence`;
    } else if (confidence > 0.4) {
      return `Moderate confidence, consider manual review`;
    } else {
      return `Low confidence categorization, manual review recommended`;
    }
  }

  /**
   * Learn from user feedback
   */
  async learnFromFeedback(correctCategory, receiptData) {
    try {
      const features = this.extractNLPFeatures(
        `${receiptData.merchantName || ''} ${receiptData.ocrText || ''}`
      );
      
      // Add to training data
      this.classifier.addDocument(features, correctCategory);
      this.classifier.train();

      // Update merchant patterns
      if (receiptData.merchantName) {
        this.updateMerchantPattern(correctCategory, receiptData.merchantName);
      }

      logger.debug(`Learned from feedback: ${correctCategory} for ${receiptData.merchantName}`);
    } catch (error) {
      logger.warn('Failed to learn from feedback:', error);
    }
  }

  /**
   * Load category patterns
   */
  async loadCategoryPatterns() {
    // Initialize category weight patterns
    this.categoryWeights.set('Food & Dining', 1.0);
    this.categoryWeights.set('Transportation', 1.0);
    this.categoryWeights.set('Shopping', 1.0);
    this.categoryWeights.set('Healthcare', 1.0);
    this.categoryWeights.set('Entertainment', 1.0);
    this.categoryWeights.set('Utilities', 1.0);
    this.categoryWeights.set('Other', 0.5);
  }

  /**
   * Load merchant patterns
   */
  async loadMerchantPatterns() {
    this.merchantPatterns.set('Food & Dining', [
      'mcdonald', 'burger king', 'subway', 'starbucks', 'dunkin', 'pizza hut',
      'domino', 'kfc', 'taco bell', 'wendy', 'chipotle', 'panera', 'restaurant',
      'cafe', 'coffee', 'bistro', 'deli', 'bakery'
    ]);

    this.merchantPatterns.set('Transportation', [
      'shell', 'exxon', 'chevron', 'bp', 'mobil', 'texaco', 'citgo',
      'uber', 'lyft', 'parking', 'metro', 'transit', 'gas', 'fuel'
    ]);

    this.merchantPatterns.set('Shopping', [
      'walmart', 'target', 'amazon', 'costco', 'sams club', 'kroger',
      'safeway', 'whole foods', 'home depot', 'lowes', 'best buy'
    ]);

    this.merchantPatterns.set('Healthcare', [
      'cvs', 'walgreens', 'rite aid', 'pharmacy', 'hospital', 'clinic',
      'medical', 'doctor', 'dentist', 'urgent care'
    ]);

    this.merchantPatterns.set('Entertainment', [
      'netflix', 'spotify', 'apple', 'google play', 'steam', 'xbox',
      'playstation', 'movie', 'theater', 'cinema'
    ]);

    this.merchantPatterns.set('Utilities', [
      'electric', 'water', 'gas', 'internet', 'cable', 'phone',
      'verizon', 'att', 'comcast', 'spectrum'
    ]);
  }

  /**
   * Train initial model with sample data
   */
  async trainInitialModel() {
    // Sample training data
    const trainingData = [
      { text: 'starbucks coffee latte', category: 'Food & Dining' },
      { text: 'shell gas station fuel', category: 'Transportation' },
      { text: 'walmart grocery shopping', category: 'Shopping' },
      { text: 'cvs pharmacy prescription', category: 'Healthcare' },
      { text: 'netflix subscription streaming', category: 'Entertainment' },
      { text: 'electric company monthly bill', category: 'Utilities' }
    ];

    for (const data of trainingData) {
      this.classifier.addDocument(data.text, data.category);
    }

    this.classifier.train();
  }

  /**
   * Extract NLP features
   */
  extractNLPFeatures(text) {
    const doc = compromise(text);
    
    return {
      raw: text,
      normalized: text.toLowerCase().replace(/[^a-z0-9\s]/g, ''),
      nouns: doc.nouns().out('array').join(' '),
      brands: doc.match('#Organization').out('array').join(' '),
      wordCount: text.split(' ').length
    };
  }

  /**
   * Extract keywords from items
   */
  extractItemKeywords(items) {
    const keywords = [];
    for (const item of items) {
      if (item.name) {
        const words = item.name.toLowerCase().split(/\s+/);
        keywords.push(...words);
      }
    }
    return [...new Set(keywords)];
  }

  /**
   * Get category keywords
   */
  getCategoryKeywords() {
    return new Map([
      ['Food & Dining', ['food', 'drink', 'meal', 'coffee', 'tea', 'bread', 'milk', 'meat', 'vegetable']],
      ['Transportation', ['fuel', 'gas', 'oil', 'parking', 'toll', 'ticket', 'fare']],
      ['Shopping', ['clothes', 'electronics', 'book', 'toy', 'home', 'garden', 'tool']],
      ['Healthcare', ['medicine', 'prescription', 'vitamin', 'bandage', 'thermometer']],
      ['Entertainment', ['ticket', 'subscription', 'game', 'music', 'movie']],
      ['Utilities', ['electricity', 'water', 'gas', 'internet', 'phone', 'cable']]
    ]);
  }

  /**
   * Update merchant pattern
   */
  updateMerchantPattern(category, merchantName) {
    const merchant = merchantName.toLowerCase().trim();
    if (!this.merchantPatterns.has(category)) {
      this.merchantPatterns.set(category, []);
    }
    
    const patterns = this.merchantPatterns.get(category);
    if (!patterns.includes(merchant)) {
      patterns.push(merchant);
    }
  }

  /**
   * Get categorization statistics
   */
  async getCategorizationStats() {
    return {
      totalCategories: this.categoryWeights.size,
      merchantPatterns: Array.from(this.merchantPatterns.entries()).map(([cat, patterns]) => ({
        category: cat,
        patternCount: patterns.length
      })),
      isInitialized: this.isInitialized,
      classifierTrained: this.classifier !== null
    };
  }
}

// Export singleton instance
const mlCategorizationService = new MLCategorizationService();
module.exports = mlCategorizationService;