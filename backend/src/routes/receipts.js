/**
 * Receipt Routes
 * All routes related to receipt management
 */

const express = require('express');
const { authenticateToken } = require('../middleware/supabaseAuth');
const { validateReceiptInput, validateReceiptUpdate, validateReceiptQuery } = require('../middleware/validation');
const receiptController = require('../controllers/receiptController');

const router = express.Router();

// Apply authentication middleware to all routes
router.use(authenticateToken);

/**
 * @route GET /api/receipts
 * @desc Get all receipts for authenticated user with filtering and pagination
 * @access Private
 * @params {
 *   page: number,
 *   limit: number,
 *   category_id: string,
 *   merchant_name: string,
 *   date_from: string (YYYY-MM-DD),
 *   date_to: string (YYYY-MM-DD),
 *   min_amount: number,
 *   max_amount: number,
 *   is_business_expense: boolean,
 *   is_reimbursable: boolean,
 *   tags: string (comma-separated),
 *   search: string,
 *   sort_by: string (purchase_date|total_amount|merchant_name),
 *   sort_order: string (asc|desc)
 * }
 */
router.get('/', validateReceiptQuery, receiptController.getReceipts);

/**
 * @route GET /api/receipts/categories
 * @desc Get available categories for user
 * @access Private
 */
router.get('/categories', receiptController.getCategories);

/**
 * @route GET /api/receipts/analytics
 * @desc Get spending analytics for user
 * @access Private
 * @params {
 *   period: string (week|month|quarter|year|custom),
 *   date_from: string (YYYY-MM-DD) - required if period is custom,
 *   date_to: string (YYYY-MM-DD) - required if period is custom,
 *   category_id: string,
 *   group_by: string (category|merchant|date|business_expense)
 * }
 */
router.get('/analytics', receiptController.getAnalytics);

/**
 * @route GET /api/receipts/:id
 * @desc Get single receipt with items
 * @access Private
 */
router.get('/:id', receiptController.getReceiptById);

/**
 * @route POST /api/receipts
 * @desc Create new receipt
 * @access Private
 * @body {
 *   image_url: string (required),
 *   merchant_name: string (required),
 *   total_amount: number (required),
 *   purchase_date: string (required, YYYY-MM-DD),
 *   category_id?: string,
 *   merchant_address?: string,
 *   tax_amount?: number,
 *   tip_amount?: number,
 *   currency?: string,
 *   payment_method?: string,
 *   purchase_time?: string,
 *   ocr_data?: object,
 *   ocr_confidence?: number,
 *   processed_data?: object,
 *   location_lat?: number,
 *   location_lng?: number,
 *   location_address?: string,
 *   is_business_expense?: boolean,
 *   is_reimbursable?: boolean,
 *   notes?: string,
 *   tags?: string[],
 *   items?: array
 * }
 */
router.post('/', validateReceiptInput, receiptController.createReceipt);

/**
 * @route PUT /api/receipts/:id
 * @desc Update existing receipt
 * @access Private
 */
router.put('/:id', validateReceiptUpdate, receiptController.updateReceipt);

/**
 * @route PATCH /api/receipts/:id/tags
 * @desc Update receipt tags
 * @access Private
 * @body {
 *   tags: string[] (required)
 * }
 */
router.patch('/:id/tags', receiptController.updateReceiptTags);

/**
 * @route DELETE /api/receipts/:id
 * @desc Delete single receipt
 * @access Private
 */
router.delete('/:id', receiptController.deleteReceipt);

/**
 * @route DELETE /api/receipts
 * @desc Bulk delete receipts
 * @access Private
 * @body {
 *   receipt_ids: string[] (required, max 50 items)
 * }
 */
router.delete('/', receiptController.bulkDeleteReceipts);

module.exports = router;