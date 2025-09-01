/**
 * Authentication Configuration for Hey-Bills
 * Handles Google OAuth, Email/Password, and JWT authentication
 */

const { config } = require('./supabase-environment');

/**
 * Google OAuth Configuration
 */
const googleOAuthConfig = {
  // Client credentials for different platforms
  clientId: {
    web: process.env.GOOGLE_CLIENT_ID_WEB,
    android: process.env.GOOGLE_CLIENT_ID_ANDROID,
    ios: process.env.GOOGLE_CLIENT_ID_IOS,
  },
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  
  // OAuth scopes
  scopes: [
    'openid',
    'profile',
    'email',
  ],
  
  // Redirect URIs for different environments
  redirectUris: {
    development: `${config.supabase.url}/auth/v1/callback`,
    production: `${config.supabase.url}/auth/v1/callback`,
    mobile: {
      android: `${config.packageName}://login-callback`,
      ios: `${config.urlScheme}://login-callback`,
    },
  },
  
  // OAuth flow configuration
  flowType: 'pkce', // Proof Key for Code Exchange (recommended for mobile)
  accessType: 'offline',
  prompt: 'consent',
  
  // Token configuration
  tokenEndpoint: 'https://oauth2.googleapis.com/token',
  userInfoEndpoint: 'https://www.googleapis.com/oauth2/v2/userinfo',
  
  // Additional configuration for mobile apps
  mobileConfig: {
    customScheme: config.urlScheme || 'heybills',
    customSchemeHost: 'login-callback',
    
    // Android-specific
    android: {
      packageName: config.packageName || 'com.heybills.app',
      sha256CertFingerprints: process.env.ANDROID_SHA256_CERT_FINGERPRINTS?.split(',') || [],
    },
    
    // iOS-specific
    ios: {
      bundleId: config.packageName || 'com.heybills.app',
      teamId: process.env.IOS_TEAM_ID,
    },
  },
};

/**
 * Supabase Auth Configuration
 */
const supabaseAuthConfig = {
  // Site URL for redirects
  siteUrl: process.env.SITE_URL || 'http://localhost:3000',
  
  // Auth providers
  providers: {
    google: {
      enabled: true,
      clientId: googleOAuthConfig.clientId.web,
      clientSecret: googleOAuthConfig.clientSecret,
      redirectTo: googleOAuthConfig.redirectUris.development,
    },
    email: {
      enabled: true,
      confirmationRequired: process.env.EMAIL_CONFIRMATION_REQUIRED !== 'false',
      securePasswordChange: true,
      minPasswordLength: parseInt(process.env.MIN_PASSWORD_LENGTH || '8'),
      passwordRequirements: {
        requireUppercase: process.env.REQUIRE_UPPERCASE !== 'false',
        requireLowercase: process.env.REQUIRE_LOWERCASE !== 'false',
        requireNumbers: process.env.REQUIRE_NUMBERS !== 'false',
        requireSpecialChars: process.env.REQUIRE_SPECIAL_CHARS !== 'false',
      },
    },
  },
  
  // JWT configuration
  jwt: {
    secret: config.security.jwtSecret,
    expiresIn: config.security.jwtExpiresIn,
    algorithm: 'HS256',
    
    // Custom claims
    customClaims: {
      'https://heybills.com/user_id': 'user.id',
      'https://heybills.com/email': 'user.email',
      'https://heybills.com/role': 'user.role',
      'https://heybills.com/business_type': 'user.user_metadata.business_type',
    },
  },
  
  // Session configuration
  session: {
    maxAge: config.security.sessionMaxAge,
    updateAge: 24 * 60 * 60, // 24 hours
    generateSessionId: true,
  },
  
  // Security settings
  security: {
    refreshTokenRotation: true,
    revokeRefreshTokenFamily: true,
    detectSessionInAnotherTab: true,
    persistSession: true,
    autoRefreshToken: true,
    
    // Rate limiting for auth endpoints
    rateLimiting: {
      signIn: {
        windowMs: config.rateLimiting.authWindowMs,
        max: config.rateLimiting.authMaxRequests,
      },
      signUp: {
        windowMs: config.rateLimiting.authWindowMs,
        max: config.rateLimiting.authMaxRequests,
      },
      passwordReset: {
        windowMs: 60 * 60 * 1000, // 1 hour
        max: 3, // Max 3 password reset attempts per hour
      },
    },
  },
  
  // Email templates configuration
  emailTemplates: {
    confirmSignUp: {
      subject: 'Welcome to Hey-Bills - Confirm your email',
      redirectTo: `${process.env.SITE_URL}/auth/confirm`,
    },
    inviteUser: {
      subject: 'You have been invited to Hey-Bills',
      redirectTo: `${process.env.SITE_URL}/auth/invite`,
    },
    magicLink: {
      subject: 'Your Hey-Bills magic link',
      redirectTo: `${process.env.SITE_URL}/auth/callback`,
    },
    recovery: {
      subject: 'Reset your Hey-Bills password',
      redirectTo: `${process.env.SITE_URL}/auth/reset-password`,
    },
    emailChange: {
      subject: 'Confirm your new email address',
      redirectTo: `${process.env.SITE_URL}/auth/confirm`,
    },
  },
  
  // Hook URLs for external processing
  hooks: {
    sendSms: process.env.AUTH_HOOK_SEND_SMS,
    sendEmail: process.env.AUTH_HOOK_SEND_EMAIL,
  },
};

