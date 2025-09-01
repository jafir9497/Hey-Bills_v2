# Deployment Environment Configuration - Hey-Bills v2

This document outlines the deployment configurations for different environments in the Hey-Bills v2 project.

## 🏗️ Environment Types

### 1. Development Environment

**Purpose**: Local development and testing

**Configuration:**
```env
# Environment
NODE_ENV=development
FLUTTER_ENV=development
DEBUG_MODE=true

# URLs
API_BASE_URL=http://localhost:3001
FRONTEND_URL=http://localhost:5173
SUPABASE_URL=https://dev-project.supabase.co

# Security (Relaxed for development)
CORS_ORIGINS=http://localhost:3000,http://localhost:5173,capacitor://localhost
SECURE_COOKIES=false
ENABLE_CERTIFICATE_PINNING=false

# Features (Enable debugging)
LOG_LEVEL=debug
VERBOSE_LOGGING=true
MOCK_SERVICES_IN_TESTS=true
ENABLE_REQUEST_LOGGING=true

# AI Services (Test keys)
OPENAI_MODEL=gpt-4-turbo-preview
OPENROUTER_MODEL=anthropic/claude-3.5-sonnet
```

### 2. Staging Environment

**Purpose**: Pre-production testing and QA

**Configuration:**
```env
# Environment
NODE_ENV=staging
FLUTTER_ENV=staging
DEBUG_MODE=false

# URLs
API_BASE_URL=https://api-staging.heybills.com
FRONTEND_URL=https://staging.heybills.com
SUPABASE_URL=https://staging-project.supabase.co

# Security (Production-like)
CORS_ORIGINS=https://staging.heybills.com,https://api-staging.heybills.com
SECURE_COOKIES=true
ENABLE_CERTIFICATE_PINNING=true

# Features (Limited debugging)
LOG_LEVEL=info
VERBOSE_LOGGING=false
ENABLE_ANALYTICS=true
ENABLE_PERFORMANCE_MONITORING=true

# AI Services (Production models)
OPENAI_MODEL=gpt-4-turbo-preview
OPENROUTER_MODEL=anthropic/claude-3.5-sonnet
```

### 3. Production Environment

**Purpose**: Live production deployment

**Configuration:**
```env
# Environment
NODE_ENV=production
FLUTTER_ENV=production
DEBUG_MODE=false

# URLs
API_BASE_URL=https://api.heybills.com
FRONTEND_URL=https://heybills.com
SUPABASE_URL=https://prod-project.supabase.co

# Security (Maximum)
CORS_ORIGINS=https://heybills.com,https://api.heybills.com
SECURE_COOKIES=true
ENABLE_CERTIFICATE_PINNING=true
ENABLE_SECURITY_HEADERS=true
ENABLE_HELMET=true

# Features (Production optimized)
LOG_LEVEL=error
VERBOSE_LOGGING=false
ENABLE_COMPRESSION=true
ENABLE_ANALYTICS=true
ENABLE_PERFORMANCE_MONITORING=true

# Performance
ENABLE_HTTP_CACHE=true
ENABLE_REDIS_CACHE=true
CONNECTION_TIMEOUT_SECONDS=15
READ_TIMEOUT_SECONDS=15

# AI Services (Production models)
OPENAI_MODEL=gpt-4-turbo-preview
OPENROUTER_MODEL=anthropic/claude-3.5-sonnet
```

## 🚀 Platform-Specific Deployments

### Docker Container Deployment

**Dockerfile Environment:**
```dockerfile
# Backend Dockerfile
FROM node:18-alpine

# Environment variables
ENV NODE_ENV=production
ENV PORT=3001
ENV DOCKER_PORT=3001
ENV DOCKER_NODE_VERSION=18-alpine

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Run application
EXPOSE 3001
CMD ["npm", "start"]
```

**Docker Compose Configuration:**
```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
    
  frontend:
    build: ./frontend
    ports:
      - "5173:5173"
    environment:
      - FLUTTER_ENV=production
      - API_BASE_URL=http://backend:3001
    depends_on:
      - backend
    restart: unless-stopped
```

### Heroku Deployment

**Heroku Environment Variables:**
```bash
# Set Heroku config vars
heroku config:set NODE_ENV=production
heroku config:set DEPLOYMENT_PLATFORM=heroku
heroku config:set PORT=\$PORT
heroku config:set SUPABASE_URL=your-prod-supabase-url
heroku config:set SUPABASE_ANON_KEY=your-prod-anon-key

# Buildpack configuration
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/flutter (if needed)
```

**Procfile:**
```
web: cd backend && npm start
```

### AWS Deployment

