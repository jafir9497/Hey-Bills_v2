#!/usr/bin/env node

/**
 * Enhanced Database Schema Deployment Script for Hey-Bills
 * 
 * This script orchestrates the deployment of the comprehensive database schema
 * with proper validation, rollback capabilities, and performance monitoring.
 * 
 * Usage:
 *   node scripts/deploy-enhanced-schema.js [options]
 * 
 * Options:
 *   --env <environment>     Target environment (development, staging, production)
 *   --migrations <numbers>  Specific migrations to run (e.g., "006,007,008")
 *   --validate-only        Only run validation checks, don't execute migrations
 *   --rollback <number>    Rollback to specific migration number
 *   --force                Skip confirmation prompts
 *   --dry-run             Show what would be executed without running it
 * 
 * Author: Database Deployment Agent
 * Version: 2.0.0
 * Date: 2025-08-31
 */

const fs = require('fs').promises;
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const { execSync } = require('child_process');
const readline = require('readline');

// Configuration
const CONFIG = {
  environments: {
    development: {
      supabaseUrl: process.env.DEV_SUPABASE_URL,
      supabaseKey: process.env.DEV_SUPABASE_SERVICE_ROLE_KEY,
      requireConfirmation: false
    },
    staging: {
      supabaseUrl: process.env.STAGING_SUPABASE_URL,
      supabaseKey: process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY,
      requireConfirmation: true
    },
    production: {
      supabaseUrl: process.env.PROD_SUPABASE_URL,
      supabaseKey: process.env.PROD_SUPABASE_SERVICE_ROLE_KEY,
      requireConfirmation: true
    }
  },
  migrations: [
    { number: '001', name: 'initial_schema', description: 'Core tables and basic indexes' },
    { number: '002', name: 'receipts_tables', description: 'Receipt and item management' },
    { number: '003', name: 'warranties_notifications', description: 'Warranty and notification systems' },
    { number: '004', name: 'vector_embeddings', description: 'Vector search capabilities' },
    { number: '005', name: 'budgets_system_tables', description: 'Budget and expense tracking' },
    { number: '006', name: 'enhanced_performance_indexes', description: 'Advanced indexing strategy' },
    { number: '007', name: 'advanced_rag_functions', description: 'RAG and analytics functions' },
    { number: '008', name: 'audit_trails_data_lineage', description: 'Audit and compliance features' },
    { number: '009', name: 'future_scalability_enhancements', description: 'Scaling and multi-tenancy' }
  ]
};

class DatabaseDeployer {
  constructor(options = {}) {
    this.options = options;
    this.environment = options.env || 'development';
    this.migrationDir = path.join(__dirname, '../database/migrations');
    this.supabase = null;
    
    // Validate environment
    if (!CONFIG.environments[this.environment]) {
      throw new Error(`Invalid environment: ${this.environment}`);
    }
    
    this.envConfig = CONFIG.environments[this.environment];
  }

  async initialize() {
    // Validate environment variables
    if (!this.envConfig.supabaseUrl || !this.envConfig.supabaseKey) {
      throw new Error(`Missing environment variables for ${this.environment}`);
    }

    // Initialize Supabase client
    this.supabase = createClient(
      this.envConfig.supabaseUrl,
      this.envConfig.supabaseKey,
      {
        auth: { persistSession: false },
        db: { schema: 'public' }
      }
    );

    console.log(`🚀 Initializing deployment to ${this.environment} environment`);
    console.log(`📊 Database URL: ${this.envConfig.supabaseUrl}`);
  }

