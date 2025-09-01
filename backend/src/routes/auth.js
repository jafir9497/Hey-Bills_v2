/**
 * Authentication Routes
 * Defines all authentication-related endpoints
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const {
  register,
  login,
  oauthLogin,
  oauthCallback,
  logout,
  refreshSession,
  forgotPassword,
  updatePassword,
  getCurrentUser
} = require('../controllers/authController');
const {
  authenticateToken,
  requireEmailConfirmation
} = require('../middleware/supabaseAuth');

const router = express.Router();

// Rate limiting for authentication endpoints
const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 requests per windowMs
  message: {
    error: 'Too many authentication attempts, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter rate limiting for sensitive operations
const strictRateLimit = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Limit each IP to 3 requests per hour
  message: {
    error: 'Too many attempts, please try again later.',
    code: 'STRICT_RATE_LIMIT_EXCEEDED',
    retryAfter: '1 hour'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Public authentication routes
router.post('/register', authRateLimit, register);
router.post('/login', authRateLimit, login);
router.get('/oauth/:provider', oauthLogin);
router.get('/oauth/callback', oauthCallback);
router.post('/forgot-password', strictRateLimit, forgotPassword);

// Protected authentication routes
router.post('/logout', authenticateToken, logout);
router.post('/refresh', authenticateToken, refreshSession);
router.post('/update-password', authenticateToken, requireEmailConfirmation, updatePassword);
router.get('/me', authenticateToken, getCurrentUser);

// Health check endpoint for auth service
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'authentication',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    endpoints: {
      public: [
        'POST /auth/register',
        'POST /auth/login',
        'GET /auth/oauth/:provider',
        'GET /auth/oauth/callback',
        'POST /auth/forgot-password'
      ],
      protected: [
        'POST /auth/logout',
        'POST /auth/refresh',
        'POST /auth/update-password',
        'GET /auth/me'
      ]
    }
  });
});

// Documentation endpoint
router.get('/docs', (req, res) => {
  res.status(200).json({
    title: 'Hey Bills Authentication API',
    version: '1.0.0',
    description: 'Authentication endpoints for user registration, login, and session management',
    baseUrl: '/api/auth',
    endpoints: {
      'POST /register': {
        description: 'Register a new user account',
        body: {
          email: 'string (required)',
          password: 'string (required, min 8 chars)',
          fullName: 'string (optional)',
          metadata: 'object (optional)'
        },
        responses: {
          201: 'Registration successful',
          400: 'Validation error or registration failed',
          429: 'Too many requests'
        }
      },
      'POST /login': {
        description: 'Sign in an existing user',
        body: {
          email: 'string (required)',
          password: 'string (required)'
        },
        responses: {
          200: 'Login successful with user data and session',
          401: 'Invalid credentials',
          429: 'Too many requests'
        }
      },
      'GET /oauth/:provider': {
        description: 'Initiate OAuth login with supported provider',
        parameters: {
          provider: 'string (google, facebook, github, apple)'
        },
        query: {
          redirectTo: 'string (optional redirect URL)'
        },
        responses: {
          302: 'Redirect to OAuth provider',
          400: 'Unsupported provider or OAuth error'
        }
      },
      'GET /oauth/callback': {
        description: 'Handle OAuth provider callback',
        query: {
          access_token: 'string',
          refresh_token: 'string',
          error: 'string (if error occurred)'
        },
        responses: {
          302: 'Redirect to frontend with tokens or error',
          400: 'OAuth authentication failed'
        }
      },
      'POST /forgot-password': {
        description: 'Request password reset email',
        body: {
          email: 'string (required)'
        },
        responses: {
          200: 'Reset email sent (if account exists)',
          400: 'Invalid email format',
          429: 'Too many requests'
        }
      },
      'POST /logout': {
        description: 'Sign out current user (requires authentication)',
        headers: {
          Authorization: 'Bearer <access_token>'
        },
        responses: {
          200: 'Logout successful',
          401: 'Authentication required'
        }
      },
      'POST /refresh': {
        description: 'Refresh user session (requires authentication)',
        headers: {
          Authorization: 'Bearer <access_token>'
        },
        responses: {
          200: 'Session refreshed with new tokens',
          401: 'Authentication failed or session expired'
        }
      },
      'POST /update-password': {
        description: 'Update user password (requires authentication and email confirmation)',
        headers: {
          Authorization: 'Bearer <access_token>'
        },
        body: {
          newPassword: 'string (required, min 8 chars)'
        },
        responses: {
          200: 'Password updated successfully',
          400: 'Weak password or update failed',
          401: 'Authentication required',
          403: 'Email confirmation required'
        }
      },
      'GET /me': {
        description: 'Get current user information (requires authentication)',
        headers: {
          Authorization: 'Bearer <access_token>'
        },
        responses: {
          200: 'User data with profile and statistics',
          401: 'Authentication required'
        }
      }
    },
    authentication: {
      type: 'Bearer Token (JWT)',
      header: 'Authorization: Bearer <access_token>',
      note: 'Obtain tokens through login or OAuth endpoints'
    },
    rateLimiting: {
      standard: '10 requests per 15 minutes per IP',
      strict: '3 requests per hour per IP (for sensitive operations)',
      userSpecific: 'Additional per-user rate limiting may apply'
    },
    errors: {
      format: {
        error: 'string (human-readable error message)',
        code: 'string (machine-readable error code)',
        timestamp: 'string (ISO 8601 timestamp)',
        details: 'object (optional additional error details)'
      },
      codes: {
        MISSING_FIELDS: 'Required fields are missing',
        INVALID_EMAIL: 'Email format is invalid',
        WEAK_PASSWORD: 'Password does not meet security requirements',
        AUTHENTICATION_FAILED: 'Invalid credentials or token',
        RATE_LIMIT_EXCEEDED: 'Too many requests',
        EMAIL_NOT_CONFIRMED: 'Email confirmation required',
        OAUTH_ERROR: 'OAuth provider authentication failed'
      }
    }
  });
});

module.exports = router;