/**
 * Database Connection and Query Utilities
 * Centralized database operations with error handling and connection pooling
 */

const { supabase, supabaseAdmin } = require('../../config/supabase');
const { APIError } = require('../../utils/errorHandler');

/**
 * Database utility class for managing Supabase operations
 */
class DatabaseService {
  constructor() {
    this.client = supabase;
    this.adminClient = supabaseAdmin;
  }

  /**
   * Execute a query with error handling
   * @param {Function} queryFn - Query function to execute
   * @param {string} operation - Description of the operation
   * @returns {Promise<Object>} Query result
   */
  async executeQuery(queryFn, operation = 'database operation') {
    try {
      const result = await queryFn();
      
      if (result.error) {
        throw new APIError(
          `${operation} failed: ${result.error.message}`,
          result.error.code === 'PGRST116' ? 404 : 400,
          'DATABASE_ERROR',
          { details: result.error }
        );
      }
      
      return result;
    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      
      throw new APIError(
        `${operation} failed: ${error.message}`,
        500,
        'DATABASE_ERROR',
        { originalError: error.message }
      );
    }
  }

  /**
   * Execute admin query with elevated privileges
   * @param {Function} queryFn - Admin query function
   * @param {string} operation - Description of the operation
   * @returns {Promise<Object>} Query result
   */
  async executeAdminQuery(queryFn, operation = 'admin database operation') {
    if (!this.adminClient) {
      throw new APIError(
        'Admin client not configured. Please set SUPABASE_SERVICE_ROLE_KEY',
        500,
        'CONFIG_ERROR'
      );
    }

    try {
      const result = await queryFn(this.adminClient);
      
      if (result.error) {
        throw new APIError(
          `${operation} failed: ${result.error.message}`,
          result.error.code === 'PGRST116' ? 404 : 400,
          'DATABASE_ERROR',
          { details: result.error }
        );
      }
      
      return result;
    } catch (error) {
      if (error instanceof APIError) {
        throw error;
      }
      
      throw new APIError(
        `${operation} failed: ${error.message}`,
        500,
        'DATABASE_ERROR',
        { originalError: error.message }
      );
    }
  }

  /**
   * Test database connection
   * @returns {Promise<boolean>} Connection status
   */
  async testConnection() {
    try {
      const result = await this.executeQuery(
        () => this.client.from('users').select('count').limit(1),
        'connection test'
      );
      return true;
    } catch (error) {
      console.error('Database connection test failed:', error);
      return false;
    }
  }

  /**
   * Get database health information
   * @returns {Promise<Object>} Health information
   */
  async getHealthInfo() {
    try {
      const startTime = Date.now();
      
      // Test basic query
      await this.executeQuery(
        () => this.client.from('users').select('count').limit(1),
        'health check'
      );
      
      const responseTime = Date.now() - startTime;
      
      return {
        status: 'healthy',
        responseTime,
        timestamp: new Date().toISOString(),
        supabaseUrl: process.env.SUPABASE_URL?.replace(/\/.*/, '/***') || 'not configured',
        hasAdminClient: !!this.adminClient
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString(),
        supabaseUrl: process.env.SUPABASE_URL?.replace(/\/.*/, '/***') || 'not configured',
        hasAdminClient: !!this.adminClient
      };
    }
  }

  /**
   * Execute transaction with rollback support
   * @param {Function} transactionFn - Transaction function
   * @returns {Promise<Object>} Transaction result
   */
  async transaction(transactionFn) {
    // Note: Supabase doesn't support explicit transactions in the same way
    // as traditional SQL clients. This is a placeholder for potential future enhancement
    // or for use with direct database connections
    try {
      return await transactionFn(this.client);
    } catch (error) {
      throw new APIError(
        `Transaction failed: ${error.message}`,
        500,
        'TRANSACTION_ERROR',
        { originalError: error.message }
      );
    }
  }

  /**
   * Build a standardized query with common filters
   * @param {string} table - Table name
   * @param {Object} options - Query options
   * @returns {Object} Supabase query builder
   */
  buildQuery(table, options = {}) {
    let query = this.client.from(table);
    
    // Apply select fields
    if (options.select) {
      query = query.select(options.select);
    }
    
    // Apply filters
    if (options.filters) {
      Object.entries(options.filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          if (Array.isArray(value)) {
            query = query.in(key, value);
          } else if (typeof value === 'object' && value.operator) {
            // Support for complex filters like { operator: 'gte', value: 100 }
            query = query[value.operator](key, value.value);
          } else {
            query = query.eq(key, value);
          }
        }
      });
    }
    
    // Apply ordering
    if (options.orderBy) {
      const { column, ascending = true } = options.orderBy;
      query = query.order(column, { ascending });
    }
    
    // Apply pagination
    if (options.page && options.limit) {
      const from = (options.page - 1) * options.limit;
      const to = from + options.limit - 1;
      query = query.range(from, to);
    } else if (options.limit) {
      query = query.limit(options.limit);
    }
    
    return query;
  }

  /**
   * Get the current client (for direct access when needed)
   * @param {boolean} admin - Whether to return admin client
   * @returns {Object} Supabase client
   */
  getClient(admin = false) {
    return admin ? this.adminClient : this.client;
  }
}

// Create singleton instance
const databaseService = new DatabaseService();

/**
 * Convenience functions for common database operations
 */
const db = {
  // Service instance
  service: databaseService,
  
  // Quick access to clients
  client: supabase,
  adminClient: supabaseAdmin,
  
  // Utility functions
  query: (queryFn, operation) => databaseService.executeQuery(queryFn, operation),
  executeQuery: (queryFn, operation) => databaseService.executeQuery(queryFn, operation),
  adminQuery: (queryFn, operation) => databaseService.executeAdminQuery(queryFn, operation),
  testConnection: () => databaseService.testConnection(),
  getHealthInfo: () => databaseService.getHealthInfo(),
  buildQuery: (table, options) => databaseService.buildQuery(table, options),
  
  // Transaction support
  transaction: (transactionFn) => databaseService.transaction(transactionFn)
};

module.exports = {
  DatabaseService,
  db,
  supabase,
  supabaseAdmin
};