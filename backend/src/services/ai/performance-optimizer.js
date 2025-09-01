// Performance Optimizer for Vector Search and RAG
// Handles caching, query optimization, and performance monitoring

const { createClient } = require('redis');
const { supabase } = require('../../config/supabase');

class PerformanceOptimizer {
  constructor() {
    this.redis = null;
    this.initializeRedis();
    
    // Performance metrics
    this.metrics = {
      cacheHits: 0,
      cacheMisses: 0,
      totalQueries: 0,
      avgResponseTime: 0,
      vectorSearchTime: 0,
      contextAssemblyTime: 0
    };

    // Cache settings
    this.cacheSettings = {
      embeddingTTL: 24 * 60 * 60, // 24 hours for embeddings
      searchTTL: 5 * 60,          // 5 minutes for search results
      contextTTL: 15 * 60,        // 15 minutes for RAG context
      maxCacheSize: 10000         // Maximum cached items
    };

    // Query optimization settings
    this.optimizationSettings = {
      batchSize: 25,              // Batch size for embedding generation
      maxConcurrentQueries: 10,   // Maximum concurrent search queries
      contextWindowSize: 15,      // Maximum context items for RAG
      compressionThreshold: 1000  // Compress results larger than this
    };
  }

  /**
   * Initialize Redis connection for caching
   */
  async initializeRedis() {
    try {
      this.redis = createClient({
        url: process.env.REDIS_URL || 'redis://localhost:6379'
      });
      
      this.redis.on('error', (err) => {
        console.error('Redis client error:', err);
        this.redis = null; // Disable Redis if connection fails
      });

      await this.redis.connect();
      console.log('Redis connected for performance optimization');
    } catch (error) {
      console.warn('Redis not available, falling back to in-memory cache:', error.message);
      this.redis = null;
      this.initializeInMemoryCache();
    }
  }

  /**
   * Initialize in-memory cache fallback
   */
  initializeInMemoryCache() {
    this.inMemoryCache = new Map();
    this.cacheTimestamps = new Map();
    
    // Cleanup expired cache entries every 5 minutes
    setInterval(() => {
      this.cleanupExpiredCache();
    }, 5 * 60 * 1000);
  }

  /**
   * Cache embedding vectors
   */
  async cacheEmbedding(key, embedding, metadata = {}) {
    try {
      const cacheKey = `embedding:${key}`;
      const cacheData = {
        embedding,
        metadata,
        timestamp: Date.now()
      };

      if (this.redis) {
        await this.redis.setEx(cacheKey, this.cacheSettings.embeddingTTL, JSON.stringify(cacheData));
      } else {
        this.inMemoryCache.set(cacheKey, cacheData);
        this.cacheTimestamps.set(cacheKey, Date.now());
      }
    } catch (error) {
      console.error('Error caching embedding:', error);
    }
  }

  /**
   * Get cached embedding
   */
  async getCachedEmbedding(key) {
    try {
      const cacheKey = `embedding:${key}`;
      
      if (this.redis) {
        const cached = await this.redis.get(cacheKey);
        if (cached) {
          this.metrics.cacheHits++;
          return JSON.parse(cached);
        }
      } else {
        const cached = this.inMemoryCache.get(cacheKey);
        const timestamp = this.cacheTimestamps.get(cacheKey);
        
        if (cached && timestamp) {
          const age = Date.now() - timestamp;
          if (age < this.cacheSettings.embeddingTTL * 1000) {
            this.metrics.cacheHits++;
            return cached;
          } else {
            this.inMemoryCache.delete(cacheKey);
            this.cacheTimestamps.delete(cacheKey);
          }
        }
      }
      
      this.metrics.cacheMisses++;
      return null;
    } catch (error) {
      console.error('Error getting cached embedding:', error);
      this.metrics.cacheMisses++;
      return null;
    }
  }

  /**
   * Cache search results
   */
  async cacheSearchResults(queryHash, results, ttl = null) {
    try {
      const cacheKey = `search:${queryHash}`;
      const cacheData = {
        results,
        timestamp: Date.now()
      };

      const cacheTTL = ttl || this.cacheSettings.searchTTL;

      if (this.redis) {
        await this.redis.setEx(cacheKey, cacheTTL, JSON.stringify(cacheData));
      } else {
        this.inMemoryCache.set(cacheKey, cacheData);
        this.cacheTimestamps.set(cacheKey, Date.now());
      }
    } catch (error) {
      console.error('Error caching search results:', error);
    }
  }

