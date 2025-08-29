const express = require('express');
const path = require('path');
require('dotenv').config();

// Import middleware
const middleware = require('../middleware');

// Import routes
const apiRoutes = require('../routes');

// Import configuration
const { supabase } = require('../config/supabase');

const app = express();
const PORT = process.env.PORT || 3001;

// Trust proxy for rate limiting when behind reverse proxy
app.set('trust proxy', 1);

// Apply middleware stack
app.use(middleware.helmet);           // Security headers
app.use(middleware.compression);      // Gzip compression
app.use(middleware.cors);            // CORS handling
app.use(middleware.morgan);          // HTTP request logging
app.use(middleware.rateLimiter);     // Rate limiting

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files (if needed)
app.use('/static', express.static(path.join(__dirname, '../public')));

// API routes
app.use('/api', apiRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Hey Bills Backend API',
    version: require('../package.json').version,
    status: 'running',
    timestamp: new Date().toISOString(),
    documentation: '/api',
    health: '/api/health'
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('Global error handler:', error);
  
  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(error.status || 500).json({
    error: 'Internal server error',
    message: isDevelopment ? error.message : 'Something went wrong',
    ...(isDevelopment && { stack: error.stack }),
    timestamp: new Date().toISOString(),
    requestId: req.headers['x-request-id'] || 'unknown'
  });
});

// 404 handler for all other routes
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: `The requested route ${req.originalUrl} does not exist`,
    availableRoutes: {
      root: '/',
      api: '/api',
      health: '/api/health'
    },
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handling
const server = app.listen(PORT, () => {
  console.log(`🚀 Hey Bills Backend Server running on port ${PORT}`);
  console.log(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 API Base URL: http://localhost:${PORT}/api`);
  console.log(`❤️  Health Check: http://localhost:${PORT}/api/health`);
  console.log(`📊 Supabase URL: ${process.env.SUPABASE_URL ? '✅ Connected' : '❌ Not configured'}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('✅ Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('✅ Process terminated');
    process.exit(0);
  });
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled Promise Rejection:', err);
  server.close(() => {
    process.exit(1);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught Exception:', err);
  process.exit(1);
});

module.exports = app;