**AWS Environment Configuration:**
```env
# AWS-specific variables
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_S3_BUCKET=heybills-assets
AWS_CLOUDFRONT_DOMAIN=cdn.heybills.com

# ECS/Fargate configuration
DEPLOYMENT_PLATFORM=aws-ecs
CONTAINER_PORT=3001
HEALTH_CHECK_PATH=/health

# RDS Database (if not using Supabase)
DATABASE_URL=postgresql://user:pass@rds-endpoint:5432/heybills

# Redis Cache
REDIS_URL=redis://elasticache-endpoint:6379
```

### Google Cloud Platform (GCP)

**GCP Environment Configuration:**
```env
# GCP-specific variables
GOOGLE_CLOUD_PROJECT=heybills-prod
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
GCP_REGION=us-central1

# Cloud Run configuration
DEPLOYMENT_PLATFORM=gcp-cloud-run
PORT=\$PORT
CLOUD_RUN_SERVICE_TIMEOUT=3600

# Cloud SQL (if not using Supabase)
CLOUD_SQL_CONNECTION_NAME=project:region:instance
DATABASE_URL=postgresql://user:pass@/dbname?host=/cloudsql/connection-name

# Memorystore Redis
REDIS_HOST=redis-instance-ip
REDIS_PORT=6379
```

### Vercel Deployment (Frontend)

**vercel.json:**
```json
{
  "version": 2,
  "builds": [
    {
      "src": "frontend/**",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build/web"
      }
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "https://api.heybills.com/api/$1"
    },
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ],
  "env": {
    "FLUTTER_ENV": "production",
    "API_BASE_URL": "https://api.heybills.com",
    "SUPABASE_URL": "@supabase_url",
    "SUPABASE_ANON_KEY": "@supabase_anon_key"
  }
}
```

### Netlify Deployment (Frontend)

**netlify.toml:**
```toml
[build]
  base = "frontend/"
  publish = "build/web"
  command = "flutter build web --release"

[build.environment]
  FLUTTER_ENV = "production"
  API_BASE_URL = "https://api.heybills.com"

[[redirects]]
  from = "/api/*"
  to = "https://api.heybills.com/api/:splat"
  status = 200
  force = true

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

## 🔒 Security Configurations by Environment

### Development Security
```env
# Relaxed security for development
SECURE_COOKIES=false
SAME_SITE_COOKIES=lax
CORS_CREDENTIALS=true
ENABLE_HELMET=false
CERTIFICATE_PINNING=false
JWT_EXPIRES_IN=24h
```

### Staging Security
```env
# Production-like security for testing
SECURE_COOKIES=true
SAME_SITE_COOKIES=strict
CORS_CREDENTIALS=true
ENABLE_HELMET=true
CERTIFICATE_PINNING=true
JWT_EXPIRES_IN=1h
```

### Production Security
```env
# Maximum security for production
SECURE_COOKIES=true
SAME_SITE_COOKIES=strict
CORS_CREDENTIALS=false
ENABLE_HELMET=true
CERTIFICATE_PINNING=true
ENABLE_RATE_LIMITING=true
JWT_EXPIRES_IN=1h
SESSION_TIMEOUT_MINUTES=15
```

## 📊 Performance Configurations by Environment

### Development Performance
```env
# Development-optimized settings
DB_POOL_MAX=5
CONNECTION_TIMEOUT_SECONDS=60
ENABLE_COMPRESSION=false
ENABLE_HTTP_CACHE=false
IMAGE_CACHE_SIZE_MB=50
MAX_CONCURRENT_REQUESTS=20
```

### Staging Performance
```env
# Staging-optimized settings
DB_POOL_MAX=10
CONNECTION_TIMEOUT_SECONDS=30
ENABLE_COMPRESSION=true
ENABLE_HTTP_CACHE=true
IMAGE_CACHE_SIZE_MB=100
MAX_CONCURRENT_REQUESTS=15
```

### Production Performance
```env
# Production-optimized settings
DB_POOL_MAX=20
CONNECTION_TIMEOUT_SECONDS=15
ENABLE_COMPRESSION=true
ENABLE_HTTP_CACHE=true
ENABLE_REDIS_CACHE=true
IMAGE_CACHE_SIZE_MB=200
MAX_CONCURRENT_REQUESTS=10
```

## 🔍 Monitoring and Analytics by Environment

### Development Monitoring
```env
# Minimal monitoring for development
LOG_LEVEL=debug
ENABLE_ANALYTICS=false
SENTRY_ENVIRONMENT=development
ENABLE_PERFORMANCE_MONITORING=false
```

### Staging Monitoring
```env
# Enhanced monitoring for staging
LOG_LEVEL=info
ENABLE_ANALYTICS=true
SENTRY_ENVIRONMENT=staging
ENABLE_PERFORMANCE_MONITORING=true
GOOGLE_ANALYTICS_ID=GA-STAGING-ID
```

### Production Monitoring
```env
# Comprehensive monitoring for production
LOG_LEVEL=error
ENABLE_ANALYTICS=true
SENTRY_ENVIRONMENT=production
ENABLE_PERFORMANCE_MONITORING=true
GOOGLE_ANALYTICS_ID=GA-PRODUCTION-ID
MIXPANEL_TOKEN=production-token
FIREBASE_PERFORMANCE_ENABLED=true
```

## 🚀 CI/CD Pipeline Configurations

### GitHub Actions Deployment

**.github/workflows/deploy.yml:**
```yaml
name: Deploy Hey-Bills

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  NODE_VERSION: '18'
  FLUTTER_VERSION: '3.16.0'

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install backend dependencies
        run: cd backend && npm ci
        
      - name: Run backend tests
        run: cd backend && npm test
        env:
          NODE_ENV: test
          SUPABASE_URL: ${{ secrets.STAGING_SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.STAGING_SUPABASE_ANON_KEY }}
      
      - name: Deploy to staging
        run: echo "Deploy to staging environment"

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install backend dependencies
        run: cd backend && npm ci
        
      - name: Run backend tests
        run: cd backend && npm test
        env:
          NODE_ENV: test
          SUPABASE_URL: ${{ secrets.PROD_SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.PROD_SUPABASE_ANON_KEY }}
      
      - name: Deploy to production
        run: echo "Deploy to production environment"
