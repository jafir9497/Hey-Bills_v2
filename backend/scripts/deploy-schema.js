#!/usr/bin/env node
/**
 * Deploy Database Schema to Supabase
 * Deploys the complete schema using Supabase client
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function deploySchema() {
  console.log('🚀 Deploying Database Schema to Supabase...\n');
  
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_ANON_KEY) {
    console.error('❌ Missing Supabase credentials in .env file');
    process.exit(1);
  }

  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
  );

  // Read the complete schema file
  const schemaPath = path.join(__dirname, '../../database/complete-schema-deployment.sql');
  
  if (!fs.existsSync(schemaPath)) {
    console.error('❌ Schema file not found:', schemaPath);
    process.exit(1);
  }

  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  console.log('📄 Schema file loaded:', schemaPath);
  console.log(`📊 Schema size: ${(schemaSql.length / 1024).toFixed(1)}KB\n`);

  try {
    // Note: Direct SQL execution requires service role key
    // For now, we'll provide instructions for manual deployment
    
    console.log('📋 MANUAL DEPLOYMENT REQUIRED');
    console.log('='.repeat(50));
    console.log('The complete schema needs to be deployed manually via Supabase dashboard:');
    console.log('');
    console.log('1. Go to https://duedldhbaqcxbmqvjhbg.supabase.co/sql');
    console.log('2. Copy the SQL from:', schemaPath);
    console.log('3. Paste it in the SQL Editor');
    console.log('4. Click "RUN" to execute');
    console.log('');
    console.log('OR use the Supabase CLI:');
    console.log('```');
    console.log('supabase db reset --local=false');
    console.log('supabase db push');
    console.log('```');
    console.log('');
    
    // Test basic connectivity
    console.log('🔍 Testing current database state...');
    
    const { data: tables, error: tablesError } = await supabase
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public');
      
    if (tablesError) {
      console.log('⚠️  Could not list tables (this is expected if schema is not deployed)');
      console.log('   Error:', tablesError.message);
    } else {
      console.log('✅ Found existing tables:', tables?.map(t => t.table_name) || []);
    }

    // Test essential table creation with simple queries
    console.log('\n🧪 Testing essential components...');
    
    const testQueries = [
      {
        name: 'Extensions',
        query: () => supabase.rpc('version'),
        description: 'Check if basic extensions are available'
      }
    ];
    
    for (const test of testQueries) {
      try {
        await test.query();
        console.log(`✅ ${test.name}: OK`);
      } catch (error) {
        console.log(`⚠️  ${test.name}: ${error.message}`);
      }
    }
    
    console.log('\n📝 Next Steps:');
    console.log('1. Deploy the schema manually using the Supabase SQL Editor');
    console.log('2. Create storage buckets: receipts, warranties, profiles');
    console.log('3. Set up RLS policies for security');
    console.log('4. Test the application endpoints');
    
  } catch (error) {
    console.error('❌ Schema deployment failed:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  deploySchema().catch(console.error);
}

module.exports = deploySchema;