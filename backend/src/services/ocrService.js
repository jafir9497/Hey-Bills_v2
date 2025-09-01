/**
 * OCR Service
 * Handles image processing and text extraction from receipts
 */

const Tesseract = require('tesseract.js');
const sharp = require('sharp');
const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');
const { supabase } = require('../../config/supabase');
const { APIError } = require('../../utils/errorHandler');
const logger = require('../utils/logger');

class OCRService {
  constructor() {
    this.tesseractWorker = null;
    this.isInitializing = false;
    this.initializationError = null;
    // Don't initialize immediately - use lazy loading
  }

  /**
   * Initialize Tesseract worker (lazy loading)
   */
  async initializeWorker() {
    // Return existing worker if already initialized
    if (this.tesseractWorker) {
      return this.tesseractWorker;
    }

    // If initialization failed before, throw the cached error
    if (this.initializationError) {
      throw this.initializationError;
    }

    // If already initializing, wait for it to complete
    if (this.isInitializing) {
      while (this.isInitializing) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      if (this.tesseractWorker) {
        return this.tesseractWorker;
      }
      if (this.initializationError) {
        throw this.initializationError;
      }
    }

    this.isInitializing = true;

    try {
      logger.info('Initializing Tesseract worker...');
      
      this.tesseractWorker = await Tesseract.createWorker('eng', 1, {
        logger: (m) => {
          if (m.status === 'recognizing text') {
            logger.debug(`OCR Progress: ${Math.round(m.progress * 100)}%`);
          }
        },
        errorHandler: (err) => {
          logger.error('Tesseract worker error:', err);
        }
      });

      await this.tesseractWorker.setParameters({
        tessedit_char_whitelist: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz .,/$%-:',
        tessedit_pageseg_mode: Tesseract.PSM.SPARSE_TEXT,
      });

      logger.info('Tesseract worker initialized successfully');
      this.isInitializing = false;
      return this.tesseractWorker;
    } catch (error) {
      this.isInitializing = false;
      
      // Handle specific Tesseract.js error
      if (error.message && error.message.includes('SetVariable')) {
        this.initializationError = new APIError(
          'OCR service is currently unavailable due to a system compatibility issue. Please try again later or use manual entry.',
          503,
          'OCR_SYSTEM_INCOMPATIBLE'
        );
        logger.error('Tesseract.js system compatibility error (SetVariable):', {
          error: error.message,
          nodeVersion: process.version,
          platform: process.platform,
          arch: process.arch
        });
      } else {
        this.initializationError = new APIError(
          'OCR service initialization failed: ' + error.message,
          500,
          'OCR_INIT_FAILED'
        );
        logger.error('Failed to initialize Tesseract worker:', error);
      }
      
      throw this.initializationError;
    }
  }

  /**
   * Process receipt image and extract structured data
   * @param {Object} params - Processing parameters
   * @returns {Object} Structured receipt data
   */
  async processReceiptImage({
    imageBuffer,
    imagePath,
    originalName,
    mimeType,
    userId,
    previewMode = false
  }) {
    const startTime = Date.now();
    let processedImagePath = null;

    try {
      logger.info('Starting OCR processing', {
        originalName,
        mimeType,
        bufferSize: imageBuffer?.length,
        previewMode
      });

      // Validate input
      if (!imageBuffer && !imagePath) {
        throw new APIError('No image provided', 400, 'MISSING_IMAGE');
      }

      // Prepare image for OCR
      processedImagePath = await this.preprocessImage({
        imageBuffer,
        imagePath,
        originalName
      });

      // Extract text using OCR
      const ocrResult = await this.extractTextFromImage(processedImagePath);

      if (!ocrResult.text || ocrResult.text.trim().length === 0) {
        throw new APIError('No text found in image', 400, 'NO_TEXT_FOUND');
      }

      // Parse extracted text into structured data
      const parsedData = this.parseReceiptText(ocrResult);

      // Upload image to storage (unless preview mode)
      let imageUrl = null;
      if (!previewMode) {
        imageUrl = await this.uploadImageToStorage({
          imageBuffer: imageBuffer || await fs.readFile(processedImagePath),
          originalName,
          mimeType,
          userId
        });
      }

      const processingTime = Date.now() - startTime;

      // Create structured OCR data response
      const ocrData = {
        rawText: ocrResult.text,
        merchantName: parsedData.merchantName,
        totalAmount: parsedData.totalAmount,
        date: parsedData.date,
        items: parsedData.items,
        category: parsedData.category,
        confidence: parsedData.confidence,
        imageUrl,
        processingMetadata: {
          processingTime: processingTime + 'ms',
          linesProcessed: parsedData.linesProcessed,
          ocrConfidence: ocrResult.confidence,
          imageHash: this.calculateImageHash(imageBuffer || await fs.readFile(processedImagePath)),
          dimensions: parsedData.imageDimensions,
          processingDate: new Date().toISOString()
        }
      };

      logger.info('OCR processing completed', {
        processingTime: processingTime + 'ms',
        confidence: parsedData.confidence,
        merchantName: parsedData.merchantName
      });

      return ocrData;

    } catch (error) {
      logger.error('OCR processing failed:', error);
      
      if (error instanceof APIError) {
        throw error;
      }
      
      throw new APIError(
        'Failed to process receipt image',
        500,
        'OCR_PROCESSING_FAILED',
        { originalError: error.message }
      );
    } finally {
      // Clean up temporary files
      if (processedImagePath && processedImagePath !== imagePath) {
        try {
          await fs.unlink(processedImagePath);
        } catch (cleanupError) {
          logger.warn('Failed to cleanup temporary file:', cleanupError);
        }
      }
    }
  }

