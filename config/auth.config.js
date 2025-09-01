/**
 * Authentication Configuration
 * Comprehensive auth setup for Google OAuth, Email auth, and security policies
 */

const { getCurrentConfig } = require('./environment');

/**
 * Supabase Auth Configuration
 * This configuration is used to set up Supabase authentication providers
 */
const authConfig = {
  // Site URL - where users will be redirected after authentication
  site_url: getCurrentConfig().frontend.url,
  
  // Redirect URLs - all valid redirect URLs for your application
  redirect_urls: [
    // Web URLs
    'http://localhost:3000',
    'http://localhost:5173',
    'https://your-domain.com',
    
    // Mobile deep links
    'com.heybills.app://auth/callback',
    'heybills://auth/callback',
    
    // Auth callback URLs
    'http://localhost:3000/auth/callback',
    'http://localhost:5173/auth/callback',
    'https://your-domain.com/auth/callback',
  ],

  // JWT Settings
  jwt_expiry: 3600, // 1 hour in seconds
  refresh_token_rotation_enabled: true,
  security_update_email_change_confirm: true,

  // Email Authentication
  enable_signup: true,
  enable_email_confirmations: true,
  enable_email_change_confirmations: true,
  
  // Password Requirements
  password_min_length: 8,
  
  // Session Configuration
  sessions: {
    timebox: 24 * 60 * 60, // 24 hours in seconds
    inactivity_timeout: 8 * 60 * 60, // 8 hours in seconds
  },

  // External OAuth Providers
  external: {
    // Google OAuth Configuration
    google: {
      enabled: true,
      client_id: getCurrentConfig().auth.google.clientId,
      client_secret: getCurrentConfig().auth.google.clientSecret,
      redirect_uri: 'https://your-project-id.supabase.co/auth/v1/callback',
      // Scopes - what information you want from Google
      scopes: [
        'openid',
        'email', 
        'profile'
      ],
      // Additional Google-specific settings
      skip_nonce_check: false,
      // Map Google profile fields to your user metadata
      attribute_mapping: {
        email: 'email',
        name: 'name',
        picture: 'avatar_url',
        email_verified: 'email_verified',
        given_name: 'first_name',
        family_name: 'last_name',
      }
    },

    // Apple OAuth (for future implementation)
    apple: {
      enabled: false,
      client_id: process.env.APPLE_CLIENT_ID,
      client_secret: process.env.APPLE_CLIENT_SECRET,
      redirect_uri: 'https://your-project-id.supabase.co/auth/v1/callback',
    },

    // Facebook OAuth (for future implementation)
    facebook: {
      enabled: false,
      client_id: process.env.FACEBOOK_APP_ID,
      client_secret: process.env.FACEBOOK_APP_SECRET,
      redirect_uri: 'https://your-project-id.supabase.co/auth/v1/callback',
    },

    // GitHub OAuth (for future implementation)
    github: {
      enabled: false,
      client_id: process.env.GITHUB_CLIENT_ID,
      client_secret: process.env.GITHUB_CLIENT_SECRET,
      redirect_uri: 'https://your-project-id.supabase.co/auth/v1/callback',
    }
  },

  // Email Templates (customize these in Supabase Dashboard)
  email_templates: {
    confirmation: {
      subject: 'Welcome to Hey Bills - Confirm Your Email',
      // Note: Template content is managed in Supabase Dashboard
    },
    recovery: {
      subject: 'Reset Your Hey Bills Password',
    },
    email_change: {
      subject: 'Confirm Your New Email Address',
    },
    magic_link: {
      subject: 'Your Hey Bills Magic Link',
    }
  },

  // SMTP Configuration (if using custom SMTP)
  smtp: {
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    admin_email: process.env.SMTP_ADMIN_EMAIL || 'admin@heybills.com',
    sender_name: 'Hey Bills',
  },

  // Rate Limiting for Auth Endpoints
  rate_limits: {
    // Signups per hour
    signup: '10/hour',
    // Login attempts per hour
    login: '30/hour',
    // Password reset requests per hour
    reset: '5/hour',
    // Email confirmation requests per hour
    confirmation: '5/hour',
  },

  // Security Settings
  security: {
    // Refresh token reuse detection
    refresh_token_reuse_detection: true,
    // Maximum number of refresh tokens per user
    refresh_token_limit: 10,
    // Automatically clean up expired sessions
    cleanup_expired_sessions: true,
    // Enable additional security logs
    security_audit_logs: true,
  }
};

/**
 * Row Level Security (RLS) Configuration
 * Defines security policies for database access
 */
