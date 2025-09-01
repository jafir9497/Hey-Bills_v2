// Search Routes - Enhanced Vector Search and RAG Endpoints
// Integrates all search services with authentication and rate limiting

const express = require('express');
const rateLimit = require('express-rate-limit');
const SemanticSearchController = require('../controllers/search/semantic-search-controller');
const { authMiddleware } = require('../middleware/auth');
const { validateRequest } = require('../middleware/validation');
const { body, query } = require('express-validator');

const router = express.Router();
const searchController = new SemanticSearchController();

// Rate limiting for search endpoints
const searchRateLimit = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100, // 100 requests per minute per IP
  message: {
    error: 'Too many search requests. Please try again later.',
    retryAfter: 60
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const intensiveSearchRateLimit = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 20, // 20 requests per 5 minutes for intensive operations
  message: {
    error: 'Too many intensive search requests. Please try again later.',
    retryAfter: 300
  }
});

// Validation schemas
const searchQueryValidation = [
  body('query')
    .isString()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Query must be a string between 1 and 1000 characters'),
  body('options')
    .optional()
    .isObject()
    .withMessage('Options must be an object'),
  body('options.threshold')
    .optional()
    .isFloat({ min: 0, max: 1 })
    .withMessage('Threshold must be between 0 and 1'),
  body('options.limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limit must be between 1 and 50')
];

const hybridSearchValidation = [
  ...searchQueryValidation,
  body('vectorWeight')
    .optional()
    .isFloat({ min: 0, max: 1 })
    .withMessage('Vector weight must be between 0 and 1'),
  body('textWeight')
    .optional()
    .isFloat({ min: 0, max: 1 })
    .withMessage('Text weight must be between 0 and 1')
];

const receiptSearchValidation = [
  ...searchQueryValidation,
  body('filters')
    .optional()
    .isObject()
    .withMessage('Filters must be an object'),
  body('filters.merchant')
    .optional()
    .isString()
    .isLength({ max: 100 })
    .withMessage('Merchant filter must be a string up to 100 characters'),
  body('filters.category')
    .optional()
    .isString()
    .isLength({ max: 50 })
    .withMessage('Category filter must be a string up to 50 characters'),
  body('filters.minAmount')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Min amount must be a positive number'),
  body('filters.maxAmount')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Max amount must be a positive number')
];

const spendingAnalysisValidation = [
  body('query')
    .optional()
    .isString()
    .isLength({ max: 500 })
    .withMessage('Query must be a string up to 500 characters'),
  body('timeframe')
    .optional()
    .isInt({ min: 7, max: 365 })
    .withMessage('Timeframe must be between 7 and 365 days'),
  body('insightTypes')
    .optional()
    .isArray()
    .withMessage('Insight types must be an array'),
  body('insightTypes.*')
    .optional()
    .isIn(['patterns', 'anomalies', 'trends', 'recommendations'])
    .withMessage('Invalid insight type')
];

// Apply middleware to all routes
router.use(authMiddleware);
router.use(searchRateLimit);

// Main semantic search endpoint
router.post('/semantic', 
  searchQueryValidation,
  validateRequest,
  async (req, res) => {
    await searchController.search(req, res);
  }
);

// Specialized receipt search
router.post('/receipts',
  receiptSearchValidation,
  validateRequest,
  async (req, res) => {
    await searchController.searchReceipts(req, res);
  }
);

// Warranty search and recommendations
router.post('/warranties',
  searchQueryValidation,
  validateRequest,
  async (req, res) => {
    await searchController.searchWarranties(req, res);
  }
);

// Hybrid vector + text search
router.post('/hybrid',
  hybridSearchValidation,
  validateRequest,
  async (req, res) => {
    await searchController.hybridSearch(req, res);
  }
);

// AI-powered spending analysis (intensive operation)
router.post('/analyze-spending',
  intensiveSearchRateLimit,
  spendingAnalysisValidation,
  validateRequest,
  async (req, res) => {
    await searchController.analyzeSpending(req, res);
  }
);

// Duplicate detection (intensive operation)
router.post('/find-duplicates',
  intensiveSearchRateLimit,
  [
    body('receiptId')
      .isUUID()
      .withMessage('Receipt ID must be a valid UUID'),
    body('threshold')
      .optional()
      .isFloat({ min: 0.5, max: 1.0 })
      .withMessage('Threshold must be between 0.5 and 1.0')
  ],
  validateRequest,
  async (req, res) => {
    await searchController.findDuplicates(req, res);
  }
);

// Intent classification
router.post('/classify-intent',
  [
    body('query')
      .isString()
      .isLength({ min: 1, max: 500 })
      .withMessage('Query must be a string between 1 and 500 characters')
  ],
  validateRequest,
  async (req, res) => {
    await searchController.classifyIntent(req, res);
  }
);