/**
 * Password validation rules
 */
const passwordValidation = {
  minLength: supabaseAuthConfig.providers.email.minPasswordLength,
  maxLength: 128,
  
  validate: (password) => {
    const errors = [];
    const { passwordRequirements } = supabaseAuthConfig.providers.email;
    
    if (password.length < passwordValidation.minLength) {
      errors.push(`Password must be at least ${passwordValidation.minLength} characters long`);
    }
    
    if (password.length > passwordValidation.maxLength) {
      errors.push(`Password must be no more than ${passwordValidation.maxLength} characters long`);
    }
    
    if (passwordRequirements.requireUppercase && !/[A-Z]/.test(password)) {
      errors.push('Password must contain at least one uppercase letter');
    }
    
    if (passwordRequirements.requireLowercase && !/[a-z]/.test(password)) {
      errors.push('Password must contain at least one lowercase letter');
    }
    
    if (passwordRequirements.requireNumbers && !/\d/.test(password)) {
      errors.push('Password must contain at least one number');
    }
    
    if (passwordRequirements.requireSpecialChars && !/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
      errors.push('Password must contain at least one special character');
    }
    
    // Common password checks
    const commonPasswords = [
      'password', '123456', '123456789', 'qwerty', 'abc123', 
      'password123', 'admin', 'letmein', 'welcome', 'monkey'
    ];
    
    if (commonPasswords.some(common => password.toLowerCase().includes(common))) {
      errors.push('Password is too common. Please choose a more secure password');
    }
    
    return {
      isValid: errors.length === 0,
      errors,
    };
  },
};

/**
 * Auth middleware configuration
 */
const authMiddlewareConfig = {
  // JWT verification options
  jwtOptions: {
    secret: config.security.jwtSecret,
    algorithms: ['HS256'],
    ignoreExpiration: false,
    clockTolerance: 30, // 30 seconds
  },
  
  // Supabase auth options
  supabaseOptions: {
    url: config.supabase.url,
    serviceRoleKey: config.supabase.serviceRoleKey,
    anonKey: config.supabase.anonKey,
  },
  
  // Protected routes patterns
  protectedRoutes: [
    '/api/receipts',
    '/api/warranties',
    '/api/user',
    '/api/budgets',
    '/api/categories',
    '/api/upload',
    '/api/chat',
  ],
  
  // Public routes that don't require authentication
  publicRoutes: [
    '/api/health',
    '/api/auth/callback',
    '/api/auth/webhook',
    '/api/auth/reset-password',
  ],
  
  // Admin routes that require service role
  adminRoutes: [
    '/api/admin',
    '/api/system',
    '/api/embeddings/batch',
  ],
  
  // Error handling
  errors: {
    unauthorized: {
      status: 401,
      message: 'Authentication required',
      code: 'UNAUTHORIZED',
    },
    forbidden: {
      status: 403,
      message: 'Insufficient permissions',
      code: 'FORBIDDEN',
    },
    tokenExpired: {
      status: 401,
      message: 'Token has expired',
      code: 'TOKEN_EXPIRED',
    },
    invalidToken: {
      status: 401,
      message: 'Invalid token',
      code: 'INVALID_TOKEN',
    },
  },
};

