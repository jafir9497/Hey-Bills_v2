// Semantic Search API Controller
// Provides REST endpoints for advanced vector search and RAG functionality

const SemanticSearchService = require('../../services/ai/semantic-search-service');
const { validateRequest, handleError } = require('../../middleware/validation');

class SemanticSearchController {
  constructor() {
    this.searchService = new SemanticSearchService();
  }

  /**
   * POST /api/search/semantic
   * Main semantic search endpoint with intent classification
   */
  async search(req, res) {
    try {
      const { query, options = {} } = req.body;
      const userId = req.user.id;

      // Validate request
      if (!query || typeof query !== 'string' || query.trim().length === 0) {
        return res.status(400).json({
          error: 'Query is required and must be a non-empty string'
        });
      }

      if (query.length > 1000) {
        return res.status(400).json({
          error: 'Query is too long. Maximum 1000 characters allowed.'
        });
      }

      // Perform semantic search
      const results = await this.searchService.search(query, userId, options);

      // Add search metadata
      const response = {
        ...results,
        metadata: {
          user_id: userId,
          search_time: new Date().toISOString(),
          query_length: query.length,
          options_used: Object.keys(options).length
        }
      };

      res.json(response);
    } catch (error) {
      console.error('Error in semantic search:', error);
      handleError(res, error, 'Semantic search failed');
    }
  }

