const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const auth = require('./auth');

// Import dotenv to access environment variables
require('dotenv').config();

// CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:5173,capacitor://localhost').split(',');
    
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'apikey', 'x-client-info']
};

// Rate limiting configuration
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000) / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Security headers configuration
const helmetOptions = {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
};

// Morgan logging format
const morganFormat = process.env.NODE_ENV === 'production' ? 'combined' : 'dev';

// Request ID middleware for tracking
const requestId = (req, res, next) => {
  req.id = req.headers['x-request-id'] || `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  res.setHeader('x-request-id', req.id);
  next();
};

// Request timeout middleware
const timeout = (timeoutMs = 30000) => {
  return (req, res, next) => {
    res.setTimeout(timeoutMs, () => {
      res.status(408).json({
        error: 'Request timeout',
        message: 'The request took too long to process'
      });
    });
    next();
  };
};

// Health check bypass middleware (skips rate limiting for health checks)
const healthCheckBypass = (req, res, next) => {
  if (req.path.startsWith('/api/health') || req.path === '/health') {
    return next();
  }
  return limiter(req, res, next);
};

module.exports = {
  cors: cors(corsOptions),
  helmet: helmet(helmetOptions),
  morgan: morgan(morganFormat),
  compression: compression(),
  rateLimiter: healthCheckBypass,
  auth: auth.authenticate,
  optionalAuth: auth.optionalAuthenticate,
  adminOnly: auth.requireAdmin,
  requestId,
  timeout
};