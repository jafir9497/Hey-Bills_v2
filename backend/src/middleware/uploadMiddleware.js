/**
 * Enhanced Upload Middleware
 * Handles file upload configuration and validation using Multer with comprehensive security and error handling
 */

const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { APIError } = require('../../utils/errorHandler');
const logger = require('../utils/logger');

// File size and quantity limits (configurable via environment)
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024; // 10MB default
const MAX_FILES = parseInt(process.env.MAX_FILES_PER_REQUEST) || 10; // Maximum files per request

// Allowed MIME types (configurable via environment)
const ALLOWED_IMAGE_TYPES = (process.env.ALLOWED_IMAGE_TYPES || 'image/jpeg,image/png,image/webp').split(',');
const ALLOWED_DOCUMENT_TYPES = (process.env.ALLOWED_DOCUMENT_TYPES || 'application/pdf').split(',');
const ALLOWED_MIME_TYPES = [...ALLOWED_IMAGE_TYPES, ...ALLOWED_DOCUMENT_TYPES];

// Allowed file extensions
const ALLOWED_EXTENSIONS = [
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
  '.heif',
  '.pdf'
];

/**
 * Memory storage configuration for processing images in memory
 */
const memoryStorage = multer.memoryStorage();

// Ensure upload directories exist
const ensureUploadDirs = () => {
  const uploadDir = process.env.TEMP_UPLOAD_DIR || './temp/uploads';
  const processedDir = path.join(uploadDir, '../processed');
  
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }
  
  if (!fs.existsSync(processedDir)) {
    fs.mkdirSync(processedDir, { recursive: true });
  }
  
  return { uploadDir, processedDir };
};

/**
 * Enhanced disk storage configuration with security measures
 */
const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const { uploadDir } = ensureUploadDirs();
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Generate secure filename with timestamp and random suffix
    const timestamp = Date.now();
    const randomSuffix = crypto.randomBytes(8).toString('hex');
    const ext = path.extname(file.originalname).toLowerCase();
    const baseName = path.basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9]/g, '_')
      .substring(0, 50); // Limit length
    
    const filename = `${timestamp}_${randomSuffix}_${baseName}${ext}`;
    cb(null, filename);
  }
});

/**
 * File filter function to validate uploaded files
 */
const fileFilter = (req, file, cb) => {
  try {
    logger.debug('Validating uploaded file', {
      originalName: file.originalname,
      mimeType: file.mimetype,
      fieldName: file.fieldname
    });

    // Check MIME type
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      const error = new APIError(
        `Invalid file type. Allowed types: ${ALLOWED_MIME_TYPES.join(', ')}`,
        400,
        'INVALID_FILE_TYPE'
      );
      return cb(error, false);
    }

    // Check file extension
    const extension = path.extname(file.originalname).toLowerCase();
    if (!ALLOWED_EXTENSIONS.includes(extension)) {
      const error = new APIError(
        `Invalid file extension. Allowed extensions: ${ALLOWED_EXTENSIONS.join(', ')}`,
        400,
        'INVALID_FILE_EXTENSION'
      );
      return cb(error, false);
    }

    // Additional security check: verify filename doesn't contain dangerous patterns
    const filename = file.originalname;
    if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
      const error = new APIError(
        'Invalid filename: contains illegal characters',
        400,
        'INVALID_FILENAME'
      );
      return cb(error, false);
    }

    // File is valid
    cb(null, true);

  } catch (error) {
    logger.error('File filter validation error:', error);
    cb(new APIError('File validation failed', 400, 'FILE_VALIDATION_ERROR'), false);
  }
};

/**
 * Multer configuration for memory storage (default for OCR processing)
 */
const uploadMemory = multer({
  storage: memoryStorage,
  fileFilter: fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: MAX_FILES,
    fields: 10, // Allow additional form fields
    parts: 15   // Total parts (files + fields)
  }
});

/**
 * Multer configuration for disk storage (for large files or batch processing)
 */
const uploadDisk = multer({
  storage: diskStorage,
  fileFilter: fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: MAX_FILES,
    fields: 10,
    parts: 15
  }
});

/**
 * Single file upload middleware for receipts
 */
const uploadSingleReceipt = uploadMemory.single('receipt');

/**
 * Multiple files upload middleware for receipts
 */
const uploadMultipleReceipts = uploadMemory.array('receipts', MAX_FILES);

/**
 * Single file upload with disk storage
 */
const uploadSingleReceiptDisk = uploadDisk.single('receipt');

/**
 * Enhanced upload middleware with error handling and validation
 */