/**
 * User profile management configuration
 */
const userProfileConfig = {
  // Required fields for user profiles
  requiredFields: ['full_name', 'email'],
  
  // Optional fields with defaults
  optionalFields: {
    business_type: 'individual',
    timezone: 'UTC',
    currency: 'USD',
    date_format: 'MM/DD/YYYY',
    notification_preferences: {
      email: true,
      push: true,
      warranty_alerts: true,
    },
  },
  
  // Profile validation rules
  validation: {
    full_name: {
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-Z\s\-'\.]+$/,
    },
    business_type: {
      allowedValues: ['individual', 'business', 'freelancer', 'organization'],
    },
    timezone: {
      validation: (timezone) => {
        try {
          Intl.DateTimeFormat(undefined, { timeZone: timezone });
          return true;
        } catch {
          return false;
        }
      },
    },
    currency: {
      allowedValues: ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY'],
    },
    date_format: {
      allowedValues: ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD'],
    },
  },
  
  // Auto-create profile on first sign-in
  autoCreateProfile: true,
  
  // Profile completion tracking
  completionFields: ['full_name', 'business_type', 'timezone', 'currency'],
};

/**
 * Export all auth configurations
 */
module.exports = {
  googleOAuthConfig,
  supabaseAuthConfig,
  passwordValidation,
  authMiddlewareConfig,
  userProfileConfig,
  
  // Helper functions
  getGoogleClientId: (platform = 'web') => {
    return googleOAuthConfig.clientId[platform] || googleOAuthConfig.clientId.web;
  },
  
  getRedirectUri: (environment = config.environment, platform = 'web') => {
    if (platform === 'android' || platform === 'ios') {
      return googleOAuthConfig.redirectUris.mobile[platform];
    }
    return googleOAuthConfig.redirectUris[environment] || googleOAuthConfig.redirectUris.development;
  },
  
  validatePassword: passwordValidation.validate,
  
  isProtectedRoute: (path) => {
    return authMiddlewareConfig.protectedRoutes.some(route => path.startsWith(route));
  },
  
  isPublicRoute: (path) => {
    return authMiddlewareConfig.publicRoutes.some(route => path.startsWith(route));
  },
  
  isAdminRoute: (path) => {
    return authMiddlewareConfig.adminRoutes.some(route => path.startsWith(route));
  },
  
  validateUserProfile: (profile) => {
    const errors = [];
    
    // Check required fields
    userProfileConfig.requiredFields.forEach(field => {
      if (!profile[field]) {
        errors.push(`${field} is required`);
      }
    });
    
    // Validate specific fields
    Object.entries(userProfileConfig.validation).forEach(([field, rules]) => {
      if (profile[field]) {
        const value = profile[field];
        
        if (rules.minLength && value.length < rules.minLength) {
          errors.push(`${field} must be at least ${rules.minLength} characters long`);
        }
        
        if (rules.maxLength && value.length > rules.maxLength) {
          errors.push(`${field} must be no more than ${rules.maxLength} characters long`);
        }
        
        if (rules.pattern && !rules.pattern.test(value)) {
          errors.push(`${field} contains invalid characters`);
        }
        
        if (rules.allowedValues && !rules.allowedValues.includes(value)) {
          errors.push(`${field} must be one of: ${rules.allowedValues.join(', ')}`);
        }
        
        if (rules.validation && !rules.validation(value)) {
          errors.push(`${field} is not valid`);
        }
      }
    });
    
    return {
      isValid: errors.length === 0,
      errors,
    };
  },
  
  getProfileCompletionPercentage: (profile) => {
    const completedFields = userProfileConfig.completionFields.filter(field => 
      profile[field] && profile[field] !== ''
    );
    return Math.round((completedFields.length / userProfileConfig.completionFields.length) * 100);
  },
};