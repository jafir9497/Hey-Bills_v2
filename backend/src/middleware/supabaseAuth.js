/**
 * Supabase Authentication Middleware
 * Handles JWT token verification and user authentication
 */

const { authService } = require('../services/supabaseService');
const { APIError } = require('../../utils/errorHandler');

/**
 * Extract JWT token from Authorization header
 * @param {Object} req - Express request object
 * @returns {string|null} JWT token or null
 */
const extractToken = (req) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    return null;
  }
  
  // Support both "Bearer token" and "token" formats
  if (authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  
  return authHeader;
};

/**
 * Middleware to verify JWT token and attach user to request
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const authenticateToken = async (req, res, next) => {
  try {
    const token = extractToken(req);
    
    if (!token) {
      throw new APIError('Access token is required', 401, 'MISSING_TOKEN');
    }
    
    // Verify token with Supabase
    const { data: userResult, error } = await authService.verifyToken(token);
    
    if (error || !userResult.user) {
      throw new APIError('Invalid or expired token', 401, 'INVALID_TOKEN');
    }
    
    // Attach user information to request
    req.user = {
      id: userResult.user.id,
      email: userResult.user.email,
      role: userResult.user.role,
      emailConfirmed: !!userResult.user.email_confirmed_at,
      metadata: userResult.user.user_metadata || {},
      appMetadata: userResult.user.app_metadata || {},
      lastSignIn: userResult.user.last_sign_in_at,
      createdAt: userResult.user.created_at
    };
    
    // Attach raw token for potential use in downstream services
    req.token = token;
    
    next();
  } catch (error) {
    if (error instanceof APIError) {
      return res.status(error.statusCode).json({
        error: error.message,
        code: error.code,
        timestamp: new Date().toISOString()
      });
    }
    
    // Log unexpected errors
    console.error('Authentication middleware error:', error);
    
    return res.status(401).json({
      error: 'Authentication failed',
      timestamp: new Date().toISOString()
    });
  }
};

/**
 * Optional authentication middleware - doesn't fail if no token provided
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const optionalAuth = async (req, res, next) => {
  try {
    const token = extractToken(req);
    
    if (!token) {
      // No token provided, continue without authentication
      req.user = null;
      req.token = null;
      return next();
    }
    
    // Try to verify token, but don't fail if invalid
    const { data: userResult } = await authService.verifyToken(token);
    
    if (userResult?.user) {
      req.user = {
        id: userResult.user.id,
        email: userResult.user.email,
        role: userResult.user.role,
        emailConfirmed: !!userResult.user.email_confirmed_at,
        metadata: userResult.user.user_metadata || {},
        appMetadata: userResult.user.app_metadata || {},
        lastSignIn: userResult.user.last_sign_in_at,
        createdAt: userResult.user.created_at
      };
      req.token = token;
    } else {
      req.user = null;
      req.token = null;
    }
    
    next();
  } catch (error) {
    // Log error but continue without authentication
    console.warn('Optional authentication failed:', error.message);
    req.user = null;
    req.token = null;
    next();
  }
};

/**
 * Middleware to check if user has required role
 * @param {string|string[]} requiredRoles - Required role(s)
 * @returns {Function} Middleware function
 */
const requireRole = (requiredRoles) => {
  const roles = Array.isArray(requiredRoles) ? requiredRoles : [requiredRoles];
  
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED',
        timestamp: new Date().toISOString()
      });
    }
    
    const userRole = req.user.role || 'user';
    
    if (!roles.includes(userRole)) {
      return res.status(403).json({
        error: `Access denied. Required role(s): ${roles.join(', ')}. Your role: ${userRole}`,
        code: 'INSUFFICIENT_PERMISSIONS',
        timestamp: new Date().toISOString()
      });
    }
    
    next();
  };
};

/**
 * Middleware to check if user email is confirmed
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const requireEmailConfirmation = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTHENTICATION_REQUIRED',
      timestamp: new Date().toISOString()
    });
  }
  
  if (!req.user.emailConfirmed) {
    return res.status(403).json({
      error: 'Email confirmation required. Please check your email and confirm your account.',
      code: 'EMAIL_NOT_CONFIRMED',
      timestamp: new Date().toISOString()
    });
  }
  
  next();
};

/**
 * Middleware to ensure user can only access their own resources
 * @param {string} userIdParam - Request parameter name containing user ID (default: 'userId')
 * @returns {Function} Middleware function
 */
const requireOwnership = (userIdParam = 'userId') => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED',
        timestamp: new Date().toISOString()
      });
    }
    
    const resourceUserId = req.params[userIdParam] || req.body[userIdParam] || req.query[userIdParam];
    
    // Allow admin users to access any resource
    if (req.user.role === 'admin' || req.user.role === 'superuser') {
      return next();
    }
    
    // Check if user is accessing their own resource
    if (req.user.id !== resourceUserId) {
      return res.status(403).json({
        error: 'Access denied. You can only access your own resources.',
        code: 'OWNERSHIP_REQUIRED',
        timestamp: new Date().toISOString()
      });
    }
    
    next();
  };
};

/**
 * Middleware to rate limit requests per user
 * @param {Object} options - Rate limiting options
 * @returns {Function} Middleware function
 */
const userRateLimit = (options = {}) => {
  const {
    windowMs = 15 * 60 * 1000, // 15 minutes
    maxRequests = 100,
    message = 'Too many requests from this user'
  } = options;
  
  const userRequestCounts = new Map();
  
  // Clean up old entries periodically
  setInterval(() => {
    const now = Date.now();
    for (const [userId, data] of userRequestCounts.entries()) {
      if (now - data.firstRequest > windowMs) {
        userRequestCounts.delete(userId);
      }
    }
  }, windowMs);
  
  return (req, res, next) => {
    if (!req.user) {
      // Skip rate limiting for unauthenticated requests
      return next();
    }
    
    const userId = req.user.id;
    const now = Date.now();
    
    if (!userRequestCounts.has(userId)) {
      userRequestCounts.set(userId, {
        count: 1,
        firstRequest: now
      });
      return next();
    }
    
    const userData = userRequestCounts.get(userId);
    
    // Reset if window has passed
    if (now - userData.firstRequest > windowMs) {
      userRequestCounts.set(userId, {
        count: 1,
        firstRequest: now
      });
      return next();
    }
    
    userData.count++;
    
    if (userData.count > maxRequests) {
      return res.status(429).json({
        error: message,
        code: 'RATE_LIMIT_EXCEEDED',
        retryAfter: Math.ceil((userData.firstRequest + windowMs - now) / 1000),
        timestamp: new Date().toISOString()
      });
    }
    
    next();
  };
};

module.exports = {
  authenticateToken,
  optionalAuth,
  requireRole,
  requireEmailConfirmation,
  requireOwnership,
  userRateLimit,
  extractToken
};