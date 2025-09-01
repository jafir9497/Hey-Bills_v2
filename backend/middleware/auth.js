const { supabase, supabaseAdmin } = require('../config/supabase');
const logger = require('../src/utils/logger');

/**
 * Primary authentication middleware that verifies Supabase JWT tokens
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Missing or invalid authorization header'
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    // Verify the JWT token with Supabase
    const { data: { user }, error } = await supabase.auth.getUser(token);
    
    if (error || !user) {
      logger.warn('Authentication failed', {
        error: error?.message,
        requestId: req.id,
        ip: req.ip
      });
      
      return res.status(401).json({
        error: 'Invalid token',
        message: 'Authentication token is invalid or expired'
      });
    }

    // Attach user to request object
    req.user = user;
    req.userId = user.id;
    
    logger.debug('User authenticated successfully', {
      userId: user.id,
      email: user.email,
      requestId: req.id
    });
    
    next();
  } catch (error) {
    logger.error('Authentication middleware error:', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });
    
    return res.status(500).json({
      error: 'Authentication error',
      message: 'Internal server error during authentication'
    });
  }
};

/**
 * Legacy alias for backward compatibility
 */
const authenticateToken = authenticate;

/**
 * Optional authentication middleware - doesn't fail if no token provided
 */
const optionalAuthenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // No authentication provided, continue without user
      req.user = null;
      req.userId = null;
      return next();
    }

    const token = authHeader.substring(7);
    
    const { data: { user }, error } = await supabase.auth.getUser(token);
    
    if (error || !user) {
      // Invalid token, continue without user
      req.user = null;
      req.userId = null;
      return next();
    }

    req.user = user;
    req.userId = user.id;
    
    next();
  } catch (error) {
    logger.error('Optional authentication middleware error:', error);
    // Continue without user on error
    req.user = null;
    req.userId = null;
    next();
  }
};

/**
 * Admin-only middleware - requires user to have admin role
 */
const requireAdmin = async (req, res, next) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Must be authenticated to access admin endpoints'
      });
    }

    // Check if user has admin role in their metadata or profiles table
    const userRole = req.user.user_metadata?.role || req.user.app_metadata?.role;
    
    if (userRole === 'admin') {
      return next();
    }

    // If not in metadata, check profiles table
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', req.userId)
      .single();

    if (error || !profile) {
      logger.warn('Admin check failed - no profile found', {
        userId: req.userId,
        requestId: req.id
      });
      
      return res.status(403).json({
        error: 'Access denied',
        message: 'Unable to verify admin permissions'
      });
    }

    if (profile.role !== 'admin') {
      logger.warn('Admin access denied', {
        userId: req.userId,
        userRole: profile.role,
        requestId: req.id
      });
      
      return res.status(403).json({
        error: 'Insufficient permissions',
        message: 'Admin role required to access this endpoint'
      });
    }

    next();
  } catch (error) {
    logger.error('Admin middleware error:', error);
    return res.status(500).json({
      error: 'Authorization error',
      message: 'Internal server error during authorization'
    });
  }
};

/**
 * Middleware to check if user has required role(s)
 */
const requireRole = (roles) => {
  if (!Array.isArray(roles)) {
    roles = [roles];
  }
  
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'User not authenticated'
      });
    }

    // Get user role from metadata or profiles table
    let userRole = req.user.user_metadata?.role || req.user.app_metadata?.role;
    
    if (!userRole) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', req.userId)
        .single();
      
      userRole = profile?.role || 'user';
    }

    if (!roles.includes(userRole)) {
      logger.warn('Role access denied', {
        userId: req.userId,
        userRole,
        requiredRoles: roles,
        requestId: req.id
      });
      
      return res.status(403).json({
        error: 'Insufficient permissions',
        message: `Required role: ${roles.join(' or ')}`
      });
    }

    next();
  };
};

/**
 * Resource ownership middleware - ensures user owns the requested resource
 */
const requireResourceOwnership = (tableName, resourceIdParam = 'id') => {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'Must be authenticated to access this resource'
        });
      }

      const resourceId = req.params[resourceIdParam];
      
      if (!resourceId) {
        return res.status(400).json({
          error: 'Invalid request',
          message: `Resource ID parameter '${resourceIdParam}' is required`
        });
      }

      // Check if resource belongs to user
      const { data: resource, error } = await supabase
        .from(tableName)
        .select('user_id')
        .eq('id', resourceId)
        .single();

      if (error || !resource) {
        return res.status(404).json({
          error: 'Resource not found',
          message: `${tableName} with ID ${resourceId} not found`
        });
      }

      if (resource.user_id !== req.userId) {
        logger.warn('Resource access denied', {
          userId: req.userId,
          resourceId,
          tableName,
          requestId: req.id
        });
        
        return res.status(403).json({
          error: 'Access denied',
          message: 'You do not have permission to access this resource'
        });
      }

      next();
    } catch (error) {
      logger.error('Resource ownership middleware error:', error);
      return res.status(500).json({
        error: 'Authorization error',
        message: 'Internal server error during resource authorization'
      });
    }
  };
};

module.exports = {
  authenticate,
  authenticateToken, // Legacy alias
  optionalAuthenticate,
  requireAdmin,
  requireRole,
  requireResourceOwnership
};