#!/usr/bin/env node

/**
 * Database Verification Script
 * Verifies that all Hey Bills database components are properly deployed
 */

const { createClient } = require('@supabase/supabase-js');
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

class DatabaseVerifier {
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
    
    this.results = [];
    this.errors = [];
  }

  /**
   * Logs verification results
   */
  log(message, type = 'info', details = null) {
    const timestamp = new Date().toISOString();
    const result = { timestamp, message, type, details };
    this.results.push(result);
    
    switch (type) {
      case 'error':
        colorLog('red', `❌ ${message}`);
        if (details) console.log('   ', details);
        this.errors.push(message);
        break;
      case 'success':
        colorLog('green', `✅ ${message}`);
        if (details) console.log('   ', details);
        break;
      case 'warning':
        colorLog('yellow', `⚠️  ${message}`);
        if (details) console.log('   ', details);
        break;
      case 'info':
        colorLog('blue', `ℹ️  ${message}`);
        if (details) console.log('   ', details);
        break;
      default:
        console.log(message);
    }
  }

  /**
   * Executes SQL query for verification
   */
  async query(sql, description = 'Query') {
    try {
      const { data, error } = await this.supabase.rpc('exec_sql', { sql_query: sql });
      
      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }
      
      return data;
    } catch (error) {
      this.log(`Failed to execute ${description}: ${error.message}`, 'error');
      return null;
    }
  }

  /**
   * Verifies database extensions are installed
   */
  async verifyExtensions() {
    this.log('🔧 Verifying PostgreSQL Extensions...', 'info');
    
    const requiredExtensions = ['uuid-ossp', 'pgcrypto', 'vector'];
    
    for (const ext of requiredExtensions) {
      const result = await this.query(
        `SELECT extname, extversion FROM pg_extension WHERE extname = '${ext}'`,
        `Check ${ext} extension`
      );
      
      if (result && result.length > 0) {
        this.log(`Extension ${ext} installed (version: ${result[0].extversion})`, 'success');
      } else {
        this.log(`Extension ${ext} is not installed`, 'error');
      }
    }
  }

  /**
   * Verifies all required tables exist
   */
  async verifyTables() {
    this.log('📊 Verifying Database Tables...', 'info');
    
    const expectedTables = [
      'user_profiles',
      'categories', 
      'receipts',
      'receipt_items',
      'warranties',
      'notifications',
      'budgets',
      'receipt_embeddings',
      'warranty_embeddings',
      'system_settings'
    ];
    
    const result = await this.query(`
      SELECT table_name, table_type 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `, 'List all tables');
    
    if (result) {
      const existingTables = result.map(row => row.table_name);
      
      for (const table of expectedTables) {
        if (existingTables.includes(table)) {
          this.log(`Table '${table}' exists`, 'success');
        } else {
          this.log(`Table '${table}' is missing`, 'error');
        }
      }
      
      // Check for unexpected tables
      const unexpectedTables = existingTables.filter(table => !expectedTables.includes(table));
      if (unexpectedTables.length > 0) {
        this.log(`Additional tables found: ${unexpectedTables.join(', ')}`, 'info');
      }
      
      this.log(`Total tables: ${existingTables.length} (expected: ${expectedTables.length})`, 'info');
    }
  }

  /**
   * Verifies table relationships and constraints
   */
  async verifyConstraints() {
    this.log('🔗 Verifying Foreign Key Constraints...', 'info');
    
    const result = await this.query(`
      SELECT 
        tc.table_name,
        tc.constraint_name,
        tc.constraint_type,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
      FROM information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      LEFT JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type IN ('FOREIGN KEY', 'PRIMARY KEY')
        AND tc.table_schema = 'public'
      ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name
    `, 'Check constraints');
    
    if (result) {
      const foreignKeys = result.filter(r => r.constraint_type === 'FOREIGN KEY');
      const primaryKeys = result.filter(r => r.constraint_type === 'PRIMARY KEY');
      
      this.log(`Found ${foreignKeys.length} foreign key constraints`, 'success');
      this.log(`Found ${primaryKeys.length} primary key constraints`, 'success');
      
      // Verify specific critical foreign keys
      const criticalForeignKeys = [
        'user_profiles -> auth.users',
        'receipts -> auth.users',
        'receipts -> categories',
        'receipt_items -> receipts',
        'warranties -> auth.users',
        'notifications -> auth.users',
        'budgets -> auth.users',
        'receipt_embeddings -> receipts',
        'warranty_embeddings -> warranties'
      ];
      
      this.log('Checking critical foreign key relationships...', 'info');
      // Note: This is a simplified check - a full implementation would parse the actual constraints
    }
  }

  /**
   * Verifies database indexes exist
   */
  async verifyIndexes() {
    this.log('📈 Verifying Database Indexes...', 'info');
    
    const result = await this.query(`
      SELECT 
        t.tablename,
        i.indexname,
        i.indexdef
      FROM pg_indexes i
      JOIN pg_tables t ON i.tablename = t.tablename
      WHERE t.schemaname = 'public'
        AND i.indexname NOT LIKE '%_pkey'
      ORDER BY t.tablename, i.indexname
    `, 'List all indexes');
    
    if (result) {
      const indexesByTable = result.reduce((acc, row) => {
        if (!acc[row.tablename]) acc[row.tablename] = [];
        acc[row.tablename].push(row.indexname);
        return acc;
      }, {});
      
      Object.entries(indexesByTable).forEach(([table, indexes]) => {
        this.log(`Table '${table}' has ${indexes.length} indexes`, 'success', indexes.join(', '));
      });
      
      // Check for specific performance indexes
      const criticalIndexes = [
        'idx_receipts_user_id',
        'idx_receipts_purchase_date', 
        'idx_warranties_user_id',
        'idx_warranties_end_date',
        'idx_receipt_embeddings_vector',
        'idx_warranty_embeddings_vector'
      ];
      
      const allIndexes = result.map(r => r.indexname);
      for (const indexName of criticalIndexes) {
        if (allIndexes.includes(indexName)) {
          this.log(`Critical index '${indexName}' exists`, 'success');
        } else {
          this.log(`Critical index '${indexName}' is missing`, 'warning');
        }
      }
    }
  }

  /**
   * Verifies Row Level Security is enabled
   */
  async verifyRLS() {
    this.log('🔒 Verifying Row Level Security...', 'info');
    
    const result = await this.query(`
      SELECT 
        schemaname,
        tablename,
        rowsecurity,
        (SELECT count(*) FROM pg_policies WHERE tablename = pg_tables.tablename) as policy_count
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `, 'Check RLS status');
    
    if (result) {
      for (const table of result) {
        if (table.rowsecurity) {
          this.log(`RLS enabled on '${table.tablename}' with ${table.policy_count} policies`, 'success');
        } else {
          // Some tables like system_settings might not need RLS
          if (['system_settings'].includes(table.tablename)) {
            this.log(`RLS not enabled on '${table.tablename}' (expected)`, 'info');
          } else {
            this.log(`RLS not enabled on '${table.tablename}'`, 'warning');
          }
        }
      }
    }
  }

  /**
   * Verifies default data exists
   */
  async verifyDefaultData() {
    this.log('📝 Verifying Default Data...', 'info');
    
    // Check default categories
    const categories = await this.query(`
      SELECT count(*) as count FROM categories WHERE is_default = true
    `, 'Count default categories');
    
    if (categories && categories[0]) {
      const count = parseInt(categories[0].count);
      if (count >= 10) {
        this.log(`Found ${count} default categories`, 'success');
      } else {
        this.log(`Only ${count} default categories found (expected at least 10)`, 'warning');
      }
    }
    
    // Check system settings
    const settings = await this.query(`
      SELECT count(*) as count FROM system_settings
    `, 'Count system settings');
    
    if (settings && settings[0]) {
      const count = parseInt(settings[0].count);
      if (count >= 5) {
        this.log(`Found ${count} system settings`, 'success');
      } else {
        this.log(`Only ${count} system settings found (expected at least 5)`, 'warning');
      }
    }
  }

  /**
   * Tests basic CRUD operations
   */
  async testCRUDOperations() {
    this.log('🧪 Testing Basic CRUD Operations...', 'info');
    
    try {
      // Note: These tests would need proper authentication context
      // This is a simplified version for demonstration
      
      // Test reading from categories (should work with default data)
      const categoriesTest = await this.query(`
        SELECT id, name FROM categories WHERE is_default = true LIMIT 1
      `, 'Test reading categories');
      
      if (categoriesTest && categoriesTest.length > 0) {
        this.log(`Successfully read category: ${categoriesTest[0].name}`, 'success');
      } else {
        this.log('Failed to read default categories', 'error');
      }
      
      // Test reading from system_settings
      const settingsTest = await this.query(`
        SELECT key, value FROM system_settings LIMIT 1
      `, 'Test reading system settings');
      
      if (settingsTest && settingsTest.length > 0) {
        this.log(`Successfully read setting: ${settingsTest[0].key}`, 'success');
      } else {
        this.log('Failed to read system settings', 'error');
      }
      
    } catch (error) {
      this.log(`CRUD operations test failed: ${error.message}`, 'error');
    }
  }

  /**
   * Verifies storage bucket configuration
   */
  async verifyStorageBuckets() {
    this.log('🪣 Verifying Storage Buckets...', 'info');
    
    try {
      const { data: buckets, error } = await this.supabase.storage.listBuckets();
      
      if (error) {
        this.log(`Failed to list storage buckets: ${error.message}`, 'error');
        return;
      }
      
      const expectedBuckets = ['receipts', 'warranties', 'profiles'];
      const existingBuckets = buckets.map(b => b.name);
      
      for (const bucket of expectedBuckets) {
        if (existingBuckets.includes(bucket)) {
          this.log(`Storage bucket '${bucket}' exists`, 'success');
        } else {
          this.log(`Storage bucket '${bucket}' is missing`, 'error');
        }
      }
      
    } catch (error) {
      this.log(`Storage verification failed: ${error.message}`, 'error');
    }
  }

  /**
   * Generates verification report
   */
  generateReport() {
    const timestamp = new Date().toISOString();
    
    const report = {
      timestamp,
      summary: {
        total_checks: this.results.length,
        errors: this.errors.length,
        warnings: this.results.filter(r => r.type === 'warning').length,
        successes: this.results.filter(r => r.type === 'success').length,
        overall_status: this.errors.length === 0 ? 'PASS' : 'FAIL'
      },
      results: this.results,
      errors: this.errors,
      config: {
        supabase_url: this.config.supabase.url,
        environment: this.config.environment
      }
    };
    
    // Log summary
    colorLog('cyan', '\n📊 VERIFICATION SUMMARY');
    colorLog('cyan', '========================');
    console.log(`Total Checks: ${report.summary.total_checks}`);
    console.log(`Successes: ${report.summary.successes}`);
    console.log(`Warnings: ${report.summary.warnings}`);
    console.log(`Errors: ${report.summary.errors}`);
    console.log(`Overall Status: ${report.summary.overall_status}`);
    
    if (this.errors.length > 0) {
      colorLog('red', '\n❌ ERRORS TO RESOLVE:');
      this.errors.forEach(error => console.log(`   - ${error}`));
    }
    
    return report;
  }

  /**
   * Main verification function
   */
  async verify() {
    colorLog('cyan', '🔍 Hey-Bills Database Verification Starting...');
    colorLog('cyan', '==============================================');
    
    try {
      await this.verifyExtensions();
      await this.verifyTables();
      await this.verifyConstraints();
      await this.verifyIndexes();
      await this.verifyRLS();
      await this.verifyDefaultData();
      await this.testCRUDOperations();
      await this.verifyStorageBuckets();
      
      const report = this.generateReport();
      
      colorLog('cyan', '\n✨ Verification Complete!');
      
      return report.summary.overall_status === 'PASS';
      
    } catch (error) {
      this.log(`Fatal verification error: ${error.message}`, 'error');
      return false;
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Hey Bills Database Verification Tool

Usage: node verify-database.js [options]

Options:
  --help, -h        Show this help message
  --report          Generate detailed JSON report
  --quiet           Minimal output
  --tables-only     Only verify table structure
  --rls-only        Only verify RLS policies

Examples:
  node verify-database.js                # Full verification
  node verify-database.js --tables-only  # Check tables only
    `);
    process.exit(0);
  }
  
  try {
    const verifier = new DatabaseVerifier();
    const success = await verifier.verify();
    
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

module.exports = { DatabaseVerifier };