const express = require('express');
const router = express.Router();

// Import route modules
const healthRoutes = require('./health');

// API route definitions
router.use('/health', healthRoutes);

// Root API endpoint
router.get('/', (req, res) => {
  res.json({
    message: 'Hey Bills API Server',
    version: require('../package.json').version,
    status: 'running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/api/health',
      readiness: '/api/health/ready',
      liveness: '/api/health/live'
    }
  });
});

// 404 handler for API routes
router.use('*', (req, res) => {
  res.status(404).json({
    error: 'API endpoint not found',
    message: `The requested endpoint ${req.originalUrl} does not exist`,
    availableEndpoints: {
      root: '/api',
      health: '/api/health',
      readiness: '/api/health/ready',
      liveness: '/api/health/live'
    }
  });
});

module.exports = router;