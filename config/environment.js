/**
 * Environment Configuration
 * Manages environment variables and configuration across different deployment stages
 */

// Environment validation and defaults
const requiredEnvVars = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY'
];

const optionalEnvVars = {
  // Database
  SUPABASE_SERVICE_ROLE_KEY: null,
  DATABASE_URL: null,
  
  // Authentication
  GOOGLE_CLIENT_ID: null,
  GOOGLE_CLIENT_SECRET: null,
  JWT_SECRET: null,
  
  // AI Services
  OPENAI_API_KEY: null,
  GOOGLE_VISION_API_KEY: null,
  
  // Application
  NODE_ENV: 'development',
  PORT: '3000',
  API_BASE_URL: 'http://localhost:3000',
  FRONTEND_URL: 'http://localhost:5173',
  
  // Storage
  SUPABASE_STORAGE_URL: null,
  
  // Monitoring
  SENTRY_DSN: null,
  
  // Notifications
  PUSH_NOTIFICATION_KEY: null,
  EMAIL_SERVICE_API_KEY: null,
  
  // Feature Flags
  ENABLE_OCR: 'true',
  ENABLE_VECTOR_SEARCH: 'true',
  ENABLE_ANALYTICS: 'true',
};

/**
 * Validates required environment variables
 * @throws {Error} If required environment variables are missing
 */
function validateEnvironment() {
  const missing = requiredEnvVars.filter(varName => !process.env[varName]);
  
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n\n` +
      'Please check your .env file or environment configuration.\n' +
      'See .env.example for the complete list of required variables.'
    );
  }
}

/**
 * Gets environment configuration with validation
 * @param {string} environment - Target environment (development, staging, production)
 * @returns {Object} Environment configuration object
 */
function getEnvironmentConfig(environment = process.env.NODE_ENV || 'development') {
  // Validate required variables
  validateEnvironment();

  const config = {
    // Environment info
    environment,
    isDevelopment: environment === 'development',
    isStaging: environment === 'staging',
    isProduction: environment === 'production',
    
    // Supabase Configuration
    supabase: {
      url: process.env.SUPABASE_URL,
      anonKey: process.env.SUPABASE_ANON_KEY,
      serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
      storageUrl: process.env.SUPABASE_STORAGE_URL || 
                  `${process.env.SUPABASE_URL}/storage/v1`,
    },

    // Database
    database: {
      url: process.env.DATABASE_URL,
      maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
      ssl: environment === 'production' ? { rejectUnauthorized: false } : false,
    },

    // Authentication
    auth: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      },
      jwt: {
        secret: process.env.JWT_SECRET,
        expiresIn: process.env.JWT_EXPIRES_IN || '1h',
        refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
      }
    },

    // AI Services
    ai: {
      openai: {
        apiKey: process.env.OPENAI_API_KEY,
        model: process.env.OPENAI_MODEL || 'gpt-4',
        embeddingModel: process.env.OPENAI_EMBEDDING_MODEL || 'text-embedding-ada-002',
        maxTokens: parseInt(process.env.OPENAI_MAX_TOKENS) || 4000,
      },
      googleVision: {
        apiKey: process.env.GOOGLE_VISION_API_KEY,
      }
    },

    // Server Configuration
    server: {
      port: parseInt(process.env.PORT) || 3000,
      host: process.env.HOST || 'localhost',
      apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
      corsOrigins: process.env.CORS_ORIGINS 
        ? process.env.CORS_ORIGINS.split(',').map(origin => origin.trim())
        : ['http://localhost:3000', 'http://localhost:5173', 'capacitor://localhost'],
    },

    // Frontend Configuration
    frontend: {
      url: process.env.FRONTEND_URL || 'http://localhost:5173',
    },

    // Feature Flags
    features: {
      enableOcr: process.env.ENABLE_OCR === 'true',
      enableVectorSearch: process.env.ENABLE_VECTOR_SEARCH === 'true',
      enableAnalytics: process.env.ENABLE_ANALYTICS === 'true',
      enableLocationTracking: process.env.ENABLE_LOCATION_TRACKING === 'true',
      enablePushNotifications: process.env.ENABLE_PUSH_NOTIFICATIONS === 'true',
    },

    // Monitoring & Logging
    monitoring: {
      sentryDsn: process.env.SENTRY_DSN,
      logLevel: process.env.LOG_LEVEL || (environment === 'production' ? 'info' : 'debug'),
      enableHealthcheck: process.env.ENABLE_HEALTHCHECK !== 'false',
    },

    // File Upload & Storage
    storage: {
      maxFileSize: process.env.MAX_FILE_SIZE || '10MB',
      allowedImageTypes: ['image/jpeg', 'image/png', 'image/webp'],
      allowedDocumentTypes: ['application/pdf'],
    },

    // Rate Limiting
    rateLimit: {
      windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
      max: parseInt(process.env.RATE_LIMIT_MAX) || 100, // limit each IP to 100 requests per windowMs
      standardHeaders: true,
      legacyHeaders: false,
    },

    // Email & Notifications
    notifications: {
      pushNotificationKey: process.env.PUSH_NOTIFICATION_KEY,
      emailServiceApiKey: process.env.EMAIL_SERVICE_API_KEY,
      fromEmail: process.env.FROM_EMAIL || 'noreply@heybills.com',
    }
  };

  return config;
}

/**
 * Environment-specific configurations
 */
const environmentConfigs = {
  development: {
    database: {
      ssl: false,
      logging: true,
    },
    server: {
      corsOrigins: ['http://localhost:3000', 'http://localhost:5173', 'capacitor://localhost'],
    },
    features: {
      enableAnalytics: false, // Disable analytics in development
    },
    monitoring: {
      logLevel: 'debug',
    }
  },

  staging: {
    database: {
      ssl: { rejectUnauthorized: false },
      logging: false,
    },
    server: {
      corsOrigins: ['https://staging.heybills.com'],
    },
    monitoring: {
      logLevel: 'info',
    }
  },

  production: {
    database: {
      ssl: { rejectUnauthorized: false },
      logging: false,
    },
    server: {
      corsOrigins: ['https://heybills.com', 'https://app.heybills.com'],
    },
    features: {
      enableAnalytics: true,
    },
    monitoring: {
      logLevel: 'warn',
    },
    rateLimit: {
      max: 1000, // Higher limit for production
      windowMs: 15 * 60 * 1000,
    }
  }
};

/**
 * Gets the current environment configuration
 */
function getCurrentConfig() {
  const environment = process.env.NODE_ENV || 'development';
  const baseConfig = getEnvironmentConfig(environment);
  const envSpecificConfig = environmentConfigs[environment] || {};
  
  // Deep merge configurations
  return mergeDeep(baseConfig, envSpecificConfig);
}

/**
 * Deep merge utility function
 */
function mergeDeep(target, source) {
  const result = { ...target };
  
  for (const key in source) {
    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
      result[key] = mergeDeep(target[key] || {}, source[key]);
    } else {
      result[key] = source[key];
    }
  }
  
  return result;
}

module.exports = {
  getEnvironmentConfig,
  getCurrentConfig,
  validateEnvironment,
  requiredEnvVars,
  optionalEnvVars,
};