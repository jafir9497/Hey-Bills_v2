/**
 * Receipt Controller
 * Handles all receipt-related HTTP endpoints
 */

const { receiptService } = require('../services/receiptService');
const { APIError } = require('../utils/errorHandler');

/**
 * Get all receipts for user with filtering and pagination
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getReceipts = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      page = 1,
      limit = 20,
      category_id,
      merchant_name,
      date_from,
      date_to,
      min_amount,
      max_amount,
      is_business_expense,
      is_reimbursable,
      tags,
      search,
      sort_by = 'purchase_date',
      sort_order = 'desc'
    } = req.query;

    // Build filters
    const filters = {
      user_id: userId
    };

    if (category_id) filters.category_id = category_id;
    if (is_business_expense !== undefined) filters.is_business_expense = is_business_expense === 'true';
    if (is_reimbursable !== undefined) filters.is_reimbursable = is_reimbursable === 'true';

    // Date range filtering
    const dateFilters = {};
    if (date_from) dateFilters.gte = new Date(date_from).toISOString();
    if (date_to) {
      const endDate = new Date(date_to);
      endDate.setHours(23, 59, 59, 999);
      dateFilters.lte = endDate.toISOString();
    }
    if (Object.keys(dateFilters).length > 0) {
      filters.purchase_date = dateFilters;
    }

    // Amount range filtering
    const amountFilters = {};
    if (min_amount) amountFilters.gte = parseFloat(min_amount);
    if (max_amount) amountFilters.lte = parseFloat(max_amount);
    if (Object.keys(amountFilters).length > 0) {
      filters.total_amount = amountFilters;
    }

    const options = {
      page: parseInt(page),
      limit: Math.min(parseInt(limit), 100), // Cap at 100
      filters,
      search: {
        merchant_name,
        tags: tags ? tags.split(',') : null,
        query: search
      },
      sort: {
        column: sort_by,
        ascending: sort_order.toLowerCase() === 'asc'
      }
    };

    const result = await receiptService.getReceipts(options);

    res.status(200).json({
      message: 'Receipts retrieved successfully',
      data: result.data,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: result.count,
        total_pages: Math.ceil(result.count / parseInt(limit))
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Get single receipt by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getReceiptById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    if (!id) {
      throw new APIError('Receipt ID is required', 400, 'MISSING_RECEIPT_ID');
    }

    const receipt = await receiptService.getReceiptById(id, userId);

    if (!receipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    res.status(200).json({
      message: 'Receipt retrieved successfully',
      data: receipt,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Create new receipt
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const createReceipt = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const receiptData = {
      ...req.body,
      user_id: userId
    };

    // Validate required fields
    const requiredFields = ['image_url', 'merchant_name', 'total_amount', 'purchase_date'];
    for (const field of requiredFields) {
      if (!receiptData[field]) {
        throw new APIError(`${field} is required`, 400, 'MISSING_REQUIRED_FIELD');
      }
    }

    // Validate amount is positive
    if (parseFloat(receiptData.total_amount) < 0) {
      throw new APIError('Total amount must be positive', 400, 'INVALID_AMOUNT');
    }

    // Validate date format
    if (!Date.parse(receiptData.purchase_date)) {
      throw new APIError('Invalid purchase date format', 400, 'INVALID_DATE');
    }

    const newReceipt = await receiptService.createReceipt(receiptData);

    res.status(201).json({
      message: 'Receipt created successfully',
      data: newReceipt,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Update existing receipt
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const updateReceipt = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const updates = req.body;

    if (!id) {
      throw new APIError('Receipt ID is required', 400, 'MISSING_RECEIPT_ID');
    }

    // Remove fields that shouldn't be updated directly
    delete updates.id;
    delete updates.user_id;
    delete updates.created_at;

    // Validate amount if provided
    if (updates.total_amount !== undefined && parseFloat(updates.total_amount) < 0) {
      throw new APIError('Total amount must be positive', 400, 'INVALID_AMOUNT');
    }

    // Validate date if provided
    if (updates.purchase_date && !Date.parse(updates.purchase_date)) {
      throw new APIError('Invalid purchase date format', 400, 'INVALID_DATE');
    }

    const updatedReceipt = await receiptService.updateReceipt(id, userId, updates);

    if (!updatedReceipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    res.status(200).json({
      message: 'Receipt updated successfully',
      data: updatedReceipt,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Delete receipt
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const deleteReceipt = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    if (!id) {
      throw new APIError('Receipt ID is required', 400, 'MISSING_RECEIPT_ID');
    }

    const deletedReceipt = await receiptService.deleteReceipt(id, userId);

    if (!deletedReceipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    res.status(200).json({
      message: 'Receipt deleted successfully',
      data: { id },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Get available categories
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getCategories = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const categories = await receiptService.getCategories(userId);

    res.status(200).json({
      message: 'Categories retrieved successfully',
      data: categories,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Get spending analytics for user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getAnalytics = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      period = 'month',
      date_from,
      date_to,
      category_id,
      group_by = 'category'
    } = req.query;

    // Validate period
    const validPeriods = ['week', 'month', 'quarter', 'year', 'custom'];
    if (!validPeriods.includes(period)) {
      throw new APIError('Invalid period. Must be one of: ' + validPeriods.join(', '), 400, 'INVALID_PERIOD');
    }

    // Validate group_by
    const validGroupings = ['category', 'merchant', 'date', 'business_expense'];
    if (!validGroupings.includes(group_by)) {
      throw new APIError('Invalid group_by. Must be one of: ' + validGroupings.join(', '), 400, 'INVALID_GROUPING');
    }

    const options = {
      period,
      dateFrom: date_from,
      dateTo: date_to,
      categoryId: category_id,
      groupBy: group_by
    };

    const analytics = await receiptService.getAnalytics(userId, options);

    res.status(200).json({
      message: 'Analytics retrieved successfully',
      data: analytics,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Bulk delete receipts
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const bulkDeleteReceipts = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { receipt_ids } = req.body;

    if (!receipt_ids || !Array.isArray(receipt_ids) || receipt_ids.length === 0) {
      throw new APIError('receipt_ids array is required and must not be empty', 400, 'INVALID_RECEIPT_IDS');
    }

    if (receipt_ids.length > 50) {
      throw new APIError('Cannot delete more than 50 receipts at once', 400, 'TOO_MANY_RECEIPTS');
    }

    const result = await receiptService.bulkDeleteReceipts(receipt_ids, userId);

    res.status(200).json({
      message: `Successfully deleted ${result.deleted_count} receipts`,
      data: {
        deleted_count: result.deleted_count,
        failed_ids: result.failed_ids || []
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Update receipt tags
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object  
 * @param {Function} next - Next middleware function
 */
