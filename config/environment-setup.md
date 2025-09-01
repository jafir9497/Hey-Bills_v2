# Environment Configuration Guide - Hey-Bills v2

This guide provides comprehensive instructions for setting up environment variables for the Hey-Bills v2 project across all services.

## 📋 Overview

Hey-Bills v2 uses a multi-tier environment configuration system:

- **Root `.env`** - Project-wide shared variables
- **Backend `.env`** - Express.js server configuration
- **Frontend `.env`** - Flutter application configuration

## 🚀 Quick Setup

### 1. Copy Environment Template Files

```bash
# Copy root environment file
cp .env.example .env

# Copy backend environment file
cp backend/.env.example backend/.env

# Copy frontend environment file
cp frontend/.env.example frontend/.env
```

### 2. Configure Core Services

#### Required Supabase Configuration

1. Create a new Supabase project at https://supabase.com
2. Navigate to Settings > API to get your keys
3. Update these variables in all `.env` files:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-actual-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-actual-service-role-key
```

#### AI Services Configuration

Choose one of these AI service providers:

**Option 1: OpenAI (Recommended)**
```env
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_ORG_ID=your-openai-org-id
```

**Option 2: OpenRouter (Alternative)**
```env
OPENROUTER_API_KEY=sk-or-v1-your-openrouter-api-key-here
```

#### Firebase Push Notifications

1. Create a Firebase project at https://console.firebase.google.com
2. Generate a service account key
3. Configure Firebase variables in all `.env` files

## 🔧 Service-Specific Configuration

### Backend Configuration (`backend/.env`)

The backend requires additional configuration for:

- **Database connections**
- **File upload handling**
- **OCR processing**
- **Background job queues**
- **Caching and performance**

Key backend-specific variables:
```env
PORT=3001
NODE_ENV=development
JWT_SECRET=your-super-secret-jwt-key-change-in-production
MAX_FILE_SIZE=10485760
OCR_ENGINE=google-vision
RATE_LIMIT_WINDOW_MS=900000
```

### Frontend Configuration (`frontend/.env`)

The Flutter frontend requires:

- **Platform-specific OAuth client IDs**
- **Firebase configuration for each platform**
- **Feature flags and UI settings**
- **Build and deployment configuration**

Key frontend-specific variables:
```env
FLUTTER_ENV=development
DEBUG_MODE=true
GOOGLE_CLIENT_ID_ANDROID=your-android-client-id.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=your-ios-client-id.googleusercontent.com
ENABLE_BIOMETRIC_AUTH=true
```

## 🔐 Security Configuration

### Required Security Variables

```env
# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters
SESSION_SECRET=your-session-secret-key

# Encryption Keys
ENCRYPTION_KEY_ALIAS=heybills_encryption_key

# CORS Configuration
CORS_ORIGINS=http://localhost:3000,http://localhost:5173,capacitor://localhost
```

### Certificate Pinning (Production)

```env
ENABLE_CERTIFICATE_PINNING=true
API_CERTIFICATE_SHA256=your-api-cert-sha256-hash
```

## 📊 Analytics and Monitoring

### Error Tracking (Sentry)

```env
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
SENTRY_ENVIRONMENT=development
```

### Analytics Services

```env
GOOGLE_ANALYTICS_ID=G-XXXXXXXXXX
MIXPANEL_TOKEN=your-mixpanel-token
```

## 🚀 Deployment Configuration

### Environment-Specific URLs

**Development:**
```env
API_BASE_URL=http://localhost:3001
FRONTEND_URL=http://localhost:5173
```

**Staging:**
```env
API_BASE_URL=https://api-staging.heybills.com
FRONTEND_URL=https://staging.heybills.com
```

**Production:**
```env
API_BASE_URL=https://api.heybills.com
FRONTEND_URL=https://heybills.com
```

### Docker Configuration

```env
DOCKER_NODE_VERSION=18-alpine
DOCKER_PORT=3001
```

## 🔍 Validation and Testing

### Environment Validation

The application includes built-in environment validation:

- **Backend**: Validates required variables on startup
- **Frontend**: Validates Supabase configuration on initialization

### Test Configuration

Separate test environment variables:
```env
TEST_DATABASE_URL=postgresql://postgres:password@localhost:5432/hey_bills_test
TEST_API_BASE_URL=http://localhost:3001
MOCK_SERVICES_IN_TESTS=true
```

## ⚡ Performance Optimization

### Caching Configuration

```env
ENABLE_HTTP_CACHE=true
HTTP_CACHE_SIZE_MB=50
IMAGE_CACHE_SIZE_MB=100
REDIS_URL=redis://localhost:6379
```

### Connection Optimization

```env
CONNECTION_TIMEOUT_SECONDS=30
READ_TIMEOUT_SECONDS=30
MAX_CONCURRENT_REQUESTS=10
DB_POOL_MAX=10
```

## 🎯 Feature Flags

Enable/disable features across environments:

```env
# Core Features
ENABLE_OCR=true
ENABLE_AI_CHAT=true
ENABLE_VECTOR_SEARCH=true
ENABLE_OFFLINE_MODE=true

