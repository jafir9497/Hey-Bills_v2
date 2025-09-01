/**
 * Jest Configuration for Hey-Bills Backend
 */

module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Test file patterns
  testMatch: [
    '**/tests/**/*.test.js',
    '**/tests/**/*.spec.js',
    '**/__tests__/**/*.js'
  ],
  
  // Coverage configuration
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.js',
    'config/**/*.js',
    '!src/**/*.test.js',
    '!src/**/*.spec.js'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  
  // Test timeout
  testTimeout: 10000,
  
  // Module paths
  roots: ['<rootDir>/src', '<rootDir>/tests', '<rootDir>/config'],
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Verbose output
  verbose: true,
  
  // Environment variables for testing
  setupFiles: ['<rootDir>/tests/env.setup.js']
};