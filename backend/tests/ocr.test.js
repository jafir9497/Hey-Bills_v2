/**
 * OCR Controller Tests
 * Comprehensive tests for OCR processing endpoints
 */

const request = require('supertest');
const path = require('path');
const fs = require('fs');
const app = require('../src/server');

describe('OCR Endpoints', () => {
  let authToken;
  let userId;

  // Mock image buffer for testing
  const createMockImageBuffer = () => {
    // Create a minimal JPEG header for testing
    return Buffer.from([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
      0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
      0x00, 0x48, 0x00, 0x00, 0xFF, 0xD9
    ]);
  };

  beforeAll(async () => {
    // Setup authentication token for testing
    // This would typically involve creating a test user and getting a valid JWT
    const authResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: process.env.TEST_USER_EMAIL || 'test@example.com',
        password: process.env.TEST_USER_PASSWORD || 'testpassword123'
      });

    if (authResponse.status === 200) {
      authToken = authResponse.body.session?.accessToken;
      userId = authResponse.body.user?.id;
    }
  });

  describe('POST /api/ocr/process', () => {
    it('should successfully process a valid receipt image', async () => {
      const response = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', createMockImageBuffer(), 'test-receipt.jpg')
        .field('notes', 'Test receipt')
        .field('is_business_expense', 'true');

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('message', 'Receipt processed successfully');
      expect(response.body).toHaveProperty('receipt');
      expect(response.body.receipt).toHaveProperty('id');
      expect(response.body.receipt).toHaveProperty('merchantName');
      expect(response.body.receipt).toHaveProperty('totalAmount');
      expect(response.body.receipt).toHaveProperty('confidence');
      expect(response.body).toHaveProperty('ocrMetadata');
    });

    it('should reject request without authentication', async () => {
      const response = await request(app)
        .post('/api/ocr/process')
        .attach('receipt', createMockImageBuffer(), 'test-receipt.jpg');

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
    });

    it('should reject request without image file', async () => {
      const response = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .field('notes', 'Test without image');

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('NO_FILE_UPLOADED');
    });

    it('should reject unsupported file types', async () => {
      const textBuffer = Buffer.from('This is not an image', 'utf8');
      
      const response = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', textBuffer, 'test.txt');

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('INVALID_FILE_TYPE');
    });

    it('should validate request body fields', async () => {
      const response = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', createMockImageBuffer(), 'test-receipt.jpg')
        .field('category_id', 'invalid-uuid')
        .field('notes', 'A'.repeat(1001)); // Exceed max length

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });

    it('should handle file size limits', async () => {
      // Create a large buffer exceeding the limit
      const largeBuffer = Buffer.alloc(15 * 1024 * 1024); // 15MB
      
      const response = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', largeBuffer, 'large-receipt.jpg');

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('FILE_TOO_LARGE');
    });
  });

  describe('POST /api/ocr/preview', () => {
    it('should return OCR preview without saving to database', async () => {
      const response = await request(app)
        .post('/api/ocr/preview')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', createMockImageBuffer(), 'preview-receipt.jpg');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'OCR preview completed');
      expect(response.body).toHaveProperty('preview');
      expect(response.body.preview).toHaveProperty('merchantName');
      expect(response.body.preview).toHaveProperty('totalAmount');
      expect(response.body.preview).toHaveProperty('confidence');
      expect(response.body).toHaveProperty('recommendations');
    });

    it('should require authentication for preview', async () => {
      const response = await request(app)
        .post('/api/ocr/preview')
        .attach('receipt', createMockImageBuffer(), 'preview-receipt.jpg');

      expect(response.status).toBe(401);
    });
  });

  describe('POST /api/ocr/batch-process', () => {
    it('should process multiple receipt images', async () => {
      const response = await request(app)
        .post('/api/ocr/batch-process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipts', createMockImageBuffer(), 'receipt1.jpg')
        .attach('receipts', createMockImageBuffer(), 'receipt2.jpg');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'Batch processing completed');
      expect(response.body).toHaveProperty('summary');
      expect(response.body.summary).toHaveProperty('totalFiles', 2);
      expect(response.body).toHaveProperty('results');
      expect(Array.isArray(response.body.results)).toBe(true);
    });

    it('should handle mixed success/failure in batch processing', async () => {
      const response = await request(app)
        .post('/api/ocr/batch-process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipts', createMockImageBuffer(), 'good-receipt.jpg')
        .attach('receipts', Buffer.from('invalid'), 'bad-receipt.txt');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('summary');
      expect(response.body.summary.totalFiles).toBe(2);
      expect(response.body).toHaveProperty('errors');
    });
  });

  describe('PUT /api/ocr/reprocess/:receiptId', () => {
    let receiptId;

    beforeEach(async () => {
      // Create a receipt first
      const createResponse = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', createMockImageBuffer(), 'reprocess-test.jpg');

      if (createResponse.status === 201) {
        receiptId = createResponse.body.receipt.id;
      }
    });

    it('should successfully reprocess existing receipt', async () => {
      if (!receiptId) {
        pending('Could not create receipt for reprocessing test');
        return;
      }

      const response = await request(app)
        .put(`/api/ocr/reprocess/${receiptId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'Receipt reprocessed successfully');
      expect(response.body).toHaveProperty('receipt');
      expect(response.body).toHaveProperty('improvements');
    });

    it('should reject reprocessing non-existent receipt', async () => {
      const fakeId = '00000000-0000-4000-8000-000000000000';
      
      const response = await request(app)
        .put(`/api/ocr/reprocess/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('RECEIPT_NOT_FOUND');
    });

    it('should validate receipt ID format', async () => {
      const response = await request(app)
        .put('/api/ocr/reprocess/invalid-id')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('GET /api/ocr/status/:receiptId', () => {
    let receiptId;

    beforeEach(async () => {
      // Create a receipt first
      const createResponse = await request(app)
        .post('/api/ocr/process')
        .set('Authorization', `Bearer ${authToken}`)
        .attach('receipt', createMockImageBuffer(), 'status-test.jpg');

      if (createResponse.status === 201) {
        receiptId = createResponse.body.receipt.id;
      }
    });

    it('should return OCR status for existing receipt', async () => {
      if (!receiptId) {
        pending('Could not create receipt for status test');
        return;
      }

      const response = await request(app)
        .get(`/api/ocr/status/${receiptId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'OCR status retrieved successfully');
      expect(response.body).toHaveProperty('ocrStatus');
      expect(response.body.ocrStatus).toHaveProperty('receiptId', receiptId);
      expect(response.body.ocrStatus).toHaveProperty('hasOCRData');
      expect(response.body.ocrStatus).toHaveProperty('confidence');
    });

    it('should return 404 for non-existent receipt', async () => {
      const fakeId = '00000000-0000-4000-8000-000000000000';
      
      const response = await request(app)
        .get(`/api/ocr/status/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/ocr/stats', () => {
    it('should return OCR statistics for authenticated user', async () => {
      const response = await request(app)
        .get('/api/ocr/stats')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'OCR statistics retrieved successfully');
      expect(response.body).toHaveProperty('stats');
      expect(response.body.stats).toHaveProperty('totalReceipts');
      expect(response.body.stats).toHaveProperty('avgConfidence');
      expect(response.body.stats).toHaveProperty('highConfidenceCount');
      expect(response.body.stats).toHaveProperty('lowConfidenceCount');
      expect(response.body.stats).toHaveProperty('topMerchants');
    });

    it('should require authentication for stats', async () => {
      const response = await request(app)
        .get('/api/ocr/stats');

      expect(response.status).toBe(401);
    });
  });

  describe('GET /api/ocr/health', () => {
    it('should return OCR service health status', async () => {
      const response = await request(app)
        .get('/api/ocr/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('service', 'OCR Processing Service');
      expect(response.body).toHaveProperty('checks');
      expect(response.body).toHaveProperty('limits');
    });
  });

  describe('GET /api/ocr/supported-formats', () => {
    it('should return supported file formats and limits', async () => {
      const response = await request(app)
        .get('/api/ocr/supported-formats');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message', 'Supported formats and limits');
      expect(response.body).toHaveProperty('formats');
      expect(response.body.formats).toHaveProperty('mimeTypes');
      expect(response.body.formats).toHaveProperty('extensions');
      expect(response.body).toHaveProperty('limits');
      expect(response.body).toHaveProperty('recommendations');
      expect(Array.isArray(response.body.formats.mimeTypes)).toBe(true);
      expect(Array.isArray(response.body.formats.extensions)).toBe(true);
    });
  });

  afterAll(async () => {
    // Cleanup any test data if needed
    // Close any open connections
  });
});