  /**
   * Reprocess existing receipt image
   */
  async reprocessReceiptImage({ imageUrl, receiptId }) {
    try {
      logger.info('Reprocessing receipt', { receiptId, imageUrl });

      // Download image from storage
      const { data: imageData, error } = await supabase.storage
        .from('receipts')
        .download(imageUrl.replace(/^.*\/receipts\//, ''));

      if (error) {
        throw new APIError('Failed to download image for reprocessing', 404, 'IMAGE_NOT_FOUND');
      }

      const imageBuffer = Buffer.from(await imageData.arrayBuffer());

      // Process with updated OCR
      return await this.processReceiptImage({
        imageBuffer,
        originalName: 'reprocessed-receipt.jpg',
        mimeType: 'image/jpeg',
        userId: null, // Not needed for reprocessing
        previewMode: true // Don't re-upload image
      });

    } catch (error) {
      logger.error('Receipt reprocessing failed:', error);
      throw error;
    }
  }

  /**
   * Preprocess image for better OCR results
   */
  async preprocessImage({ imageBuffer, imagePath, originalName }) {
    try {
      const tempDir = path.join(__dirname, '../../temp');
      await fs.mkdir(tempDir, { recursive: true });

      const processedPath = path.join(tempDir, `processed_${Date.now()}_${originalName}`);

      let sharpInstance;
      if (imageBuffer) {
        sharpInstance = sharp(imageBuffer);
      } else {
        sharpInstance = sharp(imagePath);
      }

      // Get image metadata
      const metadata = await sharpInstance.metadata();
      
      // Preprocess image for better OCR
      await sharpInstance
        .resize(null, 2000, { // Increase height to 2000px, maintain aspect ratio
          withoutEnlargement: true,
          fit: 'inside'
        })
        .normalize() // Normalize contrast
        .sharpen() // Enhance edges
        .grayscale() // Convert to grayscale
        .threshold(128) // Apply threshold for better text contrast
        .jpeg({ quality: 95 })
        .toFile(processedPath);

      logger.debug('Image preprocessed', {
        originalSize: `${metadata.width}x${metadata.height}`,
        processedPath
      });

      return processedPath;

    } catch (error) {
      logger.error('Image preprocessing failed:', error);
      throw new APIError('Failed to preprocess image', 500, 'IMAGE_PREPROCESSING_FAILED');
    }
  }

  /**
   * Extract text from image using Tesseract
   */
  async extractTextFromImage(imagePath) {
    try {
      // Initialize worker if not already done (lazy loading)
      const worker = await this.initializeWorker();

      const result = await worker.recognize(imagePath);

      return {
        text: result.data.text,
        confidence: result.data.confidence / 100, // Convert to 0-1 scale
        blocks: result.data.blocks,
        lines: result.data.lines
      };

    } catch (error) {
      logger.error('Text extraction failed:', error);
      
      // If initialization failed, provide fallback response
      if (error.code === 'OCR_INIT_FAILED') {
        throw new APIError(
          'OCR service is currently unavailable. Please try again later.',
          503,
          'OCR_SERVICE_UNAVAILABLE'
        );
      }
      
      throw new APIError('Failed to extract text from image', 500, 'TEXT_EXTRACTION_FAILED');
    }
  }

  /**
   * Parse extracted text into structured receipt data
   */
  parseReceiptText(ocrResult) {
    const lines = ocrResult.text
      .split('\n')
      .map(line => line.trim())
      .filter(line => line.length > 0);

    logger.debug(`Processing ${lines.length} text lines`);

    // Extract merchant name
    const merchantName = this.extractMerchantName(lines);

    // Extract total amount
    const totalAmount = this.extractTotalAmount(lines);

    // Extract date
    const date = this.extractDate(lines) || new Date();

    // Extract items
    const items = this.extractItems(lines);

    // Determine category
    const category = this.categorizeReceipt(merchantName, items);

    // Calculate confidence
    const confidence = this.calculateConfidence({
      merchantName,
      totalAmount,
      items,
      ocrConfidence: ocrResult.confidence,
      textQuality: lines.length
    });

    return {
      merchantName,
      totalAmount,
      date,
      items,
      category,
      confidence,
      linesProcessed: lines.length,
      imageDimensions: null // Will be set by preprocessing
    };
  }

  /**
   * Extract merchant name from receipt lines
   */
  extractMerchantName(lines) {
    // Look for merchant name in first few lines
    for (let i = 0; i < Math.min(5, lines.length); i++) {
      const line = lines[i];
      
      // Skip lines that look like addresses, phone numbers, or common headers
      if (this.isLikelyMerchantName(line)) {
        return line;
      }
    }
    
    // Fallback to first non-empty line
    return lines.length > 0 ? lines[0] : 'Unknown Merchant';
  }

  /**
   * Check if line is likely a merchant name
   */
  isLikelyMerchantName(line) {
    // Skip if contains common non-merchant patterns
    if (/\d{3}[-\s]\d{3}[-\s]\d{4}/.test(line)) return false; // Phone
    if (/\d+\s+[NSEW]?\s*\w+\s+(st|ave|rd|blvd|dr)/i.test(line)) return false; // Address
    if (/(receipt|invoice|bill|order)/i.test(line)) return false; // Common headers
    if (line.length < 3 || line.length > 50) return false; // Reasonable length
    
    // Should contain letters
    if (!/[a-zA-Z]/.test(line)) return false;
    
    return true;
  }

  /**
   * Extract total amount from receipt lines
   */
  extractTotalAmount(lines) {
    const totalPatterns = [
      /total[:\s]*\$?(\d+\.?\d*)/i,
      /amount[:\s]*\$?(\d+\.?\d*)/i,
      /balance[:\s]*\$?(\d+\.?\d*)/i,
      /\$(\d+\.?\d*)$/i,
    ];

    // Look for total amount patterns (start from bottom)
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i];
      for (const pattern of totalPatterns) {
        const match = pattern.exec(line);
        if (match) {
          const amount = parseFloat(match[1]);
          if (amount && amount > 0) {
            return amount;
          }
        }
      }
    }

    return 0.0;
  }