# Advanced Features
ENABLE_BUDGET_INSIGHTS=true
ENABLE_WARRANTY_TRACKING=true
ENABLE_MULTI_CURRENCY=false

# Experimental Features
ENABLE_LOCATION_TRACKING=false
ENABLE_VOICE_NOTES=false
ENABLE_WEB_ASSEMBLY=false
```

## 🛠 Development Tools

### Debug Configuration

```env
DEBUG_MODE=true
LOG_LEVEL=debug
VERBOSE_LOGGING=true
ENABLE_INSPECTOR=true
```

### Mock Services (Development)

```env
MOCK_OCR_SERVICE=false
MOCK_OPENAI=false
MOCK_EMAIL=false
MOCK_API_RESPONSES=false
```

## 📱 Platform-Specific Configuration

### Android

```env
ANDROID_PACKAGE_NAME=com.heybills.app
ANDROID_MIN_SDK_VERSION=21
ANDROID_TARGET_SDK_VERSION=34
GOOGLE_CLIENT_ID_ANDROID=your-android-client-id.googleusercontent.com
```

### iOS

```env
IOS_BUNDLE_ID=com.heybills.app
IOS_DEPLOYMENT_TARGET=12.0
IOS_TEAM_ID=your-ios-team-id
GOOGLE_CLIENT_ID_IOS=your-ios-client-id.googleusercontent.com
```

### Web (if supporting PWA)

```env
WEB_RENDERER=html
ENABLE_PWA=true
PWA_MANIFEST_PATH=web/manifest.json
GOOGLE_CLIENT_ID_WEB=your-web-client-id.googleusercontent.com
```

## ✅ Environment Checklist

### Development Setup Checklist

- [ ] Supabase project created and configured
- [ ] AI service API key obtained (OpenAI or OpenRouter)
- [ ] Firebase project created for push notifications
- [ ] Google Vision API enabled for OCR
- [ ] Google OAuth credentials configured for each platform
- [ ] Environment files copied and configured
- [ ] Database migrations applied
- [ ] Test environment validated

### Production Deployment Checklist

- [ ] Production Supabase project configured
- [ ] Production Firebase project configured
- [ ] SSL certificates configured
- [ ] Domain DNS configured
- [ ] CDN configured for static assets
- [ ] Monitoring and analytics configured
- [ ] Backup and disaster recovery configured
- [ ] Security headers and CORS configured
- [ ] Rate limiting configured
- [ ] Error tracking configured

## 🔧 Troubleshooting

### Common Issues

**1. Supabase Connection Errors**
- Verify SUPABASE_URL and SUPABASE_ANON_KEY
- Check if project is paused
- Verify network connectivity

**2. Authentication Errors**
- Check Google OAuth client ID configuration
- Verify redirect URLs in Google Console
- Ensure Firebase configuration matches

**3. Push Notification Issues**
- Verify FCM configuration
- Check Firebase service account permissions
- Validate FCM server key

**4. OCR Processing Errors**
- Verify Google Vision API is enabled
- Check API quotas and limits
- Validate service account credentials

### Environment Variable Validation

Both frontend and backend include validation for critical environment variables. Check the console output for specific missing or invalid variables.

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [OpenRouter API Documentation](https://openrouter.ai/docs)
- [Flutter Environment Variables](https://flutter.dev/docs/deployment/flavors)
- [Express.js Environment Variables](https://expressjs.com/en/advanced/best-practice-security.html)

## 🆘 Support

If you encounter issues with environment configuration:

1. Check the console output for validation errors
2. Verify all required services are properly configured
3. Review this guide for platform-specific requirements
4. Check the service documentation for specific configuration requirements

---

*This configuration guide is maintained as part of the Hey-Bills v2 project. Please keep it updated when adding new environment variables or services.*