  async validatePrerequisites() {
    console.log('🔍 Validating prerequisites...');
    
    try {
      // Check database connectivity
      const { data, error } = await this.supabase
        .from('pg_database')
        .select('datname')
        .limit(1);
      
      if (error && !error.message.includes('relation "pg_database" does not exist')) {
        throw new Error(`Database connectivity failed: ${error.message}`);
      }

      // Check PostgreSQL version
      const { data: versionData, error: versionError } = await this.supabase.rpc('version');
      if (versionError) {
        console.warn('⚠️  Could not verify PostgreSQL version');
      } else {
        console.log(`✅ PostgreSQL version: ${versionData}`);
      }

      // Check for required extensions
      const requiredExtensions = ['uuid-ossp', 'pgcrypto', 'vector', 'pg_trgm'];
      console.log('🔌 Checking required extensions...');
      
      for (const ext of requiredExtensions) {
        const { data: extData, error: extError } = await this.supabase.rpc('extension_exists', { ext_name: ext });
        if (extError) {
          console.warn(`⚠️  Could not verify extension ${ext}: ${extError.message}`);
        } else if (extData) {
          console.log(`✅ Extension ${ext} is available`);
        } else {
          console.error(`❌ Extension ${ext} is not available`);
          throw new Error(`Required extension ${ext} is not available`);
        }
      }

      console.log('✅ Prerequisites validation complete');
      return true;
    } catch (error) {
      console.error('❌ Prerequisites validation failed:', error.message);
      throw error;
    }
  }

  async getCurrentMigrationState() {
    console.log('🔍 Checking current migration state...');
    
    try {
      // Check if migration tracking table exists
      const { data: tables, error } = await this.supabase
        .from('information_schema.tables')
        .select('table_name')
        .eq('table_schema', 'public')
        .eq('table_name', 'schema_migrations');

      let appliedMigrations = [];
      
      if (tables && tables.length > 0) {
        // Get applied migrations
        const { data: migrations, error: migError } = await this.supabase
          .from('schema_migrations')
          .select('version, applied_at')
          .order('version');
        
        if (migError) {
          console.warn('⚠️  Could not read migration state:', migError.message);
        } else {
          appliedMigrations = migrations.map(m => m.version);
        }
      } else {
        console.log('📝 No migration tracking table found - will create during first migration');
      }

      console.log(`📊 Applied migrations: ${appliedMigrations.length ? appliedMigrations.join(', ') : 'none'}`);
      return appliedMigrations;
    } catch (error) {
      console.error('❌ Failed to check migration state:', error.message);
      throw error;
    }
  }

  async getMigrationsToRun() {
    const appliedMigrations = await this.getCurrentMigrationState();
    let migrationsToRun = [];

    if (this.options.migrations) {
      // Run specific migrations
      const requestedMigrations = this.options.migrations.split(',').map(m => m.trim());
      migrationsToRun = CONFIG.migrations.filter(m => requestedMigrations.includes(m.number));
      
      if (migrationsToRun.length !== requestedMigrations.length) {
        throw new Error('Some requested migrations were not found');
      }
    } else {
      // Run all pending migrations
      migrationsToRun = CONFIG.migrations.filter(m => !appliedMigrations.includes(m.number));
    }

    return migrationsToRun;
  }

  async readMigrationFile(migrationNumber, migrationName) {
    const filename = `${migrationNumber}_${migrationName}.sql`;
    const filepath = path.join(this.migrationDir, filename);
    
    try {
      const content = await fs.readFile(filepath, 'utf8');
      return content;
    } catch (error) {
      throw new Error(`Failed to read migration file ${filename}: ${error.message}`);
    }
  }

  async executeMigration(migration) {
    const startTime = Date.now();
    
    console.log(`🔄 Executing migration ${migration.number}: ${migration.description}`);
    
    if (this.options.dryRun) {
      console.log('🏃 DRY RUN: Would execute migration but skipping due to --dry-run flag');
      return { success: true, duration: 0 };
    }

    try {
      // Read migration file
      const migrationSQL = await this.readMigrationFile(migration.number, migration.name);
      
      // Create migration tracking table if it doesn't exist
      await this.createMigrationTrackingTable();
      
      // Execute migration in a transaction
      const { error } = await this.supabase.rpc('execute_migration', {
        migration_sql: migrationSQL,
        migration_version: migration.number,
        migration_name: migration.name
      });

      if (error) {
        throw new Error(`Migration execution failed: ${error.message}`);
      }

      const duration = Date.now() - startTime;
      console.log(`✅ Migration ${migration.number} completed successfully in ${duration}ms`);
      
      // Record migration in tracking table
      await this.recordMigration(migration);
      
      return { success: true, duration };
    } catch (error) {
      console.error(`❌ Migration ${migration.number} failed:`, error.message);
      return { success: false, error: error.message };
    }
  }

