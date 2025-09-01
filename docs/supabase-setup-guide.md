# 🚀 Complete Supabase Setup Guide for Hey-Bills v2

This comprehensive guide walks you through creating and configuring your Supabase project from scratch, including all necessary credentials and configurations.

## 📋 Quick Overview

You'll be setting up:
- ✅ Supabase project with PostgreSQL database
- ✅ Authentication (email/password + Google OAuth)
- ✅ Storage buckets for receipts and documents
- ✅ Vector embeddings support (pgvector)
- ✅ Row Level Security (RLS) policies
- ✅ Environment configuration files

## 🏗️ Step 1: Create Supabase Project

### 1.1 Create the Project
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Sign in or create account
3. Click **"Create a new project"**
4. Fill in project details:
   ```
   Project Name: hey-bills-v2
   Database Password: [Generate secure password - SAVE THIS!]
   Region: US East (N. Virginia)  // or closest to your users
   Organization: [Your organization]
   ```
5. Click **"Create new project"**
6. ⏱️ Wait 2-3 minutes for project initialization

### 1.2 Get Your Credentials
Once your project is ready:

1. Go to **Settings > API**
2. Copy these values (you'll need them):
   ```
   Project URL: https://your-project-ref.supabase.co
   API Keys:
   - anon/public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   - service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

### 1.3 Update Environment Files

**Backend (.env):**
```bash
cd backend
# Edit .env file and replace these values:
SUPABASE_URL=https://your-actual-project-ref.supabase.co
SUPABASE_ANON_KEY=your-actual-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-actual-service-role-key-here
DATABASE_URL=postgresql://postgres:your-db-password@db.your-project-ref.supabase.co:5432/postgres
```

**Frontend (.env):**
```bash
cd frontend
# Edit .env file and replace these values:
SUPABASE_URL=https://your-actual-project-ref.supabase.co
SUPABASE_ANON_KEY=your-actual-anon-key-here
```

## 🔐 Step 2: Configure Google OAuth

### 2.1 Create Google OAuth Credentials
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project or select existing
3. Enable **Google+ API** or **Google Identity API**
4. Go to **Credentials > Create Credentials > OAuth 2.0 Client ID**

### 2.2 Configure OAuth Consent Screen
1. Fill in application details:
   ```
   App Name: Hey Bills
   User Support Email: your-email@domain.com
   App Logo: [Upload your logo]
   Application Homepage: https://heybills.com
   Privacy Policy: https://heybills.com/privacy
   Terms of Service: https://heybills.com/terms
   ```

### 2.3 Create OAuth Client IDs

**Web Application:**
```
Name: Hey Bills Web
Authorized JavaScript Origins:
  - http://localhost:3000
  - http://localhost:5173
  - https://your-domain.com

Authorized Redirect URIs:
  - https://your-project-ref.supabase.co/auth/v1/callback
  - http://localhost:3000/auth/callback
```

**Android Application:**
```
Name: Hey Bills Android
Package Name: com.heybills.app
SHA-1 Certificate Fingerprint: [Your debug/release SHA-1]
```

**iOS Application:**
```
Name: Hey Bills iOS
Bundle ID: com.heybills.app
```

### 2.4 Update Environment Variables
Add to your .env files:
```bash
# Backend .env
GOOGLE_CLIENT_ID=your-web-client-id.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-web-client-secret

# Frontend .env  
GOOGLE_CLIENT_ID_WEB=your-web-client-id.googleusercontent.com
GOOGLE_CLIENT_ID_ANDROID=your-android-client-id.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=your-ios-client-id.googleusercontent.com
```

## 🎯 Step 3: Configure Supabase Authentication

### 3.1 Enable Authentication Providers
1. In Supabase Dashboard, go to **Authentication > Providers**
2. **Enable Email** (already enabled by default)
3. **Enable Google:**
   - Toggle ON
   - Client ID: `your-web-client-id.googleusercontent.com`
   - Client Secret: `your-web-client-secret`
   - Save

### 3.2 Configure Auth Settings
Go to **Authentication > Settings**:

```
Site URL: http://localhost:3000
Additional Redirect URLs:
  - http://localhost:5173
  - https://your-domain.com
  - com.heybills.app://auth/callback
  - heybills://auth/callback

Email Settings:
  ✅ Enable email confirmations
  ✅ Enable secure password change
  ✅ Enable email change confirmations

JWT Settings:
  JWT expiry: 3600 seconds (1 hour)
  Refresh token rotation: ✅ Enabled
```

## 🗄️ Step 4: Deploy Database Schema

### 4.1 Enable Required Extensions
1. Go to **Database > Extensions**
2. Enable these extensions:
   ```
   ✅ uuid-ossp (UUID generation)
   ✅ pgcrypto (Encryption functions)
   ✅ vector (AI embeddings) - Requires Pro plan
   ✅ pg_trgm (Text search)
   ```

### 4.2 Run Automated Setup
```bash
# Make setup script executable
chmod +x scripts/setup-supabase.js

# Install dependencies
npm install @supabase/supabase-js

# Run the setup script
node scripts/setup-supabase.js --setup
```

### 4.3 Manual Schema Deployment (Alternative)
If automated setup fails:

1. Go to **Database > SQL Editor**
2. Copy and paste content from `database/schema.sql`
3. Click **Run** to execute
4. Copy and paste content from `database/policies/rls_policies.sql`
5. Click **Run** to execute

## 📁 Step 5: Configure Storage

### 5.1 Create Storage Buckets
The setup script creates these automatically, but you can also create manually:

**Go to Storage > Create bucket:**

1. **receipts** bucket:
   ```
   Name: receipts
   Public: No (Private)
   File size limit: 10 MB
   Allowed MIME types: image/jpeg, image/png, image/webp, application/pdf
   ```

2. **warranties** bucket:
   ```
   Name: warranties  
   Public: No (Private)
   File size limit: 20 MB
   Allowed MIME types: image/jpeg, image/png, image/webp, application/pdf
   ```

3. **profiles** bucket:
   ```
   Name: profiles
   Public: Yes (Public)
   File size limit: 5 MB
   Allowed MIME types: image/jpeg, image/png, image/webp
   ```

### 5.2 Storage Policies
Storage policies are automatically configured via the setup script to ensure users can only access their own files.

## 🔧 Step 6: Additional API Keys

### 6.1 OpenAI API Key (Required for AI features)
1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Create new API key
3. Add to backend .env:
   ```bash
   OPENAI_API_KEY=sk-your-openai-api-key-here
   OPENAI_MODEL=gpt-4-turbo-preview
   OPENAI_EMBEDDING_MODEL=text-embedding-3-small
   ```

### 6.2 Google Vision API (Required for OCR)
1. In Google Cloud Console, enable **Cloud Vision API**
2. Create service account and download JSON key
3. Add to backend .env:
   ```bash
   GOOGLE_VISION_API_KEY=your-google-vision-api-key
   GOOGLE_APPLICATION_CREDENTIALS=config/service-account.json
   ```

### 6.3 Generate Secure Secrets
```bash
# Generate JWT secret
openssl rand -hex 32

# Generate session secret  
openssl rand -hex 32

# Add to backend .env
JWT_SECRET=your-generated-jwt-secret
SESSION_SECRET=your-generated-session-secret
```

## ✅ Step 7: Verify Setup

### 7.1 Run Verification Script
```bash
node scripts/setup-supabase.js --verify
```

### 7.2 Test Backend Connection
```bash
cd backend
npm test
```

### 7.3 Test Frontend Connection
```bash
cd frontend
flutter test
```

### 7.4 Manual Verification Checklist
- [ ] Supabase project created and accessible
- [ ] Database schema deployed (tables visible in Database > Tables)
- [ ] Storage buckets created (visible in Storage)
- [ ] Google OAuth working (test sign-in)
- [ ] Environment variables updated with real values
- [ ] API keys configured and tested
- [ ] Extensions enabled (especially pgvector for Pro users)

## 🚨 Security Checklist

### 🔒 Environment Security
- [ ] Never commit .env files with real credentials
- [ ] Use different secrets for development/production
- [ ] Enable 2FA on all service accounts
- [ ] Restrict API keys to minimum required permissions
- [ ] Monitor API key usage regularly

### 🔐 Supabase Security
- [ ] Row Level Security (RLS) enabled on all tables
- [ ] Storage bucket policies configured
- [ ] JWT secrets are secure random strings
- [ ] CORS origins properly configured
- [ ] Rate limiting enabled

### 📱 Flutter Security
- [ ] Only public keys in Flutter app (never service_role key)
- [ ] Certificate pinning enabled for production
- [ ] Secure storage for sensitive data
- [ ] ProGuard/R8 enabled for release builds

## 🔧 Troubleshooting

### Common Issues

**"Extension 'vector' is not available"**
- pgvector requires Supabase Pro plan ($25/month)
- For testing, comment out vector-related code

**"Permission denied for schema auth"**
- Use service_role key for admin operations
- Check if SUPABASE_SERVICE_ROLE_KEY is correct

**Google OAuth "redirect_uri_mismatch"**
- Verify redirect URIs in Google Console match exactly
- Include all localhost URLs for development

**"Row Level Security policy violation"**
- Ensure RLS policies are deployed
- Check if user is authenticated properly

### Debug Commands
```bash
# Check environment
node -e "console.log(require('./config/environment').getCurrentConfig())"

# Test database connection
node scripts/setup-supabase.js --verify

# Check Supabase project status
curl -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
     "${SUPABASE_URL}/rest/v1/"
```

## 📚 Next Steps

After completing Supabase setup:

1. **Test Authentication**: Try signing up/in with email and Google
2. **Test File Upload**: Upload a receipt image
3. **Test OCR**: Verify receipt text extraction works  
4. **Test AI Chat**: Try the AI assistant features
5. **Run Full Test Suite**: Execute all automated tests
6. **Deploy to Production**: Set up production environment

## 🎉 Completion Summary

Your Hey-Bills v2 Supabase configuration should now include:

- ✅ **Database**: PostgreSQL with pgvector extension
- ✅ **Authentication**: Email/password + Google OAuth
- ✅ **Storage**: Three buckets with proper policies
- ✅ **Security**: Row Level Security policies
- ✅ **APIs**: OpenAI and Google Vision integration
- ✅ **Environment**: Fully configured .env files

**Important Files Created:**
- `/backend/.env` - Backend environment configuration
- `/frontend/.env` - Frontend environment configuration  
- `/scripts/setup-supabase.js` - Automated setup script
- `/docs/supabase-setup-guide.md` - This guide

Your Hey-Bills application is now ready for development and testing! 🎉