  /**
   * Get cached search results
   */
  async getCachedSearchResults(queryHash) {
    try {
      const cacheKey = `search:${queryHash}`;
      
      if (this.redis) {
        const cached = await this.redis.get(cacheKey);
        if (cached) {
          this.metrics.cacheHits++;
          return JSON.parse(cached);
        }
      } else {
        const cached = this.inMemoryCache.get(cacheKey);
        const timestamp = this.cacheTimestamps.get(cacheKey);
        
        if (cached && timestamp) {
          const age = Date.now() - timestamp;
          if (age < this.cacheSettings.searchTTL * 1000) {
            this.metrics.cacheHits++;
            return cached;
          } else {
            this.inMemoryCache.delete(cacheKey);
            this.cacheTimestamps.delete(cacheKey);
          }
        }
      }
      
      this.metrics.cacheMisses++;
      return null;
    } catch (error) {
      console.error('Error getting cached search results:', error);
      this.metrics.cacheMisses++;
      return null;
    }
  }

  /**
   * Cache RAG context
   */
  async cacheRAGContext(contextHash, context) {
    try {
      const cacheKey = `rag:${contextHash}`;
      const cacheData = {
        context,
        timestamp: Date.now()
      };

      if (this.redis) {
        await this.redis.setEx(cacheKey, this.cacheSettings.contextTTL, JSON.stringify(cacheData));
      } else {
        this.inMemoryCache.set(cacheKey, cacheData);
        this.cacheTimestamps.set(cacheKey, Date.now());
      }
    } catch (error) {
      console.error('Error caching RAG context:', error);
    }
  }

  /**
   * Get cached RAG context
   */
  async getCachedRAGContext(contextHash) {
    try {
      const cacheKey = `rag:${contextHash}`;
      
      if (this.redis) {
        const cached = await this.redis.get(cacheKey);
        if (cached) {
          this.metrics.cacheHits++;
          return JSON.parse(cached);
        }
      } else {
        const cached = this.inMemoryCache.get(cacheKey);
        const timestamp = this.cacheTimestamps.get(cacheKey);
        
        if (cached && timestamp) {
          const age = Date.now() - timestamp;
          if (age < this.cacheSettings.contextTTL * 1000) {
            this.metrics.cacheHits++;
            return cached;
          } else {
            this.inMemoryCache.delete(cacheKey);
            this.cacheTimestamps.delete(cacheKey);
          }
        }
      }
      
      this.metrics.cacheMisses++;
      return null;
    } catch (error) {
      console.error('Error getting cached RAG context:', error);
      this.metrics.cacheMisses++;
      return null;
    }
  }

  /**
   * Optimize vector search query
   */
  async optimizeVectorSearch(queryEmbedding, searchParams, userId) {
    const startTime = Date.now();
    
    try {
      // Generate query hash for caching
      const queryHash = this.generateQueryHash(queryEmbedding, searchParams, userId);
      
      // Check cache first
      const cached = await this.getCachedSearchResults(queryHash);
      if (cached) {
        return {
          ...cached.results,
          cached: true,
          responseTime: Date.now() - startTime
        };
      }

      // Optimize search parameters
      const optimizedParams = this.optimizeSearchParams(searchParams);

      // Execute search with optimizations
      const results = await this.executeOptimizedSearch(queryEmbedding, optimizedParams, userId);

      // Cache results
      await this.cacheSearchResults(queryHash, results);

      // Update metrics
      this.updateSearchMetrics(Date.now() - startTime);

      return {
        ...results,
        cached: false,
        responseTime: Date.now() - startTime
      };
    } catch (error) {
      console.error('Error in optimized vector search:', error);
      throw error;
    }
  }

  /**
   * Optimize search parameters
   */
  optimizeSearchParams(params) {
    return {
      ...params,
      // Limit result count to prevent excessive data transfer
      match_count: Math.min(params.match_count || 10, 50),
      
      // Adjust threshold based on query complexity
      match_threshold: params.match_threshold || this.calculateOptimalThreshold(params),
      
      // Optimize similarity metric
      similarity_metric: params.similarity_metric || 'cosine'
    };
  }

