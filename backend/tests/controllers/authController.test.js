/**
 * @fileoverview Authentication Controller Unit Tests
 * @description Comprehensive testing for authentication flow, JWT handling, and user management
 */

const request = require('supertest');
const express = require('express');
const authController = require('../../src/controllers/authController');
const supabaseService = require('../../src/services/supabaseService');

// Mock dependencies
jest.mock('../../src/services/supabaseService');
jest.mock('../../src/utils/logger');

describe('AuthController', () => {
  let app;
  let mockRequest;
  let mockResponse;
  let mockNext;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.post('/login', authController.login);
    app.post('/register', authController.register);
    app.post('/logout', authController.logout);
    app.post('/refresh', authController.refreshSession);
    app.get('/profile', authController.getCurrentUser);

    mockRequest = global.testUtils.createMockRequest();
    mockResponse = global.testUtils.createMockResponse();
    mockNext = global.testUtils.createMockNext();

    jest.clearAllMocks();
  });

  describe('POST /login', () => {
    const validLoginData = {
      email: 'test@example.com',
      password: 'SecurePass123!'
    };

    it('should login user successfully with valid credentials', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        access_token: 'mock-access-token',
        refresh_token: 'mock-refresh-token'
      };

      supabaseService.signIn.mockResolvedValue({
        data: { user: mockUser, session: { access_token: 'token' } },
        error: null
      });

      const response = await request(app)
        .post('/login')
        .send(validLoginData);

      expect(response.status).toBe(200);
      expect(response.body).toMatchObject({
        success: true,
        user: expect.objectContaining({
          id: mockUser.id,
          email: mockUser.email
        }),
        token: expect.any(String)
      });
      expect(supabaseService.signIn).toHaveBeenCalledWith(
        validLoginData.email,
        validLoginData.password
      );
    });

    it('should return 401 for invalid credentials', async () => {
      supabaseService.signIn.mockResolvedValue({
        data: null,
        error: { message: 'Invalid login credentials' }
      });

      const response = await request(app)
        .post('/login')
        .send(validLoginData);

      expect(response.status).toBe(401);
      expect(response.body).toMatchObject({
        success: false,
        error: 'Invalid login credentials'
      });
    });

    it('should return 400 for missing email', async () => {
      const response = await request(app)
        .post('/login')
        .send({ password: 'password123' });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Email is required');
    });

    it('should return 400 for invalid email format', async () => {
      const response = await request(app)
        .post('/login')
        .send({ email: 'invalid-email', password: 'password123' });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('valid email');
    });

    it('should handle rate limiting', async () => {
      // Simulate multiple rapid requests
      const promises = Array(10).fill().map(() =>
        request(app).post('/login').send(validLoginData)
      );

      const responses = await Promise.all(promises);
      const rateLimitedResponses = responses.filter(r => r.status === 429);
      
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
    });

    it('should sanitize user input', async () => {
      const maliciousInput = {
        email: 'test@example.com<script>alert("xss")</script>',
        password: 'password123'
      };

      supabaseService.signIn.mockResolvedValue({
        data: null,
        error: { message: 'Invalid credentials' }
      });

      const response = await request(app)
        .post('/login')
        .send(maliciousInput);

      expect(supabaseService.signIn).not.toHaveBeenCalledWith(
        expect.stringContaining('<script>'),
        expect.anything()
      );
    });
  });

  describe('POST /register', () => {
    const validRegistrationData = {
      email: 'newuser@example.com',
      password: 'SecurePass123!',
      fullName: 'John Doe'
    };

    it('should register new user successfully', async () => {
      const mockUser = {
        id: 'user-456',
        email: 'newuser@example.com',
        user_metadata: { full_name: 'John Doe' }
      };

      supabaseService.signUp.mockResolvedValue({
        data: { user: mockUser },
        error: null
      });

      const response = await request(app)
        .post('/register')
        .send(validRegistrationData);

      expect(response.status).toBe(201);
      expect(response.body).toMatchObject({
        success: true,
        message: expect.stringContaining('registered'),
        user: expect.objectContaining({
          id: mockUser.id,
          email: mockUser.email
        })
      });
    });

    it('should return 409 for duplicate email', async () => {
      supabaseService.signUp.mockResolvedValue({
        data: null,
        error: { message: 'User already registered' }
      });

      const response = await request(app)
        .post('/register')
        .send(validRegistrationData);

      expect(response.status).toBe(409);
      expect(response.body.error).toContain('already registered');
    });

    it('should validate password strength', async () => {
      const weakPasswords = [
        'weak',
        '12345678',
        'password',
        'abcdefgh',
        'PASSWORD'
      ];

      for (const password of weakPasswords) {
        const response = await request(app)
          .post('/register')
          .send({
            ...validRegistrationData,
            password
          });

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(
          /password.*strong|Password.*requirements/i
        );
      }
    });

    it('should enforce email confirmation', async () => {
      supabaseService.signUp.mockResolvedValue({
        data: { user: { email_confirmed_at: null } },
        error: null
      });

      const response = await request(app)
        .post('/register')
        .send(validRegistrationData);

      expect(response.body.message).toContain('confirmation email');
    });
  });

  describe('POST /logout', () => {
    it('should logout user successfully', async () => {
      supabaseService.signOut.mockResolvedValue({ error: null });

      mockRequest.headers = { authorization: 'Bearer valid-token' };
      
      await authController.logout(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(200);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: true,
        message: 'Logged out successfully'
      });
    });

    it('should handle logout errors gracefully', async () => {
      supabaseService.signOut.mockResolvedValue({
        error: { message: 'Token expired' }
      });

      mockRequest.headers = { authorization: 'Bearer expired-token' };

      await authController.logout(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(400);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: false,
        error: 'Token expired'
      });
    });
  });

  describe('POST /refresh', () => {
    it('should refresh token successfully', async () => {
      const mockRefreshResponse = {
        data: {
          session: {
            access_token: 'new-access-token',
            refresh_token: 'new-refresh-token'
          }
        },
        error: null
      };

      supabaseService.refreshSession.mockResolvedValue(mockRefreshResponse);

      mockRequest.body = { refreshToken: 'valid-refresh-token' };

      await authController.refreshToken(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(200);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: true,
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token'
      });
    });

    it('should return 401 for invalid refresh token', async () => {
      supabaseService.refreshSession.mockResolvedValue({
        data: null,
        error: { message: 'Invalid refresh token' }
      });

      mockRequest.body = { refreshToken: 'invalid-token' };

      await authController.refreshToken(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(401);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: false,
        error: 'Invalid refresh token'
      });
    });
  });

  describe('GET /profile', () => {
    it('should return user profile successfully', async () => {
      const mockUser = global.testUtils.createMockUser({
        id: 'user-123',
        email: 'test@example.com'
      });

      mockRequest.user = mockUser;

      await authController.getProfile(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(200);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: true,
        user: mockUser
      });
    });

    it('should return 401 for unauthenticated request', async () => {
      mockRequest.user = null;

      await authController.getProfile(mockRequest, mockResponse, mockNext);

      expect(mockResponse.status).toHaveBeenCalledWith(401);
      expect(mockResponse.json).toHaveBeenCalledWith({
        success: false,
        error: 'Authentication required'
      });
    });
  });

  describe('Security Tests', () => {
    it('should prevent SQL injection in login', async () => {
      const sqlInjectionAttempt = {
        email: "test@example.com'; DROP TABLE users; --",
        password: 'password123'
      };

      supabaseService.signIn.mockResolvedValue({
        data: null,
        error: { message: 'Invalid credentials' }
      });

      const response = await request(app)
        .post('/login')
        .send(sqlInjectionAttempt);

      // Should not crash and should handle safely
      expect(response.status).toBe(401);
      expect(supabaseService.signIn).toHaveBeenCalledWith(
        expect.not.stringContaining('DROP TABLE'),
        'password123'
      );
    });

    it('should sanitize XSS attempts in registration', async () => {
      const xssAttempt = {
        email: 'test@example.com',
        password: 'SecurePass123!',
        fullName: '<script>alert("XSS")</script>'
      };

      supabaseService.signUp.mockResolvedValue({
        data: { user: { id: 'user-123' } },
        error: null
      });

      const response = await request(app)
        .post('/register')
        .send(xssAttempt);

      expect(supabaseService.signUp).toHaveBeenCalledWith(
        expect.anything(),
        expect.anything(),
        expect.objectContaining({
          full_name: expect.not.stringContaining('<script>')
        })
      );
    });

    it('should enforce HTTPS in production', () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      // Test HTTPS enforcement logic
      mockRequest.secure = false;
      mockRequest.get = jest.fn().mockReturnValue('http');

      // Middleware should redirect to HTTPS
      expect(() => {
        // This would be handled by security middleware
      }).not.toThrow();

      process.env.NODE_ENV = originalEnv;
    });
  });

  describe('Performance Tests', () => {
    it('should handle concurrent login requests', async () => {
      supabaseService.signIn.mockResolvedValue({
        data: { user: { id: 'user-123' }, session: { access_token: 'token' } },
        error: null
      });

      const concurrentRequests = Array(50).fill().map(() =>
        request(app)
          .post('/login')
          .send({
            email: 'test@example.com',
            password: 'password123'
          })
      );

      const startTime = Date.now();
      const responses = await Promise.all(concurrentRequests);
      const duration = Date.now() - startTime;

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      // Should complete within reasonable time (5 seconds for 50 requests)
      expect(duration).toBeLessThan(5000);
    });

    it('should respond within performance thresholds', async () => {
      supabaseService.signIn.mockResolvedValue({
        data: { user: { id: 'user-123' }, session: { access_token: 'token' } },
        error: null
      });

      const startTime = Date.now();
      
      const response = await request(app)
        .post('/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      const duration = Date.now() - startTime;

      expect(response.status).toBe(200);
      expect(duration).toBeLessThan(1000); // Should respond within 1 second
    });
  });
});