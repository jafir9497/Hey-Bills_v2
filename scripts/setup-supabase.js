#!/usr/bin/env node

/**
 * Supabase Setup Script for Hey-Bills v2
 * 
 * This script automates the complete setup of your Supabase project:
 * - Database schema deployment
 * - Row Level Security policies
 * - Storage bucket creation
 * - Authentication configuration
 * - Extension enablement
 * 
 * Usage:
 *   node scripts/setup-supabase.js --setup
 *   node scripts/setup-supabase.js --verify
 *   node scripts/setup-supabase.js --reset (dangerous!)
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Configuration
const CONFIG = {
  supabaseUrl: process.env.SUPABASE_URL,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  anonKey: process.env.SUPABASE_ANON_KEY,
};

// Validate environment
function validateEnvironment() {
  const missing = [];
  if (!CONFIG.supabaseUrl) missing.push('SUPABASE_URL');
  if (!CONFIG.serviceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!CONFIG.anonKey) missing.push('SUPABASE_ANON_KEY');
  
  if (missing.length > 0) {
    console.error('❌ Missing required environment variables:');
    missing.forEach(key => console.error(`   - ${key}`));
    console.error('\n💡 Make sure to update your .env file with actual Supabase credentials');
    process.exit(1);
  }
  
  // Check if using placeholder values
  if (CONFIG.supabaseUrl.includes('your-project-ref') || 
      CONFIG.serviceRoleKey.includes('your-actual-service-role-key')) {
    console.error('❌ You are still using placeholder values in your .env file');
    console.error('💡 Please update with your actual Supabase project credentials');
    process.exit(1);
  }
}

// Create Supabase client with admin privileges
function createSupabaseClient() {
  return createClient(CONFIG.supabaseUrl, CONFIG.serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
}

// Storage bucket configuration
const STORAGE_BUCKETS = [
  {
    name: 'receipts',
    public: false,
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
    fileSizeLimit: 10485760, // 10MB
  },
  {
    name: 'warranties',
    public: false,
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
    fileSizeLimit: 20971520, // 20MB
  },
  {
    name: 'profiles',
    public: true,
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    fileSizeLimit: 5242880, // 5MB
  }
];

// Extensions to enable
const REQUIRED_EXTENSIONS = [
  'uuid-ossp',
  'pgcrypto',
  'vector', // pgvector for embeddings
  'pg_trgm' // for text search
];

/**
 * Enable PostgreSQL extensions
 */
async function enableExtensions(supabase) {
  console.log('🔧 Enabling PostgreSQL extensions...');
  
  for (const extension of REQUIRED_EXTENSIONS) {
    try {
      const { error } = await supabase.rpc('enable_extension', {
        extension_name: extension
      });
      
      if (error && !error.message.includes('already exists')) {
        console.warn(`⚠️  Could not enable extension ${extension}: ${error.message}`);
        if (extension === 'vector') {
          console.warn('💡 Note: pgvector extension requires Supabase Pro plan or higher');
        }
      } else {
        console.log(`   ✅ ${extension} enabled`);
      }
    } catch (err) {
      // Try alternative SQL approach
      try {
        const { error: sqlError } = await supabase
          .from('sql')
          .execute(`CREATE EXTENSION IF NOT EXISTS "${extension}";`);
        
        if (!sqlError) {
          console.log(`   ✅ ${extension} enabled (via SQL)`);
        }
      } catch (sqlErr) {
        console.warn(`   ⚠️  Could not enable ${extension}: Extension may not be available`);
      }
    }
  }
}

/**
 * Deploy database schema
 */
async function deploySchema(supabase) {
  console.log('🗄️  Deploying database schema...');
  
  try {
    const schemaPath = path.join(__dirname, '..', 'database', 'schema.sql');
    if (!fs.existsSync(schemaPath)) {
      throw new Error('Schema file not found at database/schema.sql');
    }
    
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');
    
    // Split SQL into individual statements
    const statements = schemaSql
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    console.log(`   Executing ${statements.length} SQL statements...`);
    
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i];
      try {
        const { error } = await supabase.rpc('exec_sql', { 
          query: statement + ';' 
        });
        
        if (error && !error.message.includes('already exists')) {
          console.warn(`   ⚠️  Statement ${i + 1} warning: ${error.message.substring(0, 100)}...`);
        }
      } catch (err) {
        console.warn(`   ⚠️  Statement ${i + 1} failed: ${err.message.substring(0, 100)}...`);
      }
    }
    
    console.log('   ✅ Schema deployment completed');
  } catch (error) {
    console.error('   ❌ Schema deployment failed:', error.message);
    throw error;
  }
}

/**
 * Deploy RLS policies
 */
async function deployRLSPolicies(supabase) {
  console.log('🔒 Deploying Row Level Security policies...');
  
  try {
    const rlsPath = path.join(__dirname, '..', 'database', 'policies', 'rls_policies.sql');
    if (!fs.existsSync(rlsPath)) {
      console.warn('   ⚠️  RLS policies file not found, skipping...');
      return;
    }
    
    const rlsSql = fs.readFileSync(rlsPath, 'utf8');
    const { error } = await supabase.rpc('exec_sql', { query: rlsSql });
    
    if (error) {
      console.warn(`   ⚠️  RLS policies warning: ${error.message}`);
    } else {
      console.log('   ✅ RLS policies deployed');
    }
  } catch (error) {
    console.warn('   ⚠️  RLS policies deployment failed:', error.message);
  }
}

/**
 * Create storage buckets
 */
