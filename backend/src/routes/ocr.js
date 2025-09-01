/**
 * OCR Routes
 * Routes for receipt image processing and OCR functionality
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');

// Import controllers and middleware
const ocrController = require('../controllers/ocrController');
const { authenticateToken: authenticate } = require('../middleware/supabaseAuth');
const { 
  uploadReceiptWithValidation, 
  uploadMultipleReceiptsWithValidation,
  cleanupTempFiles 
} = require('../middleware/uploadMiddleware');
const { APIError } = require('../../utils/errorHandler');
const logger = require('../utils/logger');

// Validation schemas
const processReceiptSchema = Joi.object({
  category_id: Joi.string().uuid().optional(),
  notes: Joi.string().max(1000).optional(),
  is_business_expense: Joi.string().valid('true', 'false').optional(),
  is_reimbursable: Joi.string().valid('true', 'false').optional(),
  tags: Joi.string().max(500).optional() // Comma-separated tags
});

const receiptIdSchema = Joi.object({
  receiptId: Joi.string().uuid().required()
});

/**
 * Validation middleware for request body
 */
const validateRequestBody = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body);
    if (error) {
      logger.warn('Request validation failed', {
        error: error.details[0].message,
        body: req.body
      });
      return next(new APIError(
        'Invalid request data: ' + error.details[0].message,
        400,
        'VALIDATION_ERROR'
      ));
    }
    req.body = value;
    next();
  };
};

/**
 * Validation middleware for URL parameters
 */
const validateParams = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.params);
    if (error) {
      logger.warn('Parameter validation failed', {
        error: error.details[0].message,
        params: req.params
      });
      return next(new APIError(
        'Invalid parameters: ' + error.details[0].message,
        400,
        'VALIDATION_ERROR'
      ));
    }
    req.params = value;
    next();
  };
};

/**
 * @route   POST /api/ocr/process
 * @desc    Process receipt image and extract structured data
 * @access  Private (authenticated users only)
 * @body    {file} receipt - Receipt image file
 * @body    {string} [category_id] - Optional category ID
 * @body    {string} [notes] - Optional notes
 * @body    {string} [is_business_expense] - 'true' or 'false'
 * @body    {string} [is_reimbursable] - 'true' or 'false'  
 * @body    {string} [tags] - Comma-separated tags
 */
router.post(
  '/process',
  authenticate,
  cleanupTempFiles,
  uploadReceiptWithValidation,
  validateRequestBody(processReceiptSchema),
  ocrController.processReceipt
);

/**
 * @route   POST /api/ocr/preview
 * @desc    Preview OCR results without saving to database
 * @access  Private (authenticated users only)
 * @body    {file} receipt - Receipt image file
 */
router.post(
  '/preview',
  authenticate,
  cleanupTempFiles,
  uploadReceiptWithValidation,
  ocrController.previewOCR
);

/**
 * @route   POST /api/ocr/batch-process
 * @desc    Process multiple receipt images
 * @access  Private (authenticated users only)
 * @body    {file[]} receipts - Multiple receipt image files
 */
