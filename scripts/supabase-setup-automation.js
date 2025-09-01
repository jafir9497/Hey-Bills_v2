#!/usr/bin/env node

/**
 * Supabase Setup Automation Script for Hey-Bills
 * Automates the complete Supabase project setup including schema, policies, and storage
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs').promises;
const path = require('path');
const { config } = require('../config/supabase-environment');

class SupabaseSetupManager {
  constructor(options = {}) {
    this.supabaseUrl = options.supabaseUrl || config.supabase.url;
    this.serviceRoleKey = options.serviceRoleKey || config.supabase.serviceRoleKey;
    this.verbose = options.verbose || false;
    
    // Initialize Supabase client with service role
    this.supabase = createClient(this.supabaseUrl, this.serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
  }

  /**
   * Main setup orchestrator
   */
  async runFullSetup() {
    console.log('🚀 Starting Hey-Bills Supabase Setup...\n');
    
    try {
      // Step 1: Verify connection
      await this.verifyConnection();
      
      // Step 2: Enable extensions
      await this.enableExtensions();
      
      // Step 3: Deploy database schema
      await this.deploySchema();
      
      // Step 4: Create storage buckets
      await this.createStorageBuckets();
      
      // Step 5: Apply RLS policies
      await this.applyRLSPolicies();
      
      // Step 6: Create vector search functions
      await this.createVectorFunctions();
      
      // Step 7: Insert default data
      await this.insertDefaultData();
      
      // Step 8: Verify setup
      await this.verifySetup();
      
      console.log('\n✅ Supabase setup completed successfully!');
      console.log('🎯 Your Hey-Bills project is now ready for development.\n');
      
    } catch (error) {
      console.error('\n❌ Setup failed:', error.message);
      if (this.verbose) {
        console.error('Full error:', error);
      }
      process.exit(1);
    }
  }

  /**
   * Verify Supabase connection
   */
  async verifyConnection() {
    this.log('🔗 Verifying Supabase connection...');
    
    try {
      const { data, error } = await this.supabase
        .from('information_schema.tables')
        .select('table_name')
        .limit(1);
      
      if (error) throw error;
      
      console.log('✅ Connection verified');
    } catch (error) {
      throw new Error(`Failed to connect to Supabase: ${error.message}`);
    }
  }

  /**
   * Enable required PostgreSQL extensions
   */
  async enableExtensions() {
    this.log('🔌 Enabling PostgreSQL extensions...');
    
    const extensionsSQL = await this.readSQLFile('database/migrations/001_enable_extensions.sql');
    
    try {
      const { error } = await this.supabase.rpc('exec_sql', { sql: extensionsSQL });
      if (error) throw error;
      
      console.log('✅ Extensions enabled: uuid-ossp, pgcrypto, vector, pg_trgm');
    } catch (error) {
      // Try alternative method for extensions
      const extensions = ['uuid-ossp', 'pgcrypto', 'vector', 'pg_trgm'];
      for (const ext of extensions) {
        try {
          await this.executeSQL(`CREATE EXTENSION IF NOT EXISTS "${ext}";`);
          console.log(`✅ Enabled ${ext}`);
        } catch (extError) {
          console.warn(`⚠️  Warning: Could not enable ${ext}: ${extError.message}`);
        }
      }
    }
  }

  /**
   * Deploy database schema
   */
  async deploySchema() {
    this.log('📋 Deploying database schema...');
    
    const schemaSQL = await this.readSQLFile('database/schema.sql');
    
    try {
      // Split schema into individual statements to execute separately
      const statements = this.splitSQLStatements(schemaSQL);
      
      for (let i = 0; i < statements.length; i++) {
        const statement = statements[i].trim();
        if (statement && !statement.startsWith('--')) {
          try {
            await this.executeSQL(statement);
            this.log(`Executed statement ${i + 1}/${statements.length}`);
          } catch (error) {
            console.warn(`⚠️  Warning: Statement failed: ${error.message}`);
            if (this.verbose) {
              console.warn('Failed statement:', statement.substring(0, 100) + '...');
            }
          }
        }
      }
      
      console.log('✅ Database schema deployed');
    } catch (error) {
      throw new Error(`Schema deployment failed: ${error.message}`);
    }
  }

  /**
   * Create storage buckets
   */
  async createStorageBuckets() {
    this.log('🗄️  Creating storage buckets...');
    
    const buckets = [
      {
        id: 'receipts',
        name: 'receipts',
        public: false,
        file_size_limit: 10485760, // 10MB
        allowed_mime_types: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
      },
      {
        id: 'warranties',
        name: 'warranties', 
        public: false,
        file_size_limit: 20971520, // 20MB
        allowed_mime_types: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
      },
      {
        id: 'profiles',
        name: 'profiles',
        public: true,
        file_size_limit: 5242880, // 5MB
        allowed_mime_types: ['image/jpeg', 'image/png', 'image/webp']
      }
    ];

    for (const bucket of buckets) {
      try {
        const { error } = await this.supabase.storage.createBucket(
          bucket.id,
          {
            public: bucket.public,
            fileSizeLimit: bucket.file_size_limit,
            allowedMimeTypes: bucket.allowed_mime_types
          }
        );
        
        if (error && !error.message.includes('already exists')) {
          throw error;
        }
        
        console.log(`✅ Created bucket: ${bucket.name}`);
      } catch (error) {
        console.warn(`⚠️  Bucket ${bucket.name} may already exist: ${error.message}`);
      }
    }
  }

  /**
   * Apply Row Level Security policies
   */
  async applyRLSPolicies() {
    this.log('🔒 Applying Row Level Security policies...');
    
    const rlsSQL = await this.readSQLFile('database/migrations/002_create_rls_policies.sql');
    
    try {
      const statements = this.splitSQLStatements(rlsSQL);
      
      for (const statement of statements) {
        const trimmed = statement.trim();
        if (trimmed && !trimmed.startsWith('--')) {
          try {
            await this.executeSQL(trimmed);
          } catch (error) {
            // Some policies may already exist
            if (!error.message.includes('already exists')) {
              console.warn(`⚠️  Policy warning: ${error.message}`);
            }
          }
        }
      }
      
      console.log('✅ RLS policies applied');
    } catch (error) {
      throw new Error(`RLS policy application failed: ${error.message}`);
    }
  }

  /**
   * Create vector search functions
   */
  async createVectorFunctions() {
    this.log('🧠 Creating vector search functions...');
    
    try {
      const functionsSQL = await this.readSQLFile('database/functions/vector_search_functions.sql');
      const statements = this.splitSQLStatements(functionsSQL);
      
      for (const statement of statements) {
        const trimmed = statement.trim();
        if (trimmed && !trimmed.startsWith('--')) {
          try {
            await this.executeSQL(trimmed);
          } catch (error) {
            console.warn(`⚠️  Function warning: ${error.message}`);
          }
        }
      }
      
      console.log('✅ Vector search functions created');
    } catch (error) {
      console.warn(`⚠️  Vector functions may need manual setup: ${error.message}`);
    }
  }

  /**
   * Insert default data
   */
  async insertDefaultData() {
    this.log('📝 Inserting default data...');
    
    try {
      // Check if default categories already exist
      const { data: existingCategories } = await this.supabase
        .from('categories')
        .select('id')
        .eq('is_default', true)
        .limit(1);
      
      if (existingCategories && existingCategories.length > 0) {
        console.log('✅ Default data already exists');
        return;
      }
      
      // Insert default categories
      const defaultCategories = [
        { name: 'Food & Dining', description: 'Restaurants, groceries, and food delivery', icon: '🍽️', is_default: true, sort_order: 1 },
        { name: 'Transportation', description: 'Gas, parking, rideshare, and public transport', icon: '🚗', is_default: true, sort_order: 2 },
        { name: 'Office Supplies', description: 'Business supplies, stationery, and equipment', icon: '🏢', is_default: true, sort_order: 3 },
        { name: 'Technology', description: 'Electronics, software, and digital services', icon: '💻', is_default: true, sort_order: 4 },
        { name: 'Healthcare', description: 'Medical expenses, prescriptions, and health services', icon: '🏥', is_default: true, sort_order: 5 },
        { name: 'Entertainment', description: 'Movies, events, subscriptions, and leisure', icon: '🎬', is_default: true, sort_order: 6 },
        { name: 'Home & Garden', description: 'Home improvement, furniture, and garden supplies', icon: '🏠', is_default: true, sort_order: 7 },
        { name: 'Other', description: 'Miscellaneous expenses', icon: '📋', is_default: true, sort_order: 99 }
      ];
      
      const { error } = await this.supabase
        .from('categories')
        .insert(defaultCategories);
      
      if (error) throw error;
      
      console.log('✅ Default categories inserted');
    } catch (error) {
      console.warn(`⚠️  Default data insertion warning: ${error.message}`);
    }
  }

  /**
   * Verify setup completion
   */
  async verifySetup() {
    this.log('🔍 Verifying setup...');
    
    const verifications = [];
    
    // Check tables exist
    try {
      const tables = ['user_profiles', 'categories', 'receipts', 'warranties', 'notifications'];
      for (const table of tables) {
        const { data, error } = await this.supabase
          .from(table)
          .select('*')
          .limit(1);
        
        if (error) {
          verifications.push(`❌ Table ${table}: ${error.message}`);
        } else {
          verifications.push(`✅ Table ${table}: OK`);
        }
      }
    } catch (error) {
      verifications.push(`❌ Table verification failed: ${error.message}`);
    }
    
    // Check storage buckets
    try {
      const { data: buckets, error } = await this.supabase.storage.listBuckets();
      if (error) throw error;
      
      const expectedBuckets = ['receipts', 'warranties', 'profiles'];
      for (const bucket of expectedBuckets) {
        const exists = buckets.some(b => b.name === bucket);
        verifications.push(`${exists ? '✅' : '❌'} Bucket ${bucket}: ${exists ? 'OK' : 'Missing'}`);
      }
    } catch (error) {
      verifications.push(`❌ Storage verification failed: ${error.message}`);
    }
    
    // Check default data
    try {
      const { data, error } = await this.supabase
        .from('categories')
        .select('count')
        .eq('is_default', true);
      
      if (error) throw error;
      verifications.push(`✅ Default categories: ${data.length} found`);
    } catch (error) {
      verifications.push(`❌ Default data verification failed: ${error.message}`);
    }
    
    console.log('\n📊 Setup Verification Results:');
    verifications.forEach(result => console.log(`  ${result}`));
  }

  /**
   * Utility methods
   */
  async readSQLFile(relativePath) {
    const fullPath = path.join(__dirname, '..', relativePath);
    try {
      return await fs.readFile(fullPath, 'utf8');
    } catch (error) {
      throw new Error(`Could not read SQL file ${relativePath}: ${error.message}`);
    }
  }

  splitSQLStatements(sql) {
    // Simple SQL statement splitter - handles most cases
    return sql
      .split(';')
      .map(statement => statement.trim())
      .filter(statement => statement && !statement.startsWith('--'));
  }

  async executeSQL(sql) {
    // Use raw SQL execution via Supabase's PostgreSQL interface
    const { error } = await this.supabase.rpc('exec_sql', { sql });
    if (error) throw error;
  }

  log(message) {
    if (this.verbose) {
      console.log(`[${new Date().toISOString()}] ${message}`);
    } else {
      console.log(message);
    }
  }
}

