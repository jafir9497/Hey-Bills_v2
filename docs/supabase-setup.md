# Supabase Configuration Guide for Hey Bills

This guide walks you through setting up Supabase for the Hey Bills application, including authentication, database schema deployment, and configuration.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Supabase Project Setup](#supabase-project-setup)
3. [Environment Configuration](#environment-configuration)
4. [Database Schema Deployment](#database-schema-deployment)
5. [Authentication Setup](#authentication-setup)
6. [Storage Configuration](#storage-configuration)
7. [Edge Functions](#edge-functions)
8. [Verification & Testing](#verification--testing)
9. [Troubleshooting](#troubleshooting)

## 🚀 Prerequisites

- [Supabase Account](https://app.supabase.com)
- [Node.js](https://nodejs.org/) v18 or higher
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional but recommended)
- Google Cloud Console account (for OAuth)

## 🏗️ Supabase Project Setup

### Step 1: Create New Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Click "Create a new project"
3. Fill in project details:
   - **Project Name**: `hey-bills`
   - **Database Password**: Generate a secure password (save it!)
   - **Region**: Choose closest to your users (e.g., `us-east-1`)
   - **Organization**: Your organization
4. Click "Create new project"
5. Wait for project initialization (2-3 minutes)

### Step 2: Get Project Credentials

Once your project is ready, go to **Settings > API**:

- **Project URL**: `https://your-project-id.supabase.co`
- **Project API Keys**:
  - `anon` key (public) - for client-side operations
  - `service_role` key (private) - for server-side operations with admin privileges

⚠️ **Important**: Never expose your `service_role` key in client-side code!

## ⚙️ Environment Configuration

### Step 1: Copy Environment Template

```bash
cp .env.example .env
```

### Step 2: Configure Environment Variables

Open `.env` and fill in your Supabase credentials:

```env
# Required Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Optional: Direct database connection
DATABASE_URL=postgresql://postgres:[password]@db.your-project-id.supabase.co:5432/postgres
```

### Step 3: Validate Configuration

```bash
node -e "
const config = require('./config/environment');
console.log('✅ Environment configuration loaded successfully');
console.log('Project URL:', config.getCurrentConfig().supabase.url);
"
```

## 🗄️ Database Schema Deployment

Our database includes:
- **PostgreSQL extensions**: `uuid-ossp`, `pgcrypto`, `vector` (pgvector)
- **Core tables**: users, receipts, warranties, categories, budgets
- **AI features**: Vector embeddings for similarity search
- **Security**: Row Level Security (RLS) policies
- **Performance**: Optimized indexes and triggers

### Option 1: Automated Deployment (Recommended)

```bash
# Make deployment script executable
chmod +x scripts/deploy-database.js

# Run full deployment
node scripts/deploy-database.js

# Or verify existing deployment
node scripts/deploy-database.js --verify-only
```

### Option 2: Manual Deployment

1. **Enable Extensions** (in Supabase SQL Editor):
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
```

2. **Deploy Schema**:
```bash
# Copy and paste the contents of database/schema.sql into Supabase SQL Editor
```

3. **Deploy RLS Policies**:
```bash
# Copy and paste the contents of database/policies/rls_policies.sql
```

### Schema Overview

#### Core Tables
- **`user_profiles`**: Extended user information
- **`receipts`**: Receipt storage with OCR data
- **`receipt_items`**: Individual line items
- **`warranties`**: Product warranty tracking
- **`categories`**: Expense categorization
- **`notifications`**: System alerts and reminders
- **`budgets`**: Spending limits and tracking

#### AI/ML Tables
- **`receipt_embeddings`**: Vector embeddings for receipt similarity
- **`warranty_embeddings`**: Vector embeddings for warranty matching

#### Features
- **Row Level Security**: Users can only access their own data
- **Vector Search**: pgvector extension for AI-powered search
- **Automated Triggers**: `updated_at` timestamps
- **Performance Indexes**: Optimized for common queries

## 🔐 Authentication Setup

### Step 1: Configure Authentication Settings

In Supabase Dashboard > **Authentication > Settings**:

#### General Settings
- **Enable email confirmations**: ✅ Enabled
- **Enable email change confirmations**: ✅ Enabled  
- **Enable secure password change**: ✅ Enabled

#### URL Configuration
Add your redirect URLs:
```
http://localhost:3000
http://localhost:5173
https://your-domain.com
com.heybills.app://auth/callback
heybills://auth/callback
```

### Step 2: Google OAuth Setup

#### Create Google OAuth App
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project or select existing
3. Enable **Google+ API**
4. Go to **Credentials > Create Credentials > OAuth 2.0 Client ID**
5. Configure OAuth consent screen
6. Create OAuth Client:
   - **Application Type**: Web application
   - **Authorized redirect URIs**:
     ```
     https://your-project-id.supabase.co/auth/v1/callback
     ```
7. Copy `Client ID` and `Client Secret`

#### Configure in Supabase
1. Go to **Authentication > Providers**
2. Enable **Google**
3. Enter:
   - **Client ID**: Your Google Client ID
   - **Client Secret**: Your Google Client Secret
4. Save configuration

#### Update Environment Variables
```env
GOOGLE_CLIENT_ID=your-google-client-id.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

### Step 3: Email Templates (Optional)

Customize email templates in **Authentication > Email Templates**:

- **Confirm signup**: Welcome email
- **Reset password**: Password reset instructions
- **Magic link**: Passwordless login
- **Change email address**: Email change confirmation

## 📁 Storage Configuration

### Step 1: Create Storage Buckets

Run the deployment script or manually create buckets in **Storage**:

#### Receipts Bucket
- **Name**: `receipts`
- **Public**: No (private)
- **File size limit**: 10MB
- **Allowed file types**: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`

#### Warranties Bucket  
- **Name**: `warranties`
- **Public**: No (private)
- **File size limit**: 20MB
- **Allowed file types**: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`

#### Profiles Bucket
- **Name**: `profiles`
- **Public**: Yes (for profile pictures)
- **File size limit**: 5MB
- **Allowed file types**: `image/jpeg`, `image/png`, `image/webp`

### Step 2: Storage Policies

Storage policies are automatically configured to ensure users can only access their own files.

## ⚡ Edge Functions

Edge Functions are serverless functions that run on Supabase Edge Runtime for:
- OCR processing
- AI embeddings generation  
- Webhook handlers
- Background jobs

### Setup Edge Functions (Optional)

```bash
# Install Supabase CLI
npm install -g supabase

# Initialize functions
supabase functions new ocr-processor
supabase functions new embedding-generator

# Deploy functions
supabase functions deploy ocr-processor
supabase functions deploy embedding-generator
```

## ✅ Verification & Testing

### Step 1: Database Verification

```bash
# Run verification script
node scripts/deploy-database.js --verify-only
```

### Step 2: Authentication Test

```javascript
// Test in browser console
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'YOUR_SUPABASE_URL',
  'YOUR_ANON_KEY'
)

// Test Google OAuth
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google'
})

console.log('Auth test:', { data, error })
```

### Step 3: Database Connection Test

```bash
# Test with Node.js
node -e "
const { createClient } = require('@supabase/supabase-js');
const config = require('./config/environment').getCurrentConfig();

const supabase = createClient(
  config.supabase.url,
  config.supabase.anonKey
);

supabase.from('categories')
  .select('count')
  .then(({ data, error }) => {
    console.log('Database test:', { data, error });
  });
"
```

## 🔧 Troubleshooting

### Common Issues

#### 1. "Extension 'vector' is not available"
**Solution**: The `vector` extension requires Supabase Pro plan or higher.
```sql
-- Check available extensions
SELECT * FROM pg_available_extensions WHERE name LIKE '%vector%';
```

#### 2. "Permission denied for schema auth"
**Solution**: Use service role key for admin operations:
```javascript
const supabase = createClient(url, SERVICE_ROLE_KEY)
```

#### 3. "Row Level Security policy violation"
**Solution**: Ensure RLS policies are properly deployed:
```bash
node scripts/deploy-database.js --verify-only
```

#### 4. Google OAuth "redirect_uri_mismatch"
**Solution**: Verify redirect URIs in Google Cloud Console match exactly:
```
https://your-project-id.supabase.co/auth/v1/callback
```

#### 5. "Failed to fetch" errors
**Solution**: Check CORS settings and network connectivity:
```javascript
// Verify Supabase URL and keys
console.log('Supabase URL:', process.env.SUPABASE_URL)
```

### Debug Commands

```bash
# Check environment variables
node -e "console.log(require('./config/environment').getCurrentConfig())"

# Test database connection
node scripts/deploy-database.js --verify-only

# Check Supabase project status
supabase status

# View Supabase logs (if CLI is set up)
supabase functions logs
```

### Getting Help

1. **Supabase Documentation**: https://supabase.com/docs
2. **Community Discord**: https://discord.supabase.com  
3. **GitHub Issues**: https://github.com/supabase/supabase/issues
4. **Hey Bills Issues**: [Create an issue in your repository]

## 📚 Additional Resources

- [Supabase Auth Guide](https://supabase.com/docs/guides/auth)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Google OAuth Setup](https://developers.google.com/identity/protocols/oauth2)

## 🚀 Next Steps

After completing Supabase setup:

1. **Frontend Integration**: Configure Supabase client in Flutter app
2. **Backend Integration**: Set up Express.js API with Supabase
3. **Testing**: Run integration tests
4. **Deployment**: Deploy to production environment
5. **Monitoring**: Set up error tracking and analytics

---

## 📝 Configuration Summary

After completing this guide, you should have:

- ✅ Supabase project created and configured
- ✅ Database schema deployed with pgvector extension
- ✅ Row Level Security policies enabled
- ✅ Google OAuth authentication configured
- ✅ Storage buckets created with proper policies
- ✅ Environment variables configured
- ✅ TypeScript types generated

Your Hey Bills application is now ready for development and testing!