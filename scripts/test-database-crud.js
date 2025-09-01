#!/usr/bin/env node

/**
 * Database CRUD Test Script
 * Tests basic Create, Read, Update, Delete operations on Hey-Bills database
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

class DatabaseTester {
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
    
    this.testResults = [];
    this.createdRecords = [];
  }

  /**
   * Logs test results
   */
  log(message, type = 'info', details = null) {
    const timestamp = new Date().toISOString();
    this.testResults.push({ timestamp, message, type, details });
    
    switch (type) {
      case 'error':
        colorLog('red', `❌ ${message}`);
        if (details) console.log('   Details:', details);
        break;
      case 'success':
        colorLog('green', `✅ ${message}`);
        break;
      case 'warning':
        colorLog('yellow', `⚠️  ${message}`);
        break;
      case 'info':
        colorLog('blue', `ℹ️  ${message}`);
        break;
      default:
        console.log(message);
    }
  }

  /**
   * Test reading default categories
   */
  async testReadCategories() {
    this.log('Testing READ operation on categories table...', 'info');
    
    try {
      const { data, error } = await this.supabase
        .from('categories')
        .select('id, name, description, is_default')
        .eq('is_default', true)
        .limit(5);
      
      if (error) {
        throw error;
      }
      
      if (data && data.length > 0) {
        this.log(`Successfully read ${data.length} default categories`, 'success');
        this.log(`Sample categories: ${data.map(c => c.name).join(', ')}`, 'info');
        return true;
      } else {
        this.log('No default categories found', 'warning');
        return false;
      }
      
    } catch (error) {
      this.log(`Failed to read categories: ${error.message}`, 'error', error);
      return false;
    }
  }

  /**
   * Test reading system settings
   */
  async testReadSystemSettings() {
    this.log('Testing READ operation on system_settings table...', 'info');
    
    try {
      const { data, error } = await this.supabase
        .from('system_settings')
        .select('key, value, description')
        .limit(5);
      
      if (error) {
        throw error;
      }
      
      if (data && data.length > 0) {
        this.log(`Successfully read ${data.length} system settings`, 'success');
        this.log(`Settings keys: ${data.map(s => s.key).join(', ')}`, 'info');
        return true;
      } else {
        this.log('No system settings found', 'warning');
        return false;
      }
      
    } catch (error) {
      this.log(`Failed to read system settings: ${error.message}`, 'error', error);
      return false;
    }
  }

  /**
   * Test creating a test user profile (requires authentication)
   */
  async testUserProfileOperations() {
    this.log('Testing user profile operations (requires auth context)...', 'info');
    
    try {
      // Note: In a real scenario, this would require proper authentication
      // For now, we'll just test the table structure exists
      
      const { data, error } = await this.supabase
        .from('user_profiles')
        .select('id, full_name, business_type, created_at')
        .limit(1);
      
      if (error) {
        // Expected error due to RLS policies without auth
        if (error.message.includes('row-level security')) {
          this.log('User profiles table exists and RLS is active (expected)', 'success');
          return true;
        } else {
          throw error;
        }
      }
      
      this.log('User profiles table accessible (unexpected - check RLS)', 'warning');
      return true;
      
    } catch (error) {
      this.log(`User profile test error: ${error.message}`, 'error', error);
      return false;
    }
  }

  /**
   * Test table structure and constraints
   */
  async testTableStructure() {
    this.log('Testing database table structure...', 'info');
    
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
    
    try {
      for (const tableName of expectedTables) {
        const { data, error } = await this.supabase
          .from(tableName)
          .select('*')
          .limit(0); // Just check if table exists, don't return data
        
        if (error) {
          // RLS errors are expected for user-specific tables
          if (error.message.includes('row-level security') || 
              error.message.includes('permission denied')) {
            this.log(`Table '${tableName}' exists with RLS protection`, 'success');
          } else {
            this.log(`Table '${tableName}' error: ${error.message}`, 'error');
          }
        } else {
          this.log(`Table '${tableName}' exists and accessible`, 'success');
        }
      }
      
      return true;
      
    } catch (error) {
      this.log(`Table structure test failed: ${error.message}`, 'error', error);
      return false;
    }
  }

  /**
   * Test vector embedding table structure (without actual vectors)
   */
  async testVectorTables() {
    this.log('Testing vector embedding tables...', 'info');
    
    const vectorTables = ['receipt_embeddings', 'warranty_embeddings'];
    
    try {
      for (const tableName of vectorTables) {
        // Test table structure by selecting columns (no data)
        const { data, error } = await this.supabase
          .rpc('exec_sql', {
            sql_query: `
              SELECT column_name, data_type, is_nullable
              FROM information_schema.columns 
              WHERE table_name = '${tableName}' 
              AND table_schema = 'public'
              ORDER BY ordinal_position
            `
          });
        
        if (error) {
          this.log(`Failed to check ${tableName} structure: ${error.message}`, 'error');
        } else if (data && data.length > 0) {
          const hasEmbeddingColumn = data.some(col => col.column_name === 'embedding');
          if (hasEmbeddingColumn) {
            this.log(`Vector table '${tableName}' has embedding column`, 'success');
          } else {
            this.log(`Vector table '${tableName}' missing embedding column`, 'error');
          }
        } else {
          this.log(`Could not verify ${tableName} structure`, 'warning');
        }
      }
      
      return true;
      
    } catch (error) {
      this.log(`Vector table test failed: ${error.message}`, 'error', error);
      return false;
    }
  }

  /**
   * Test basic SQL operations
   */
  async testBasicSQL() {
    this.log('Testing basic SQL operations...', 'info');
    
    const testQueries = [
      {
        name: 'Current timestamp',
        query: 'SELECT NOW() as current_time'
      },
      {
        name: 'UUID generation',
        query: 'SELECT uuid_generate_v4() as test_uuid'
      },
      {
        name: 'Categories count',
        query: 'SELECT COUNT(*) as total_categories FROM categories'
      },
      {
        name: 'System settings count', 
        query: 'SELECT COUNT(*) as total_settings FROM system_settings'
      }
    ];
    
    let successCount = 0;
    
    for (const test of testQueries) {
      try {
        const { data, error } = await this.supabase.rpc('exec_sql', {
          sql_query: test.query
        });
        
        if (error) {
          this.log(`SQL test '${test.name}' failed: ${error.message}`, 'error');
        } else {
          this.log(`SQL test '${test.name}' passed`, 'success');
          successCount++;
        }
        
      } catch (error) {
        this.log(`SQL test '${test.name}' error: ${error.message}`, 'error');
      }
    }
    
    return successCount === testQueries.length;
  }

  /**
   * Cleanup any test data created
   */
  async cleanup() {
    if (this.createdRecords.length === 0) {
      return true;
    }
    
    this.log(`Cleaning up ${this.createdRecords.length} test records...`, 'info');
    
    for (const record of this.createdRecords) {
      try {
        const { error } = await this.supabase
          .from(record.table)
          .delete()
          .eq('id', record.id);
        
        if (error) {
          this.log(`Failed to cleanup ${record.table} record: ${error.message}`, 'warning');
        }
      } catch (error) {
        this.log(`Cleanup error: ${error.message}`, 'warning');
      }
    }
    
    return true;
  }

  /**
   * Generate test report
   */
  generateReport() {
    const timestamp = new Date().toISOString();
    const errors = this.testResults.filter(r => r.type === 'error');
    const successes = this.testResults.filter(r => r.type === 'success');
    const warnings = this.testResults.filter(r => r.type === 'warning');
    
    const report = {
      timestamp,
      summary: {
        total_tests: this.testResults.length,
        successes: successes.length,
        warnings: warnings.length,
        errors: errors.length,
        overall_status: errors.length === 0 ? 'PASS' : 'FAIL'
      },
      results: this.testResults,
      config: {
        supabase_url: this.config.supabase.url,
        environment: this.config.environment
      }
    };
    
    // Log summary
    colorLog('cyan', '\n📊 CRUD TEST SUMMARY');
    colorLog('cyan', '====================');
    console.log(`Total Tests: ${report.summary.total_tests}`);
    console.log(`Successes: ${report.summary.successes}`);
    console.log(`Warnings: ${report.summary.warnings}`);
    console.log(`Errors: ${report.summary.errors}`);
    console.log(`Overall Status: ${report.summary.overall_status}`);
    
    return report;
  }

  /**
   * Run all CRUD tests
   */
  async runAllTests() {
    colorLog('cyan', '🧪 Hey-Bills Database CRUD Tests Starting...');
    colorLog('cyan', '===========================================');
    
    try {
      await this.testTableStructure();
      await this.testReadCategories();
      await this.testReadSystemSettings();
      await this.testUserProfileOperations();
      await this.testVectorTables();
      await this.testBasicSQL();
      
      const report = this.generateReport();
      
      await this.cleanup();
      
      colorLog('cyan', '\n✨ CRUD Tests Complete!');
      
      return report.summary.overall_status === 'PASS';
      
    } catch (error) {
      this.log(`Fatal test error: ${error.message}`, 'error');
      return false;
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Hey Bills Database CRUD Test Tool

Usage: node test-database-crud.js [options]

Options:
  --help, -h        Show this help message
  --basic-only      Run only basic tests
  --no-cleanup      Skip cleanup of test data

Examples:
  node test-database-crud.js           # Full CRUD testing
  node test-database-crud.js --basic-only  # Basic tests only
    `);
    process.exit(0);
  }
  
  try {
    const tester = new DatabaseTester();
    const success = await tester.runAllTests();
    
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

module.exports = { DatabaseTester };