/**
 * Validation Middleware
 * Input validation for API endpoints
 */

const { APIError } = require('../../utils/errorHandler');

/**
 * Validate receipt creation input
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const validateReceiptInput = (req, res, next) => {
  try {
    const { 
      image_url, 
      merchant_name, 
      total_amount, 
      purchase_date,
      tax_amount,
      tip_amount,
      location_lat,
      location_lng,
      ocr_confidence,
      tags,
      items
    } = req.body;

    // Required fields validation
    if (!image_url || typeof image_url !== 'string') {
      throw new APIError('image_url is required and must be a string', 400, 'INVALID_IMAGE_URL');
    }

    if (!merchant_name || typeof merchant_name !== 'string') {
      throw new APIError('merchant_name is required and must be a string', 400, 'INVALID_MERCHANT_NAME');
    }

    if (!total_amount || isNaN(parseFloat(total_amount))) {
      throw new APIError('total_amount is required and must be a valid number', 400, 'INVALID_TOTAL_AMOUNT');
    }

    if (!purchase_date || !Date.parse(purchase_date)) {
      throw new APIError('purchase_date is required and must be a valid date (YYYY-MM-DD)', 400, 'INVALID_PURCHASE_DATE');
    }

    // Validate amounts are positive
    const totalAmountValue = parseFloat(total_amount);
    if (totalAmountValue < 0) {
      throw new APIError('total_amount must be positive', 400, 'NEGATIVE_TOTAL_AMOUNT');
    }

    if (tax_amount !== undefined && tax_amount !== null) {
      const taxAmountValue = parseFloat(tax_amount);
      if (isNaN(taxAmountValue) || taxAmountValue < 0) {
        throw new APIError('tax_amount must be a positive number', 400, 'INVALID_TAX_AMOUNT');
      }
    }

    if (tip_amount !== undefined && tip_amount !== null) {
      const tipAmountValue = parseFloat(tip_amount);
      if (isNaN(tipAmountValue) || tipAmountValue < 0) {
        throw new APIError('tip_amount must be a positive number', 400, 'INVALID_TIP_AMOUNT');
      }
    }

    // Validate coordinates if provided
    if (location_lat !== undefined && location_lat !== null) {
      const lat = parseFloat(location_lat);
      if (isNaN(lat) || lat < -90 || lat > 90) {
        throw new APIError('location_lat must be a valid latitude (-90 to 90)', 400, 'INVALID_LATITUDE');
      }
    }

    if (location_lng !== undefined && location_lng !== null) {
      const lng = parseFloat(location_lng);
      if (isNaN(lng) || lng < -180 || lng > 180) {
        throw new APIError('location_lng must be a valid longitude (-180 to 180)', 400, 'INVALID_LONGITUDE');
      }
    }

    // Validate OCR confidence score
    if (ocr_confidence !== undefined && ocr_confidence !== null) {
      const confidence = parseFloat(ocr_confidence);
      if (isNaN(confidence) || confidence < 0 || confidence > 1) {
        throw new APIError('ocr_confidence must be between 0 and 1', 400, 'INVALID_OCR_CONFIDENCE');
      }
    }

    // Validate tags
    if (tags !== undefined && tags !== null) {
      if (!Array.isArray(tags)) {
        throw new APIError('tags must be an array', 400, 'INVALID_TAGS_FORMAT');
      }
      
      if (tags.length > 20) {
        throw new APIError('Cannot have more than 20 tags per receipt', 400, 'TOO_MANY_TAGS');
      }

      for (const tag of tags) {
        if (typeof tag !== 'string' || tag.trim().length === 0) {
          throw new APIError('Each tag must be a non-empty string', 400, 'INVALID_TAG');
        }
        if (tag.length > 50) {
          throw new APIError('Tags cannot be longer than 50 characters', 400, 'TAG_TOO_LONG');
        }
      }
    }

    // Validate receipt items if provided
    if (items !== undefined && items !== null) {
      if (!Array.isArray(items)) {
        throw new APIError('items must be an array', 400, 'INVALID_ITEMS_FORMAT');
      }

      if (items.length > 100) {
        throw new APIError('Cannot have more than 100 items per receipt', 400, 'TOO_MANY_ITEMS');
      }

      for (const item of items) {
        if (!item.item_name || typeof item.item_name !== 'string') {
          throw new APIError('Each item must have a valid item_name', 400, 'INVALID_ITEM_NAME');
        }

        if (!item.total_price || isNaN(parseFloat(item.total_price))) {
          throw new APIError('Each item must have a valid total_price', 400, 'INVALID_ITEM_PRICE');
        }

        if (parseFloat(item.total_price) < 0) {
          throw new APIError('Item prices must be positive', 400, 'NEGATIVE_ITEM_PRICE');
        }
      }
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Validate receipt update input
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const validateReceiptUpdate = (req, res, next) => {
  try {
    const { 
      total_amount,
      purchase_date,
      tax_amount,
      tip_amount,
      location_lat,
      location_lng,
      ocr_confidence,
      tags
    } = req.body;

    // Validate amounts if provided
    if (total_amount !== undefined && total_amount !== null) {
      const totalAmountValue = parseFloat(total_amount);
      if (isNaN(totalAmountValue) || totalAmountValue < 0) {
        throw new APIError('total_amount must be a positive number', 400, 'INVALID_TOTAL_AMOUNT');
      }
    }

    if (tax_amount !== undefined && tax_amount !== null) {
      const taxAmountValue = parseFloat(tax_amount);
      if (isNaN(taxAmountValue) || taxAmountValue < 0) {
        throw new APIError('tax_amount must be a positive number', 400, 'INVALID_TAX_AMOUNT');
      }
    }

    if (tip_amount !== undefined && tip_amount !== null) {
      const tipAmountValue = parseFloat(tip_amount);
      if (isNaN(tipAmountValue) || tipAmountValue < 0) {
        throw new APIError('tip_amount must be a positive number', 400, 'INVALID_TIP_AMOUNT');
      }
    }

    // Validate date if provided
    if (purchase_date && !Date.parse(purchase_date)) {
      throw new APIError('purchase_date must be a valid date (YYYY-MM-DD)', 400, 'INVALID_PURCHASE_DATE');
    }

    // Validate coordinates if provided
    if (location_lat !== undefined && location_lat !== null) {
      const lat = parseFloat(location_lat);
      if (isNaN(lat) || lat < -90 || lat > 90) {
        throw new APIError('location_lat must be a valid latitude (-90 to 90)', 400, 'INVALID_LATITUDE');
      }
    }

    if (location_lng !== undefined && location_lng !== null) {
      const lng = parseFloat(location_lng);
      if (isNaN(lng) || lng < -180 || lng > 180) {
        throw new APIError('location_lng must be a valid longitude (-180 to 180)', 400, 'INVALID_LONGITUDE');
      }
    }

    // Validate OCR confidence score if provided
    if (ocr_confidence !== undefined && ocr_confidence !== null) {
      const confidence = parseFloat(ocr_confidence);
      if (isNaN(confidence) || confidence < 0 || confidence > 1) {
        throw new APIError('ocr_confidence must be between 0 and 1', 400, 'INVALID_OCR_CONFIDENCE');
      }
    }

    // Validate tags if provided
    if (tags !== undefined && tags !== null) {
      if (!Array.isArray(tags)) {
        throw new APIError('tags must be an array', 400, 'INVALID_TAGS_FORMAT');
      }
      
      if (tags.length > 20) {
        throw new APIError('Cannot have more than 20 tags per receipt', 400, 'TOO_MANY_TAGS');
      }

      for (const tag of tags) {
        if (typeof tag !== 'string' || tag.trim().length === 0) {
          throw new APIError('Each tag must be a non-empty string', 400, 'INVALID_TAG');
        }
        if (tag.length > 50) {
          throw new APIError('Tags cannot be longer than 50 characters', 400, 'TAG_TOO_LONG');
        }
      }
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Validate receipt query parameters
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const validateReceiptQuery = (req, res, next) => {
  try {
    const {
      page,
      limit,
      min_amount,
      max_amount,
      date_from,
      date_to,
      sort_by,
      sort_order
    } = req.query;

    // Validate pagination parameters
    if (page !== undefined) {
      const pageNum = parseInt(page);
      if (isNaN(pageNum) || pageNum < 1) {
        throw new APIError('page must be a positive integer', 400, 'INVALID_PAGE');
      }
    }

    if (limit !== undefined) {
      const limitNum = parseInt(limit);
      if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
        throw new APIError('limit must be between 1 and 100', 400, 'INVALID_LIMIT');
      }
    }

    // Validate amount filters
    if (min_amount !== undefined) {
      const minAmount = parseFloat(min_amount);
      if (isNaN(minAmount) || minAmount < 0) {
        throw new APIError('min_amount must be a non-negative number', 400, 'INVALID_MIN_AMOUNT');
      }
    }

    if (max_amount !== undefined) {
      const maxAmount = parseFloat(max_amount);
      if (isNaN(maxAmount) || maxAmount < 0) {
        throw new APIError('max_amount must be a non-negative number', 400, 'INVALID_MAX_AMOUNT');
      }
      
      if (min_amount !== undefined && parseFloat(max_amount) < parseFloat(min_amount)) {
        throw new APIError('max_amount must be greater than or equal to min_amount', 400, 'INVALID_AMOUNT_RANGE');
      }
    }

    // Validate date filters
    if (date_from && !Date.parse(date_from)) {
      throw new APIError('date_from must be a valid date (YYYY-MM-DD)', 400, 'INVALID_DATE_FROM');
    }

    if (date_to && !Date.parse(date_to)) {
      throw new APIError('date_to must be a valid date (YYYY-MM-DD)', 400, 'INVALID_DATE_TO');
    }

    if (date_from && date_to && new Date(date_from) > new Date(date_to)) {
      throw new APIError('date_from must be before or equal to date_to', 400, 'INVALID_DATE_RANGE');
    }

    // Validate sort parameters
    if (sort_by !== undefined) {
      const validSortFields = ['purchase_date', 'total_amount', 'merchant_name', 'created_at'];
      if (!validSortFields.includes(sort_by)) {
        throw new APIError(`sort_by must be one of: ${validSortFields.join(', ')}`, 400, 'INVALID_SORT_FIELD');
      }
    }

    if (sort_order !== undefined) {
      const validSortOrders = ['asc', 'desc'];
      if (!validSortOrders.includes(sort_order.toLowerCase())) {
        throw new APIError('sort_order must be either "asc" or "desc"', 400, 'INVALID_SORT_ORDER');
      }
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Validate analytics query parameters
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const validateAnalyticsQuery = (req, res, next) => {
  try {
    const { period, date_from, date_to, group_by } = req.query;

    // Validate period
    if (period !== undefined) {
      const validPeriods = ['week', 'month', 'quarter', 'year', 'custom'];
      if (!validPeriods.includes(period)) {
        throw new APIError(`period must be one of: ${validPeriods.join(', ')}`, 400, 'INVALID_PERIOD');
      }

      // For custom period, require date_from and date_to
      if (period === 'custom') {
        if (!date_from || !date_to) {
          throw new APIError('date_from and date_to are required when period is "custom"', 400, 'MISSING_CUSTOM_DATES');
        }
      }
    }

    // Validate dates if provided
    if (date_from && !Date.parse(date_from)) {
      throw new APIError('date_from must be a valid date (YYYY-MM-DD)', 400, 'INVALID_DATE_FROM');
    }

    if (date_to && !Date.parse(date_to)) {
      throw new APIError('date_to must be a valid date (YYYY-MM-DD)', 400, 'INVALID_DATE_TO');
    }

    if (date_from && date_to && new Date(date_from) > new Date(date_to)) {
      throw new APIError('date_from must be before or equal to date_to', 400, 'INVALID_DATE_RANGE');
    }

    // Validate group_by
    if (group_by !== undefined) {
      const validGroupings = ['category', 'merchant', 'date', 'business_expense'];
      if (!validGroupings.includes(group_by)) {
        throw new APIError(`group_by must be one of: ${validGroupings.join(', ')}`, 400, 'INVALID_GROUPING');
      }
    }

    next();
  } catch (error) {
    next(error);
  }
};

// Warranty validation functions
const validateWarrantyInput = (req, res, next) => {
  try {
    // Add basic warranty validation
    const { product_name, product_value } = req.body;
    
    if (!product_name || typeof product_name !== 'string' || product_name.trim().length === 0) {
      throw new APIError('Product name is required', 400, 'MISSING_PRODUCT_NAME');
    }
    
    if (product_value !== undefined && (typeof product_value !== 'number' || product_value < 0)) {
      throw new APIError('Product value must be a positive number', 400, 'INVALID_PRODUCT_VALUE');
    }
    
    next();
  } catch (error) {
    next(error);
  }
};

const validateWarrantyUpdate = (req, res, next) => {
  try {
    // Basic update validation - allow partial updates
    const { product_value } = req.body;
    
    if (product_value !== undefined && (typeof product_value !== 'number' || product_value < 0)) {
      throw new APIError('Product value must be a positive number', 400, 'INVALID_PRODUCT_VALUE');
    }
    
    next();
  } catch (error) {
    next(error);
  }
};

const validateWarrantyQuery = (req, res, next) => {
  try {
    // Basic query validation
    const { page, limit } = req.query;
    
    if (page !== undefined) {
      const pageNum = parseInt(page);
      if (isNaN(pageNum) || pageNum < 1) {
        throw new APIError('Page must be a positive integer', 400, 'INVALID_PAGE');
      }
    }
    
    if (limit !== undefined) {
      const limitNum = parseInt(limit);
      if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
        throw new APIError('Limit must be between 1 and 100', 400, 'INVALID_LIMIT');
      }
    }
    
    next();
  } catch (error) {
    next(error);
  }
};

module.exports = {
  validateReceiptInput,
  validateReceiptUpdate,
  validateReceiptQuery,
  validateAnalyticsQuery,
  validateWarrantyInput,
  validateWarrantyUpdate,
  validateWarrantyQuery
};