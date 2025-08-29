-- Migration: 001_initial_schema.sql
-- Description: Initial database schema setup for Hey-Bills
-- Author: System Architect
-- Date: 2024-12-XX

BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE warranty_status AS ENUM ('active', 'expiring_soon', 'expired');
CREATE TYPE notification_type AS ENUM ('warranty_expiring', 'warranty_expired', 'system_alert', 'budget_alert');
CREATE TYPE delivery_method AS ENUM ('push', 'email', 'in_app');
CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'critical');

-- User profiles table (extends Supabase auth.users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    business_type TEXT DEFAULT 'individual',
    timezone TEXT DEFAULT 'UTC',
    currency TEXT DEFAULT 'USD',
    date_format TEXT DEFAULT 'MM/DD/YYYY',
    notification_preferences JSONB DEFAULT '{"email": true, "push": true, "warranty_alerts": true}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories table
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT DEFAULT '#6B7280',
    is_default BOOLEAN DEFAULT FALSE,
    parent_category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT categories_name_user_unique UNIQUE (name, user_id)
);

-- Insert default categories
INSERT INTO categories (id, name, description, icon, is_default, sort_order) VALUES
    (uuid_generate_v4(), 'Food & Dining', 'Restaurants, groceries, and food delivery', '🍽️', true, 1),
    (uuid_generate_v4(), 'Transportation', 'Gas, parking, rideshare, and public transport', '🚗', true, 2),
    (uuid_generate_v4(), 'Office Supplies', 'Business supplies, stationery, and equipment', '🏢', true, 3),
    (uuid_generate_v4(), 'Technology', 'Electronics, software, and digital services', '💻', true, 4),
    (uuid_generate_v4(), 'Healthcare', 'Medical expenses, prescriptions, and health services', '🏥', true, 5),
    (uuid_generate_v4(), 'Entertainment', 'Movies, events, subscriptions, and leisure', '🎬', true, 6),
    (uuid_generate_v4(), 'Home & Garden', 'Home improvement, furniture, and garden supplies', '🏠', true, 7),
    (uuid_generate_v4(), 'Clothing', 'Apparel, shoes, and accessories', '👕', true, 8),
    (uuid_generate_v4(), 'Travel', 'Hotels, flights, and travel-related expenses', '✈️', true, 9),
    (uuid_generate_v4(), 'Utilities', 'Phone, internet, electricity, and other utilities', '⚡', true, 10),
    (uuid_generate_v4(), 'Professional Services', 'Consulting, legal, accounting, and other services', '👔', true, 11),
    (uuid_generate_v4(), 'Other', 'Miscellaneous expenses', '📋', true, 99);

-- Basic indexes for initial schema
CREATE INDEX idx_user_profiles_business_type ON user_profiles(business_type);
CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_categories_parent ON categories(parent_category_id);
CREATE INDEX idx_categories_active ON categories(is_active) WHERE is_active = true;

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;