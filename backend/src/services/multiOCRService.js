/**
 * Multi-OCR Service with Quality-Based Selection
 * Integrates multiple OCR providers with intelligent selection
 */

const { GoogleAuth } = require('google-auth-library');
const { ImageAnnotatorClient } = require('@google-cloud/vision');
const AWS = require('aws-sdk');
const Tesseract = require('tesseract.js');
const sharp = require('sharp');
const logger = require('../utils/logger');
const { APIError } = require('../utils/errorHandler');

class MultiOCRService {
  constructor() {
    this.providers = {
      tesseract: { available: true, cost: 0, speed: 'slow', accuracy: 'medium' },
      googleVision: { available: false, cost: 0.0015, speed: 'fast', accuracy: 'high' },
      awsTextract: { available: false, cost: 0.0015, speed: 'fast', accuracy: 'high' },
      azureCV: { available: false, cost: 0.001, speed: 'medium', accuracy: 'high' }
    };
    
    this.qualityThresholds = {
      high: 0.85,
      medium: 0.65,
      low: 0.45
    };

    this.initializeProviders();
  }

  /**
   * Initialize available OCR providers
   */
  async initializeProviders() {
    try {
      // Initialize Google Vision
      if (process.env.GOOGLE_VISION_API_KEY || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        try {
          this.googleVisionClient = new ImageAnnotatorClient();
          this.providers.googleVision.available = true;
          logger.info('Google Vision API initialized');
        } catch (error) {
          logger.warn('Google Vision API not available:', error.message);
        }
      }

      // Initialize AWS Textract
      if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
        try {
          this.awsTextract = new AWS.Textract({
            region: process.env.AWS_REGION || 'us-east-1'
          });
          this.providers.awsTextract.available = true;
          logger.info('AWS Textract initialized');
        } catch (error) {
          logger.warn('AWS Textract not available:', error.message);
        }
      }

      logger.info('Multi-OCR Service initialized with providers:', 
        Object.entries(this.providers)
          .filter(([_, config]) => config.available)
          .map(([name, _]) => name)
      );

    } catch (error) {
      logger.error('Failed to initialize OCR providers:', error);
    }
  }

  /**
   * Process image with quality-based OCR selection
   */
  async processImageWithBestOCR({
    imageBuffer,
    imagePath,
    originalName,
    qualityHint = 'auto',
    budgetLimit = null,
    timeoutMs = 30000
  }) {
    try {
      logger.info('Starting multi-OCR processing', {
        originalName,
        qualityHint,
        budgetLimit,
        availableProviders: Object.entries(this.providers)
          .filter(([_, config]) => config.available)
          .map(([name, _]) => name)
      });

      // Analyze image quality
      const imageQuality = await this.analyzeImageQuality(imageBuffer || imagePath);
      
      // Select optimal OCR provider
      const selectedProvider = this.selectOptimalProvider({
        imageQuality,
        qualityHint,
        budgetLimit,
        timeoutMs
      });

      logger.info(`Selected OCR provider: ${selectedProvider.name}`, {
        reason: selectedProvider.reason,
        estimatedCost: selectedProvider.cost,
        expectedAccuracy: selectedProvider.accuracy
      });

      // Process with selected provider
      const ocrResult = await this.processWithProvider(selectedProvider.name, {
        imageBuffer,
        imagePath,
        imageQuality
      });

      // Validate result quality
      const qualityScore = this.assessResultQuality(ocrResult, imageQuality);

      // If quality is too low, try fallback provider
      if (qualityScore < this.qualityThresholds.low && selectedProvider.fallback) {
        logger.warn(`OCR quality too low (${qualityScore}), trying fallback provider: ${selectedProvider.fallback}`);
        
        const fallbackResult = await this.processWithProvider(selectedProvider.fallback, {
          imageBuffer,
          imagePath,
          imageQuality
        });

        const fallbackQuality = this.assessResultQuality(fallbackResult, imageQuality);
        
        if (fallbackQuality > qualityScore) {
          return this.formatResult(fallbackResult, selectedProvider.fallback, fallbackQuality, imageQuality);
        }
      }

      return this.formatResult(ocrResult, selectedProvider.name, qualityScore, imageQuality);

    } catch (error) {
      logger.error('Multi-OCR processing failed:', error);
      throw new APIError('OCR processing failed', 500, 'MULTI_OCR_FAILED', {
        error: error.message
      });
    }
  }

  /**
   * Analyze image quality metrics
   */
  async analyzeImageQuality(imageInput) {
    try {
      let sharpInstance;
      if (Buffer.isBuffer(imageInput)) {
        sharpInstance = sharp(imageInput);
      } else {
        sharpInstance = sharp(imageInput);
      }

      const metadata = await sharpInstance.metadata();
      const stats = await sharpInstance.stats();

      // Calculate quality metrics
      const resolution = metadata.width * metadata.height;
      const aspectRatio = metadata.width / metadata.height;
      const meanBrightness = stats.channels[0].mean;
      const contrast = stats.channels[0].stdev;

      // Quality scoring
      let qualityScore = 0.5; // Base score

      // Resolution scoring
      if (resolution > 2000000) qualityScore += 0.2; // High res
      else if (resolution > 500000) qualityScore += 0.1; // Medium res
      else qualityScore -= 0.1; // Low res

      // Brightness scoring (optimal range: 100-200)
      if (meanBrightness >= 80 && meanBrightness <= 180) {
        qualityScore += 0.15;
      } else if (meanBrightness < 50 || meanBrightness > 220) {
        qualityScore -= 0.15; // Too dark or too bright
      }

      // Contrast scoring
      if (contrast > 40) qualityScore += 0.1; // Good contrast
      else if (contrast < 20) qualityScore -= 0.1; // Poor contrast

      // Aspect ratio (receipt-like ratios get bonus)
      if ((aspectRatio >= 0.6 && aspectRatio <= 0.8) || (aspectRatio >= 1.2 && aspectRatio <= 1.7)) {
        qualityScore += 0.05;
      }

      return {
        score: Math.max(0, Math.min(1, qualityScore)),
        resolution,
        brightness: meanBrightness,
        contrast,
        aspectRatio,
        size: metadata.size,
        format: metadata.format,
        recommendations: this.generateQualityRecommendations({
          brightness: meanBrightness,
          contrast,
          resolution
        })
      };

    } catch (error) {
      logger.warn('Image quality analysis failed:', error);
      return {
        score: 0.5,
        resolution: 0,
        brightness: 128,
        contrast: 30,
        aspectRatio: 1,
        recommendations: ['Unable to analyze image quality']
      };
    }
  }

  /**
   * Select optimal OCR provider based on criteria
   */
  selectOptimalProvider({ imageQuality, qualityHint, budgetLimit, timeoutMs }) {
    const availableProviders = Object.entries(this.providers)
      .filter(([_, config]) => config.available);

    if (availableProviders.length === 1) {
      return {
        name: availableProviders[0][0],
        reason: 'Only provider available',
        cost: availableProviders[0][1].cost,
        accuracy: availableProviders[0][1].accuracy
      };
    }

    // Budget constraints
    if (budgetLimit !== null && budgetLimit <= 0) {
      return {
        name: 'tesseract',
        reason: 'Budget constraint - free provider only',
        fallback: null,
        cost: 0,
        accuracy: 'medium'
      };
    }

    // Quality-based selection
    if (imageQuality.score >= this.qualityThresholds.high) {
      // High quality image - any provider will work well
      if (qualityHint === 'fast' || timeoutMs < 10000) {
        return this.selectFastestProvider(availableProviders, budgetLimit);
      } else {
        return this.selectMostAccurateProvider(availableProviders, budgetLimit);
      }
    } else if (imageQuality.score >= this.qualityThresholds.medium) {
      // Medium quality - prefer cloud OCR
      return this.selectMostAccurateProvider(availableProviders, budgetLimit, 'tesseract');
    } else {
      // Poor quality - need best OCR with fallback
      return this.selectMostAccurateProvider(availableProviders, budgetLimit, 'tesseract');
    }
  }

  /**
   * Select fastest available provider
   */
  selectFastestProvider(availableProviders, budgetLimit) {
    const speedOrder = ['googleVision', 'awsTextract', 'azureCV', 'tesseract'];
    
    for (const providerName of speedOrder) {
      const provider = availableProviders.find(([name, _]) => name === providerName);
      if (provider && (budgetLimit === null || provider[1].cost <= budgetLimit)) {
        return {
          name: providerName,
          reason: 'Fastest available provider within budget',
          fallback: 'tesseract',
          cost: provider[1].cost,
          accuracy: provider[1].accuracy
        };
      }
    }

    return {
      name: 'tesseract',
      reason: 'Budget constraints - using free provider',
      cost: 0,
      accuracy: 'medium'
    };
  }

  /**
   * Select most accurate available provider
   */
  selectMostAccurateProvider(availableProviders, budgetLimit, fallback = null) {
    const accuracyOrder = ['googleVision', 'awsTextract', 'azureCV', 'tesseract'];
    
    for (const providerName of accuracyOrder) {
      const provider = availableProviders.find(([name, _]) => name === providerName);
      if (provider && (budgetLimit === null || provider[1].cost <= budgetLimit)) {
        return {
          name: providerName,
          reason: 'Most accurate provider within budget',
          fallback: fallback,
          cost: provider[1].cost,
          accuracy: provider[1].accuracy
        };
      }
    }

    return {
      name: 'tesseract',
      reason: 'Budget constraints - using free provider',
      cost: 0,
      accuracy: 'medium'
    };
  }

  /**
   * Process with specific OCR provider
   */
  async processWithProvider(providerName, { imageBuffer, imagePath, imageQuality }) {
    switch (providerName) {
      case 'tesseract':
        return await this.processWithTesseract(imageBuffer || imagePath);
      case 'googleVision':
        return await this.processWithGoogleVision(imageBuffer || imagePath);
      case 'awsTextract':
        return await this.processWithAWSTextract(imageBuffer);
      default:
        throw new APIError(`Unsupported OCR provider: ${providerName}`, 400, 'INVALID_PROVIDER');
    }
  }

  /**
   * Process with Tesseract OCR
   */
  async processWithTesseract(imageInput) {
    try {
      const worker = await Tesseract.createWorker('eng');
      await worker.setParameters({
        tessedit_char_whitelist: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz .,/$%-:',
        tessedit_pageseg_mode: Tesseract.PSM.SPARSE_TEXT,
      });

      const result = await worker.recognize(imageInput);
      await worker.terminate();

      return {
        text: result.data.text,
        confidence: result.data.confidence / 100,
        provider: 'tesseract',
        blocks: result.data.blocks,
        lines: result.data.lines,
        words: result.data.words
      };
    } catch (error) {
      throw new APIError('Tesseract OCR failed', 500, 'TESSERACT_FAILED', { error: error.message });
    }
  }

  /**
   * Process with Google Vision API
   */
  async processWithGoogleVision(imageInput) {
    if (!this.providers.googleVision.available) {
      throw new APIError('Google Vision API not available', 503, 'PROVIDER_UNAVAILABLE');
    }

    try {
      let imageBuffer;
      if (Buffer.isBuffer(imageInput)) {
        imageBuffer = imageInput;
      } else {
        imageBuffer = require('fs').readFileSync(imageInput);
      }

      const [result] = await this.googleVisionClient.textDetection({
        image: { content: imageBuffer }
      });

      const detections = result.textAnnotations;
      if (!detections || detections.length === 0) {
        throw new APIError('No text detected by Google Vision', 400, 'NO_TEXT_DETECTED');
      }

      // Calculate average confidence
      const confidenceSum = detections.slice(1).reduce((sum, detection) => {
        return sum + (detection.confidence || 0.8);
      }, 0);
      const avgConfidence = confidenceSum / Math.max(1, detections.length - 1);

      return {
        text: detections[0].description,
        confidence: avgConfidence,
        provider: 'googleVision',
        blocks: this.convertGoogleBlocksFormat(detections),
        boundingBoxes: detections.map(d => d.boundingPoly),
        fullResponse: result
      };
    } catch (error) {
      throw new APIError('Google Vision OCR failed', 500, 'GOOGLE_VISION_FAILED', { error: error.message });
    }
  }

  /**
   * Process with AWS Textract
   */
  async processWithAWSTextract(imageBuffer) {
    if (!this.providers.awsTextract.available) {
      throw new APIError('AWS Textract not available', 503, 'PROVIDER_UNAVAILABLE');
    }

    try {
      const params = {
        Document: {
          Bytes: imageBuffer
        },
        FeatureTypes: ['TABLES', 'FORMS']
      };

      const result = await this.awsTextract.analyzeDocument(params).promise();
      
      // Extract text and calculate confidence
      let fullText = '';
      let totalConfidence = 0;
      let lineCount = 0;

      for (const block of result.Blocks) {
        if (block.BlockType === 'LINE') {
          fullText += block.Text + '\n';
          totalConfidence += block.Confidence;
          lineCount++;
        }
      }

      return {
        text: fullText.trim(),
        confidence: lineCount > 0 ? totalConfidence / (lineCount * 100) : 0,
        provider: 'awsTextract',
        blocks: result.Blocks,
        tables: result.Blocks.filter(b => b.BlockType === 'TABLE'),
        keyValuePairs: result.Blocks.filter(b => b.BlockType === 'KEY_VALUE_SET'),
        fullResponse: result
      };
    } catch (error) {
      throw new APIError('AWS Textract OCR failed', 500, 'AWS_TEXTRACT_FAILED', { error: error.message });
    }
  }

  /**
   * Assess OCR result quality
   */
  assessResultQuality(ocrResult, imageQuality) {
    let qualityScore = 0.3; // Base score

    // Text length check
    if (ocrResult.text && ocrResult.text.length > 20) {
      qualityScore += 0.2;
    }

    // Confidence score
    if (ocrResult.confidence) {
      qualityScore += ocrResult.confidence * 0.4;
    }

    // Text pattern analysis
    const hasNumbers = /\d/.test(ocrResult.text);
    const hasLetters = /[a-zA-Z]/.test(ocrResult.text);
    const hasCurrency = /\$/.test(ocrResult.text);
    const hasTotal = /total/i.test(ocrResult.text);

    if (hasNumbers && hasLetters) qualityScore += 0.1;
    if (hasCurrency) qualityScore += 0.05;
    if (hasTotal) qualityScore += 0.05;

    // Image quality bonus
    qualityScore += imageQuality.score * 0.1;

    return Math.min(1.0, qualityScore);
  }

  /**
   * Format final OCR result
   */
  formatResult(ocrResult, providerName, qualityScore, imageQuality) {
    return {
      text: ocrResult.text,
      confidence: ocrResult.confidence,
      qualityScore: qualityScore,
      provider: {
        name: providerName,
        accuracy: this.providers[providerName].accuracy,
        cost: this.providers[providerName].cost
      },
      imageAnalysis: {
        qualityScore: imageQuality.score,
        recommendations: imageQuality.recommendations,
        resolution: imageQuality.resolution
      },
      processingMetadata: {
        timestamp: new Date().toISOString(),
        provider: providerName,
        qualityAssessment: this.getQualityLabel(qualityScore)
      },
      rawResult: ocrResult // Include provider-specific data
    };
  }

  /**
   * Generate image quality recommendations
   */
  generateQualityRecommendations({ brightness, contrast, resolution }) {
    const recommendations = [];

    if (brightness < 80) {
      recommendations.push('Image appears too dark - try better lighting');
    } else if (brightness > 180) {
      recommendations.push('Image appears too bright - reduce lighting or avoid glare');
    }

    if (contrast < 20) {
      recommendations.push('Low contrast detected - ensure clear text visibility');
    }

    if (resolution < 500000) {
      recommendations.push('Low resolution image - try capturing at higher resolution');
    }

    return recommendations.length > 0 ? recommendations : ['Image quality appears good'];
  }

  /**
   * Convert Google Vision blocks to standard format
   */
  convertGoogleBlocksFormat(detections) {
    return detections.slice(1).map(detection => ({
      text: detection.description,
      confidence: detection.confidence || 0.8,
      boundingBox: detection.boundingPoly
    }));
  }

  /**
   * Get quality label
   */
  getQualityLabel(score) {
    if (score >= this.qualityThresholds.high) return 'high';
    if (score >= this.qualityThresholds.medium) return 'medium';
    return 'low';
  }

  /**
   * Get provider status
   */
  getProviderStatus() {
    return Object.entries(this.providers).map(([name, config]) => ({
      name,
      available: config.available,
      cost: config.cost,
      speed: config.speed,
      accuracy: config.accuracy
    }));
  }
}

// Export singleton instance
const multiOCRService = new MultiOCRService();
module.exports = multiOCRService;