  /**
   * Calculate optimal similarity threshold
   */
  calculateOptimalThreshold(params) {
    // Dynamic threshold based on search context
    if (params.search_type === 'duplicate_detection') {
      return 0.85; // High threshold for duplicates
    } else if (params.search_type === 'recommendations') {
      return 0.70; // Medium threshold for recommendations
    } else {
      return 0.65; // Default threshold for general search
    }
  }

  /**
   * Execute optimized search
   */
  async executeOptimizedSearch(queryEmbedding, params, userId) {
    try {
      // Use the appropriate search function based on type
      const searchFunction = this.getSearchFunction(params.search_type || 'receipts');
      
      const { data, error } = await supabase.rpc(searchFunction, {
        query_embedding: queryEmbedding,
        user_id_param: userId,
        ...params
      });

      if (error) {
        throw error;
      }

      // Compress results if needed
      return this.compressResults(data);
    } catch (error) {
      console.error('Error executing optimized search:', error);
      throw error;
    }
  }

  /**
   * Get appropriate search function name
   */
  getSearchFunction(searchType) {
    const functions = {
      receipts: 'search_receipts_advanced',
      warranties: 'search_warranties_similarity',
      hybrid: 'hybrid_search_receipts',
      context: 'assemble_rag_context'
    };
    
    return functions[searchType] || functions.receipts;
  }

  /**
   * Compress search results if they're large
   */
  compressResults(results) {
    if (!results || results.length === 0) {
      return results;
    }

    const resultsSize = JSON.stringify(results).length;
    
    if (resultsSize > this.optimizationSettings.compressionThreshold) {
      // Remove or truncate large fields
      return results.map(result => ({
        ...result,
        content_text: result.content_text ? result.content_text.substring(0, 200) + '...' : null,
        metadata: result.metadata ? this.truncateMetadata(result.metadata) : null
      }));
    }

    return results;
  }

  /**
   * Truncate metadata to essential fields
   */
  truncateMetadata(metadata) {
    const essential = ['similarity_score', 'confidence_score', 'search_type'];
    const truncated = {};
    
    for (const key of essential) {
      if (metadata[key] !== undefined) {
        truncated[key] = metadata[key];
      }
    }
    
    return truncated;
  }

  /**
   * Optimize RAG context assembly
   */
  async optimizeRAGContext(query, userId, options = {}) {
    const startTime = Date.now();
    
    try {
      // Generate context hash
      const contextHash = this.generateContextHash(query, userId, options);
      
      // Check cache
      const cached = await this.getCachedRAGContext(contextHash);
      if (cached) {
        return {
          ...cached.context,
          cached: true,
          assemblyTime: Date.now() - startTime
        };
      }

      // Optimize context parameters
      const optimizedOptions = {
        ...options,
        maxItems: Math.min(options.maxItems || 15, this.optimizationSettings.contextWindowSize)
      };

      // Assemble context with database function
      const { data, error } = await supabase.rpc('assemble_rag_context', {
        query_embedding: options.queryEmbedding,
        user_id_param: userId,
        context_types: optimizedOptions.contextTypes || ['receipts', 'warranties', 'conversations'],
        max_context_items: optimizedOptions.maxItems,
        relevance_threshold: optimizedOptions.threshold || 0.6
      });

      if (error) {
        throw error;
      }

      // Cache the assembled context
      await this.cacheRAGContext(contextHash, data);

      // Update metrics
      this.updateContextMetrics(Date.now() - startTime);

      return {
        ...data,
        cached: false,
        assemblyTime: Date.now() - startTime
      };
    } catch (error) {
      console.error('Error optimizing RAG context:', error);
      throw error;
    }
  }

  /**
   * Batch optimize embeddings
   */
  async batchOptimizeEmbeddings(items, type) {
    const batches = [];
    const batchSize = this.optimizationSettings.batchSize;

    // Split into batches
    for (let i = 0; i < items.length; i += batchSize) {
      batches.push(items.slice(i, i + batchSize));
    }

    const results = [];
    
    // Process batches with concurrency control
    const semaphore = new Array(this.optimizationSettings.maxConcurrentQueries).fill(null);
    
    for (const batch of batches) {
      await Promise.race(semaphore.map(async (_, index) => {
        if (semaphore[index] === null) {
          semaphore[index] = this.processBatch(batch, type);
          const batchResults = await semaphore[index];
          results.push(...batchResults);
          semaphore[index] = null;
        }
      }));
    }

    return results;
  }

