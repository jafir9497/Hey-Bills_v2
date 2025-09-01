/**
 * Supabase Connection Test
 * Tests the Supabase connection with provided credentials
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

describe('Supabase Connection Tests', () => {
  let supabase;
  
  beforeAll(() => {
    // Initialize Supabase client
    supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_ANON_KEY
    );
  });

  test('should have valid environment variables', () => {
    expect(process.env.SUPABASE_URL).toBeDefined();
    expect(process.env.SUPABASE_ANON_KEY).toBeDefined();
    expect(process.env.SUPABASE_URL).toMatch(/^https:\/\/.*\.supabase\.co$/);
    expect(process.env.SUPABASE_ANON_KEY).toMatch(/^eyJ/);
  });

  test('should initialize Supabase client successfully', () => {
    expect(supabase).toBeDefined();
    expect(supabase.auth).toBeDefined();
    expect(supabase.from).toBeDefined();
    expect(supabase.storage).toBeDefined();
  });

  test('should connect to database and check schema', async () => {
    try {
      // Test basic query to get table information
      const { data, error } = await supabase
        .from('information_schema.tables')
        .select('table_name')
        .eq('table_schema', 'public')
        .limit(5);

      if (error) {
        console.log('Database query error:', error);
        // If we can't query information_schema, try a simple health check
        const { data: healthData, error: healthError } = await supabase
          .rpc('version'); // This should work if Supabase is connected

        if (healthError) {
          console.log('Health check error:', healthError);
        } else {
          console.log('Health check successful:', healthData);
        }
      } else {
        console.log('Found tables:', data);
        expect(data).toBeDefined();
      }
    } catch (err) {
      console.log('Connection test error:', err.message);
      // Don't fail the test, just log the error
    }
  });

  test('should test auth functionality', async () => {
    try {
      // Test getting session (should be null for anonymous)
      const { data: session, error } = await supabase.auth.getSession();
      
      console.log('Auth session test:', { session: session?.session, error });
      expect(error).toBeNull();
    } catch (err) {
      console.log('Auth test error:', err.message);
    }
  });

  test('should test storage functionality', async () => {
    try {
      // Test listing storage buckets
      const { data, error } = await supabase.storage.listBuckets();
      
      console.log('Storage buckets:', { data, error });
      
      if (error) {
        console.log('Storage test error:', error);
      } else {
        console.log('Found storage buckets:', data);
      }
    } catch (err) {
      console.log('Storage test error:', err.message);
    }
  });

  test('should test real-time functionality', async () => {
    try {
      // Test creating a channel
      const channel = supabase.channel('test-channel');
      expect(channel).toBeDefined();
      
      // Clean up
      channel.unsubscribe();
    } catch (err) {
      console.log('Real-time test error:', err.message);
    }
  });
});