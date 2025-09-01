/**
 * OCR Controller
 * Handles receipt image upload, processing, and data extraction
 */

const { ocrService, receiptService } = require('../services');
const { APIError } = require('../utils/errorHandler');
const logger = require('../utils/logger');

/**
 * Process receipt image and extract structured data
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const processReceipt = async (req, res, next) => {
  try {
    logger.info('Starting receipt processing', {
      userId: req.user?.id,
      hasFile: !!req.file,
      fileSize: req.file?.size
    });

    // Validate file upload
    if (!req.file) {
      throw new APIError('No image file provided', 400, 'MISSING_FILE');
    }

    // Validate user authentication
    if (!req.user) {
      throw new APIError('Authentication required', 401, 'NOT_AUTHENTICATED');
    }

    // Process image with OCR service
    const ocrData = await ocrService.processReceiptImage({
      imageBuffer: req.file.buffer,
      imagePath: req.file.path,
      originalName: req.file.originalname,
      mimeType: req.file.mimetype,
      userId: req.user.id
    });

    // Save receipt to database
    const receipt = await receiptService.createReceipt({
      userId: req.user.id,
      ocrData,
      imageUrl: ocrData.imageUrl,
      categoryId: req.body.category_id || null,
      notes: req.body.notes || null,
      isBusinessExpense: req.body.is_business_expense === 'true',
      isReimbursable: req.body.is_reimbursable === 'true',
      tags: req.body.tags ? req.body.tags.split(',').map(tag => tag.trim()) : []
    });

    logger.info('Receipt processed successfully', {
      receiptId: receipt.id,
      merchantName: ocrData.merchantName,
      totalAmount: ocrData.totalAmount,
      confidence: ocrData.confidence
    });

    res.status(201).json({
      message: 'Receipt processed successfully',
      receipt: {
        id: receipt.id,
        merchantName: ocrData.merchantName,
        totalAmount: ocrData.totalAmount,
        purchaseDate: ocrData.date,
        items: ocrData.items,
        category: ocrData.category,
        confidence: ocrData.confidence,
        imageUrl: ocrData.imageUrl,
        notes: receipt.notes,
        tags: receipt.tags,
        isBusinessExpense: receipt.is_business_expense,
        isReimbursable: receipt.is_reimbursable,
        createdAt: receipt.created_at
      },
      ocrMetadata: {
        processingTime: ocrData.processingMetadata?.processingTime,
        linesProcessed: ocrData.processingMetadata?.linesProcessed,
        confidence: ocrData.confidence
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Receipt processing failed', {
      error: error.message,
      code: error.code,
      userId: req.user?.id,
      fileName: req.file?.originalname
    });

    // Handle OCR service unavailable - provide fallback response
    if (error.code === 'OCR_SERVICE_UNAVAILABLE' || 
        error.code === 'OCR_INIT_FAILED' || 
        error.code === 'OCR_SYSTEM_INCOMPATIBLE') {
      
      const statusCode = error.code === 'OCR_SYSTEM_INCOMPATIBLE' ? 503 : 503;
      const retryAfter = error.code === 'OCR_SYSTEM_INCOMPATIBLE' ? 1800 : 300; // 30 min vs 5 min
      
      return res.status(statusCode).json({
        error: 'OCR service unavailable',
        message: error.message || 'Receipt image processing is currently unavailable. You can manually enter receipt details.',
        code: error.code,
        fallback: {
          canManualEntry: true,
          canReprocessLater: error.code !== 'OCR_SYSTEM_INCOMPATIBLE',
          supportedActions: error.code === 'OCR_SYSTEM_INCOMPATIBLE' 
            ? ['manual entry'] 
            : ['manual entry', 'reprocess when service available'],
          recommendation: 'Use manual entry for now. OCR functionality may work in different environments.'
        },
        retryAfter: retryAfter,
        timestamp: new Date().toISOString()
      });
    }

    next(error);
  }
};

/**
 * Reprocess existing receipt with updated OCR
 * @param {Object} req - Express request object  
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const reprocessReceipt = async (req, res, next) => {
  try {
    const { receiptId } = req.params;
    const userId = req.user.id;

    logger.info('Reprocessing receipt', { receiptId, userId });

    // Get existing receipt
    const existingReceipt = await receiptService.getReceiptById(receiptId, userId);
    if (!existingReceipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    // Reprocess with current image
    const ocrData = await ocrService.reprocessReceiptImage({
      imageUrl: existingReceipt.image_url,
      receiptId: receiptId
    });

    // Update receipt with new OCR data
    const updatedReceipt = await receiptService.updateReceiptOCR({
      receiptId,
      ocrData,
      userId
    });

    logger.info('Receipt reprocessed successfully', {
      receiptId,
      newConfidence: ocrData.confidence
    });

    res.status(200).json({
      message: 'Receipt reprocessed successfully',
      receipt: {
        id: updatedReceipt.id,
        merchantName: ocrData.merchantName,
        totalAmount: ocrData.totalAmount,
        purchaseDate: ocrData.date,
        items: ocrData.items,
        category: ocrData.category,
        confidence: ocrData.confidence,
        updatedAt: updatedReceipt.updated_at
      },
      improvements: {
        confidenceImproved: ocrData.confidence > existingReceipt.ocr_confidence,
        previousConfidence: existingReceipt.ocr_confidence,
        newConfidence: ocrData.confidence
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Receipt reprocessing failed', {
      error: error.message,
      receiptId: req.params.receiptId,
      userId: req.user?.id
    });
    next(error);
  }
};

/**
 * Get OCR processing status for a receipt
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getOCRStatus = async (req, res, next) => {
  try {
    const { receiptId } = req.params;
    const userId = req.user.id;

    const receipt = await receiptService.getReceiptById(receiptId, userId);
    if (!receipt) {
      throw new APIError('Receipt not found', 404, 'RECEIPT_NOT_FOUND');
    }

    const ocrStatus = {
      receiptId: receipt.id,
      hasOCRData: !!receipt.ocr_data,
      confidence: receipt.ocr_confidence,
      merchantName: receipt.merchant_name,
      totalAmount: receipt.total_amount,
      itemCount: receipt.processed_data?.items?.length || 0,
      processingMetadata: receipt.ocr_data?.processing_metadata || null,
      needsReprocessing: receipt.ocr_confidence && receipt.ocr_confidence < 0.75,
      lastProcessed: receipt.updated_at
    };

    res.status(200).json({
      message: 'OCR status retrieved successfully',
      ocrStatus,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

/**
 * Preview OCR results without saving to database
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const previewOCR = async (req, res, next) => {
  try {
    logger.info('Starting OCR preview', {
      userId: req.user?.id,
      hasFile: !!req.file
    });

    // Validate file upload
    if (!req.file) {
      throw new APIError('No image file provided', 400, 'MISSING_FILE');
    }

    // Process image with OCR service (preview mode)
    const ocrData = await ocrService.processReceiptImage({
      imageBuffer: req.file.buffer,
      imagePath: req.file.path,
      originalName: req.file.originalname,
      mimeType: req.file.mimetype,
      userId: req.user.id,
      previewMode: true
    });

    logger.info('OCR preview completed', {
      merchantName: ocrData.merchantName,
      confidence: ocrData.confidence
    });

    res.status(200).json({
      message: 'OCR preview completed',
      preview: {
        merchantName: ocrData.merchantName,
        totalAmount: ocrData.totalAmount,
        purchaseDate: ocrData.date,
        items: ocrData.items,
        category: ocrData.category,
        confidence: ocrData.confidence,
        rawText: ocrData.rawText
      },
      metadata: ocrData.processingMetadata,
      recommendations: {
        saveRecommended: ocrData.confidence >= 0.75,
        needsReview: ocrData.confidence < 0.6,
        confidenceLevel: ocrData.confidence >= 0.9 ? 'high' : 
                        ocrData.confidence >= 0.75 ? 'medium' : 'low'
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('OCR preview failed', {
      error: error.message,
      userId: req.user?.id
    });
    next(error);
  }
};

/**
 * Get OCR processing statistics
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const getOCRStats = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const stats = await receiptService.getOCRStats(userId);

    res.status(200).json({
      message: 'OCR statistics retrieved successfully',
      stats: {
        totalReceipts: stats.total_receipts,
        avgConfidence: stats.avg_confidence,
        highConfidenceCount: stats.high_confidence_count,
        lowConfidenceCount: stats.low_confidence_count,
        reprocessedCount: stats.reprocessed_count,
        topMerchants: stats.top_merchants,
        monthlyProcessing: stats.monthly_processing
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    next(error);
  }
};

module.exports = {
  processReceipt,
  reprocessReceipt,
  getOCRStatus,
  previewOCR,
  getOCRStats
};