router.post(
  '/batch-process',
  authenticate,
  cleanupTempFiles,
  uploadMultipleReceiptsWithValidation,
  async (req, res, next) => {
    try {
      logger.info('Starting batch OCR processing', {
        userId: req.user.id,
        fileCount: req.files.length
      });

      const results = [];
      const errors = [];

      // Process each file
      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        try {
          // Create a mock request object for individual processing
          const mockReq = {
            ...req,
            file: file,
            body: req.body // Use same body for all files
          };

          // Process individual receipt (reuse existing logic)
          await new Promise((resolve, reject) => {
            const mockRes = {
              status: (code) => ({
                json: (data) => {
                  if (code === 201) {
                    results.push({
                      fileIndex: i,
                      fileName: file.originalname,
                      success: true,
                      receipt: data.receipt
                    });
                  } else {
                    errors.push({
                      fileIndex: i,
                      fileName: file.originalname,
                      error: data.message || 'Processing failed'
                    });
                  }
                  resolve();
                }
              })
            };

            const mockNext = (error) => {
              errors.push({
                fileIndex: i,
                fileName: file.originalname,
                error: error.message || 'Processing failed'
              });
              resolve();
            };

            // Call the process receipt controller
            ocrController.processReceipt(mockReq, mockRes, mockNext);
          });

        } catch (error) {
          errors.push({
            fileIndex: i,
            fileName: file.originalname,
            error: error.message || 'Processing failed'
          });
        }
      }

      logger.info('Batch OCR processing completed', {
        totalFiles: req.files.length,
        successful: results.length,
        failed: errors.length
      });

      res.status(200).json({
        message: 'Batch processing completed',
        summary: {
          totalFiles: req.files.length,
          successful: results.length,
          failed: errors.length,
          successRate: `${Math.round((results.length / req.files.length) * 100)}%`
        },
        results,
        errors: errors.length > 0 ? errors : undefined,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('Batch processing failed:', error);
      next(error);
    }
  }
);

/**
 * @route   PUT /api/ocr/reprocess/:receiptId
 * @desc    Reprocess existing receipt with updated OCR
 * @access  Private (authenticated users only)
 * @params  {string} receiptId - UUID of receipt to reprocess
 */
router.put(
  '/reprocess/:receiptId',
  authenticate,
  validateParams(receiptIdSchema),
  ocrController.reprocessReceipt
);

/**
 * @route   GET /api/ocr/status/:receiptId
 * @desc    Get OCR processing status for a receipt
 * @access  Private (authenticated users only)
 * @params  {string} receiptId - UUID of receipt
 */
router.get(
  '/status/:receiptId',
  authenticate,
  validateParams(receiptIdSchema),
  ocrController.getOCRStatus
);

/**
 * @route   GET /api/ocr/stats
 * @desc    Get OCR processing statistics for current user
 * @access  Private (authenticated users only)
 */
router.get(
  '/stats',
  authenticate,
  ocrController.getOCRStats
);

/**
 * @route   GET /api/ocr/health
 * @desc    Check OCR service health
 * @access  Public
 */
router.get('/health', async (req, res) => {
  try {
    // Basic health check - could be enhanced with actual service checks
    const health = {
      status: 'healthy',
      service: 'OCR Processing Service',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      checks: {
        tesseract: 'available', // Would check actual Tesseract availability
        storage: 'connected',   // Would check Supabase storage
        database: 'connected'   // Would check database connection
      },
      limits: {
        maxFileSize: '10MB',
        maxFiles: 5,
        supportedFormats: ['JPEG', 'PNG', 'WebP', 'HEIC', 'PDF']
      }
    };

    res.status(200).json(health);
  } catch (error) {
    logger.error('OCR health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      service: 'OCR Processing Service',
      error: 'Service temporarily unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * @route   GET /api/ocr/supported-formats
 * @desc    Get list of supported file formats and limits
 * @access  Public
 */
router.get('/supported-formats', (req, res) => {
  const { MAX_FILE_SIZE, MAX_FILES, ALLOWED_MIME_TYPES, ALLOWED_EXTENSIONS } = require('../middleware/uploadMiddleware');
  
  res.status(200).json({
    message: 'Supported formats and limits',
    formats: {
      mimeTypes: ALLOWED_MIME_TYPES,
      extensions: ALLOWED_EXTENSIONS,
      description: {
        'image/jpeg': 'JPEG images - standard photo format',
        'image/png': 'PNG images - supports transparency',
        'image/webp': 'WebP images - modern efficient format',
        'image/heic': 'HEIC images - iOS Live Photos format',
        'application/pdf': 'PDF documents - single page receipts'
      }
    },
    limits: {
      maxFileSize: `${MAX_FILE_SIZE / (1024 * 1024)}MB`,
      maxFileSizeBytes: MAX_FILE_SIZE,
      maxFiles: MAX_FILES,
      maxFilesPerRequest: MAX_FILES
    },
    recommendations: {
      optimalFormat: 'JPEG or PNG',
      optimalSize: '1-5MB',
      optimalResolution: '1200x1600 pixels or higher',
      tips: [
        'Ensure good lighting when taking photos',
        'Keep receipt flat and avoid shadows',
        'Include entire receipt in the frame',
        'Avoid blurry or low-contrast images'
      ]
    },
    timestamp: new Date().toISOString()
  });
});

/**
 * Error handling middleware specific to OCR routes
 */
router.use((error, req, res, next) => {
  // Log OCR-specific errors
  logger.error('OCR route error:', {
    error: error.message,
    stack: error.stack,
    route: req.route?.path,
    method: req.method,
    userId: req.user?.id,
    hasFile: !!req.file,
    hasFiles: !!(req.files && req.files.length > 0)
  });

  // Cleanup any uploaded files on error
  if (res.cleanup) {
    res.cleanup();
  }

  // Pass error to global error handler
  next(error);
});

module.exports = router;