const updateReceiptTags = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const { tags } = req.body;

    if (!id) {
      throw new APIError('Receipt ID is required', 400, 'MISSING_RECEIPT_ID');
    }

    if (!Array.isArray(tags)) {
      throw new APIError('Tags must be an array', 400, 'INVALID_TAGS_FORMAT');
    }

    // Validate tag length and format
    for (const tag of tags) {
      if (typeof tag !== 'string' || tag.trim().length === 0) {
        throw new APIError('Each tag must be a non-empty string', 400, 'INVALID_TAG');
      }
      if (tag.length > 50) {
        throw new APIError('Tags cannot be longer than 50 characters', 400, 'TAG_TOO_LONG');
      }
    }

    if (tags.length > 20) {
      throw new APIError('Cannot have more than 20 tags per receipt', 400, 'TOO_MANY_TAGS');
    }

    const updatedReceipt = await receiptService.updateReceiptTags(id, userId, tags);

    if (!updatedReceipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    res.status(200).json({
      message: 'Receipt tags updated successfully',
      data: updatedReceipt,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

module.exports = {
  getReceipts,
  getReceiptById,
  createReceipt,
  updateReceipt,
  deleteReceipt,
  getCategories,
  getAnalytics,
  bulkDeleteReceipts,
  updateReceiptTags
};