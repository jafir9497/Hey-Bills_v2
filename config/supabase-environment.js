/**
 * Supabase Environment Configuration
 * Centralized environment variable management for different deployment environments
 */

// Environment type detection
const getEnvironment = () => {
  if (process.env.NODE_ENV === 'production') {
    return 'production';
  }
  if (process.env.NODE_ENV === 'test') {
    return 'test';
  }
  return 'development';
};

// Base configuration
const baseConfig = {
  // Server Configuration
  port: process.env.PORT || 3001,
  host: process.env.HOST || '0.0.0.0',
  
  // Application Information
  app: {
    name: process.env.APP_NAME || 'hey-bills-backend',
    version: process.env.APP_VERSION || '1.0.0',
  },
  
  // CORS Configuration
  cors: {
    origin: (process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:5173').split(','),
    credentials: process.env.CORS_CREDENTIALS === 'true',
  },
  
  // Security Configuration
  security: {
    helmet: process.env.HELMET_ENABLED !== 'false',
    trustProxy: process.env.TRUST_PROXY === 'true',
    jwtSecret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production',
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
    sessionSecret: process.env.SESSION_SECRET || 'your-session-secret-key',
    sessionMaxAge: parseInt(process.env.SESSION_MAX_AGE || '86400000'),
  },
  
  // Rate Limiting
  rateLimiting: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
    authWindowMs: parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS || '900000'),
    authMaxRequests: parseInt(process.env.AUTH_RATE_LIMIT_MAX_REQUESTS || '5'),
    uploadWindowMs: parseInt(process.env.UPLOAD_RATE_LIMIT_WINDOW_MS || '3600000'),
    uploadMaxRequests: parseInt(process.env.UPLOAD_RATE_LIMIT_MAX_REQUESTS || '50'),
  },
  
  // File Upload Configuration
  upload: {
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760'), // 10MB
    maxFilesPerRequest: parseInt(process.env.MAX_FILES_PER_REQUEST || '10'),
    allowedImageTypes: (process.env.ALLOWED_IMAGE_TYPES || 'image/jpeg,image/png,image/webp').split(','),
    allowedDocumentTypes: (process.env.ALLOWED_DOCUMENT_TYPES || 'application/pdf').split(','),
    tempUploadDir: process.env.TEMP_UPLOAD_DIR || './temp/uploads',
    cleanupTempFiles: process.env.CLEANUP_TEMP_FILES !== 'false',
    tempFileMaxAge: parseInt(process.env.TEMP_FILE_MAX_AGE || '3600000'), // 1 hour
  },
  
  // Image Processing
  imageProcessing: {
    quality: parseInt(process.env.IMAGE_QUALITY || '80'),
    maxWidth: parseInt(process.env.IMAGE_MAX_WIDTH || '2048'),
    maxHeight: parseInt(process.env.IMAGE_MAX_HEIGHT || '2048'),
  },
  
  // AI/ML Configuration
  ai: {
    openai: {
      apiKey: process.env.OPENAI_API_KEY,
      orgId: process.env.OPENAI_ORG_ID,
      model: process.env.OPENAI_MODEL || 'gpt-4-turbo-preview',
      embeddingModel: process.env.OPENAI_EMBEDDING_MODEL || 'text-embedding-3-small',
    },
    googleVision: {
      apiKey: process.env.GOOGLE_VISION_API_KEY,
      credentialsPath: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    },
    openRouter: {
      apiKey: process.env.OPENROUTER_API_KEY,
      model: process.env.OPENROUTER_MODEL || 'anthropic/claude-3.5-sonnet',
    },
    ocr: {
      engine: process.env.OCR_ENGINE || 'google-vision',
      fallbackEngine: process.env.OCR_FALLBACK_ENGINE || 'tesseract',
      confidenceThreshold: parseFloat(process.env.OCR_CONFIDENCE_THRESHOLD || '0.6'),
    },
    vectorSearch: {
      embeddingDimensions: parseInt(process.env.EMBEDDING_DIMENSIONS || '1536'),
      similarityThreshold: parseFloat(process.env.SIMILARITY_THRESHOLD || '0.7'),
      maxSearchResults: parseInt(process.env.MAX_SEARCH_RESULTS || '10'),
    },
    features: {
      enableAiCategorization: process.env.ENABLE_AI_CATEGORIZATION !== 'false',
      enableSmartExtraction: process.env.ENABLE_SMART_EXTRACTION !== 'false',
      enableDuplicateDetection: process.env.ENABLE_DUPLICATE_DETECTION !== 'false',
    },
  },
  
  // Caching Configuration
  cache: {
    enabled: process.env.CACHE_ENABLED !== 'false',
    ttl: parseInt(process.env.CACHE_TTL || '3600'), // 1 hour
    maxSize: parseInt(process.env.CACHE_MAX_SIZE || '100'),
    redis: {
      url: process.env.REDIS_URL,
      password: process.env.REDIS_PASSWORD,
      db: parseInt(process.env.REDIS_DB || '0'),
    },
  },
  
  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.LOG_FORMAT || 'combined',
    file: process.env.LOG_FILE,
    rotation: process.env.LOG_ROTATION || 'daily',
    maxFiles: parseInt(process.env.LOG_MAX_FILES || '7'),
    debug: {
      sql: process.env.DEBUG_SQL === 'true',
      api: process.env.DEBUG_API === 'true',
      auth: process.env.DEBUG_AUTH === 'true',
    },
  },
  
  // Health Check Configuration
  health: {
    enabled: process.env.HEALTH_CHECK_ENABLED !== 'false',
    path: process.env.HEALTH_CHECK_PATH || '/health',
    dependencies: (process.env.HEALTH_CHECK_DEPENDENCIES || 'supabase,openai').split(','),
  },
  
  // Monitoring Configuration
  monitoring: {
    metricsEnabled: process.env.METRICS_ENABLED !== 'false',
    metricsPath: process.env.METRICS_PATH || '/metrics',
    sentry: {
      dsn: process.env.SENTRY_DSN,
      environment: process.env.SENTRY_ENVIRONMENT || getEnvironment(),
    },
  },
  
  // Background Jobs Configuration
  jobs: {
    enabled: process.env.ENABLE_JOB_QUEUE !== 'false',
    concurrency: parseInt(process.env.JOB_CONCURRENCY || '5'),
    retryAttempts: parseInt(process.env.JOB_RETRY_ATTEMPTS || '3'),
    retryDelay: parseInt(process.env.JOB_RETRY_DELAY || '5000'),
    cronJobsEnabled: process.env.ENABLE_CRON_JOBS !== 'false',
    webhookProcessingEnabled: process.env.WEBHOOK_PROCESSING_ENABLED !== 'false',
  },
  
  // Feature Flags
  features: {
    enableOcr: process.env.ENABLE_OCR !== 'false',
    enableAiChat: process.env.ENABLE_AI_CHAT !== 'false',
    enableVectorSearch: process.env.ENABLE_VECTOR_SEARCH !== 'false',
    enableDuplicateDetection: process.env.ENABLE_DUPLICATE_DETECTION !== 'false',
    enableBudgetInsights: process.env.ENABLE_BUDGET_INSIGHTS !== 'false',
    enableWarrantyTracking: process.env.ENABLE_WARRANTY_TRACKING !== 'false',
    enableExpenseCategorization: process.env.ENABLE_EXPENSE_CATEGORIZATION !== 'false',
    enableReceiptTemplates: process.env.ENABLE_RECEIPT_TEMPLATES !== 'false',
    // Experimental features
    enableMultiCurrency: process.env.ENABLE_MULTI_CURRENCY === 'true',
    enableLocationTracking: process.env.ENABLE_LOCATION_TRACKING === 'true',
    enableVoiceNotes: process.env.ENABLE_VOICE_NOTES === 'true',
  },
  
  // Performance Configuration
  performance: {
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT || '30000'),
    databaseTimeout: parseInt(process.env.DATABASE_TIMEOUT || '10000'),
    externalApiTimeout: parseInt(process.env.EXTERNAL_API_TIMEOUT || '15000'),
    compressionEnabled: process.env.COMPRESSION_ENABLED !== 'false',
    compressionThreshold: parseInt(process.env.COMPRESSION_THRESHOLD || '1024'),
    keepAliveTimeout: parseInt(process.env.KEEP_ALIVE_TIMEOUT || '5000'),
    headersTimeout: parseInt(process.env.HEADERS_TIMEOUT || '60000'),
  },
};

