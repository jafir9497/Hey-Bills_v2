/**
 * Warranty Routes
 * All routes related to warranty management
 */

const express = require('express');
const { authenticateToken } = require('../middleware/supabaseAuth');
const { validateWarrantyInput, validateWarrantyUpdate, validateWarrantyQuery } = require('../middleware/validation');
const warrantyController = require('../controllers/warrantyController');

const router = express.Router();

// Apply authentication middleware to all routes
router.use(authenticateToken);

/**
 * @route GET /api/warranties
 * @desc Get all warranties for authenticated user with filtering and pagination
 * @access Private
 * @params {
 *   page: number,
 *   limit: number,
 *   category: string,
 *   status: string (active|expired|expiring_soon),
 *   product_name: string,
 *   purchase_date_from: string (YYYY-MM-DD),
 *   purchase_date_to: string (YYYY-MM-DD),
 *   expiry_date_from: string (YYYY-MM-DD),
 *   expiry_date_to: string (YYYY-MM-DD),
 *   min_value: number,
 *   max_value: number,
 *   search: string,
 *   sort_by: string (purchase_date|expiry_date|product_name|product_value),
 *   sort_order: string (asc|desc)
 * }
 */
router.get('/', validateWarrantyQuery, warrantyController.getWarranties);

/**
 * @route GET /api/warranties/expiring
 * @desc Get warranties expiring soon
 * @access Private
 * @params {
 *   days: number (default: 30) - number of days to look ahead
 * }
 */
router.get('/expiring', warrantyController.getExpiringWarranties);

/**
 * @route GET /api/warranties/analytics
 * @desc Get warranty analytics for user
 * @access Private
 * @params {
 *   period: string (week|month|quarter|year|custom),
 *   date_from: string (YYYY-MM-DD) - required if period is custom,
 *   date_to: string (YYYY-MM-DD) - required if period is custom,
 *   group_by: string (category|status|month)
 * }
 */
router.get('/analytics', warrantyController.getWarrantyAnalytics);

/**
 * @route GET /api/warranties/:id
 * @desc Get single warranty with receipt information
 * @access Private
 */
router.get('/:id', warrantyController.getWarrantyById);

/**
 * @route POST /api/warranties
 * @desc Create new warranty record
 * @access Private
 * @body {
 *   receipt_id?: string,
 *   product_name: string (required),
 *   product_value: number (required),
 *   purchase_date: string (required, YYYY-MM-DD),
 *   warranty_start_date: string (required, YYYY-MM-DD),
 *   warranty_end_date: string (required, YYYY-MM-DD),
 *   warranty_duration_months: number,
 *   category?: string,
 *   brand?: string,
 *   model?: string,
 *   serial_number?: string,
 *   warranty_provider?: string,
 *   warranty_type?: string,
 *   warranty_terms?: string,
 *   contact_info?: object,
 *   is_transferable?: boolean,
 *   notes?: string,
 *   documents?: array,
 *   reminder_settings?: object
 * }
 */
router.post('/', validateWarrantyInput, warrantyController.createWarranty);

/**
 * @route PUT /api/warranties/:id
 * @desc Update existing warranty
 * @access Private
 */
router.put('/:id', validateWarrantyUpdate, warrantyController.updateWarranty);

/**
 * @route PATCH /api/warranties/:id/reminder
 * @desc Update warranty reminder settings
 * @access Private
 * @body {
 *   reminder_settings: object (required)
 * }
 */
router.patch('/:id/reminder', warrantyController.updateWarrantyReminder);

/**
 * @route POST /api/warranties/:id/claim
 * @desc Create a warranty claim
 * @access Private
 * @body {
 *   claim_reason: string (required),
 *   claim_description: string (required),
 *   claim_date: string (YYYY-MM-DD),
 *   supporting_documents?: array
 * }
 */
router.post('/:id/claim', warrantyController.createWarrantyClaim);

/**
 * @route DELETE /api/warranties/:id
 * @desc Delete single warranty
 * @access Private
 */
router.delete('/:id', warrantyController.deleteWarranty);

/**
 * @route DELETE /api/warranties
 * @desc Bulk delete warranties
 * @access Private
 * @body {
 *   warranty_ids: string[] (required, max 50 items)
 * }
 */
router.delete('/', warrantyController.bulkDeleteWarranties);

module.exports = router;