const uploadReceiptWithValidation = (req, res, next) => {
  uploadSingleReceipt(req, res, (error) => {
    try {
      if (error) {
        logger.error('File upload error:', error);

        // Handle specific multer errors
        if (error instanceof multer.MulterError) {
          switch (error.code) {
            case 'LIMIT_FILE_SIZE':
              return next(new APIError(
                `File too large. Maximum size allowed: ${MAX_FILE_SIZE / (1024 * 1024)}MB`,
                400,
                'FILE_TOO_LARGE'
              ));
            case 'LIMIT_FILE_COUNT':
              return next(new APIError(
                `Too many files. Maximum allowed: ${MAX_FILES}`,
                400,
                'TOO_MANY_FILES'
              ));
            case 'LIMIT_UNEXPECTED_FILE':
              return next(new APIError(
                'Unexpected file field. Use "receipt" as the field name',
                400,
                'UNEXPECTED_FILE_FIELD'
              ));
            default:
              return next(new APIError(
                'File upload error: ' + error.message,
                400,
                'UPLOAD_ERROR'
              ));
          }
        }

        // Handle custom validation errors
        if (error instanceof APIError) {
          return next(error);
        }

        // Handle other errors
        return next(new APIError(
          'File upload failed',
          500,
          'UPLOAD_FAILED',
          { originalError: error.message }
        ));
      }

      // Validate that file was uploaded
      if (!req.file) {
        return next(new APIError(
          'No file uploaded. Please select a receipt image',
          400,
          'NO_FILE_UPLOADED'
        ));
      }

      // Additional file validation
      const file = req.file;

      // Log successful upload
      logger.info('File uploaded successfully', {
        originalName: file.originalname,
        mimeType: file.mimetype,
        size: file.size,
        fieldName: file.fieldname
      });

      // Add upload metadata to request
      req.uploadMetadata = {
        uploadedAt: new Date().toISOString(),
        fileSize: file.size,
        fileName: file.originalname,
        mimeType: file.mimetype,
        isValid: true
      };

      next();

    } catch (validationError) {
      logger.error('Upload validation error:', validationError);
      next(new APIError(
        'Upload validation failed',
        500,
        'UPLOAD_VALIDATION_ERROR'
      ));
    }
  });
};

/**
 * Multiple receipts upload middleware with validation
 */
const uploadMultipleReceiptsWithValidation = (req, res, next) => {
  uploadMultipleReceipts(req, res, (error) => {
    try {
      if (error) {
        logger.error('Multiple files upload error:', error);

        if (error instanceof multer.MulterError) {
          switch (error.code) {
            case 'LIMIT_FILE_SIZE':
              return next(new APIError(
                `One or more files too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB per file`,
                400,
                'FILE_TOO_LARGE'
              ));
            case 'LIMIT_FILE_COUNT':
              return next(new APIError(
                `Too many files. Maximum allowed: ${MAX_FILES}`,
                400,
                'TOO_MANY_FILES'
              ));
            default:
              return next(new APIError(
                'Multiple files upload error: ' + error.message,
                400,
                'UPLOAD_ERROR'
              ));
          }
        }

        if (error instanceof APIError) {
          return next(error);
        }

        return next(new APIError('Multiple files upload failed', 500, 'UPLOAD_FAILED'));
      }

      // Validate that files were uploaded
      if (!req.files || req.files.length === 0) {
        return next(new APIError(
          'No files uploaded. Please select receipt images',
          400,
          'NO_FILES_UPLOADED'
        ));
      }

      // Log successful uploads
      logger.info('Multiple files uploaded successfully', {
        fileCount: req.files.length,
        totalSize: req.files.reduce((sum, file) => sum + file.size, 0)
      });

      // Add upload metadata
      req.uploadMetadata = {
        uploadedAt: new Date().toISOString(),
        fileCount: req.files.length,
        totalSize: req.files.reduce((sum, file) => sum + file.size, 0),
        files: req.files.map(file => ({
          fileName: file.originalname,
          size: file.size,
          mimeType: file.mimetype
        }))
      };

      next();

    } catch (validationError) {
      logger.error('Multiple upload validation error:', validationError);
      next(new APIError(
        'Multiple upload validation failed',
        500,
        'UPLOAD_VALIDATION_ERROR'
      ));
    }
  });
};

/**
 * Cleanup middleware to remove temporary files
 */
const cleanupTempFiles = (req, res, next) => {
  // Add cleanup function to response object
  res.cleanup = () => {
    if (req.file && req.file.path) {
      // Delete single file
      const fs = require('fs');
      fs.unlink(req.file.path, (err) => {
        if (err) {
          logger.warn('Failed to cleanup temp file:', req.file.path, err);
        } else {
          logger.debug('Cleaned up temp file:', req.file.path);
        }
      });
    }

    if (req.files && req.files.length > 0) {
      // Delete multiple files
      const fs = require('fs');
      req.files.forEach(file => {
        if (file.path) {
          fs.unlink(file.path, (err) => {
            if (err) {
              logger.warn('Failed to cleanup temp file:', file.path, err);
            } else {
              logger.debug('Cleaned up temp file:', file.path);
            }
          });
        }
      });
    }
  };

  // Auto-cleanup on response finish
  res.on('finish', () => {
    if (res.cleanup) {
      res.cleanup();
    }
  });

  next();
};

module.exports = {
  // Basic upload configurations
  uploadMemory,
  uploadDisk,
  uploadSingleReceipt,
  uploadMultipleReceipts,
  uploadSingleReceiptDisk,
  
  // Enhanced middleware with validation
  uploadReceiptWithValidation,
  uploadMultipleReceiptsWithValidation,
  cleanupTempFiles,
  
  // Configuration constants
  MAX_FILE_SIZE,
  MAX_FILES,
  ALLOWED_MIME_TYPES,
  ALLOWED_EXTENSIONS
};