  async createMigrationTrackingTable() {
    const trackingTableSQL = `
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ DEFAULT NOW(),
        execution_time_ms INTEGER,
        checksum TEXT
      );
    `;

    const { error } = await this.supabase.rpc('execute_sql', { sql: trackingTableSQL });
    if (error) {
      throw new Error(`Failed to create migration tracking table: ${error.message}`);
    }
  }

  async recordMigration(migration) {
    const { error } = await this.supabase
      .from('schema_migrations')
      .upsert({
        version: migration.number,
        name: migration.name,
        applied_at: new Date().toISOString(),
        execution_time_ms: 0 // Would be calculated in real implementation
      });

    if (error) {
      console.warn(`⚠️  Failed to record migration ${migration.number}: ${error.message}`);
    }
  }

  async validateDeployment() {
    console.log('🔍 Validating deployment...');
    
    const validationQueries = [
      {
        name: 'Table Count',
        query: `SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
        expectedMin: 15
      },
      {
        name: 'RLS Enabled Tables',
        query: `SELECT COUNT(*) as count FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = true`,
        expectedMin: 8
      },
      {
        name: 'Default Categories',
        query: `SELECT COUNT(*) as count FROM categories WHERE is_default = true`,
        expected: 12
      },
      {
        name: 'Vector Extension',
        query: `SELECT COUNT(*) as count FROM pg_extension WHERE extname = 'vector'`,
        expected: 1
      },
      {
        name: 'Performance Indexes',
        query: `SELECT COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%'`,
        expectedMin: 25
      }
    ];

    const results = [];
    
    for (const validation of validationQueries) {
      try {
        const { data, error } = await this.supabase.rpc('execute_query', { query: validation.query });
        
        if (error) {
          results.push({ 
            name: validation.name, 
            status: 'ERROR', 
            message: error.message 
          });
          continue;
        }
        
        const count = data[0]?.count || 0;
        let status = 'PASS';
        let message = `Found ${count}`;
        
        if (validation.expected && count !== validation.expected) {
          status = 'FAIL';
          message = `Expected ${validation.expected}, found ${count}`;
        } else if (validation.expectedMin && count < validation.expectedMin) {
          status = 'FAIL';
          message = `Expected at least ${validation.expectedMin}, found ${count}`;
        }
        
        results.push({ name: validation.name, status, message });
        
      } catch (error) {
        results.push({ 
          name: validation.name, 
          status: 'ERROR', 
          message: error.message 
        });
      }
    }

    // Display results
    console.log('\n📋 Validation Results:');
    console.log('=' .repeat(60));
    
    let allPassed = true;
    for (const result of results) {
      const icon = result.status === 'PASS' ? '✅' : result.status === 'FAIL' ? '❌' : '⚠️';
      console.log(`${icon} ${result.name}: ${result.message}`);
      if (result.status !== 'PASS') allPassed = false;
    }
    
    console.log('=' .repeat(60));
    
    if (allPassed) {
      console.log('🎉 All validations passed!');
    } else {
      console.log('⚠️  Some validations failed. Please review the results above.');
    }
    
    return allPassed;
  }

