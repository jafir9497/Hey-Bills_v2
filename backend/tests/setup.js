/**
 * Test Setup
 * Global test configuration and utilities
 */

// Increase timeout for async operations
jest.setTimeout(10000);

// Global test utilities
global.testUtils = {
  /**
   * Create a mock user object
   */
  createMockUser: (overrides = {}) => ({
    id: 'test-user-id',
    email: 'test@example.com',
    role: 'user',
    emailConfirmed: true,
    metadata: {},
    appMetadata: {},
    lastSignIn: new Date().toISOString(),
    createdAt: new Date().toISOString(),
    ...overrides
  }),
  
  /**
   * Create a mock request object
   */
  createMockRequest: (overrides = {}) => ({
    body: {},
    params: {},
    query: {},
    headers: {},
    user: null,
    token: null,
    ...overrides
  }),
  
  /**
   * Create a mock response object
   */
  createMockResponse: () => {
    const res = {};
    res.status = jest.fn(() => res);
    res.json = jest.fn(() => res);
    res.send = jest.fn(() => res);
    res.redirect = jest.fn(() => res);
    return res;
  },
  
  /**
   * Create a mock next function
   */
  createMockNext: () => jest.fn(),
  
  /**
   * Wait for a specified amount of time
   */
  delay: (ms) => new Promise(resolve => setTimeout(resolve, ms)),
  
  /**
   * Generate a random string
   */
  randomString: (length = 8) => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }
};

// Mock console methods to reduce noise during testing
const originalConsole = { ...console };

beforeAll(() => {
  // Suppress console output during tests unless specifically needed
  global.console = {
    ...console,
    log: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    info: jest.fn(),
    debug: jest.fn()
  };
});

afterAll(() => {
  // Restore console
  global.console = originalConsole;
});

// Clean up after each test
afterEach(() => {
  jest.clearAllMocks();
});

module.exports = {};