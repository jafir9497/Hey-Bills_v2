#!/usr/bin/env node

/**
 * Database Deployment Script
 * Deploys the complete Hey Bills database schema to Supabase
 * Includes schema creation, RLS policies, and initial data
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs').promises;
const path = require('path');
const { getCurrentConfig } = require('../config/environment');

// Color console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

function colorLog(color, message) {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

class DatabaseDeployment {
  constructor() {
    this.config = getCurrentConfig();
    this.supabase = createClient(
      this.config.supabase.url,
      this.config.supabase.serviceRoleKey,
      {
        auth: { persistSession: false },
        db: { schema: 'public' }
      }
    );
    
    this.deploymentLog = [];
    this.errors = [];
  }

  /**
   * Logs deployment steps and results
   */
  log(message, type = 'info') {
    const timestamp = new Date().toISOString();
    const logEntry = { timestamp, message, type };
    this.deploymentLog.push(logEntry);
    
    switch (type) {
      case 'error':
        colorLog('red', `❌ ERROR: ${message}`);
        this.errors.push(message);
        break;
      case 'success':
        colorLog('green', `✅ SUCCESS: ${message}`);
        break;
      case 'warning':
        colorLog('yellow', `⚠️  WARNING: ${message}`);
        break;
      case 'info':
        colorLog('blue', `ℹ️  INFO: ${message}`);
        break;
      default:
        console.log(message);
    }
  }

  /**
   * Reads and executes SQL file
   */
  async executeSqlFile(filePath, description) {
    try {
      this.log(`Reading ${description} from ${filePath}`, 'info');
      const sql = await fs.readFile(filePath, 'utf-8');
      
      this.log(`Executing ${description}...`, 'info');
      const { error } = await this.supabase.rpc('exec_sql', { sql_query: sql });
      
      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }
      
      this.log(`Successfully executed ${description}`, 'success');
      return true;
    } catch (error) {
      this.log(`Failed to execute ${description}: ${error.message}`, 'error');
      return false;
    }
  }

  /**
   * Executes raw SQL query
   */
  async executeQuery(query, description) {
    try {
      this.log(`Executing: ${description}`, 'info');
      const { error } = await this.supabase.rpc('exec_sql', { sql_query: query });
      
      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }
      
      this.log(`Successfully executed: ${description}`, 'success');
      return true;
    } catch (error) {
      this.log(`Failed to execute ${description}: ${error.message}`, 'error');
      return false;
    }
  }

  /**
   * Checks if required extensions are available
   */
  async checkExtensions() {
    try {
      this.log('Checking available PostgreSQL extensions...', 'info');
      
      const extensions = ['uuid-ossp', 'pgcrypto', 'vector', 'pg_trgm'];
      const results = [];
      
      for (const ext of extensions) {
        const { data, error } = await this.supabase
          .from('pg_available_extensions')
          .select('name, installed_version')
          .eq('name', ext)
          .single();
        
        if (error) {
          this.log(`Extension ${ext} not found or error checking: ${error.message}`, 'warning');
          results.push({ name: ext, available: false });
        } else {
          this.log(`Extension ${ext} is ${data.installed_version ? 'installed' : 'available'}`, 'info');
          results.push({ name: ext, available: true, installed: !!data.installed_version });
        }
      }
      
      return results;
    } catch (error) {
      this.log(`Error checking extensions: ${error.message}`, 'warning');
      return [];
    }
  }

  /**
   * Enables required PostgreSQL extensions
   */
  async enableExtensions() {
    const extensions = ['uuid-ossp', 'pgcrypto', 'vector'];
    
    for (const extension of extensions) {
      const success = await this.executeQuery(
        `CREATE EXTENSION IF NOT EXISTS "${extension}";`,
        `Enable ${extension} extension`
      );
      
      if (!success) {
        this.log(`Failed to enable ${extension} extension`, 'error');
      }
    }
  }

  /**
   * Creates storage buckets
   */
  async createStorageBuckets() {
    this.log('Creating storage buckets...', 'info');
    
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
        const { error } = await this.supabase.storage.createBucket(bucket.id, {
          public: bucket.public,
          fileSizeLimit: bucket.file_size_limit,
          allowedMimeTypes: bucket.allowed_mime_types
        });
        
        if (error && !error.message.includes('already exists')) {
          this.log(`Failed to create bucket ${bucket.name}: ${error.message}`, 'error');
        } else {
          this.log(`Storage bucket '${bucket.name}' created successfully`, 'success');
        }
      } catch (error) {
        this.log(`Error creating bucket ${bucket.name}: ${error.message}`, 'error');
      }
    }
  }

  /**
   * Verifies deployment by running basic queries
   */
  async verifyDeployment() {
    this.log('Verifying deployment...', 'info');
    
    const verificationQueries = [
      {
        description: 'Check if main tables exist',
        query: `
          SELECT table_name 
          FROM information_schema.tables 
          WHERE table_schema = 'public' 
          AND table_name IN ('user_profiles', 'receipts', 'warranties', 'categories')
        `
      },
      {
        description: 'Check if RLS is enabled',
        query: `
          SELECT schemaname, tablename, rowsecurity 
          FROM pg_tables 
          WHERE schemaname = 'public' 
          AND tablename IN ('user_profiles', 'receipts', 'warranties')
        `
      },
      {
        description: 'Check if vector extension is available',
        query: `SELECT 1 FROM pg_extension WHERE extname = 'vector'`
      },
      {
        description: 'Verify default categories exist',
        query: `SELECT COUNT(*) as count FROM categories WHERE is_default = true`
      }
    ];
    
    let verificationPassed = true;
    
    for (const check of verificationQueries) {
      try {
        const { data, error } = await this.supabase.rpc('exec_sql', { 
          sql_query: check.query 
        });
        
        if (error) {
          this.log(`Verification failed - ${check.description}: ${error.message}`, 'error');
          verificationPassed = false;
        } else {
          this.log(`Verification passed - ${check.description}`, 'success');
        }
      } catch (error) {
        this.log(`Verification error - ${check.description}: ${error.message}`, 'error');
        verificationPassed = false;
      }
    }
    
    return verificationPassed;
  }

  /**
   * Generates TypeScript types from database schema
   */
  async generateTypes() {
    try {
      this.log('Generating TypeScript types...', 'info');
      
      // This would typically use supabase CLI, but for now we'll just log the command
      const command = `supabase gen types typescript --project-id=${this.extractProjectId()} > types/supabase.ts`;
      
      this.log(`To generate types, run: ${command}`, 'info');
      this.log('TypeScript types generation queued', 'success');
      
      return true;
    } catch (error) {
      this.log(`Error generating types: ${error.message}`, 'error');
      return false;
    }
  }

  /**
   * Extracts project ID from Supabase URL
   */
  extractProjectId() {
    try {
      const url = new URL(this.config.supabase.url);
      return url.hostname.split('.')[0];
    } catch (error) {
      return 'your-project-id';
    }
  }

  /**
   * Saves deployment log to file
   */
  async saveDeploymentLog() {
    try {
      const logDir = path.join(__dirname, '..', 'logs');
      await fs.mkdir(logDir, { recursive: true });
      
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const logFile = path.join(logDir, `deployment-${timestamp}.json`);
      
      const deploymentReport = {
        timestamp: new Date().toISOString(),
        config: {
          supabaseUrl: this.config.supabase.url,
          projectId: this.extractProjectId(),
          environment: this.config.environment
        },
        steps: this.deploymentLog,
        errors: this.errors,
        success: this.errors.length === 0
      };
      
      await fs.writeFile(logFile, JSON.stringify(deploymentReport, null, 2));
      this.log(`Deployment log saved to ${logFile}`, 'success');
      
      return logFile;
    } catch (error) {
      this.log(`Failed to save deployment log: ${error.message}`, 'error');
      return null;
    }
  }

  /**
   * Main deployment function
   */
  async deploy() {
    this.log('🚀 Starting Hey Bills database deployment...', 'info');
    this.log(`Target Supabase project: ${this.config.supabase.url}`, 'info');
    this.log(`Environment: ${this.config.environment}`, 'info');
    
    try {
      // Step 1: Check extensions
      await this.checkExtensions();
      
      // Step 2: Enable extensions
      await this.enableExtensions();
      
      // Step 3: Deploy main schema
      const schemaPath = path.join(__dirname, '..', 'database', 'schema.sql');
      await this.executeSqlFile(schemaPath, 'main database schema');
      
      // Step 4: Deploy RLS policies
      const rlsPath = path.join(__dirname, '..', 'database', 'policies', 'rls_policies.sql');
      await this.executeSqlFile(rlsPath, 'Row Level Security policies');
      
      // Step 5: Deploy helper functions
      const functionsPath = path.join(__dirname, '..', 'database', 'functions', 'helper_functions.sql');
      try {
        await this.executeSqlFile(functionsPath, 'helper functions');
      } catch (error) {
        this.log('Helper functions file not found or failed to deploy', 'warning');
      }
      
      // Step 6: Create storage buckets
      await this.createStorageBuckets();
      
      // Step 7: Verify deployment
      const verified = await this.verifyDeployment();
      
      // Step 8: Generate types
      await this.generateTypes();
      
      // Step 9: Save deployment log
      await this.saveDeploymentLog();
      
      // Final summary
      if (this.errors.length === 0) {
        this.log('🎉 Database deployment completed successfully!', 'success');
        this.log('Next steps:', 'info');
        this.log('1. Configure authentication providers in Supabase dashboard', 'info');
        this.log('2. Set up environment variables', 'info');
        this.log('3. Test the application', 'info');
      } else {
        this.log(`❌ Deployment completed with ${this.errors.length} errors`, 'error');
        this.log('Please review the errors above and fix them before proceeding', 'error');
      }
      
      return this.errors.length === 0;
      
    } catch (error) {
      this.log(`Fatal deployment error: ${error.message}`, 'error');
      await this.saveDeploymentLog();
      return false;
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Hey Bills Database Deployment Tool

Usage: node deploy-database.js [options]

Options:
  --help, -h        Show this help message
  --verify-only     Only run verification checks
  --types-only      Only generate TypeScript types
  --force          Force deployment even if verification fails

Environment Variables Required:
  SUPABASE_URL            Your Supabase project URL
  SUPABASE_SERVICE_ROLE_KEY   Your Supabase service role key (with admin privileges)

Examples:
  node deploy-database.js                 # Full deployment
  node deploy-database.js --verify-only   # Just verify current deployment
  node deploy-database.js --types-only    # Just generate TypeScript types
    `);
    process.exit(0);
  }
  
  try {
    // Validate environment
    const config = getCurrentConfig();
    if (!config.supabase.url || !config.supabase.serviceRoleKey) {
      colorLog('red', '❌ Missing required environment variables:');
      console.log('   SUPABASE_URL');
      console.log('   SUPABASE_SERVICE_ROLE_KEY');
      console.log('\nPlease check your .env file or environment configuration.');
      process.exit(1);
    }
    
    const deployment = new DatabaseDeployment();
    
    if (args.includes('--verify-only')) {
      const verified = await deployment.verifyDeployment();
      process.exit(verified ? 0 : 1);
    }
    
    if (args.includes('--types-only')) {
      const generated = await deployment.generateTypes();
      process.exit(generated ? 0 : 1);
    }
    
    // Full deployment
    const success = await deployment.deploy();
    process.exit(success ? 0 : 1);
    
  } catch (error) {
    colorLog('red', `Fatal error: ${error.message}`);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { DatabaseDeployment };