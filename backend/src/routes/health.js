/**
 * Health Check Routes
 * System health monitoring and database connection testing
 */

const express = require('express');
const { db } = require('../utils/database');
const { APIError } = require('../../utils/errorHandler');

const router = express.Router();

/**
 * Basic health check endpoint
 */
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    
    // Test database connection
    const dbHealth = await db.getHealthInfo();
    const responseTime = Date.now() - startTime;
    
    // Determine overall health status
    const isHealthy = dbHealth.status === 'healthy';
    const statusCode = isHealthy ? 200 : 503;
    
    res.status(statusCode).json({
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      version: require('../../package.json').version,
      uptime: process.uptime(),
      responseTime,
      environment: process.env.NODE_ENV || 'development',
      services: {
        database: dbHealth,
        server: {
          status: 'healthy',
          memory: {
            used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
            total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
            external: Math.round(process.memoryUsage().external / 1024 / 1024)
          },
          cpu: process.cpuUsage()
        }
      },
      checks: {
        database_connection: dbHealth.status === 'healthy' ? 'pass' : 'fail',
        memory_usage: process.memoryUsage().heapUsed < 500 * 1024 * 1024 ? 'pass' : 'warn', // 500MB threshold
        response_time: responseTime < 1000 ? 'pass' : 'warn' // 1 second threshold
      }
    });
    
  } catch (error) {
    console.error('Health check failed:', error);
    
    res.status(503).json({
      status: 'unhealthy',
      error: 'Health check failed',
      timestamp: new Date().toISOString(),
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * Detailed system information endpoint
 */
router.get('/detailed', async (req, res) => {
  try {
    const startTime = Date.now();
    
    // Gather system information
    const [dbHealth] = await Promise.all([
      db.getHealthInfo()
    ]);
    
    const memoryUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    const responseTime = Date.now() - startTime;
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      application: {
        name: 'hey-bills-backend',
        version: require('../../package.json').version,
        environment: process.env.NODE_ENV || 'development',
        nodeVersion: process.version,
        uptime: {
          seconds: Math.floor(process.uptime()),
          human: formatUptime(process.uptime())
        },
        pid: process.pid,
        responseTime
      },
      system: {
        platform: process.platform,
        arch: process.arch,
        loadAverage: process.loadavg ? process.loadavg() : null,
        memory: {
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
          external: Math.round(memoryUsage.external / 1024 / 1024),
          rss: Math.round(memoryUsage.rss / 1024 / 1024),
          arrayBuffers: Math.round(memoryUsage.arrayBuffers / 1024 / 1024),
          unit: 'MB'
        },
        cpu: {
          user: cpuUsage.user,
          system: cpuUsage.system,
          unit: 'microseconds'
        }
      },
      services: {
        database: dbHealth,
        supabase: {
          configured: !!(process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY),
          url: process.env.SUPABASE_URL ? process.env.SUPABASE_URL.replace(/\/.*/, '/***') : null,
          hasServiceRole: !!process.env.SUPABASE_SERVICE_ROLE_KEY
        }
      },
      configuration: {
        port: process.env.PORT || 3001,
        cors: {
          enabled: true,
          origins: process.env.CORS_ORIGINS?.split(',') || ['*']
        },
        rateLimit: {
          enabled: true,
          windowMs: 15 * 60 * 1000,
          maxRequests: 100
        },
        features: {
          ocrProcessing: process.env.FEATURE_OCR_PROCESSING !== 'false',
          vectorSearch: process.env.FEATURE_VECTOR_SEARCH !== 'false',
          budgetTracking: process.env.FEATURE_BUDGET_TRACKING !== 'false',
          analytics: process.env.FEATURE_ANALYTICS !== 'false'
        }
      }
    });
    
  } catch (error) {
    console.error('Detailed health check failed:', error);
    
    res.status(500).json({
      status: 'error',
      error: 'Detailed health check failed',
      timestamp: new Date().toISOString(),
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * Database-specific health check
 */
router.get('/database', async (req, res) => {
  try {
    const startTime = Date.now();
    const dbHealth = await db.getHealthInfo();
    const responseTime = Date.now() - startTime;
    
    const statusCode = dbHealth.status === 'healthy' ? 200 : 503;
    
    res.status(statusCode).json({
      ...dbHealth,
      responseTime,
      connection: {
        supabaseUrl: process.env.SUPABASE_URL ? 'configured' : 'missing',
        anonKey: process.env.SUPABASE_ANON_KEY ? 'configured' : 'missing',
        serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ? 'configured' : 'missing'
      }
    });
    
  } catch (error) {
    console.error('Database health check failed:', error);
    
    res.status(503).json({
      status: 'unhealthy',
      error: 'Database health check failed',
      timestamp: new Date().toISOString(),
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * Readiness probe (for Kubernetes/Docker deployments)
 */
router.get('/ready', async (req, res) => {
  try {
    // Check if essential services are ready
    const dbReady = await db.testConnection();
    
    if (!dbReady) {
      throw new Error('Database not ready');
    }
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        database: 'ready'
      }
    });
    
  } catch (error) {
    console.error('Readiness check failed:', error);
    
    res.status(503).json({
      status: 'not ready',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Liveness probe (for Kubernetes/Docker deployments)
 */
router.get('/live', (req, res) => {
  // Simple liveness check - if the server responds, it's alive
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

/**
 * Helper function to format uptime in human-readable format
 * @param {number} seconds - Uptime in seconds
 * @returns {string} Formatted uptime string
 */
function formatUptime(seconds) {
  const days = Math.floor(seconds / (24 * 60 * 60));
  const hours = Math.floor((seconds % (24 * 60 * 60)) / (60 * 60));
  const minutes = Math.floor((seconds % (60 * 60)) / 60);
  const secs = Math.floor(seconds % 60);
  
  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  parts.push(`${secs}s`);
  
  return parts.join(' ');
}

module.exports = router;