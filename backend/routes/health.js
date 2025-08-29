const express = require('express');
const { supabase } = require('../config/supabase');
const router = express.Router();

/**
 * Health check endpoint
 * GET /api/health
 */
router.get('/', async (req, res) => {
  try {
    const healthCheck = {
      status: 'OK',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: require('../package.json').version,
      services: {
        database: 'checking...',
        supabase: 'checking...'
      }
    };

    // Test Supabase connection
    try {
      const { error } = await supabase
        .from('health_check')
        .select('*')
        .limit(1);
      
      if (error && error.code !== 'PGRST116') { // PGRST116 = table doesn't exist (which is OK for health check)
        healthCheck.services.supabase = 'degraded';
        healthCheck.services.database = 'degraded';
      } else {
        healthCheck.services.supabase = 'operational';
        healthCheck.services.database = 'operational';
      }
    } catch (supabaseError) {
      console.error('Supabase health check error:', supabaseError);
      healthCheck.services.supabase = 'down';
      healthCheck.services.database = 'down';
      healthCheck.status = 'DEGRADED';
    }

    // Determine overall status
    const serviceStatuses = Object.values(healthCheck.services);
    if (serviceStatuses.includes('down')) {
      healthCheck.status = 'DOWN';
      res.status(503);
    } else if (serviceStatuses.includes('degraded')) {
      healthCheck.status = 'DEGRADED';
      res.status(200);
    } else {
      res.status(200);
    }

    res.json(healthCheck);
  } catch (error) {
    console.error('Health check error:', error);
    res.status(503).json({
      status: 'DOWN',
      timestamp: new Date().toISOString(),
      error: 'Health check failed',
      message: error.message
    });
  }
});

/**
 * Readiness probe endpoint
 * GET /api/health/ready
 */
router.get('/ready', async (req, res) => {
  try {
    // Check if all critical services are ready
    const { error } = await supabase
      .from('health_check')
      .select('*')
      .limit(1);

    if (error && error.code !== 'PGRST116') {
      throw new Error('Database not ready');
    }

    res.status(200).json({
      status: 'READY',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'NOT_READY',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

/**
 * Liveness probe endpoint
 * GET /api/health/live
 */
router.get('/live', (req, res) => {
  res.status(200).json({
    status: 'ALIVE',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

module.exports = router;