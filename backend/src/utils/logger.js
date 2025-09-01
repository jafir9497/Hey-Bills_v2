/**
 * Logger Utility
 * Centralized logging configuration for the application
 */

const isDevelopment = process.env.NODE_ENV === 'development';
const isTest = process.env.NODE_ENV === 'test';

/**
 * Simple logger implementation
 * In production, you might want to use Winston, Pino, or another logging library
 */
class Logger {
  constructor() {
    this.logLevel = process.env.LOG_LEVEL || (isDevelopment ? 'debug' : 'info');
    this.levels = {
      error: 0,
      warn: 1,
      info: 2,
      debug: 3
    };
  }

  shouldLog(level) {
    return this.levels[level] <= this.levels[this.logLevel];
  }

  formatMessage(level, message, meta = {}) {
    const timestamp = new Date().toISOString();
    const metaString = Object.keys(meta).length > 0 ? JSON.stringify(meta) : '';
    
    if (isDevelopment) {
      return `[${timestamp}] ${level.toUpperCase()}: ${message} ${metaString}`;
    } else {
      return JSON.stringify({
        timestamp,
        level: level.toUpperCase(),
        message,
        ...meta
      });
    }
  }

  error(message, meta = {}) {
    if (this.shouldLog('error') && !isTest) {
      console.error(this.formatMessage('error', message, meta));
    }
  }

  warn(message, meta = {}) {
    if (this.shouldLog('warn') && !isTest) {
      console.warn(this.formatMessage('warn', message, meta));
    }
  }

  info(message, meta = {}) {
    if (this.shouldLog('info') && !isTest) {
      console.log(this.formatMessage('info', message, meta));
    }
  }

  debug(message, meta = {}) {
    if (this.shouldLog('debug') && !isTest) {
      console.log(this.formatMessage('debug', message, meta));
    }
  }
}

// Export singleton instance
const logger = new Logger();

module.exports = logger;