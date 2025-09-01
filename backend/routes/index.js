const express = require('express');
const router = express.Router();

// Import route modules
const healthRoutes = require('./health');
const authRoutes = require('../src/routes/auth');
const ocrRoutes = require('../src/routes/ocr');
const receiptRoutes = require('../src/routes/receipts');
const warrantyRoutes = require('../src/routes/warranties');
// TODO: Fix axios dependency for chat routes
// const chatRoutes = require('../src/routes/chat');
// const searchRoutes = require('../src/routes/search');

// API route definitions
router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/ocr', ocrRoutes);
router.use('/receipts', receiptRoutes);
router.use('/warranties', warrantyRoutes);
// router.use('/chat', chatRoutes);
// router.use('/search', searchRoutes);

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
      liveness: '/api/health/live',
      auth: '/api/auth',
      ocr: '/api/ocr',
      receipts: '/api/receipts',
      warranties: '/api/warranties'
      // TODO: Enable after fixing dependencies
      // chat: '/api/chat',
      // search: '/api/search'
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
      liveness: '/api/health/live',
      auth: '/api/auth',
      ocr: '/api/ocr',
      receipts: '/api/receipts',
      warranties: '/api/warranties'
    }
  });
});

module.exports = router;