```

## 📱 Mobile App Store Deployment

### Android Play Store
```env
# Android deployment configuration
ANDROID_PACKAGE_NAME=com.heybills.app
ANDROID_TARGET_SDK_VERSION=34
ANDROID_MIN_SDK_VERSION=21
ENABLE_PROGUARD=true
ENABLE_R8=true
BUILD_MODE=release
```

### iOS App Store
```env
# iOS deployment configuration
IOS_BUNDLE_ID=com.heybills.app
IOS_DEPLOYMENT_TARGET=12.0
IOS_TEAM_ID=your-team-id
BUILD_MODE=release
ENABLE_BITCODE=false
```

## ✅ Environment Validation Checklist

### Pre-deployment Checklist

**Development:**
- [ ] All environment variables set in `.env` files
- [ ] Supabase project configured and accessible
- [ ] AI service API keys valid and working
- [ ] Local database migrations applied
- [ ] All tests passing
- [ ] Debug logging enabled

**Staging:**
- [ ] Staging Supabase project configured
- [ ] Production-like security settings enabled
- [ ] SSL certificates configured
- [ ] Monitoring and analytics configured
- [ ] Performance testing completed
- [ ] User acceptance testing passed

**Production:**
- [ ] Production Supabase project configured
- [ ] All security settings enabled and tested
- [ ] SSL certificates installed and valid
- [ ] CDN configured for static assets
- [ ] Backup and disaster recovery tested
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Load testing completed

### Post-deployment Validation

**All Environments:**
- [ ] Health check endpoints responding
- [ ] Authentication flow working
- [ ] File upload functionality working
- [ ] AI/OCR services responding
- [ ] Push notifications working
- [ ] Error tracking configured
- [ ] Performance monitoring active
- [ ] Database connectivity verified

## 🆘 Troubleshooting Environment Issues

### Common Environment Problems

1. **Supabase Connection Issues**
   - Verify URL and keys are correct
   - Check project status in Supabase dashboard
   - Verify network connectivity and firewalls

2. **AI Service Integration Issues**
   - Verify API keys are valid and have sufficient credits
   - Check API rate limits and quotas
   - Verify model names are correct

3. **Authentication Problems**
   - Verify OAuth client IDs match environment
   - Check redirect URLs are configured correctly
   - Verify JWT secrets are properly set

4. **Performance Issues**
   - Check database connection pool settings
   - Verify cache configuration
   - Monitor resource usage and limits

### Environment-Specific Debugging

**Development:**
```bash
# Check environment variables
npm run env:check

# Validate configuration
npm run config:validate

# Run health checks
npm run health:check
```

**Production:**
```bash
# Monitor application health
curl https://api.heybills.com/health

# Check performance metrics
curl https://api.heybills.com/metrics

# View application logs
heroku logs --tail (for Heroku)
kubectl logs -f deployment/heybills-api (for Kubernetes)
```

---

*This deployment configuration guide should be reviewed and updated with each major release or infrastructure change.*