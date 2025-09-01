/**
 * Supabase Client Configuration
 * Centralized Supabase client setup for Hey-Bills v2
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Environment validation
const validateEnvironment = () => {
  const requiredEnvVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY'
  ];

  const missing = requiredEnvVars.filter(envVar => !process.env[envVar]);
  
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n` +
      'Please check your .env file and ensure all Supabase credentials are configured.'
    );
  }

  // Check for placeholder values
  if (process.env.SUPABASE_URL?.includes('your-project-ref') ||
      process.env.SUPABASE_ANON_KEY?.includes('your-actual-anon-key')) {
    throw new Error(
      'Found placeholder values in environment variables.\n' +
      'Please replace with your actual Supabase project credentials.'
    );
  }
};

// Validate environment on module load
try {
  validateEnvironment();
} catch (error) {
  console.error('❌ Supabase Configuration Error:', error.message);
  process.exit(1);
}

// Supabase configuration
const supabaseConfig = {
  url: process.env.SUPABASE_URL,
  anonKey: process.env.SUPABASE_ANON_KEY,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
};

// Client options
const clientOptions = {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
  db: {
    schema: 'public',
  },
  global: {
    headers: {
      'X-Client-Info': 'hey-bills-backend@1.0.0',
    },
  },
};

// Admin client options (for server-side operations)
const adminClientOptions = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
  db: {
    schema: 'public',
  },
  global: {
    headers: {
      'X-Client-Info': 'hey-bills-backend-admin@1.0.0',
    },
  },
};

/**
 * Create a standard Supabase client for user operations
 * Uses the anon key for client-side operations
 */
const createSupabaseClient = () => {
  return createClient(supabaseConfig.url, supabaseConfig.anonKey, clientOptions);
};

/**
 * Create an admin Supabase client for server operations
 * Uses the service role key for admin operations
 * ⚠️ WARNING: Only use server-side, never expose service role key to client
 */
const createSupabaseAdminClient = () => {
  return createClient(supabaseConfig.url, supabaseConfig.serviceRoleKey, adminClientOptions);
};

/**
 * Create a Supabase client with custom authentication
 * Useful for operations with specific user context
 */
const createSupabaseClientWithAuth = (accessToken) => {
  const customOptions = {
    ...clientOptions,
    global: {
      ...clientOptions.global,
      headers: {
        ...clientOptions.global.headers,
        Authorization: `Bearer ${accessToken}`,
      },
    },
  };

  return createClient(supabaseConfig.url, supabaseConfig.anonKey, customOptions);
};

/**
 * Database schemas and table names
 * Centralized reference for all database entities
 */
const DATABASE = {
  schemas: {
    PUBLIC: 'public',
    AUTH: 'auth',
    STORAGE: 'storage',
  },
  tables: {
    // Core tables
    USER_PROFILES: 'user_profiles',
    CATEGORIES: 'categories',
    RECEIPTS: 'receipts',
    RECEIPT_ITEMS: 'receipt_items',
    WARRANTIES: 'warranties',
    NOTIFICATIONS: 'notifications',
    BUDGETS: 'budgets',
    
    // AI/ML tables
    RECEIPT_EMBEDDINGS: 'receipt_embeddings',
    WARRANTY_EMBEDDINGS: 'warranty_embeddings',
    
    // System tables
    MIGRATION_HISTORY: 'migration_history',
  },
  views: {
    RECEIPT_SUMMARIES: 'receipt_summaries',
    WARRANTY_STATUS: 'warranty_status',
    BUDGET_ANALYTICS: 'budget_analytics',
  },
  functions: {
    // RPC functions
    SEARCH_RECEIPTS: 'search_receipts',
    GENERATE_EMBEDDINGS: 'generate_embeddings',
    MATCH_SIMILAR_RECEIPTS: 'match_similar_receipts',
    UPDATE_BUDGET_STATS: 'update_budget_stats',
  },
  storage: {
    buckets: {
      RECEIPTS: 'receipts',
      WARRANTIES: 'warranties', 
      PROFILES: 'profiles',
    },
  },
};

/**
 * Common database operations helper
 */
const createDatabaseHelpers = (client) => ({
  
  /**
   * Get user profile by ID
   */
  getUserProfile: async (userId) => {
    const { data, error } = await client
      .from(DATABASE.tables.USER_PROFILES)
      .select('*')
      .eq('id', userId)
      .single();
    
    if (error) throw error;
    return data;
  },

  /**
   * Create or update user profile
   */
  upsertUserProfile: async (profile) => {
    const { data, error } = await client
      .from(DATABASE.tables.USER_PROFILES)
      .upsert(profile)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  },

  /**
   * Get user's receipts with pagination
   */
  getUserReceipts: async (userId, { limit = 20, offset = 0 } = {}) => {
    const { data, error, count } = await client
      .from(DATABASE.tables.RECEIPTS)
      .select('*, receipt_items(*)', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);
    
    if (error) throw error;
    return { receipts: data, total: count };
  },

  /**
   * Search receipts using vector similarity
   */
  searchReceipts: async (userId, query, limit = 10) => {
    const { data, error } = await client.rpc(
      DATABASE.functions.SEARCH_RECEIPTS,
      { 
        user_id: userId,
        search_query: query,
        match_limit: limit 
      }
    );
    
    if (error) throw error;
    return data;
  },

  /**
   * Upload file to storage bucket
   */
  uploadFile: async (bucket, path, file, options = {}) => {
    const { data, error } = await client.storage
      .from(bucket)
      .upload(path, file, options);
    
    if (error) throw error;
    return data;
  },

  /**
   * Get public URL for file
   */
  getFileUrl: (bucket, path) => {
    const { data } = client.storage
      .from(bucket)
      .getPublicUrl(path);
    
    return data.publicUrl;
  },

});

/**
 * Test database connection
 */
const testConnection = async () => {
  try {
    const client = createSupabaseClient();
    const { error } = await client.from(DATABASE.tables.CATEGORIES).select('count');
    
    if (error && error.code !== 'PGRST116') {
      throw error;
    }
    
    console.log('✅ Supabase connection test successful');
    return true;
  } catch (error) {
    console.error('❌ Supabase connection test failed:', error.message);
    return false;
  }
};

/**
 * Health check for Supabase services
 */
const healthCheck = async () => {
  const client = createSupabaseClient();
  const results = {
    database: false,
    auth: false,
    storage: false,
    realtime: false,
  };

  // Test database
  try {
    await client.from(DATABASE.tables.CATEGORIES).select('count').limit(1);
    results.database = true;
  } catch (error) {
    console.warn('Database health check failed:', error.message);
  }

  // Test auth
  try {
    const { error } = await client.auth.getSession();
    results.auth = !error;
  } catch (error) {
    console.warn('Auth health check failed:', error.message);
  }

  // Test storage
  try {
    const { data } = await client.storage.listBuckets();
    results.storage = Array.isArray(data);
  } catch (error) {
    console.warn('Storage health check failed:', error.message);
  }

  // Test realtime
  try {
    const channel = client.channel('health-check');
    results.realtime = !!channel;
    channel.unsubscribe();
  } catch (error) {
    console.warn('Realtime health check failed:', error.message);
  }

  return results;
};

module.exports = {
  // Client creators
  createSupabaseClient,
  createSupabaseAdminClient,
  createSupabaseClientWithAuth,
  
  // Database schema reference
  DATABASE,
  
  // Helper functions
  createDatabaseHelpers,
  testConnection,
  healthCheck,
  
  // Configuration
  supabaseConfig: {
    url: supabaseConfig.url,
    // Don't expose keys in exports for security
  },
};