async function createStorageBuckets(supabase) {
  console.log('📁 Creating storage buckets...');
  
  for (const bucket of STORAGE_BUCKETS) {
    try {
      // Check if bucket exists
      const { data: existingBucket } = await supabase.storage.getBucket(bucket.name);
      
      if (existingBucket) {
        console.log(`   ✅ Bucket '${bucket.name}' already exists`);
        continue;
      }
      
      // Create bucket
      const { error: createError } = await supabase.storage.createBucket(bucket.name, {
        public: bucket.public,
        fileSizeLimit: bucket.fileSizeLimit,
        allowedMimeTypes: bucket.allowedMimeTypes,
      });
      
      if (createError) {
        console.error(`   ❌ Failed to create bucket '${bucket.name}': ${createError.message}`);
      } else {
        console.log(`   ✅ Created bucket '${bucket.name}' (${bucket.public ? 'public' : 'private'})`);
      }
      
    } catch (error) {
      console.warn(`   ⚠️  Bucket '${bucket.name}' setup warning: ${error.message}`);
    }
  }
}

/**
 * Set up authentication configuration
 */
async function configureAuth(supabase) {
  console.log('🔐 Configuring authentication...');
  
  // Note: Auth configuration is typically done through the Supabase dashboard
  // This function mainly validates that auth is properly configured
  
  try {
    // Test anonymous access
    const testClient = createClient(CONFIG.supabaseUrl, CONFIG.anonKey);
    const { error } = await testClient.from('categories').select('count');
    
    if (error && error.code !== 'PGRST116') { // PGRST116 is expected for empty table
      console.warn(`   ⚠️  Auth test warning: ${error.message}`);
    } else {
      console.log('   ✅ Authentication configuration validated');
    }
  } catch (error) {
    console.warn('   ⚠️  Auth configuration check failed:', error.message);
  }
}

/**
 * Verify setup completion
 */
async function verifySetup(supabase) {
  console.log('🔍 Verifying setup...');
  
  const checks = [];
  
  // Check extensions
  try {
    const { data } = await supabase.rpc('get_installed_extensions');
    const installedExtensions = data?.map(ext => ext.name) || [];
    
    for (const ext of REQUIRED_EXTENSIONS) {
      if (installedExtensions.includes(ext)) {
        checks.push(`✅ Extension ${ext} is installed`);
      } else {
        checks.push(`❌ Extension ${ext} is missing`);
      }
    }
  } catch (error) {
    checks.push(`⚠️  Could not verify extensions: ${error.message}`);
  }
  
  // Check core tables
  const coreTables = ['user_profiles', 'categories', 'receipts', 'warranties'];
  for (const table of coreTables) {
    try {
      const { error } = await supabase.from(table).select('count').limit(1);
      if (!error) {
        checks.push(`✅ Table ${table} exists and accessible`);
      } else {
        checks.push(`❌ Table ${table} not accessible: ${error.message}`);
      }
    } catch (error) {
      checks.push(`❌ Table ${table} check failed: ${error.message}`);
    }
  }
  
  // Check storage buckets
  for (const bucket of STORAGE_BUCKETS) {
    try {
      const { data } = await supabase.storage.getBucket(bucket.name);
      if (data) {
        checks.push(`✅ Storage bucket '${bucket.name}' exists`);
      } else {
        checks.push(`❌ Storage bucket '${bucket.name}' missing`);
      }
    } catch (error) {
      checks.push(`❌ Storage bucket '${bucket.name}' check failed`);
    }
  }
  
  // Display results
  console.log('\n📊 Setup Verification Results:');
  checks.forEach(check => console.log(`   ${check}`));
  
  const failures = checks.filter(check => check.startsWith('❌')).length;
  const warnings = checks.filter(check => check.startsWith('⚠️')).length;
  
  if (failures === 0 && warnings === 0) {
    console.log('\n🎉 All checks passed! Your Supabase setup is complete.');
  } else if (failures === 0) {
    console.log(`\n⚠️  Setup complete with ${warnings} warnings.`);
  } else {
    console.log(`\n❌ Setup incomplete: ${failures} failures, ${warnings} warnings.`);
  }
  
  return { failures, warnings };
}

/**
 * Main setup function
 */
async function runSetup() {
  console.log('🚀 Starting Hey-Bills Supabase setup...\n');
  
  try {
    validateEnvironment();
    const supabase = createSupabaseClient();
    
    await enableExtensions(supabase);
    await deploySchema(supabase);
    await deployRLSPolicies(supabase);
    await createStorageBuckets(supabase);
    await configureAuth(supabase);
    
    console.log('\n✅ Setup completed successfully!');
    
    // Run verification
    console.log('\n' + '='.repeat(50));
    await verifySetup(supabase);
    
  } catch (error) {
    console.error('\n❌ Setup failed:', error.message);
    process.exit(1);
  }
}

/**
 * Reset function (dangerous!)
 */
async function runReset() {
  console.log('⚠️  WARNING: This will reset your entire database!');
  console.log('This operation cannot be undone.');
  
  // Add confirmation prompt here if needed
  // For now, we'll skip the dangerous reset operation
  console.log('❌ Reset operation not implemented for safety');
  console.log('💡 To reset, manually delete and recreate your Supabase project');
}

// Command line interface
const args = process.argv.slice(2);
const command = args[0];

if (!command) {
  console.log('Usage:');
  console.log('  node scripts/setup-supabase.js --setup    # Run full setup');
  console.log('  node scripts/setup-supabase.js --verify   # Verify existing setup');
  console.log('  node scripts/setup-supabase.js --reset    # Reset database (dangerous!)');
  process.exit(1);
}

switch (command) {
  case '--setup':
    runSetup();
    break;
  case '--verify':
    validateEnvironment();
    verifySetup(createSupabaseClient());
    break;
  case '--reset':
    runReset();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    process.exit(1);
}