// Environment-specific configurations
const environmentConfigs = {
  development: {
    supabase: {
      url: process.env.SUPABASE_URL || 'https://your-project-ref.supabase.co',
      anonKey: process.env.SUPABASE_ANON_KEY || 'your-anon-key-here',
      serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-service-role-key-here',
      database: {
        url: process.env.DATABASE_URL || 'postgresql://postgres:password@db.your-project-ref.supabase.co:5432/postgres',
        poolMin: parseInt(process.env.DB_POOL_MIN || '2'),
        poolMax: parseInt(process.env.DB_POOL_MAX || '10'),
        idleTimeout: parseInt(process.env.DB_POOL_IDLE_TIMEOUT || '30000'),
        acquireTimeout: parseInt(process.env.DB_POOL_ACQUIRE_TIMEOUT || '60000'),
      },
    },
    oauth: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      },
    },
    debug: true,
    verbose: process.env.VERBOSE_LOGGING === 'true',
    prettyPrintJson: process.env.PRETTY_PRINT_JSON !== 'false',
    mock: {
      openai: process.env.MOCK_OPENAI === 'true',
      googleVision: process.env.MOCK_GOOGLE_VISION === 'true',
      email: process.env.MOCK_EMAIL === 'true',
    },
  },
  
  test: {
    supabase: {
      url: process.env.TEST_SUPABASE_URL || process.env.SUPABASE_URL,
      anonKey: process.env.TEST_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY,
      serviceRoleKey: process.env.TEST_SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY,
      database: {
        url: process.env.TEST_DATABASE_URL || 'postgresql://postgres:password@localhost:5432/hey_bills_test',
        poolMin: 1,
        poolMax: 5,
      },
    },
    oauth: {
      google: {
        clientId: 'test-client-id',
        clientSecret: 'test-client-secret',
      },
    },
    debug: false,
    verbose: false,
    prettyPrintJson: false,
    mock: {
      openai: true,
      googleVision: true,
      email: true,
    },
    // Override for testing
    rateLimiting: {
      windowMs: 60000, // 1 minute
      maxRequests: 1000,
      authMaxRequests: 50,
      uploadMaxRequests: 200,
    },
  },
  
  production: {
    supabase: {
      url: process.env.SUPABASE_URL,
      anonKey: process.env.SUPABASE_ANON_KEY,
      serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
      database: {
        url: process.env.DATABASE_URL,
        poolMin: parseInt(process.env.DB_POOL_MIN || '5'),
        poolMax: parseInt(process.env.DB_POOL_MAX || '20'),
        idleTimeout: parseInt(process.env.DB_POOL_IDLE_TIMEOUT || '30000'),
        acquireTimeout: parseInt(process.env.DB_POOL_ACQUIRE_TIMEOUT || '60000'),
      },
    },
    oauth: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      },
    },
    debug: false,
    verbose: false,
    prettyPrintJson: false,
    mock: {
      openai: false,
      googleVision: false,
      email: false,
    },
    // Production-specific overrides
    security: {
      ...baseConfig.security,
      jwtSecret: process.env.JWT_SECRET, // Must be set in production
      sessionSecret: process.env.SESSION_SECRET, // Must be set in production
    },
    logging: {
      ...baseConfig.logging,
      level: process.env.LOG_LEVEL || 'warn',
      file: process.env.LOG_FILE || 'logs/production.log',
    },
  },
};

