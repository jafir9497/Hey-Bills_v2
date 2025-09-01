/**
 * Supabase Configuration
 * Central configuration for Supabase project settings, authentication, and database
 */

const config = {
  // Project Configuration
  project: {
    name: 'Hey Bills',
    description: 'AI-Powered Financial Wellness Companion',
    organization: 'heybills',
    region: 'us-east-1', // Choose region closest to your users
  },

  // Authentication Configuration
  auth: {
    // Email Authentication
    email: {
      enabled: true,
      confirmEmail: true,
      autoConfirm: false,
      enableSignups: true,
      emailChangeConfirmation: true,
      securePasswordChange: true,
    },
    
    // Google OAuth Configuration
    google: {
      enabled: true,
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      redirectUrls: [
        'http://localhost:3000/auth/callback',
        'https://your-domain.com/auth/callback',
        // Mobile deep links
        'com.heybills.app://auth/callback',
        'heybills://auth/callback'
      ],
      scopes: ['openid', 'email', 'profile'],
      skipNonce: false,
    },

    // Session Configuration
    session: {
      refreshTokenRotation: true,
      accessTokenLimit: 10,
      refreshTokenReuse: 3,
      securityUpdateEmailChangeConfirm: true,
    },

    // JWT Configuration
    jwt: {
      algorithm: 'HS256',
      expiry: 3600, // 1 hour
      refreshExpiry: 2592000, // 30 days
    },

    // Additional OAuth Providers (for future expansion)
    apple: {
      enabled: false,
    },
    facebook: {
      enabled: false,
    },
    github: {
      enabled: false,
    }
  },

  // Database Configuration
  database: {
    // Extensions to enable
    extensions: [
      'uuid-ossp',
      'pgcrypto',
      'vector', // pgvector for AI embeddings
      'pg_trgm', // for text search
      'postgis', // for location data (if needed)
    ],

    // Connection pooling
    pooling: {
      mode: 'transaction',
      maxConnections: 100,
      defaultToTransaction: true,
    },

    // Backup configuration
    backup: {
      enabled: true,
      schedule: 'daily',
      retentionDays: 30,
    }
  },

  // Storage Configuration
  storage: {
    buckets: {
      receipts: {
        public: false,
        maxFileSize: '10MB',
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
        transformation: {
          enabled: true,
          formats: ['webp'],
          quality: 80,
        }
      },
      warranties: {
        public: false,
        maxFileSize: '20MB',
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
      },
      profiles: {
        public: true,
        maxFileSize: '5MB',
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        transformation: {
          enabled: true,
          formats: ['webp'],
          quality: 80,
        }
      }
    }
  },

  // Edge Functions Configuration
  functions: {
    region: 'us-east-1',
    environment: {
      OPENAI_API_KEY: process.env.OPENAI_API_KEY,
      GOOGLE_VISION_API_KEY: process.env.GOOGLE_VISION_API_KEY,
    }
  },

  // Real-time Configuration
  realtime: {
    enabled: true,
    maxConnections: 100,
    enableMultitenancy: true,
  },

  // Security Configuration
  security: {
    // CORS settings
    cors: {
      origins: [
        'http://localhost:3000',
        'http://localhost:5173',
        'https://your-domain.com',
        'capacitor://localhost',
        'ionic://localhost',
        'http://localhost',
        'https://localhost'
      ]
    },

    // Rate limiting
    rateLimits: {
      auth: '60/hour',
      api: '1000/hour',
      storage: '100/hour'
    },

    // Security headers
    headers: {
      strictTransportSecurity: true,
      contentTypeOptions: true,
      frameOptions: 'DENY',
      xssProtection: true,
      referrerPolicy: 'strict-origin-when-cross-origin'
    }
  },

  // Feature Flags
  features: {
    vectorSearch: true,
    ocrProcessing: true,
    budgetTracking: true,
    warrantyAlerts: true,
    analytics: true,
    multiCurrency: true,
    locationTracking: false, // Privacy-first approach
  },

  // Development Settings
  development: {
    // Reset database on schema changes
    resetDatabase: false,
    // Enable detailed logging
    verboseLogging: true,
    // Mock external services
    mockServices: {
      ocr: false,
      embeddings: false,
      notifications: false,
    }
  }
};

module.exports = config;