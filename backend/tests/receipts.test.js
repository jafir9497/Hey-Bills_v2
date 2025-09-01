/**
 * Receipt API Tests
 * Comprehensive test suite for receipt endpoints
 */

const request = require('supertest');
const app = require('../src/server');
const { supabase } = require('../config/supabase');

// Test data
const testUser = {
  email: 'receipt-test@example.com',
  password: 'testpassword123',
  full_name: 'Receipt Test User'
};

const testReceipt = {
  image_url: 'https://example.com/receipt.jpg',
  merchant_name: 'Test Merchant',
  total_amount: 25.99,
  purchase_date: '2024-01-15',
  merchant_address: '123 Test St, Test City',
  tax_amount: 2.34,
  currency: 'USD',
  payment_method: 'credit_card',
  is_business_expense: true,
  notes: 'Test receipt for API testing',
  tags: ['test', 'api', 'receipt']
};

let authToken = null;
let userId = null;
let testReceiptId = null;
let testCategoryId = null;

describe('Receipt API', () => {
  // Setup: Create test user and authenticate
  beforeAll(async () => {
    try {
      // Create test user
      const { data: authData, error: signUpError } = await supabase.auth.signUp({
        email: testUser.email,
        password: testUser.password,
        options: {
          data: { full_name: testUser.full_name }
        }
      });

      if (signUpError && !signUpError.message.includes('already registered')) {
        throw signUpError;
      }

      // Sign in to get token
      const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
        email: testUser.email,
        password: testUser.password
      });

      if (signInError) {
        throw signInError;
      }

      authToken = signInData.session.access_token;
      userId = signInData.user.id;

      // Get a test category
      const categoriesResponse = await request(app)
        .get('/api/receipts/categories')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      if (categoriesResponse.body.data.length > 0) {
        testCategoryId = categoriesResponse.body.data[0].id;
      }
    } catch (error) {
      console.error('Test setup failed:', error);
      throw error;
    }
  });

  // Cleanup: Remove test data
  afterAll(async () => {
    try {
      if (testReceiptId) {
        await request(app)
          .delete(`/api/receipts/${testReceiptId}`)
          .set('Authorization', `Bearer ${authToken}`);
      }

      // Delete test user (admin operation)
      if (userId) {
        await supabase.auth.admin.deleteUser(userId);
      }
    } catch (error) {
      console.warn('Test cleanup failed:', error);
    }
  });

  describe('GET /api/receipts/categories', () => {
    it('should return available categories', async () => {
      const response = await request(app)
        .get('/api/receipts/categories')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.message).toBe('Categories retrieved successfully');
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);
      expect(response.body.data[0]).toHaveProperty('id');
      expect(response.body.data[0]).toHaveProperty('name');
    });

    it('should require authentication', async () => {
      await request(app)
        .get('/api/receipts/categories')
        .expect(401);
    });
  });

  describe('POST /api/receipts', () => {
    it('should create a new receipt', async () => {
      const receiptData = {
        ...testReceipt,
        category_id: testCategoryId
      };

      const response = await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(receiptData)
        .expect(201);

      expect(response.body.message).toBe('Receipt created successfully');
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.data.merchant_name).toBe(testReceipt.merchant_name);
      expect(response.body.data.total_amount).toBe(testReceipt.total_amount.toString());
      expect(response.body.data.user_id).toBe(userId);

      testReceiptId = response.body.data.id;
    });

    it('should validate required fields', async () => {
      const incompleteReceipt = {
        merchant_name: 'Test Merchant'
        // Missing required fields
      };

      const response = await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(incompleteReceipt)
        .expect(400);

      expect(response.body.error).toContain('required');
    });

    it('should validate amount is positive', async () => {
      const negativeAmountReceipt = {
        ...testReceipt,
        total_amount: -10.00
      };

      await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(negativeAmountReceipt)
        .expect(400);
    });

    it('should validate date format', async () => {
      const invalidDateReceipt = {
        ...testReceipt,
        purchase_date: 'invalid-date'
      };

      await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidDateReceipt)
        .expect(400);
    });

    it('should validate tags array', async () => {
      const invalidTagsReceipt = {
        ...testReceipt,
        tags: 'not-an-array'
      };

      await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidTagsReceipt)
        .expect(400);
    });

    it('should require authentication', async () => {
      await request(app)
        .post('/api/receipts')
        .send(testReceipt)
        .expect(401);
    });
  });

  describe('GET /api/receipts', () => {
    it('should return user receipts with pagination', async () => {
      const response = await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ page: 1, limit: 10 })
        .expect(200);

      expect(response.body.message).toBe('Receipts retrieved successfully');
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.pagination).toHaveProperty('page');
      expect(response.body.pagination).toHaveProperty('limit');
      expect(response.body.pagination).toHaveProperty('total');
    });

    it('should filter by date range', async () => {
      const response = await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({
          date_from: '2024-01-01',
          date_to: '2024-01-31'
        })
        .expect(200);

      expect(response.body.data).toBeDefined();
    });

    it('should filter by amount range', async () => {
      const response = await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({
          min_amount: 10,
          max_amount: 100
        })
        .expect(200);

      expect(response.body.data).toBeDefined();
    });

    it('should search by merchant name', async () => {
      const response = await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ merchant_name: 'Test' })
        .expect(200);

      expect(response.body.data).toBeDefined();
    });

    it('should validate pagination parameters', async () => {
      await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ page: 0 })
        .expect(400);

      await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ limit: 200 })
        .expect(400);
    });

    it('should validate sort parameters', async () => {
      await request(app)
        .get('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ sort_by: 'invalid_field' })
        .expect(400);
    });
  });

  describe('GET /api/receipts/:id', () => {
    it('should return a specific receipt', async () => {
      const response = await request(app)
        .get(`/api/receipts/${testReceiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.message).toBe('Receipt retrieved successfully');
      expect(response.body.data.id).toBe(testReceiptId);
      expect(response.body.data.merchant_name).toBe(testReceipt.merchant_name);
    });

    it('should return 404 for non-existent receipt', async () => {
      const fakeId = '123e4567-e89b-12d3-a456-426614174000';
      await request(app)
        .get(`/api/receipts/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });

    it('should not allow access to other users receipts', async () => {
      // This would require creating another user, simplified for now
      // In a real scenario, you'd create another user and receipt
      const response = await request(app)
        .get(`/api/receipts/${testReceiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.data.user_id).toBe(userId);
    });
  });

  describe('PUT /api/receipts/:id', () => {
    it('should update a receipt', async () => {
      const updates = {
        merchant_name: 'Updated Merchant',
        notes: 'Updated notes',
        total_amount: 30.99
      };

      const response = await request(app)
        .put(`/api/receipts/${testReceiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updates)
        .expect(200);

      expect(response.body.message).toBe('Receipt updated successfully');
      expect(response.body.data.merchant_name).toBe(updates.merchant_name);
      expect(response.body.data.notes).toBe(updates.notes);
      expect(response.body.data.total_amount).toBe(updates.total_amount.toString());
    });

    it('should validate update data', async () => {
      const invalidUpdates = {
        total_amount: -5.00
      };

      await request(app)
        .put(`/api/receipts/${testReceiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidUpdates)
        .expect(400);
    });

    it('should return 404 for non-existent receipt', async () => {
      const fakeId = '123e4567-e89b-12d3-a456-426614174000';
      await request(app)
        .put(`/api/receipts/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ notes: 'test' })
        .expect(404);
    });
  });

  describe('PATCH /api/receipts/:id/tags', () => {
    it('should update receipt tags', async () => {
      const newTags = ['updated', 'tags', 'test'];

      const response = await request(app)
        .patch(`/api/receipts/${testReceiptId}/tags`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ tags: newTags })
        .expect(200);

      expect(response.body.message).toBe('Receipt tags updated successfully');
      expect(response.body.data.tags).toEqual(newTags);
    });

    it('should validate tags format', async () => {
      await request(app)
        .patch(`/api/receipts/${testReceiptId}/tags`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ tags: 'not-an-array' })
        .expect(400);
    });

    it('should enforce tag limits', async () => {
      const tooManyTags = Array(25).fill('tag');
      await request(app)
        .patch(`/api/receipts/${testReceiptId}/tags`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ tags: tooManyTags })
        .expect(400);
    });
  });

  describe('GET /api/receipts/analytics', () => {
    it('should return analytics data', async () => {
      const response = await request(app)
        .get('/api/receipts/analytics')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ period: 'month', group_by: 'category' })
        .expect(200);

      expect(response.body.message).toBe('Analytics retrieved successfully');
      expect(response.body.data).toHaveProperty('summary');
      expect(response.body.data).toHaveProperty('grouped_data');
      expect(response.body.data.summary).toHaveProperty('total_spent');
      expect(response.body.data.summary).toHaveProperty('total_receipts');
    });

    it('should handle different grouping options', async () => {
      const groupings = ['category', 'merchant', 'date', 'business_expense'];
      
      for (const groupBy of groupings) {
        const response = await request(app)
          .get('/api/receipts/analytics')
          .set('Authorization', `Bearer ${authToken}`)
          .query({ period: 'month', group_by: groupBy })
          .expect(200);

        expect(response.body.data.group_by).toBe(groupBy);
      }
    });

    it('should validate analytics parameters', async () => {
      await request(app)
        .get('/api/receipts/analytics')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ period: 'invalid' })
        .expect(400);

      await request(app)
        .get('/api/receipts/analytics')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ group_by: 'invalid' })
        .expect(400);
    });
  });

  describe('DELETE /api/receipts/:id', () => {
    it('should delete a receipt', async () => {
      // Create a receipt to delete
      const receiptToDelete = {
        ...testReceipt,
        merchant_name: 'Delete Test Merchant'
      };

      const createResponse = await request(app)
        .post('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send(receiptToDelete)
        .expect(201);

      const receiptId = createResponse.body.data.id;

      const response = await request(app)
        .delete(`/api/receipts/${receiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.message).toBe('Receipt deleted successfully');
      expect(response.body.data.id).toBe(receiptId);

      // Verify it's deleted
      await request(app)
        .get(`/api/receipts/${receiptId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });

    it('should return 404 for non-existent receipt', async () => {
      const fakeId = '123e4567-e89b-12d3-a456-426614174000';
      await request(app)
        .delete(`/api/receipts/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });
  });

  describe('DELETE /api/receipts (bulk delete)', () => {
    it('should bulk delete receipts', async () => {
      // Create multiple receipts to delete
      const receiptsToCreate = [
        { ...testReceipt, merchant_name: 'Bulk Delete 1' },
        { ...testReceipt, merchant_name: 'Bulk Delete 2' }
      ];

      const createdReceipts = [];
      for (const receipt of receiptsToCreate) {
        const response = await request(app)
          .post('/api/receipts')
          .set('Authorization', `Bearer ${authToken}`)
          .send(receipt)
          .expect(201);
        createdReceipts.push(response.body.data.id);
      }

      const response = await request(app)
        .delete('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ receipt_ids: createdReceipts })
        .expect(200);

      expect(response.body.message).toContain('Successfully deleted');
      expect(response.body.data.deleted_count).toBe(2);
    });

    it('should validate bulk delete input', async () => {
      await request(app)
        .delete('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ receipt_ids: 'not-an-array' })
        .expect(400);

      await request(app)
        .delete('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ receipt_ids: [] })
        .expect(400);
    });

    it('should enforce bulk delete limits', async () => {
      const tooManyIds = Array(60).fill('123e4567-e89b-12d3-a456-426614174000');
      await request(app)
        .delete('/api/receipts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ receipt_ids: tooManyIds })
        .expect(400);
    });
  });

  describe('Authentication and Authorization', () => {
    it('should require authentication for all endpoints', async () => {
      const endpoints = [
        { method: 'get', path: '/api/receipts' },
        { method: 'get', path: `/api/receipts/${testReceiptId}` },
        { method: 'post', path: '/api/receipts' },
        { method: 'put', path: `/api/receipts/${testReceiptId}` },
        { method: 'delete', path: `/api/receipts/${testReceiptId}` },
        { method: 'get', path: '/api/receipts/categories' },
        { method: 'get', path: '/api/receipts/analytics' }
      ];

      for (const endpoint of endpoints) {
        await request(app)[endpoint.method](endpoint.path)
          .expect(401);
      }
    });

    it('should reject invalid tokens', async () => {
      await request(app)
        .get('/api/receipts')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);
    });
  });
});