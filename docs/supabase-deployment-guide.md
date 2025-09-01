# Hey-Bills Database Deployment Guide

This guide provides step-by-step instructions for deploying the Hey-Bills database schema to Supabase.

## Prerequisites

1. **Supabase Project**: Create a new project at [supabase.com](https://supabase.com)
2. **Database Access**: Note your project URL and service role key
3. **Extensions**: Ensure your Supabase project supports the required extensions

## Required PostgreSQL Extensions

The Hey-Bills schema requires these extensions:
- `uuid-ossp` - For UUID generation
- `pgcrypto` - For cryptographic functions
- `vector` - For vector embeddings (RAG functionality)

## Deployment Options

### Option 1: Automated Deployment Script

1. **Configure Environment Variables**
   
   Copy the `.env.example` to `.env` and update with your Supabase credentials:
   ```bash
   cp backend/.env.example backend/.env
   ```
   
   Update the following variables in `backend/.env`:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your_anon_key_here
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
   ```

2. **Run Deployment Script**
   ```bash
   node scripts/deploy-database.js
   ```

3. **Verify Deployment**
   ```bash
   node scripts/deploy-database.js --verify-only
   ```

### Option 2: Manual SQL Execution

If the automated script doesn't work, you can execute the SQL files manually through the Supabase dashboard:

#### Step 1: Enable Extensions
Execute in Supabase SQL Editor:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
```

#### Step 2: Execute Migration Files in Order

1. **Initial Schema** - Execute: `database/migrations/001_initial_schema.sql`
2. **Receipts Tables** - Execute: `database/migrations/002_receipts_tables.sql`
3. **Warranties & Notifications** - Execute: `database/migrations/003_warranties_notifications.sql`
4. **Vector Embeddings** - Execute: `database/migrations/004_vector_embeddings.sql`
5. **Budgets & System** - Execute: `database/migrations/005_budgets_system_tables.sql`

#### Step 3: Apply Row Level Security
Execute: `database/policies/rls_policies.sql`

#### Step 4: Setup Storage Buckets
In Supabase dashboard, create these storage buckets:

1. **receipts**
   - Public: No
   - File size limit: 10MB
   - Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`

2. **warranties**  
   - Public: No
   - File size limit: 20MB
   - Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`

3. **profiles**
   - Public: Yes
   - File size limit: 5MB
   - Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`

### Option 3: Complete Schema Deployment

Execute the complete schema file: `database/schema.sql`

This single file contains:
- All extensions
- All tables with relationships
- All indexes for performance
- All triggers and functions
- Default data (categories and system settings)
- Documentation comments

## Database Schema Overview

### Core Tables

1. **user_profiles** - Extended user information (links to Supabase auth.users)
2. **categories** - Receipt categorization with hierarchical support
3. **receipts** - Main receipt storage with OCR data
4. **receipt_items** - Individual line items from receipts
5. **warranties** - Product warranty tracking with alerts
6. **notifications** - System notifications and alerts
7. **budgets** - User spending budgets and limits

### AI/ML Tables

8. **receipt_embeddings** - Vector embeddings for receipt search
9. **warranty_embeddings** - Vector embeddings for warranty recommendations
10. **system_settings** - Application configuration

### Key Features

- **Row Level Security (RLS)**: All tables have proper RLS policies
- **Vector Search**: pgvector integration for intelligent search
- **Audit Trails**: All tables have created_at/updated_at timestamps
- **Computed Columns**: Warranty status automatically computed
- **Performance Indexes**: Optimized indexes for common queries
- **Data Validation**: Proper constraints and foreign keys

## Verification Checklist

After deployment, verify:

- [ ] All 10 tables created successfully
- [ ] All indexes created without errors  
- [ ] RLS policies applied and working
- [ ] Default categories inserted (12 categories)
- [ ] Default system settings inserted (5 settings)
- [ ] Storage buckets created with correct policies
- [ ] Extensions enabled (uuid-ossp, pgcrypto, vector)

## Troubleshooting

### Common Issues

1. **Extension Not Available**
   - Ensure your Supabase plan supports pgvector
   - Contact Supabase support if vector extension is missing

2. **Permission Errors**
   - Use service role key, not anon key
   - Ensure service role has admin privileges

3. **RLS Policy Conflicts**
   - Execute RLS policies after all tables are created
   - Check for conflicting policies if updates fail

### Testing Database Connection

```bash
# Test basic connectivity
node scripts/deploy-database.js --verify-only

# Test specific functionality
npm test -- --testNamePattern="database"
```

## Next Steps

After successful deployment:

1. **Configure Authentication**: Set up auth providers in Supabase dashboard
2. **Update Environment Variables**: Ensure all backend services use correct credentials  
3. **Test API Endpoints**: Verify CRUD operations work correctly
4. **Enable Real-time**: Configure real-time subscriptions if needed
5. **Setup Monitoring**: Enable logging and monitoring

## Security Considerations

- **Service Role Key**: Keep service role key secure, never expose in frontend
- **RLS Policies**: Review and test all RLS policies thoroughly
- **Storage Policies**: Ensure storage buckets have appropriate access controls
- **API Keys**: Rotate keys periodically and use environment variables

## Support

For issues with deployment:
1. Check Supabase dashboard logs
2. Review database/docs/database_architecture.md
3. Consult backend/docs/deployment-readiness.md