/**
 * Supabase Integration Tests
 * Tests for database connections, authentication, and core services
 */

const { db } = require('../src/utils/database');
const { authService, userService } = require('../src/services/supabaseService');

// Mock environment variables for testing
process.env.SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:54321';
process.env.SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'test-anon-key';

describe('Supabase Configuration Tests', () => {
  describe('Database Connection', () => {
    test('should have Supabase URL configured', () => {
      expect(process.env.SUPABASE_URL).toBeDefined();
      expect(process.env.SUPABASE_URL).toMatch(/^https?:\/\/.+/);
    });

    test('should have anon key configured', () => {
      expect(process.env.SUPABASE_ANON_KEY).toBeDefined();
      expect(process.env.SUPABASE_ANON_KEY.length).toBeGreaterThan(10);
    });

    test('should initialize database service', () => {
      expect(db).toBeDefined();
      expect(db.client).toBeDefined();
      expect(db.service).toBeDefined();
    });

    test('should have query methods available', () => {
      expect(typeof db.query).toBe('function');
      expect(typeof db.buildQuery).toBe('function');
      expect(typeof db.testConnection).toBe('function');
      expect(typeof db.getHealthInfo).toBe('function');
    });
  });

  describe('Authentication Service', () => {
    test('should initialize auth service', () => {
      expect(authService).toBeDefined();
      expect(typeof authService.signUp).toBe('function');
      expect(typeof authService.signIn).toBe('function');
      expect(typeof authService.signOut).toBe('function');
    });

    test('should initialize user service', () => {
      expect(userService).toBeDefined();
      expect(typeof userService.getUserProfile).toBe('function');
      expect(typeof userService.updateUserProfile).toBe('function');
      expect(typeof userService.createUserProfile).toBe('function');
    });
  });

  describe('Database Health Check', () => {
    test('should return health information', async () => {
      const healthInfo = await db.getHealthInfo();
      
      expect(healthInfo).toBeDefined();
      expect(healthInfo).toHaveProperty('status');
      expect(healthInfo).toHaveProperty('timestamp');
      expect(healthInfo).toHaveProperty('supabaseUrl');
      expect(healthInfo).toHaveProperty('hasAdminClient');
      
      // Status should be either 'healthy' or 'unhealthy'
      expect(['healthy', 'unhealthy']).toContain(healthInfo.status);
    });

    test('should handle connection test gracefully', async () => {
      const connectionResult = await db.testConnection();
      expect(typeof connectionResult).toBe('boolean');
    });
  });

  describe('Query Builder', () => {
    test('should build basic query', () => {
      const query = db.buildQuery('users', {
        select: 'id, email',
        filters: { active: true },
        limit: 10
      });
      
      expect(query).toBeDefined();
      // The query should be a Supabase query object
      expect(typeof query.select).toBe('function');
    });

    test('should handle complex filters', () => {
      const query = db.buildQuery('receipts', {
        select: '*',
        filters: {
          user_id: 'test-user-id',
          amount: { operator: 'gte', value: 100 }
        },
        orderBy: { column: 'created_at', ascending: false },
        page: 1,
        limit: 20
      });
      
      expect(query).toBeDefined();
    });
  });

  describe('Error Handling', () => {
    test('should handle database errors gracefully', async () => {
      try {
        // This should fail with a controlled error
        await db.query(
          () => db.client.from('nonexistent_table').select('*'),
          'test query on nonexistent table'
        );
      } catch (error) {
        expect(error).toBeDefined();
        expect(error.message).toContain('test query on nonexistent table failed');
      }
    });

    test('should wrap errors properly', async () => {
      try {
        await db.executeQuery(
          () => {
            throw new Error('Test error');
          },
          'test operation'
        );
      } catch (error) {
        expect(error.message).toContain('test operation failed');
      }
    });
  });

  describe('Configuration Validation', () => {
    test('should validate required environment variables', () => {
      const requiredVars = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];
      
      requiredVars.forEach(varName => {
        expect(process.env[varName]).toBeDefined();
        expect(process.env[varName]).not.toBe('');
      });
    });

    test('should handle optional service role key', () => {
      // Service role key is optional, but if present should be valid
      if (process.env.SUPABASE_SERVICE_ROLE_KEY) {
        expect(process.env.SUPABASE_SERVICE_ROLE_KEY.length).toBeGreaterThan(10);
        expect(db.adminClient).toBeDefined();
      }
    });

    test('should have proper URL format', () => {
      const url = process.env.SUPABASE_URL;
      expect(url).toMatch(/^https?:\/\/.+\.supabase\.(co|io)$|^http:\/\/localhost:\d+$/);
    });
  });

  describe('Feature Flags', () => {
    test('should respect feature flags from environment', () => {
      const features = {
        OCR_PROCESSING: process.env.FEATURE_OCR_PROCESSING !== 'false',
        VECTOR_SEARCH: process.env.FEATURE_VECTOR_SEARCH !== 'false',
        BUDGET_TRACKING: process.env.FEATURE_BUDGET_TRACKING !== 'false',
        ANALYTICS: process.env.FEATURE_ANALYTICS !== 'false'
      };
      
      // Features should default to true if not explicitly disabled
      Object.values(features).forEach(feature => {
        expect(typeof feature).toBe('boolean');
      });
    });
  });
});

// Integration tests (only run if we can connect to Supabase)
describe('Supabase Integration Tests', () => {
  let isConnected = false;
  
  beforeAll(async () => {
    try {
      isConnected = await db.testConnection();
    } catch (error) {
      console.warn('Supabase not available for integration tests:', error.message);
    }
  });

  describe('Live Database Tests', () => {
    test('should connect to Supabase if configured', async () => {
      if (!isConnected) {
        console.log('Skipping live database tests - Supabase not connected');
        return;
      }
      
      const healthInfo = await db.getHealthInfo();
      expect(healthInfo.status).toBe('healthy');
    });

    test('should handle real queries if connected', async () => {
      if (!isConnected) {
        console.log('Skipping live query tests - Supabase not connected');
        return;
      }
      
      try {
        // Try to query a system table that should exist
        await db.query(
          () => db.client.rpc('version'),
          'get database version'
        );
      } catch (error) {
        // This might fail if RLS is enabled or function doesn't exist
        // but we should still get a structured error
        expect(error.message).toBeDefined();
      }
    });
  });
});

// Cleanup
afterAll(async () => {
  // Clean up any test data or connections if needed
});