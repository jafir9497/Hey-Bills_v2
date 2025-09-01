#!/usr/bin/env node
/**
 * Direct Supabase Connection Test Script
 * Tests connection and reports detailed information
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

async function testSupabaseConnection() {
  console.log('🔍 Testing Supabase Connection...\n');
  
  // Check environment variables
  console.log('📋 Environment Variables:');
  console.log(`SUPABASE_URL: ${process.env.SUPABASE_URL}`);
  console.log(`SUPABASE_ANON_KEY: ${process.env.SUPABASE_ANON_KEY ? 'Set (length: ' + process.env.SUPABASE_ANON_KEY.length + ')' : 'Not set'}`);
  console.log();

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_ANON_KEY) {
    console.error('❌ Missing required environment variables');
    process.exit(1);
  }

  // Initialize Supabase client
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
  );

  console.log('✅ Supabase client initialized successfully\n');

  // Test 1: Auth functionality
  console.log('🔐 Testing Authentication...');
  try {
    const { data: session, error } = await supabase.auth.getSession();
    if (error) {
      console.log('⚠️ Auth warning:', error.message);
    } else {
      console.log('✅ Auth test passed - Session state:', session?.session ? 'Active' : 'Anonymous');
    }
  } catch (err) {
    console.log('❌ Auth test failed:', err.message);
  }
  console.log();

  // Test 2: Database connectivity
  console.log('🗄️ Testing Database Connectivity...');
  try {
    // Try a simple query first
    const { data, error } = await supabase
      .rpc('version');
      
    if (error) {
      console.log('⚠️ RPC version call failed, trying table query...');
      
      // Try querying a system table
      const { data: tableData, error: tableError } = await supabase
        .from('pg_tables')
        .select('tablename')
        .eq('schemaname', 'public')
        .limit(5);
        
      if (tableError) {
        console.log('❌ Database query failed:', tableError.message);
        console.log('   This might indicate missing tables or RLS policies');
      } else {
        console.log('✅ Database connected successfully');
        console.log('📋 Found tables:', tableData?.map(t => t.tablename) || 'None');
      }
    } else {
      console.log('✅ Database connected successfully');
      console.log('📊 Database version info available');
    }
  } catch (err) {
    console.log('❌ Database test failed:', err.message);
  }
  console.log();

  // Test 3: Storage functionality
  console.log('📁 Testing Storage...');
  try {
    const { data, error } = await supabase.storage.listBuckets();
    
    if (error) {
      console.log('⚠️ Storage test warning:', error.message);
    } else {
      console.log('✅ Storage connected successfully');
      console.log('🪣 Available buckets:', data?.map(b => b.name) || 'None');
    }
  } catch (err) {
    console.log('❌ Storage test failed:', err.message);
  }
  console.log();

  // Test 4: Real-time functionality
  console.log('⚡ Testing Real-time...');
  try {
    const channel = supabase.channel('connection-test');
    
    // Subscribe and immediately unsubscribe to test the connection
    const subscription = channel.subscribe((status) => {
      console.log('📡 Real-time status:', status);
    });
    
    setTimeout(() => {
      channel.unsubscribe();
      console.log('✅ Real-time functionality available');
    }, 1000);
    
  } catch (err) {
    console.log('❌ Real-time test failed:', err.message);
  }

  // Test 5: Check for common tables
  console.log('🔍 Checking for application tables...');
  const expectedTables = ['users', 'receipts', 'warranties', 'categories', 'budgets'];
  
  for (const table of expectedTables) {
    try {
      const { data, error } = await supabase
        .from(table)
        .select('count', { count: 'exact' })
        .limit(0);
        
      if (error) {
        if (error.code === '42P01') {
          console.log(`⚠️ Table '${table}' does not exist`);
        } else if (error.code === '42501') {
          console.log(`⚠️ Table '${table}' exists but no RLS policy allows access`);
        } else {
          console.log(`⚠️ Table '${table}' - ${error.message}`);
        }
      } else {
        console.log(`✅ Table '${table}' accessible (${data?.length || 0} records)`);
      }
    } catch (err) {
      console.log(`❌ Error checking table '${table}':`, err.message);
    }
  }

  console.log('\n🎉 Connection test completed!');
  console.log('\n💡 Next steps:');
  console.log('   - If tables are missing, run database migrations');
  console.log('   - If RLS policies block access, check authentication');
  console.log('   - If storage buckets are missing, create them in Supabase dashboard');
  
  return supabase;
}

// Run the test
if (require.main === module) {
  testSupabaseConnection().catch(console.error);
}

module.exports = testSupabaseConnection;