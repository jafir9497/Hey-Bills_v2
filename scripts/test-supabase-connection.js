#!/usr/bin/env node

/**
 * Supabase Connection Test Script
 * Quick verification that your Supabase configuration is working
 * 
 * Usage: node scripts/test-supabase-connection.js
 */

const { createSupabaseClient, createSupabaseAdminClient, testConnection, healthCheck } = require('../config/supabase-client');

console.log('🔍 Testing Supabase Configuration for Hey-Bills v2...\n');

async function runTests() {
  let passed = 0;
  let failed = 0;
  
  // Test 1: Environment Variables
  console.log('1️⃣ Testing environment variables...');
  try {
    const url = process.env.SUPABASE_URL;
    const anonKey = process.env.SUPABASE_ANON_KEY;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    
    if (!url || !anonKey || !serviceKey) {
      throw new Error('Missing required environment variables');
    }
    
    if (url.includes('your-project-ref') || anonKey.includes('your-actual-anon-key')) {
      throw new Error('Found placeholder values - please update with actual credentials');
    }
    
    console.log('   ✅ Environment variables configured correctly');
    passed++;
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 2: Client Creation
  console.log('\n2️⃣ Testing client creation...');
  try {
    const client = createSupabaseClient();
    const adminClient = createSupabaseAdminClient();
    
    if (!client || !adminClient) {
      throw new Error('Failed to create Supabase clients');
    }
    
    console.log('   ✅ Supabase clients created successfully');
    passed++;
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 3: Basic Connection
  console.log('\n3️⃣ Testing basic connection...');
  try {
    const isConnected = await testConnection();
    if (!isConnected) {
      throw new Error('Connection test failed');
    }
    console.log('   ✅ Basic connection test passed');
    passed++;
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 4: Service Health Check
  console.log('\n4️⃣ Testing service health...');
  try {
    const health = await healthCheck();
    
    const services = ['database', 'auth', 'storage', 'realtime'];
    let healthyServices = 0;
    
    for (const service of services) {
      if (health[service]) {
        console.log(`   ✅ ${service} service healthy`);
        healthyServices++;
      } else {
        console.log(`   ⚠️  ${service} service check failed`);
      }
    }
    
    if (healthyServices >= 2) {
      console.log('   ✅ Core services are healthy');
      passed++;
    } else {
      throw new Error(`Only ${healthyServices}/4 services healthy`);
    }
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 5: Database Schema Check
  console.log('\n5️⃣ Testing database schema...');
  try {
    const client = createSupabaseAdminClient();
    
    // Check if core tables exist
    const tables = ['user_profiles', 'categories', 'receipts', 'warranties'];
    let existingTables = 0;
    
    for (const table of tables) {
      try {
        await client.from(table).select('count').limit(1);
        console.log(`   ✅ Table ${table} exists`);
        existingTables++;
      } catch (error) {
        console.log(`   ⚠️  Table ${table} not found or not accessible`);
      }
    }
    
    if (existingTables > 0) {
      console.log(`   ✅ Database schema partially deployed (${existingTables}/${tables.length} tables)`);
      passed++;
    } else {
      throw new Error('No tables found - schema not deployed');
    }
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 6: Storage Buckets Check
  console.log('\n6️⃣ Testing storage buckets...');
  try {
    const client = createSupabaseClient();
    const { data: buckets, error } = await client.storage.listBuckets();
    
    if (error) {
      throw new Error(`Storage error: ${error.message}`);
    }
    
    const expectedBuckets = ['receipts', 'warranties', 'profiles'];
    const existingBuckets = buckets?.map(b => b.name) || [];
    
    let foundBuckets = 0;
    for (const bucket of expectedBuckets) {
      if (existingBuckets.includes(bucket)) {
        console.log(`   ✅ Bucket '${bucket}' exists`);
        foundBuckets++;
      } else {
        console.log(`   ⚠️  Bucket '${bucket}' not found`);
      }
    }
    
    if (foundBuckets > 0) {
      console.log(`   ✅ Storage buckets configured (${foundBuckets}/${expectedBuckets.length} found)`);
      passed++;
    } else {
      throw new Error('No storage buckets found');
    }
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Test 7: Authentication Test
  console.log('\n7️⃣ Testing authentication...');
  try {
    const client = createSupabaseClient();
    
    // Test session retrieval (should not error even if no session)
    const { error } = await client.auth.getSession();
    
    if (error) {
      throw new Error(`Auth error: ${error.message}`);
    }
    
    console.log('   ✅ Authentication service accessible');
    passed++;
  } catch (error) {
    console.log(`   ❌ ${error.message}`);
    failed++;
  }
  
  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('📊 Test Summary:');
  console.log(`   ✅ Passed: ${passed}`);
  console.log(`   ❌ Failed: ${failed}`);
  console.log(`   📊 Success Rate: ${Math.round((passed / (passed + failed)) * 100)}%`);
  
  if (failed === 0) {
    console.log('\n🎉 All tests passed! Your Supabase configuration is ready.');
    console.log('\n📝 Next steps:');
    console.log('   1. Run: node scripts/setup-supabase.js --setup');
    console.log('   2. Test your backend: cd backend && npm test');
    console.log('   3. Test your frontend: cd frontend && flutter test');
  } else if (passed > failed) {
    console.log('\n⚠️  Most tests passed, but some issues found.');
    console.log('💡 You may need to run the setup script or check configurations.');
  } else {
    console.log('\n❌ Multiple tests failed. Please check your configuration.');
    console.log('\n🔧 Troubleshooting:');
    console.log('   1. Verify .env files have correct Supabase credentials');
    console.log('   2. Ensure Supabase project is created and active');
    console.log('   3. Check that API keys are not expired or restricted');
    console.log('   4. Run: node scripts/setup-supabase.js --setup');
  }
  
  process.exit(failed > 0 ? 1 : 0);
}

// Run the tests
runTests().catch(error => {
  console.error('\n💥 Test runner crashed:', error.message);
  process.exit(1);
});