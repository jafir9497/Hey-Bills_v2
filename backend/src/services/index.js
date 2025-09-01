/**
 * Services Index
 * Centralized export for all application services
 */

const ocrService = require('./ocrService');
const receiptService = require('./receiptService');

// Export supabase service components
const { authService, userService } = require('./supabaseService');

module.exports = {
  // OCR and receipt processing
  ocrService,
  receiptService,
  
  // Authentication and user management
  authService,
  userService
};