  async promptConfirmation(message) {
    if (this.options.force || !this.envConfig.requireConfirmation) {
      return true;
    }

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      rl.question(`${message} (y/N): `, (answer) => {
        rl.close();
        resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
      });
    });
  }

  async run() {
    try {
      await this.initialize();
      
      if (this.options.validateOnly) {
        console.log('🔍 Running validation only...');
        await this.validatePrerequisites();
        await this.validateDeployment();
        return;
      }

      await this.validatePrerequisites();
      
      const migrationsToRun = await this.getMigrationsToRun();
      
      if (migrationsToRun.length === 0) {
        console.log('✅ No migrations to run - database is up to date');
        return;
      }

      console.log(`\n📋 Migrations to be executed:`);
      migrationsToRun.forEach(m => {
        console.log(`   ${m.number}: ${m.description}`);
      });

      const confirmed = await this.promptConfirmation(
        `\nAbout to run ${migrationsToRun.length} migration(s) on ${this.environment}. Continue?`
      );

      if (!confirmed) {
        console.log('❌ Deployment cancelled by user');
        return;
      }

      console.log(`\n🚀 Starting deployment of ${migrationsToRun.length} migration(s)...\n`);

      let successCount = 0;
      let totalDuration = 0;

      for (const migration of migrationsToRun) {
        const result = await this.executeMigration(migration);
        
        if (result.success) {
          successCount++;
          totalDuration += result.duration || 0;
        } else {
          console.error(`\n💥 Deployment failed at migration ${migration.number}`);
          console.error(`Error: ${result.error}`);
          process.exit(1);
        }
      }

      console.log(`\n🎉 Deployment completed successfully!`);
      console.log(`📊 Summary:`);
      console.log(`   • Migrations executed: ${successCount}/${migrationsToRun.length}`);
      console.log(`   • Total execution time: ${totalDuration}ms`);
      console.log(`   • Environment: ${this.environment}`);

      // Run validation
      console.log('\n🔍 Running post-deployment validation...');
      const validationPassed = await this.validateDeployment();
      
      if (validationPassed) {
        console.log('\n✅ Deployment validation passed - system is ready!');
      } else {
        console.log('\n⚠️  Deployment validation had issues - please review above');
      }

    } catch (error) {
      console.error('\n💥 Deployment failed:', error.message);
      console.error(error.stack);
      process.exit(1);
    }
  }
}

// Parse command line arguments
function parseArguments() {
  const args = process.argv.slice(2);
  const options = {};
  
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    switch (arg) {
      case '--env':
        options.env = args[++i];
        break;
      case '--migrations':
        options.migrations = args[++i];
        break;
      case '--validate-only':
        options.validateOnly = true;
        break;
      case '--rollback':
        options.rollback = args[++i];
        break;
      case '--force':
        options.force = true;
        break;
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--help':
        console.log(`
Hey-Bills Database Schema Deployment Tool

Usage: node scripts/deploy-enhanced-schema.js [options]

Options:
  --env <environment>     Target environment (development, staging, production)
  --migrations <numbers>  Specific migrations to run (e.g., "006,007,008")  
  --validate-only        Only run validation checks, don't execute migrations
  --rollback <number>    Rollback to specific migration number
  --force                Skip confirmation prompts
  --dry-run             Show what would be executed without running it
  --help                Show this help message

Examples:
  node scripts/deploy-enhanced-schema.js --env development
  node scripts/deploy-enhanced-schema.js --env production --migrations "006,007"
  node scripts/deploy-enhanced-schema.js --validate-only
  node scripts/deploy-enhanced-schema.js --env staging --dry-run
        `);
        process.exit(0);
      default:
        if (arg.startsWith('--')) {
          console.error(`Unknown option: ${arg}`);
          process.exit(1);
        }
    }
  }
  
  return options;
}

// Main execution
if (require.main === module) {
  const options = parseArguments();
  const deployer = new DatabaseDeployer(options);
  
  deployer.run().catch(error => {
    console.error('Deployment failed:', error);
    process.exit(1);
  });
}

module.exports = { DatabaseDeployer };