  /**
   * Extract date from receipt lines
   */
  extractDate(lines) {
    const datePatterns = [
      /(\d{1,2})\/(\d{1,2})\/(\d{2,4})/, // MM/DD/YYYY or M/D/YY
      /(\d{1,2})-(\d{1,2})-(\d{2,4})/, // MM-DD-YYYY
      /(\d{4})-(\d{1,2})-(\d{1,2})/, // YYYY-MM-DD
    ];

    for (const line of lines) {
      for (let i = 0; i < datePatterns.length; i++) {
        const pattern = datePatterns[i];
        const match = pattern.exec(line);
        if (match) {
          try {
            let year, month, day;
            
            if (i === 2) { // YYYY-MM-DD
              year = parseInt(match[1]);
              month = parseInt(match[2]);
              day = parseInt(match[3]);
            } else { // MM/DD/YYYY or MM-DD-YYYY
              month = parseInt(match[1]);
              day = parseInt(match[2]);
              year = parseInt(match[3]);
              
              // Handle 2-digit years
              if (year < 100) {
                year += 2000;
              }
            }

            const date = new Date(year, month - 1, day);
            if (date <= new Date()) { // Don't accept future dates
              return date;
            }
          } catch (e) {
            continue; // Try next pattern
          }
        }
      }
    }

    return null;
  }

