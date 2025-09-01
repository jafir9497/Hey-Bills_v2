/**
 * Authentication Controller
 * Handles user authentication endpoints
 */

const { authService, userService } = require('../services/supabaseService');
const { APIError } = require('../../utils/errorHandler');

/**
 * Register a new user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const register = async (req, res, next) => {
  try {
    const { email, password, fullName, ...metadata } = req.body;
    
    // Validate required fields
    if (!email || !password) {
      throw new APIError('Email and password are required', 400, 'MISSING_FIELDS');
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new APIError('Invalid email format', 400, 'INVALID_EMAIL');
    }
    
    // Validate password strength
    if (password.length < 8) {
      throw new APIError('Password must be at least 8 characters long', 400, 'WEAK_PASSWORD');
    }
    
    // Sign up with Supabase Auth
    const { data: authResult, error } = await authService.signUp(
      email,
      password,
      {
        full_name: fullName,
        ...metadata
      }
    );
    
    if (error) {
      throw new APIError(
        error.message || 'Registration failed',
        400,
        'REGISTRATION_FAILED'
      );
    }
    
    // Create user profile if auth was successful and user was created
    if (authResult.user && !authResult.user.identities?.length) {
      await userService.createUserProfile(authResult.user);
    }
    
    res.status(201).json({
      message: 'Registration successful',
      user: {
        id: authResult.user?.id,
        email: authResult.user?.email,
        emailConfirmed: !!authResult.user?.email_confirmed_at,
        createdAt: authResult.user?.created_at
      },
      session: authResult.session ? {
        accessToken: authResult.session.access_token,
        refreshToken: authResult.session.refresh_token,
        expiresAt: authResult.session.expires_at,
        expiresIn: authResult.session.expires_in
      } : null,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Sign in a user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    
    // Validate required fields
    if (!email || !password) {
      throw new APIError('Email and password are required', 400, 'MISSING_CREDENTIALS');
    }
    
    // Sign in with Supabase Auth
    const { data: authResult, error } = await authService.signIn(email, password);
    
    if (error) {
      throw new APIError(
        error.message === 'Invalid login credentials' 
          ? 'Invalid email or password'
          : error.message,
        401,
        'AUTHENTICATION_FAILED'
      );
    }
    
    // Get or create user profile
    let userProfile = null;
    try {
      const profileResult = await userService.getUserProfile(authResult.user.id);
      userProfile = profileResult.data;
    } catch (profileError) {
      // If profile doesn't exist, create it
      if (profileError.code === 'DATABASE_ERROR') {
        const createResult = await userService.createUserProfile(authResult.user);
        userProfile = createResult.data;
      }
    }
    
    res.status(200).json({
      message: 'Login successful',
      user: {
        id: authResult.user.id,
        email: authResult.user.email,
        emailConfirmed: !!authResult.user.email_confirmed_at,
        profile: userProfile,
        lastSignIn: authResult.user.last_sign_in_at
      },
      session: {
        accessToken: authResult.session.access_token,
        refreshToken: authResult.session.refresh_token,
        expiresAt: authResult.session.expires_at,
        expiresIn: authResult.session.expires_in
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Sign in with OAuth provider
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const oauthLogin = async (req, res, next) => {
  try {
    const { provider } = req.params;
    const { redirectTo } = req.query;
    
    // Validate provider
    const supportedProviders = ['google', 'facebook', 'github', 'apple'];
    if (!supportedProviders.includes(provider)) {
      throw new APIError(
        `Unsupported OAuth provider: ${provider}`,
        400,
        'UNSUPPORTED_PROVIDER'
      );
    }
    
    // Initiate OAuth flow
    const { data: authResult, error } = await authService.signInWithOAuth(
      provider,
      { redirectTo }
    );
    
    if (error) {
      throw new APIError(
        error.message || `OAuth login with ${provider} failed`,
        400,
        'OAUTH_FAILED'
      );
    }
    
    // For OAuth, we typically redirect to the provider
    if (authResult.url) {
      res.redirect(authResult.url);
    } else {
      res.status(200).json({
        message: `OAuth login with ${provider} initiated`,
        provider,
        timestamp: new Date().toISOString()
      });
    }
    
  } catch (error) {
    next(error);
  }
};

/**
 * Handle OAuth callback
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const oauthCallback = async (req, res, next) => {
  try {
    const { access_token, refresh_token, error, error_description } = req.query;
    
    if (error) {
      throw new APIError(
        error_description || 'OAuth authentication failed',
        400,
        'OAUTH_ERROR'
      );
    }
    
    // For successful OAuth, redirect to frontend with tokens
    const redirectUrl = new URL(process.env.FRONTEND_URL || 'http://localhost:3000');
    
    if (access_token) {
      redirectUrl.searchParams.set('access_token', access_token);
    }
    if (refresh_token) {
      redirectUrl.searchParams.set('refresh_token', refresh_token);
    }
    
    res.redirect(redirectUrl.toString());
    
  } catch (error) {
    next(error);
  }
};

/**
 * Sign out current user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const logout = async (req, res, next) => {
  try {
    // Sign out from Supabase (this invalidates the JWT)
    const { error } = await authService.signOut();
    
    if (error) {
      console.error('Logout error:', error);
      // Don't fail the request if logout fails - client can still clear tokens
    }
    
    res.status(200).json({
      message: 'Logout successful',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Refresh user session
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const refreshSession = async (req, res, next) => {
  try {
    const { data: authResult, error } = await authService.refreshSession();
    
    if (error) {
      throw new APIError(
        'Session refresh failed',
        401,
        'REFRESH_FAILED'
      );
    }
    
    res.status(200).json({
      message: 'Session refreshed successfully',
      session: {
        accessToken: authResult.session.access_token,
        refreshToken: authResult.session.refresh_token,
        expiresAt: authResult.session.expires_at,
        expiresIn: authResult.session.expires_in
      },
      user: {
        id: authResult.user.id,
        email: authResult.user.email,
        emailConfirmed: !!authResult.user.email_confirmed_at
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Request password reset
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      throw new APIError('Email is required', 400, 'MISSING_EMAIL');
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new APIError('Invalid email format', 400, 'INVALID_EMAIL');
    }
    
    const { error } = await authService.resetPassword(email);
    
    if (error) {
      // Don't expose whether email exists or not for security
      console.error('Password reset error:', error);
    }
    
    // Always return success to prevent email enumeration
    res.status(200).json({
      message: 'If an account with that email exists, we have sent a password reset link.',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Update user password
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const updatePassword = async (req, res, next) => {
  try {
    const { newPassword } = req.body;
    
    if (!newPassword) {
      throw new APIError('New password is required', 400, 'MISSING_PASSWORD');
    }
    
    // Validate password strength
    if (newPassword.length < 8) {
      throw new APIError('Password must be at least 8 characters long', 400, 'WEAK_PASSWORD');
    }
    
    const { data, error } = await authService.updatePassword(newPassword);
    
    if (error) {
      throw new APIError(
        error.message || 'Password update failed',
        400,
        'PASSWORD_UPDATE_FAILED'
      );
    }
    
    res.status(200).json({
      message: 'Password updated successfully',
      user: {
        id: data.user.id,
        email: data.user.email,
        updatedAt: data.user.updated_at
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

/**
 * Get current user information
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getCurrentUser = async (req, res, next) => {
  try {
    // User information is already attached to req by auth middleware
    if (!req.user) {
      throw new APIError('User not authenticated', 401, 'NOT_AUTHENTICATED');
    }
    
    // Get full user profile
    const { data: userProfile } = await userService.getUserProfile(req.user.id);
    
    // Get user statistics
    const userStats = await userService.getUserStats(req.user.id);
    
    res.status(200).json({
      user: {
        ...req.user,
        profile: userProfile,
        stats: userStats
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  oauthLogin,
  oauthCallback,
  logout,
  refreshSession,
  forgotPassword,
  updatePassword,
  getCurrentUser
};