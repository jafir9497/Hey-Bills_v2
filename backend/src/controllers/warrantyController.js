/**
 * Warranty Controller
 * Handles warranty management endpoints
 */

const warrantyService = require('../services/warrantyService');
const { APIError } = require('../../utils/errorHandler');

/**
 * Get all warranties for authenticated user
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getWarranties = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const filters = {
      page: parseInt(req.query.page) || 1,
      limit: Math.min(parseInt(req.query.limit) || 20, 100),
      category: req.query.category,
      status: req.query.status,
      product_name: req.query.product_name,
      purchase_date_from: req.query.purchase_date_from,
      purchase_date_to: req.query.purchase_date_to,
      expiry_date_from: req.query.expiry_date_from,
      expiry_date_to: req.query.expiry_date_to,
      min_value: req.query.min_value ? parseFloat(req.query.min_value) : undefined,
      max_value: req.query.max_value ? parseFloat(req.query.max_value) : undefined,
      search: req.query.search,
      sort_by: req.query.sort_by || 'expiry_date',
      sort_order: req.query.sort_order || 'asc'
    };

    const result = await warrantyService.getUserWarranties(userId, filters);

    res.status(200).json({
      success: true,
      data: result.warranties,
      pagination: {
        page: filters.page,
        limit: filters.limit,
        total: result.total,
        pages: Math.ceil(result.total / filters.limit),
        hasNext: filters.page < Math.ceil(result.total / filters.limit),
        hasPrev: filters.page > 1
      },
      filters: {
        applied: Object.fromEntries(
          Object.entries(filters).filter(([_, value]) => 
            value !== undefined && value !== null && value !== ''
          )
        )
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get warranties expiring soon
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getExpiringWarranties = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const days = parseInt(req.query.days) || 30;

    const expiringWarranties = await warrantyService.getExpiringWarranties(userId, days);

    res.status(200).json({
      success: true,
      data: expiringWarranties,
      count: expiringWarranties.length,
      daysAhead: days,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get warranty analytics
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getWarrantyAnalytics = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { period, date_from, date_to, group_by } = req.query;

    const analytics = await warrantyService.getWarrantyAnalytics(userId, {
      period,
      date_from,
      date_to,
      group_by
    });

    res.status(200).json({
      success: true,
      data: analytics,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single warranty by ID
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getWarrantyById = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyId = req.params.id;

    const warranty = await warrantyService.getWarrantyById(warrantyId, userId);

    if (!warranty) {
      throw new APIError('Warranty not found', 404, 'WARRANTY_NOT_FOUND');
    }

    res.status(200).json({
      success: true,
      data: warranty,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Create new warranty
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const createWarranty = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyData = {
      ...req.body,
      user_id: userId
    };

    const warranty = await warrantyService.createWarranty(warrantyData);

    res.status(201).json({
      success: true,
      message: 'Warranty created successfully',
      data: warranty,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update existing warranty
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const updateWarranty = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyId = req.params.id;
    const updateData = req.body;

    const warranty = await warrantyService.updateWarranty(warrantyId, userId, updateData);

    if (!warranty) {
      throw new APIError('Warranty not found', 404, 'WARRANTY_NOT_FOUND');
    }

    res.status(200).json({
      success: true,
      message: 'Warranty updated successfully',
      data: warranty,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update warranty reminder settings
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const updateWarrantyReminder = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyId = req.params.id;
    const { reminder_settings } = req.body;

    const warranty = await warrantyService.updateWarrantyReminder(
      warrantyId, 
      userId, 
      reminder_settings
    );

    if (!warranty) {
      throw new APIError('Warranty not found', 404, 'WARRANTY_NOT_FOUND');
    }

    res.status(200).json({
      success: true,
      message: 'Warranty reminder settings updated successfully',
      data: warranty,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Create warranty claim
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const createWarrantyClaim = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyId = req.params.id;
    const claimData = {
      ...req.body,
      warranty_id: warrantyId,
      user_id: userId,
      claim_date: req.body.claim_date || new Date().toISOString().split('T')[0]
    };

    const claim = await warrantyService.createWarrantyClaim(claimData);

    res.status(201).json({
      success: true,
      message: 'Warranty claim created successfully',
      data: claim,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete warranty
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const deleteWarranty = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const warrantyId = req.params.id;

    const deleted = await warrantyService.deleteWarranty(warrantyId, userId);

    if (!deleted) {
      throw new APIError('Warranty not found', 404, 'WARRANTY_NOT_FOUND');
    }

    res.status(200).json({
      success: true,
      message: 'Warranty deleted successfully',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Bulk delete warranties
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const bulkDeleteWarranties = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { warranty_ids } = req.body;

    if (!warranty_ids || !Array.isArray(warranty_ids)) {
      throw new APIError('warranty_ids must be an array', 400, 'INVALID_INPUT');
    }

    if (warranty_ids.length === 0) {
      throw new APIError('At least one warranty ID is required', 400, 'EMPTY_ARRAY');
    }

    if (warranty_ids.length > 50) {
      throw new APIError('Cannot delete more than 50 warranties at once', 400, 'TOO_MANY_IDS');
    }

    const result = await warrantyService.bulkDeleteWarranties(warranty_ids, userId);

    res.status(200).json({
      success: true,
      message: `${result.deletedCount} warranties deleted successfully`,
      data: {
        requested: warranty_ids.length,
        deleted: result.deletedCount,
        failed: warranty_ids.length - result.deletedCount
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getWarranties,
  getExpiringWarranties,
  getWarrantyAnalytics,
  getWarrantyById,
  createWarranty,
  updateWarranty,
  updateWarrantyReminder,
  createWarrantyClaim,
  deleteWarranty,
  bulkDeleteWarranties
};