// Search suggestions
router.get('/suggestions',
  [
    query('query')
      .optional()
      .isString()
      .isLength({ max: 100 })
      .withMessage('Query must be a string up to 100 characters'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 20 })
      .withMessage('Limit must be between 1 and 20')
  ],
  validateRequest,
  async (req, res) => {
    await searchController.getSuggestions(req, res);
  }
);

// Health check endpoint (no auth required for monitoring)
router.get('/health', (req, res, next) => {
  // Skip auth for health check
  req.skipAuth = true;
  next();
}, async (req, res) => {
  await searchController.healthCheck(req, res);
});

// Advanced search with filters and sorting
router.post('/advanced',
  [
    body('query').isString().isLength({ min: 1, max: 1000 }),
    body('filters').optional().isObject(),
    body('sorting').optional().isObject(),
    body('pagination').optional().isObject(),
    body('pagination.page').optional().isInt({ min: 1 }),
    body('pagination.limit').optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { query, filters = {}, sorting = {}, pagination = {} } = req.body;
      const userId = req.user.id;

      // Advanced search logic would go here
      // This is a placeholder for the full implementation
      
      const searchOptions = {
        ...filters,
        sortBy: sorting.field || 'relevance',
        sortOrder: sorting.order || 'desc',
        page: pagination.page || 1,
        limit: pagination.limit || 10
      };

      const result = await searchController.searchService.semanticSearch(
        query, 
        userId, 
        searchOptions
      );

      res.json({
        query,
        filters,
        sorting,
        pagination,
        results: result,
        metadata: {
          search_type: 'advanced',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in advanced search:', error);
      res.status(500).json({
        error: 'Advanced search failed',
        message: error.message
      });
    }
  }
);

// Batch search endpoint
router.post('/batch',
  intensiveSearchRateLimit,
  [
    body('queries').isArray({ min: 1, max: 10 }).withMessage('Queries must be an array of 1-10 items'),
    body('queries.*').isString().isLength({ min: 1, max: 500 }),
    body('options').optional().isObject()
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { queries, options = {} } = req.body;
      const userId = req.user.id;

      const batchPromises = queries.map(async (query, index) => {
        try {
          const result = await searchController.searchService.search(query, userId, options);
          return {
            index,
            query,
            success: true,
            result
          };
        } catch (error) {
          return {
            index,
            query,
            success: false,
            error: error.message
          };
        }
      });

      const results = await Promise.all(batchPromises);

      res.json({
        queries,
        results,
        summary: {
          total: queries.length,
          successful: results.filter(r => r.success).length,
          failed: results.filter(r => !r.success).length
        },
        metadata: {
          search_type: 'batch',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in batch search:', error);
      res.status(500).json({
        error: 'Batch search failed',
        message: error.message
      });
    }
  }
);

// Search analytics endpoint
router.get('/analytics',
  [
    query('timeframe')
      .optional()
      .isIn(['1h', '24h', '7d', '30d'])
      .withMessage('Timeframe must be one of: 1h, 24h, 7d, 30d')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { timeframe = '24h' } = req.query;
      const userId = req.user.id;

      // Get search analytics (placeholder)
      const analytics = {
        user_id: userId,
        timeframe,
        total_searches: 0,
        top_queries: [],
        search_types: {},
        avg_response_time: 0,
        cache_hit_rate: 0
      };

      res.json({
        analytics,
        metadata: {
          generated_at: new Date().toISOString(),
          timeframe
        }
      });
    } catch (error) {
      console.error('Error getting search analytics:', error);
      res.status(500).json({
        error: 'Failed to get search analytics',
        message: error.message
      });
    }
  }
);

// Export search configuration
router.get('/config', async (req, res) => {
  try {
    const config = {
      search_types: [
        'semantic',
        'receipts', 
        'warranties',
        'hybrid',
        'spending_analysis',
        'duplicate_detection'
      ],
      similarity_metrics: ['cosine', 'l2', 'inner_product'],
      intent_types: [
        'receipt_search',
        'warranty_query', 
        'budget_analysis',
        'category_classification',
        'duplicate_detection',
        'trend_analysis'
      ],
      default_limits: {
        receipts: 10,
        warranties: 5,
        context_items: 15
      },
      thresholds: {
        general_search: 0.65,
        duplicate_detection: 0.85,
        recommendations: 0.70
      }
    };

    res.json({
      config,
      metadata: {
        version: '1.0.0',
        updated_at: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error getting search config:', error);
    res.status(500).json({
      error: 'Failed to get search configuration',
      message: error.message
    });
  }
});

module.exports = router;