// Merge configurations
const currentEnvironment = getEnvironment();
const config = {
  ...baseConfig,
  ...environmentConfigs[currentEnvironment],
  environment: currentEnvironment,
};

// Validation functions
const validateConfig = () => {
  const errors = [];
  
  // Required Supabase configuration
  if (!config.supabase?.url || config.supabase.url.includes('your-project-ref')) {
    errors.push('SUPABASE_URL must be set with your actual project URL');
  }
  
  if (!config.supabase?.anonKey || config.supabase.anonKey.includes('your-anon-key')) {
    errors.push('SUPABASE_ANON_KEY must be set with your actual anon key');
  }
  
  if (!config.supabase?.serviceRoleKey || config.supabase.serviceRoleKey.includes('your-service-role-key')) {
    errors.push('SUPABASE_SERVICE_ROLE_KEY must be set with your actual service role key');
  }
  
  // Production-specific validations
  if (currentEnvironment === 'production') {
    if (config.security.jwtSecret === 'your-super-secret-jwt-key-change-in-production') {
      errors.push('JWT_SECRET must be changed in production');
    }
    
    if (config.security.sessionSecret === 'your-session-secret-key') {
      errors.push('SESSION_SECRET must be changed in production');
    }
    
    if (!config.ai.openai.apiKey) {
      errors.push('OPENAI_API_KEY is required for AI features');
    }
  }
  
  // Feature-dependent validations
  if (config.features.enableOcr && !config.ai.googleVision.apiKey && !config.ai.googleVision.credentialsPath) {
    console.warn('⚠️  Warning: OCR is enabled but no Google Vision API key is configured. OCR will fallback to Tesseract.');
  }
  
  if (config.features.enableAiChat && !config.ai.openai.apiKey) {
    errors.push('OPENAI_API_KEY is required when AI chat is enabled');
  }
  
  return errors;
};

// Get configuration with validation
const getConfig = () => {
  const errors = validateConfig();
  
  if (errors.length > 0) {
    console.error('❌ Configuration errors:');
    errors.forEach(error => console.error(`   - ${error}`));
    
    if (currentEnvironment === 'production') {
      throw new Error('Configuration validation failed in production environment');
    } else {
      console.warn('⚠️  Configuration warnings detected. Application may not function correctly.');
    }
  }
  
  return config;
};

// Export configuration
module.exports = {
  config: getConfig(),
  validateConfig,
  getEnvironment,
  
  // Helper functions
  isProduction: () => currentEnvironment === 'production',
  isDevelopment: () => currentEnvironment === 'development',
  isTest: () => currentEnvironment === 'test',
  
  // Configuration getters
  getSupabaseConfig: () => config.supabase,
  getSecurityConfig: () => config.security,
  getAiConfig: () => config.ai,
  getCacheConfig: () => config.cache,
  getUploadConfig: () => config.upload,
  getLoggingConfig: () => config.logging,
  getHealthConfig: () => config.health,
  getFeatureFlags: () => config.features,
};