  /**
   * POST /api/search/receipts
   * Specialized receipt search endpoint
   */
  async searchReceipts(req, res) {
    try {
      const { query, filters = {}, options = {} } = req.body;
      const userId = req.user.id;

      if (!query) {
        return res.status(400).json({
          error: 'Query is required'
        });
      }

      // Generate query embedding
      const queryEmbedding = await this.searchService.embeddingService.generateQueryEmbedding(query);

      // Extract entities from query and merge with filters
      const entities = {
        ...this.searchService.extractEntities(query),
        ...filters
      };

      // Perform receipt search
      const results = await this.searchService.searchReceipts(
        queryEmbedding, 
        userId, 
        entities, 
        options
      );

      res.json({
        query,
        filters: entities,
        results,
        metadata: {
          search_type: 'receipts',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in receipt search:', error);
      handleError(res, error, 'Receipt search failed');
    }
  }

  /**
   * POST /api/search/warranties
   * Warranty search and recommendations
   */
  async searchWarranties(req, res) {
    try {
      const { query, filters = {}, options = {} } = req.body;
      const userId = req.user.id;

      if (!query) {
        return res.status(400).json({
          error: 'Query is required'
        });
      }

      const queryEmbedding = await this.searchService.embeddingService.generateQueryEmbedding(query);
      const entities = {
        ...this.searchService.extractEntities(query),
        ...filters
      };

      const results = await this.searchService.searchWarranties(
        queryEmbedding, 
        userId, 
        entities, 
        options
      );

      res.json({
        query,
        filters: entities,
        results,
        metadata: {
          search_type: 'warranties',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in warranty search:', error);
      handleError(res, error, 'Warranty search failed');
    }
  }

  /**
   * POST /api/search/hybrid
   * Hybrid vector + text search
   */
  async hybridSearch(req, res) {
    try {
      const { 
        query, 
        vectorWeight = 0.7, 
        textWeight = 0.3, 
        filters = {}, 
        options = {} 
      } = req.body;
      const userId = req.user.id;

      if (!query) {
        return res.status(400).json({
          error: 'Query is required'
        });
      }

      // Validate weights
      if (Math.abs((vectorWeight + textWeight) - 1.0) > 0.01) {
        return res.status(400).json({
          error: 'Vector weight and text weight must sum to 1.0'
        });
      }

      const queryEmbedding = await this.searchService.embeddingService.generateQueryEmbedding(query);
      const entities = {
        ...this.searchService.extractEntities(query),
        ...filters
      };

      const searchOptions = {
        ...options,
        vectorWeight,
        textWeight
      };

      const results = await this.searchService.hybridSearch(
        queryEmbedding, 
        query, 
        userId, 
        entities, 
        searchOptions
      );

      res.json({
        query,
        weights: { vectorWeight, textWeight },
        filters: entities,
        results,
        metadata: {
          search_type: 'hybrid',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in hybrid search:', error);
      handleError(res, error, 'Hybrid search failed');
    }
  }

  /**
   * POST /api/search/analyze-spending
   * AI-powered spending analysis
   */
  async analyzeSpending(req, res) {
    try {
      const { 
        query = 'analyze my spending patterns', 
        timeframe = 90, 
        insightTypes = ['patterns', 'anomalies', 'trends'] 
      } = req.body;
      const userId = req.user.id;

      // Generate embedding for the analysis query
      const queryEmbedding = await this.searchService.embeddingService.generateQueryEmbedding(query);
      const entities = this.searchService.extractEntities(query);

      const options = {
        insightTypes
      };

      const results = await this.searchService.analyzeBudget(
        queryEmbedding, 
        userId, 
        entities, 
        options
      );

      res.json({
        query,
        timeframe,
        insightTypes,
        analysis: results,
        metadata: {
          analysis_type: 'spending_insights',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in spending analysis:', error);
      handleError(res, error, 'Spending analysis failed');
    }
  }

  /**
   * POST /api/search/find-duplicates
   * Duplicate receipt detection
   */
  async findDuplicates(req, res) {
    try {
      const { receiptId, threshold = 0.85 } = req.body;
      const userId = req.user.id;

      if (!receiptId) {
        return res.status(400).json({
          error: 'Receipt ID is required for duplicate detection'
        });
      }

      // Get the receipt embedding
      const { data: receiptData, error: receiptError } = await this.searchService.embeddingService.supabase
        .from('receipt_embeddings')
        .select('embedding')
        .eq('receipt_id', receiptId)
        .single();

      if (receiptError || !receiptData) {
        return res.status(404).json({
          error: 'Receipt embedding not found. The receipt may need to be processed first.'
        });
      }

      const options = { 
        threshold,
        limit: 20 
      };

      const results = await this.searchService.findDuplicates(
        receiptData.embedding, 
        userId, 
        {}, 
        options
      );

      res.json({
        receiptId,
        threshold,
        results,
        metadata: {
          search_type: 'duplicate_detection',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in duplicate detection:', error);
      handleError(res, error, 'Duplicate detection failed');
    }
  }

  /**
   * POST /api/search/classify-intent
   * Intent classification for queries
   */
  async classifyIntent(req, res) {
    try {
      const { query } = req.body;

      if (!query) {
        return res.status(400).json({
          error: 'Query is required'
        });
      }

      const intent = this.searchService.classifyIntent(query);
      const entities = this.searchService.extractEntities(query);

      res.json({
        query,
        intent,
        entities,
        metadata: {
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error in intent classification:', error);
      handleError(res, error, 'Intent classification failed');
    }
  }

  /**
   * GET /api/search/suggestions
   * Get search suggestions based on user history
   */
  async getSuggestions(req, res) {
    try {
      const { query = '', limit = 5 } = req.query;
      const userId = req.user.id;

      // Get recent queries for suggestions (would be implemented with search history)
      const suggestions = await this.generateSearchSuggestions(userId, query, limit);

      res.json({
        query,
        suggestions,
        metadata: {
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error getting search suggestions:', error);
      handleError(res, error, 'Failed to get search suggestions');
    }
  }

  /**
   * GET /api/search/health
   * Health check endpoint
   */
  async healthCheck(req, res) {
    try {
      const health = await this.searchService.healthCheck();
      
      res.json({
        service: 'semantic-search',
        ...health,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error in search health check:', error);
      res.status(500).json({
        service: 'semantic-search',
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * Generate search suggestions based on user history and context
   */
  async generateSearchSuggestions(userId, query, limit) {
    // This would typically use search history, common patterns, etc.
    // For now, provide static suggestions based on query context
    
    const baseSuggestions = [
      'receipts from last month',
      'grocery store purchases',
      'warranty expiring soon',
      'duplicate receipts',
      'spending by category',
      'business expenses',
      'restaurant receipts',
      'gas station purchases',
      'online shopping',
      'healthcare expenses'
    ];

    const filteredSuggestions = baseSuggestions
      .filter(suggestion => 
        !query || suggestion.toLowerCase().includes(query.toLowerCase())
      )
      .slice(0, limit);

    return filteredSuggestions.map(suggestion => ({
      text: suggestion,
      type: this.searchService.classifyIntent(suggestion).primary,
      confidence: 0.8
    }));
  }

  /**
   * Get router with all endpoints configured
   */
  getRouter() {
    const router = require('express').Router();

    // Main search endpoints
    router.post('/semantic', this.search.bind(this));
    router.post('/receipts', this.searchReceipts.bind(this));
    router.post('/warranties', this.searchWarranties.bind(this));
    router.post('/hybrid', this.hybridSearch.bind(this));
    
    // Analysis endpoints
    router.post('/analyze-spending', this.analyzeSpending.bind(this));
    router.post('/find-duplicates', this.findDuplicates.bind(this));
    router.post('/classify-intent', this.classifyIntent.bind(this));
    
    // Utility endpoints
    router.get('/suggestions', this.getSuggestions.bind(this));
    router.get('/health', this.healthCheck.bind(this));

    return router;
  }
}

module.exports = SemanticSearchController;