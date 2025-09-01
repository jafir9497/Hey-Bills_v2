/**
 * @fileoverview Receipt Controller Unit Tests
 * @description Comprehensive testing for receipt management, OCR processing, and file uploads
 */

const request = require('supertest');
const express = require('express');
const multer = require('multer');
const receiptController = require('../../src/controllers/receiptController');
const receiptService = require('../../src/services/receiptService');
const ocrService = require('../../src/services/ocrService');

// Mock dependencies
jest.mock('../../src/services/receiptService');
jest.mock('../../src/services/ocrService');
jest.mock('../../src/services/supabaseService');
jest.mock('../../src/utils/logger');

describe('ReceiptController', () => {
  let app;
  let mockUser;
  
  beforeEach(() => {
    app = express();
    app.use(express.json());
    
    // Mock authentication middleware
    app.use((req, res, next) => {
      req.user = mockUser;
      next();
    });

    // Configure multer for file uploads
    const upload = multer({ 
      storage: multer.memoryStorage(),
      limits: { fileSize: 10 * 1024 * 1024 } // 10MB
    });

    app.get('/receipts', receiptController.getReceipts);
    app.get('/receipts/:id', receiptController.getReceiptById);
    app.post('/receipts', upload.single('image'), receiptController.createReceipt);
    app.put('/receipts/:id', receiptController.updateReceipt);
    app.delete('/receipts/:id', receiptController.deleteReceipt);
    app.post('/receipts/:id/process', receiptController.processReceiptOCR);

    mockUser = global.testUtils.createMockUser({
      id: 'user-123',
      email: 'test@example.com'
    });

    jest.clearAllMocks();
  });

  describe('GET /receipts', () => {
    it('should return all receipts for authenticated user', async () => {
      const mockReceipts = [
        {
          id: 'receipt-1',
          user_id: 'user-123',
          merchant_name: 'Test Store',
          total_amount: 25.99,
          purchase_date: '2024-01-15',
          created_at: new Date().toISOString()
        },
        {
          id: 'receipt-2',
          user_id: 'user-123',
          merchant_name: 'Another Store',
          total_amount: 15.50,
          purchase_date: '2024-01-14',
          created_at: new Date().toISOString()
        }
      ];

      receiptService.getUserReceipts.mockResolvedValue({
        data: mockReceipts,
        error: null
      });

      const response = await request(app)
        .get('/receipts');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(2);
      expect(response.body.data[0]).toMatchObject({
        id: 'receipt-1',
        merchant_name: 'Test Store',
        total_amount: 25.99
      });
      expect(receiptService.getUserReceipts).toHaveBeenCalledWith('user-123');
    });

    it('should handle pagination parameters', async () => {
      receiptService.getUserReceipts.mockResolvedValue({
        data: [],
        error: null
      });

      await request(app)
        .get('/receipts?page=2&limit=10');

      expect(receiptService.getUserReceipts).toHaveBeenCalledWith(
        'user-123',
        expect.objectContaining({
          page: 2,
          limit: 10
        })
      );
    });

    it('should filter receipts by date range', async () => {
      receiptService.getUserReceipts.mockResolvedValue({
        data: [],
        error: null
      });

      await request(app)
        .get('/receipts?startDate=2024-01-01&endDate=2024-01-31');

      expect(receiptService.getUserReceipts).toHaveBeenCalledWith(
        'user-123',
        expect.objectContaining({
          startDate: '2024-01-01',
          endDate: '2024-01-31'
        })
      );
    });

    it('should return 500 on service error', async () => {
      receiptService.getUserReceipts.mockResolvedValue({
        data: null,
        error: { message: 'Database error' }
      });

      const response = await request(app)
        .get('/receipts');

      expect(response.status).toBe(500);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Database error');
    });
  });

  describe('GET /receipts/:id', () => {
    it('should return specific receipt by ID', async () => {
      const mockReceipt = {
        id: 'receipt-1',
        user_id: 'user-123',
        merchant_name: 'Test Store',
        total_amount: 25.99,
        items: [
          { name: 'Coffee', price: 4.99, quantity: 1 },
          { name: 'Sandwich', price: 8.99, quantity: 1 }
        ]
      };

      receiptService.getReceiptById.mockResolvedValue({
        data: mockReceipt,
        error: null
      });

      const response = await request(app)
        .get('/receipts/receipt-1');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toMatchObject(mockReceipt);
      expect(receiptService.getReceiptById).toHaveBeenCalledWith('receipt-1', 'user-123');
    });

    it('should return 404 for non-existent receipt', async () => {
      receiptService.getReceiptById.mockResolvedValue({
        data: null,
        error: { message: 'Receipt not found' }
      });

      const response = await request(app)
        .get('/receipts/non-existent');

      expect(response.status).toBe(404);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Receipt not found');
    });

    it('should return 403 for receipt belonging to another user', async () => {
      receiptService.getReceiptById.mockResolvedValue({
        data: null,
        error: { message: 'Access denied' }
      });

      const response = await request(app)
        .get('/receipts/other-user-receipt');

      expect(response.status).toBe(403);
    });
  });

  describe('POST /receipts', () => {
    it('should create new receipt with image upload', async () => {
      const mockReceiptData = {
        merchant_name: 'Test Store',
        total_amount: 25.99,
        purchase_date: '2024-01-15',
        items: [
          { name: 'Coffee', price: 4.99, quantity: 1 }
        ]
      };

      const mockCreatedReceipt = {
        id: 'receipt-new',
        user_id: 'user-123',
        ...mockReceiptData
      };

      receiptService.createReceipt.mockResolvedValue({
        data: mockCreatedReceipt,
        error: null
      });

      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', '25.99')
        .field('purchase_date', '2024-01-15')
        .attach('image', Buffer.from('fake image data'), 'receipt.jpg');

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.id).toBe('receipt-new');
      expect(receiptService.createReceipt).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-123',
          merchant_name: 'Test Store',
          total_amount: 25.99
        }),
        expect.any(Object) // file object
      );
    });

    it('should validate required fields', async () => {
      const response = await request(app)
        .post('/receipts')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('required');
    });

    it('should validate file size limits', async () => {
      const largeFile = Buffer.alloc(15 * 1024 * 1024); // 15MB file

      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', '25.99')
        .attach('image', largeFile, 'large-receipt.jpg');

      expect(response.status).toBe(413);
      expect(response.body.error).toContain('File too large');
    });

    it('should validate image file types', async () => {
      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', '25.99')
        .attach('image', Buffer.from('not an image'), 'receipt.txt');

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Invalid file type');
    });

    it('should handle amount validation', async () => {
      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', 'invalid-amount')
        .attach('image', Buffer.from('fake image'), 'receipt.jpg');

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('valid amount');
    });
  });

  describe('PUT /receipts/:id', () => {
    it('should update existing receipt', async () => {
      const updateData = {
        merchant_name: 'Updated Store Name',
        total_amount: 30.99,
        notes: 'Updated notes'
      };

      const mockUpdatedReceipt = {
        id: 'receipt-1',
        user_id: 'user-123',
        ...updateData
      };

      receiptService.updateReceipt.mockResolvedValue({
        data: mockUpdatedReceipt,
        error: null
      });

      const response = await request(app)
        .put('/receipts/receipt-1')
        .send(updateData);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.merchant_name).toBe('Updated Store Name');
      expect(receiptService.updateReceipt).toHaveBeenCalledWith(
        'receipt-1',
        'user-123',
        updateData
      );
    });

    it('should return 404 for non-existent receipt', async () => {
      receiptService.updateReceipt.mockResolvedValue({
        data: null,
        error: { message: 'Receipt not found' }
      });

      const response = await request(app)
        .put('/receipts/non-existent')
        .send({ merchant_name: 'Updated' });

      expect(response.status).toBe(404);
    });

    it('should validate update data', async () => {
      const response = await request(app)
        .put('/receipts/receipt-1')
        .send({ total_amount: 'invalid' });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('valid amount');
    });
  });

  describe('DELETE /receipts/:id', () => {
    it('should delete existing receipt', async () => {
      receiptService.deleteReceipt.mockResolvedValue({
        data: { success: true },
        error: null
      });

      const response = await request(app)
        .delete('/receipts/receipt-1');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.message).toContain('deleted');
      expect(receiptService.deleteReceipt).toHaveBeenCalledWith('receipt-1', 'user-123');
    });

    it('should return 404 for non-existent receipt', async () => {
      receiptService.deleteReceipt.mockResolvedValue({
        data: null,
        error: { message: 'Receipt not found' }
      });

      const response = await request(app)
        .delete('/receipts/non-existent');

      expect(response.status).toBe(404);
    });

    it('should handle cascade deletion of related data', async () => {
      receiptService.deleteReceipt.mockResolvedValue({
        data: { 
          success: true,
          deletedItems: 5,
          deletedFiles: 2
        },
        error: null
      });

      const response = await request(app)
        .delete('/receipts/receipt-1');

      expect(response.status).toBe(200);
      expect(response.body.data.deletedItems).toBe(5);
      expect(response.body.data.deletedFiles).toBe(2);
    });
  });

  describe('POST /receipts/:id/process', () => {
    it('should process receipt with OCR', async () => {
      const mockOCRResult = {
        merchant_name: 'Extracted Store',
        total_amount: 45.67,
        purchase_date: '2024-01-15',
        items: [
          { name: 'Item 1', price: 25.99, quantity: 1 },
          { name: 'Item 2', price: 19.68, quantity: 1 }
        ],
        confidence: 0.95
      };

      ocrService.processReceiptImage.mockResolvedValue({
        data: mockOCRResult,
        error: null
      });

      receiptService.updateReceiptWithOCR.mockResolvedValue({
        data: { id: 'receipt-1', ...mockOCRResult },
        error: null
      });

      const response = await request(app)
        .post('/receipts/receipt-1/process');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.merchant_name).toBe('Extracted Store');
      expect(response.body.data.confidence).toBe(0.95);
      expect(ocrService.processReceiptImage).toHaveBeenCalledWith('receipt-1');
    });

    it('should handle OCR processing errors', async () => {
      ocrService.processReceiptImage.mockResolvedValue({
        data: null,
        error: { message: 'OCR processing failed' }
      });

      const response = await request(app)
        .post('/receipts/receipt-1/process');

      expect(response.status).toBe(500);
      expect(response.body.error).toBe('OCR processing failed');
    });

    it('should handle low confidence OCR results', async () => {
      const lowConfidenceResult = {
        merchant_name: 'Uncertain Store',
        total_amount: 0,
        confidence: 0.3
      };

      ocrService.processReceiptImage.mockResolvedValue({
        data: lowConfidenceResult,
        error: null
      });

      const response = await request(app)
        .post('/receipts/receipt-1/process');

      expect(response.status).toBe(200);
      expect(response.body.data.confidence).toBe(0.3);
      expect(response.body.warning).toContain('low confidence');
    });

    it('should queue for manual review if OCR fails', async () => {
      ocrService.processReceiptImage.mockResolvedValue({
        data: null,
        error: { message: 'Text extraction failed' }
      });

      receiptService.queueForManualReview.mockResolvedValue({
        data: { queued: true },
        error: null
      });

      const response = await request(app)
        .post('/receipts/receipt-1/process');

      expect(receiptService.queueForManualReview).toHaveBeenCalledWith('receipt-1');
    });
  });

  describe('Performance Tests', () => {
    it('should handle bulk receipt creation', async () => {
      const bulkData = Array(20).fill().map((_, index) => ({
        merchant_name: `Store ${index}`,
        total_amount: 10 + index,
        purchase_date: '2024-01-15'
      }));

      receiptService.createReceipt.mockImplementation((data) => 
        Promise.resolve({
          data: { id: `receipt-${Date.now()}`, ...data },
          error: null
        })
      );

      const promises = bulkData.map(data =>
        request(app)
          .post('/receipts')
          .field('merchant_name', data.merchant_name)
          .field('total_amount', data.total_amount.toString())
          .field('purchase_date', data.purchase_date)
          .attach('image', Buffer.from('fake image'), 'receipt.jpg')
      );

      const startTime = Date.now();
      const responses = await Promise.all(promises);
      const duration = Date.now() - startTime;

      // All should succeed
      responses.forEach(response => {
        expect(response.status).toBe(201);
      });

      // Should complete within reasonable time
      expect(duration).toBeLessThan(10000); // 10 seconds
    });

    it('should handle large file uploads efficiently', async () => {
      const largeFile = Buffer.alloc(5 * 1024 * 1024); // 5MB file

      receiptService.createReceipt.mockResolvedValue({
        data: { id: 'receipt-large', user_id: 'user-123' },
        error: null
      });

      const startTime = Date.now();

      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Large File Store')
        .field('total_amount', '25.99')
        .attach('image', largeFile, 'large-receipt.jpg');

      const duration = Date.now() - startTime;

      expect(response.status).toBe(201);
      expect(duration).toBeLessThan(5000); // Should handle within 5 seconds
    });
  });

  describe('Security Tests', () => {
    it('should prevent path traversal in file uploads', async () => {
      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', '25.99')
        .attach('image', Buffer.from('fake image'), '../../../malicious.jpg');

      // Should sanitize filename
      expect(receiptService.createReceipt).not.toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          filename: expect.stringContaining('../')
        })
      );
    });

    it('should validate file magic numbers', async () => {
      // Test with file that has wrong magic number
      const fakeImage = Buffer.from('This is not an image file');
      
      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', 'Test Store')
        .field('total_amount', '25.99')
        .attach('image', fakeImage, 'fake.jpg');

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Invalid file');
    });

    it('should prevent XSS in merchant names', async () => {
      const xssPayload = '<script>alert("XSS")</script>';
      
      receiptService.createReceipt.mockResolvedValue({
        data: { 
          id: 'receipt-xss', 
          merchant_name: 'Safe Store Name' // Should be sanitized
        },
        error: null
      });

      const response = await request(app)
        .post('/receipts')
        .field('merchant_name', xssPayload)
        .field('total_amount', '25.99')
        .attach('image', Buffer.from('fake image'), 'receipt.jpg');

      expect(receiptService.createReceipt).toHaveBeenCalledWith(
        expect.objectContaining({
          merchant_name: expect.not.stringContaining('<script>')
        }),
        expect.anything()
      );
    });
  });
});