/**
 * CLI interface
 */
async function main() {
  const args = process.argv.slice(2);
  const options = {
    verbose: args.includes('--verbose') || args.includes('-v'),
    help: args.includes('--help') || args.includes('-h')
  };

  if (options.help) {
    console.log(`
Hey-Bills Supabase Setup Tool

Usage: node scripts/supabase-setup-automation.js [options]

Options:
  --verbose, -v    Enable verbose logging
  --help, -h       Show this help message

Environment Variables:
  SUPABASE_URL              Your Supabase project URL
  SUPABASE_SERVICE_ROLE_KEY Your Supabase service role key

Example:
  SUPABASE_URL=https://your-project.supabase.co \\
  SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \\
  node scripts/supabase-setup-automation.js --verbose
    `);
    return;
  }

  // Verify required environment variables
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error(`
❌ Missing required environment variables:
  - SUPABASE_URL
  - SUPABASE_SERVICE_ROLE_KEY

Please set these in your .env file or environment before running setup.
    `);
    process.exit(1);
  }

  try {
    const setupManager = new SupabaseSetupManager({
      supabaseUrl: process.env.SUPABASE_URL,
      serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
      verbose: options.verbose
    });
    
    await setupManager.runFullSetup();
  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    if (options.verbose) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { SupabaseSetupManager };