  /**
   * Extract line items from receipt
   */
  extractItems(lines) {
    const items = [];
    const itemPattern = /^(.+?)\s+\$?(\d+\.?\d*)$/;

    for (const line of lines) {
      // Skip lines that are clearly not items
      if (this.isHeaderOrFooterLine(line)) continue;

      const match = itemPattern.exec(line);
      if (match) {
        const itemName = match[1]?.trim();
        const price = parseFloat(match[2]);
        
        if (itemName && price && price > 0 && itemName.length > 0) {
          items.push({
            name: itemName,
            price: price,
            quantity: 1, // Default quantity
            category: null
          });
        }
      }
    }

    return items;
  }

  /**
   * Check if line is likely a header or footer
   */
  isHeaderOrFooterLine(line) {
    const headerFooterPatterns = [
      /(receipt|invoice|thank you|visit|welcome)/i,
      /(total|subtotal|tax|discount)/i,
      /\d{3}[-\s]\d{3}[-\s]\d{4}/, // Phone numbers
      /www\.|\.com|@/, // Websites and emails
    ];

    return headerFooterPatterns.some(pattern => pattern.test(line));
  }

  /**
   * Categorize receipt based on merchant and items
   */
  categorizeReceipt(merchantName, items) {
    const merchant = merchantName.toLowerCase();
    
    // Merchant-based categorization
    if (/(restaurant|cafe|coffee|pizza|burger|food|deli|bistro)/.test(merchant)) {
      return 'Food & Dining';
    }
    
    if (/(gas|fuel|shell|chevron|exxon|bp|mobil)/.test(merchant)) {
      return 'Transportation';
    }
    
    if (/(grocery|market|store|walmart|target|costco)/.test(merchant)) {
      return 'Shopping';
    }
    
    if (/(pharmacy|cvs|walgreens|hospital|clinic|medical)/.test(merchant)) {
      return 'Healthcare';
    }

    // Item-based categorization
    const itemText = items.map(item => item.name.toLowerCase()).join(' ');
    
    if (/(food|drink|meal|coffee|tea|soda|bread|milk)/.test(itemText)) {
      return 'Food & Dining';
    }

    return 'Other';
  }

  /**
   * Calculate confidence score
   */
  calculateConfidence({ merchantName, totalAmount, items, ocrConfidence, textQuality }) {
    let confidence = 0.0;
    
    // Base OCR confidence (40% weight)
    confidence += (ocrConfidence || 0) * 0.4;
    
    // Merchant name quality (25% weight)
    if (merchantName && merchantName !== 'Unknown Merchant' && merchantName.length > 3) {
      confidence += 0.25;
    }
    
    // Total amount validity (25% weight)
    if (totalAmount > 0) {
      confidence += 0.25;
    }
    
    // Items extracted (10% weight)
    if (items.length > 0) {
      confidence += 0.1 * Math.min(items.length / 3, 1);
    }

    return Math.min(confidence, 1.0);
  }

  /**
   * Upload image to Supabase storage
   */
  async uploadImageToStorage({ imageBuffer, originalName, mimeType, userId }) {
    try {
      const fileExtension = path.extname(originalName) || '.jpg';
      const fileName = `${userId}/${Date.now()}_${crypto.randomBytes(6).toString('hex')}${fileExtension}`;

      const { data, error } = await supabase.storage
        .from('receipts')
        .upload(fileName, imageBuffer, {
          contentType: mimeType,
          upsert: false
        });

      if (error) {
        throw new APIError('Failed to upload image', 500, 'UPLOAD_FAILED', { error: error.message });
      }

      // Get public URL
      const { data: urlData } = supabase.storage
        .from('receipts')
        .getPublicUrl(fileName);

      return urlData.publicUrl;

    } catch (error) {
      logger.error('Image upload failed:', error);
      throw error;
    }
  }

  /**
   * Calculate image hash for duplicate detection
   */
  calculateImageHash(imageBuffer) {
    return crypto.createHash('sha256').update(imageBuffer).digest('hex');
  }

  /**
   * Cleanup resources
   */
  async dispose() {
    if (this.tesseractWorker) {
      await this.tesseractWorker.terminate();
      this.tesseractWorker = null;
    }
  }
}

// Export singleton instance
const ocrService = new OCRService();

module.exports = ocrService;