/**
 * Custom error classes for better error handling
 */

class APIError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends APIError {
  constructor(message, field = null) {
    super(message, 400, 'VALIDATION_ERROR');
    this.field = field;
  }
}

class AuthenticationError extends APIError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'AUTHENTICATION_ERROR');
  }
}

class AuthorizationError extends APIError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403, 'AUTHORIZATION_ERROR');
  }
}

class NotFoundError extends APIError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND_ERROR');
  }
}

class ConflictError extends APIError {
  constructor(message = 'Resource conflict') {
    super(message, 409, 'CONFLICT_ERROR');
  }
}

class DatabaseError extends APIError {
  constructor(message = 'Database operation failed') {
    super(message, 500, 'DATABASE_ERROR');
  }
}

class SupabaseError extends APIError {
  constructor(message, supabaseError) {
    super(message, 500, 'SUPABASE_ERROR');
    this.originalError = supabaseError;
  }
}

/**
 * Error handler utility functions
 */
const handleSupabaseError = (error, context = '') => {
  console.error(`Supabase error ${context}:`, error);
  
  // Map common Supabase errors to appropriate HTTP status codes
  const errorMappings = {
    '23505': { status: 409, message: 'Resource already exists' }, // unique_violation
    '23503': { status: 400, message: 'Referenced resource does not exist' }, // foreign_key_violation
    '42501': { status: 403, message: 'Insufficient database permissions' }, // insufficient_privilege
    'PGRST116': { status: 404, message: 'Table or view not found' }, // relation does not exist
    'PGRST301': { status: 404, message: 'Resource not found' }, // no rows returned
  };
  
  const mapping = errorMappings[error.code];
  if (mapping) {
    throw new APIError(mapping.message, mapping.status, error.code);
  }
  
  // Handle authentication errors
  if (error.message?.includes('JWT') || error.message?.includes('token')) {
    throw new AuthenticationError('Invalid or expired authentication token');
  }
  
  // Handle RLS errors
  if (error.message?.includes('RLS') || error.message?.includes('policy')) {
    throw new AuthorizationError('Access denied by security policy');
  }
  
  // Default to generic database error
  throw new SupabaseError(`Database operation failed: ${error.message}`, error);
};

/**
 * Async error wrapper for route handlers
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Response helper functions
 */
const sendSuccess = (res, data, message = 'Success', statusCode = 200) => {
  res.status(statusCode).json({
    success: true,
    message,
    data,
    timestamp: new Date().toISOString()
  });
};

const sendError = (res, error, statusCode = 500) => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(statusCode).json({
    success: false,
    error: error.message || 'Internal server error',
    code: error.code || 'INTERNAL_ERROR',
    ...(isDevelopment && error.stack && { stack: error.stack }),
    timestamp: new Date().toISOString()
  });
};

module.exports = {
  APIError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  DatabaseError,
  SupabaseError,
  handleSupabaseError,
  asyncHandler,
  sendSuccess,
  sendError
};