const rlsPolicies = {
  // User Profiles - users can only access their own profile
  user_profiles: {
    select: 'auth.uid() = id',
    insert: 'auth.uid() = id',
    update: 'auth.uid() = id',
    delete: 'auth.uid() = id',
  },

  // Categories - users can only access their own categories or default ones
  categories: {
    select: 'auth.uid() = user_id OR user_id IS NULL',
    insert: 'auth.uid() = user_id',
    update: 'auth.uid() = user_id',
    delete: 'auth.uid() = user_id AND is_default = false',
  },

  // Receipts - users can only access their own receipts
  receipts: {
    select: 'auth.uid() = user_id',
    insert: 'auth.uid() = user_id',
    update: 'auth.uid() = user_id',
    delete: 'auth.uid() = user_id',
  },

  // Receipt Items - users can only access items from their own receipts
  receipt_items: {
    select: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_items.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    insert: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_items.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    update: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_items.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    delete: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_items.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
  },

  // Warranties - users can only access their own warranties
  warranties: {
    select: 'auth.uid() = user_id',
    insert: 'auth.uid() = user_id',
    update: 'auth.uid() = user_id',
    delete: 'auth.uid() = user_id',
  },

  // Notifications - users can only access their own notifications
  notifications: {
    select: 'auth.uid() = user_id',
    insert: 'auth.uid() = user_id',
    update: 'auth.uid() = user_id',
    delete: 'auth.uid() = user_id',
  },

  // Budgets - users can only access their own budgets
  budgets: {
    select: 'auth.uid() = user_id',
    insert: 'auth.uid() = user_id',
    update: 'auth.uid() = user_id',
    delete: 'auth.uid() = user_id',
  },

  // Receipt Embeddings - users can only access embeddings for their own receipts
  receipt_embeddings: {
    select: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_embeddings.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    insert: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_embeddings.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    update: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_embeddings.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
    delete: `EXISTS (
      SELECT 1 FROM receipts 
      WHERE receipts.id = receipt_embeddings.receipt_id 
      AND receipts.user_id = auth.uid()
    )`,
  },

  // Warranty Embeddings - users can only access embeddings for their own warranties
  warranty_embeddings: {
    select: `EXISTS (
      SELECT 1 FROM warranties 
      WHERE warranties.id = warranty_embeddings.warranty_id 
      AND warranties.user_id = auth.uid()
    )`,
    insert: `EXISTS (
      SELECT 1 FROM warranties 
      WHERE warranties.id = warranty_embeddings.warranty_id 
      AND warranties.user_id = auth.uid()
    )`,
    update: `EXISTS (
      SELECT 1 FROM warranties 
      WHERE warranties.id = warranty_embeddings.warranty_id 
      AND warranties.user_id = auth.uid()
    )`,
    delete: `EXISTS (
      SELECT 1 FROM warranties 
      WHERE warranties.id = warranty_embeddings.warranty_id 
      AND warranties.user_id = auth.uid()
    )`,
  },
};

/**
 * Client-side Auth Configuration
 * Configuration object for Supabase client initialization
 */
const clientAuthConfig = {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    flowType: 'pkce', // Recommended for mobile and SPA apps
    
    // Storage adapter (for React Native, use AsyncStorage)
    storage: typeof window !== 'undefined' ? window.localStorage : null,
  },

  // Real-time configuration
  realtime: {
    // Enable real-time subscriptions
    enabled: true,
    // Heartbeat interval
    heartbeatIntervalMs: 30000,
    // Reconnection settings
    reconnectAfterMs: (tries) => Math.min(tries * 1000, 30000),
  },

  // Global fetch options
  global: {
    headers: {
      'X-Client-Info': 'hey-bills-client',
    },
  },
};

/**
 * Middleware Configuration
 * Settings for authentication middleware
 */
const middlewareConfig = {
  // Routes that require authentication
  protectedRoutes: [
    '/api/receipts',
    '/api/warranties', 
    '/api/categories',
    '/api/budgets',
    '/api/notifications',
    '/api/user',
  ],

  // Routes that should redirect to dashboard if user is already authenticated
  authRoutes: [
    '/login',
    '/signup',
    '/forgot-password',
  ],

  // Public routes that don't require authentication
  publicRoutes: [
    '/health',
    '/api/health',
    '/auth/callback',
  ],

  // JWT verification settings
  jwt: {
    // Where to look for the JWT token
    locations: ['headers', 'cookies'],
    // Header name
    authHeaderName: 'Authorization',
    // Bearer token prefix
    authScheme: 'Bearer',
    // Cookie name
    cookieName: 'supabase-auth-token',
  },
};

module.exports = {
  authConfig,
  rlsPolicies,
  clientAuthConfig,
  middlewareConfig,
};