  /**
   * Process a batch of items
   */
  async processBatch(batch, type) {
    // This would integrate with the embedding service
    // For now, return a placeholder
    return batch.map(item => ({
      item,
      success: true,
      cached: false
    }));
  }

  /**
   * Clean up expired in-memory cache
   */
  cleanupExpiredCache() {
    if (!this.inMemoryCache) return;

    const now = Date.now();
    const expired = [];

    for (const [key, timestamp] of this.cacheTimestamps.entries()) {
      const age = now - timestamp;
      const maxAge = key.startsWith('embedding:') ? 
        this.cacheSettings.embeddingTTL * 1000 :
        key.startsWith('search:') ? 
        this.cacheSettings.searchTTL * 1000 :
        this.cacheSettings.contextTTL * 1000;

      if (age > maxAge) {
        expired.push(key);
      }
    }

    for (const key of expired) {
      this.inMemoryCache.delete(key);
      this.cacheTimestamps.delete(key);
    }

    // Limit cache size
    if (this.inMemoryCache.size > this.cacheSettings.maxCacheSize) {
      const sortedKeys = Array.from(this.cacheTimestamps.entries())
        .sort(([,a], [,b]) => a - b)
        .slice(0, this.inMemoryCache.size - this.cacheSettings.maxCacheSize)
        .map(([key]) => key);

      for (const key of sortedKeys) {
        this.inMemoryCache.delete(key);
        this.cacheTimestamps.delete(key);
      }
    }
  }

  /**
   * Generate query hash for caching
   */
  generateQueryHash(queryEmbedding, params, userId) {
    const crypto = require('crypto');
    const hashInput = JSON.stringify({
      embedding: queryEmbedding.slice(0, 10), // Use first 10 dimensions for hash
      params,
      userId
    });
    return crypto.createHash('sha256').update(hashInput).digest('hex').substring(0, 16);
  }

  /**
   * Generate context hash for RAG caching
   */
  generateContextHash(query, userId, options) {
    const crypto = require('crypto');
    const hashInput = JSON.stringify({
      query: query.substring(0, 100), // Limit query length for hash
      userId,
      options: {
        contextTypes: options.contextTypes,
        maxItems: options.maxItems,
        threshold: options.threshold
      }
    });
    return crypto.createHash('sha256').update(hashInput).digest('hex').substring(0, 16);
  }

  /**
   * Update search performance metrics
   */
  updateSearchMetrics(responseTime) {
    this.metrics.totalQueries++;
    this.metrics.vectorSearchTime = (this.metrics.vectorSearchTime + responseTime) / 2;
    this.metrics.avgResponseTime = (this.metrics.avgResponseTime + responseTime) / 2;
  }

  /**
   * Update context assembly metrics
   */
  updateContextMetrics(assemblyTime) {
    this.metrics.contextAssemblyTime = (this.metrics.contextAssemblyTime + assemblyTime) / 2;
  }

  /**
   * Get performance metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      cacheHitRate: this.metrics.totalQueries > 0 ? 
        (this.metrics.cacheHits / (this.metrics.cacheHits + this.metrics.cacheMisses)) : 0,
      avgResponseTimeMs: Math.round(this.metrics.avgResponseTime),
      avgVectorSearchTimeMs: Math.round(this.metrics.vectorSearchTime),
      avgContextAssemblyTimeMs: Math.round(this.metrics.contextAssemblyTime)
    };
  }

  /**
   * Health check
   */
  async healthCheck() {
    try {
      const redisStatus = this.redis ? 'connected' : 'disconnected';
      const cacheSize = this.inMemoryCache ? this.inMemoryCache.size : 'N/A';
      
      return {
        status: 'healthy',
        redis: redisStatus,
        inMemoryCacheSize: cacheSize,
        metrics: this.getMetrics(),
        cacheSettings: this.cacheSettings
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }

  /**
   * Reset metrics
   */
  resetMetrics() {
    this.metrics = {
      cacheHits: 0,
      cacheMisses: 0,
      totalQueries: 0,
      avgResponseTime: 0,
      vectorSearchTime: 0,
      contextAssemblyTime: 0
    };
  }

  /**
   * Clear all caches
   */
  async clearCache() {
    try {
      if (this.redis) {
        await this.redis.flushAll();
      }
      
      if (this.inMemoryCache) {
        this.inMemoryCache.clear();
        this.cacheTimestamps.clear();
      }
      
      return { success: true, message: 'All caches cleared' };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

module.exports = PerformanceOptimizer;