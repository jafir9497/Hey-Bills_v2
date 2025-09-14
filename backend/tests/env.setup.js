/**
 * Test Environment Setup
 * Sets up environment variables for testing
 */

// Set test environment variables before other modules are loaded
process.env.NODE_ENV = 'test';
process.env.SUPABASE_URL = process.env.SUPABASE_URL;
process.env.SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Additional test environment variables
process.env.PORT = '3001';
process.env.JWT_SECRET = 'test-jwt-secret-for-testing-only-min-32-chars';
process.env.FRONTEND_URL = 'http://localhost:3000';
process.env.CORS_ORIGINS = 'http://localhost:3000,http://localhost:5173';

// Feature flags for testing
process.env.FEATURE_OCR_PROCESSING = 'true';
process.env.FEATURE_VECTOR_SEARCH = 'true';
process.env.FEATURE_BUDGET_TRACKING = 'true';
process.env.FEATURE_ANALYTICS = 'true';

// Mock external service keys for testing
process.env.OPENAI_API_KEY = 'test-openai-key';
process.env.GOOGLE_VISION_API_KEY = 'test-google-vision-key';
process.env.GOOGLE_CLIENT_ID = 'test-google-client-id';
process.env.GOOGLE_CLIENT_SECRET = 'test-google-client-secret';

module.exports = {};
