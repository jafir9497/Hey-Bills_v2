/**
 * Supabase Realtime Configuration for Hey-Bills
 * Handles real-time subscriptions for chat, notifications, and live updates
 */

const { config } = require('./supabase-environment');

/**
 * Realtime channel configurations
 */
const realtimeChannels = {
  // User-specific notifications
  notifications: {
    channelName: (userId) => `notifications:${userId}`,
    table: 'notifications',
    schema: 'public',
    
    events: ['INSERT', 'UPDATE'],
    
    filter: (userId) => ({
      type: 'eq',
      column: 'user_id',
      value: userId,
    }),
    
    // Client-side handling
    clientHandlers: {
      INSERT: 'onNotificationReceived',
      UPDATE: 'onNotificationUpdated',
    },
    
    // Rate limiting
    rateLimiting: {
      maxEventsPerSecond: 10,
      maxConnectionsPerUser: 3,
    },
  },
  
  // Receipt real-time updates
  receipts: {
    channelName: (userId) => `receipts:${userId}`,
    table: 'receipts',
    schema: 'public',
    
    events: ['INSERT', 'UPDATE', 'DELETE'],
    
    filter: (userId) => ({
      type: 'eq',
      column: 'user_id',
      value: userId,
    }),
    
    clientHandlers: {
      INSERT: 'onReceiptAdded',
      UPDATE: 'onReceiptUpdated',
      DELETE: 'onReceiptDeleted',
    },
    
    // Include related data
    select: '*, receipt_items(*)',
    
    rateLimiting: {
      maxEventsPerSecond: 5,
      maxConnectionsPerUser: 2,
    },
  },
  
  // Warranty updates
  warranties: {
    channelName: (userId) => `warranties:${userId}`,
    table: 'warranties',
    schema: 'public',
    
    events: ['INSERT', 'UPDATE', 'DELETE'],
    
    filter: (userId) => ({
      type: 'eq',
      column: 'user_id',
      value: userId,
    }),
    
    clientHandlers: {
      INSERT: 'onWarrantyAdded',
      UPDATE: 'onWarrantyUpdated',
      DELETE: 'onWarrantyDeleted',
    },
    
    rateLimiting: {
      maxEventsPerSecond: 3,
      maxConnectionsPerUser: 2,
    },
  },
  
  // Chat system (if implemented)
  chat: {
    channelName: (sessionId) => `chat:${sessionId}`,
    table: 'chat_messages',
    schema: 'public',
    
    events: ['INSERT'],
    
    filter: (sessionId) => ({
      type: 'eq',
      column: 'session_id',
      value: sessionId,
    }),
    
    clientHandlers: {
      INSERT: 'onMessageReceived',
    },
    
    rateLimiting: {
      maxEventsPerSecond: 20,
      maxConnectionsPerSession: 1,
    },
  },
  
  // System-wide announcements
  announcements: {
    channelName: () => 'announcements',
    table: 'system_announcements',
    schema: 'public',
    
    events: ['INSERT', 'UPDATE'],
    
    // No user filter - global announcements
    filter: () => null,
    
    clientHandlers: {
      INSERT: 'onAnnouncementReceived',
      UPDATE: 'onAnnouncementUpdated',
    },
    
    rateLimiting: {
      maxEventsPerSecond: 1,
      maxConnections: 1000,
    },
  },
  
  // OCR processing status
  ocrProcessing: {
    channelName: (userId) => `ocr:${userId}`,
    table: 'ocr_jobs',
    schema: 'public',
    
    events: ['UPDATE'],
    
    filter: (userId) => ({
      type: 'eq',
      column: 'user_id',
      value: userId,
    }),
    
    clientHandlers: {
      UPDATE: 'onOcrStatusUpdate',
    },
    
    rateLimiting: {
      maxEventsPerSecond: 5,
      maxConnectionsPerUser: 1,
    },
  },
};

/**
 * Realtime client configuration
 */
const realtimeConfig = {
  // Connection settings
  connection: {
    endpoint: `${config.supabase.url}/realtime/v1`,
    apiKey: config.supabase.anonKey,
    
    // Connection options
    options: {
      eventsPerSecond: 10,
      reconnectAfterMs: function (tries) {
        return [1000, 2000, 5000, 10000][tries - 1] || 10000;
      },
      encode: (payload, callback) => {
        return callback(null, JSON.stringify(payload));
      },
      decode: (payload, callback) => {
        try {
          return callback(null, JSON.parse(payload));
        } catch (e) {
          return callback(e, null);
        }
      },
      
      // Heartbeat
      heartbeatIntervalMs: 30000,
      sendHeartbeats: true,
      
      // Buffer settings
      bufferDelay: 500,
      maxBufferSize: 100,
    },
    
    // Authentication
    auth: {
      autoRefreshToken: true,
      detectSessionInAnotherTab: true,
      persistSession: true,
    },
  },
  
  // Channel management
  channels: {
    maxChannelsPerConnection: 10,
    autoCleanup: true,
    cleanupInterval: 300000, // 5 minutes
    
    // Channel lifecycle hooks
    hooks: {
      onJoin: 'onChannelJoined',
      onLeave: 'onChannelLeft',
      onError: 'onChannelError',
      onClose: 'onChannelClosed',
    },
  },
  
  // Error handling
  errorHandling: {
    retryAttempts: 3,
    retryDelay: 1000,
    exponentialBackoff: true,
    
    // Error types
    errors: {
      connection: 'CONNECTION_ERROR',
      authentication: 'AUTH_ERROR',
      subscription: 'SUBSCRIPTION_ERROR',
      rateLimit: 'RATE_LIMIT_ERROR',
    },
  },
  
  // Logging
  logging: {
    enabled: config.environment !== 'production',
    level: config.environment === 'development' ? 'debug' : 'error',
    logPayloads: config.environment === 'development',
  },
};

/**
 * Push notification configuration (for mobile)
 */
const pushNotificationConfig = {
  // Service configuration
  service: {
    provider: 'firebase', // or 'apn' for iOS only
    
    firebase: {
      serverKey: process.env.FIREBASE_SERVER_KEY,
      senderId: process.env.FCM_SENDER_ID,
      projectId: process.env.FIREBASE_PROJECT_ID,
    },
    
    apn: {
      keyId: process.env.APN_KEY_ID,
      teamId: process.env.APN_TEAM_ID,
      bundleId: process.env.IOS_BUNDLE_ID,
      privateKeyPath: process.env.APN_PRIVATE_KEY_PATH,
    },
  },
  
  // Notification types and templates
  templates: {
    warrantyExpiring: {
      title: 'Warranty Expiring Soon',
      body: 'Your {productName} warranty expires in {daysLeft} days',
      icon: 'warranty_icon',
      sound: 'default',
      priority: 'high',
      category: 'warranty_alert',
      
      // Custom data
      data: {
        type: 'warranty_expiring',
        action: 'view_warranty',
      },
    },
    
    warrantyExpired: {
      title: 'Warranty Has Expired',
      body: 'Your {productName} warranty has expired',
      icon: 'warranty_expired_icon',
      sound: 'default',
      priority: 'normal',
      category: 'warranty_alert',
      
      data: {
        type: 'warranty_expired',
        action: 'view_warranty',
      },
    },
    
    receiptProcessed: {
      title: 'Receipt Processed',
      body: 'Your receipt from {merchantName} has been processed',
      icon: 'receipt_icon',
      sound: 'default',
      priority: 'normal',
      category: 'receipt_update',
      
      data: {
        type: 'receipt_processed',
        action: 'view_receipt',
      },
    },
    
    budgetAlert: {
      title: 'Budget Alert',
      body: 'You have spent {percentage}% of your {categoryName} budget',
      icon: 'budget_icon',
      sound: 'default',
      priority: 'high',
      category: 'budget_alert',
      
      data: {
        type: 'budget_alert',
        action: 'view_budget',
      },
    },
  },
  
  // Delivery settings
  delivery: {
    batchSize: 100,
    retryAttempts: 3,
    retryDelay: 5000,
    
    // Rate limiting
    rateLimiting: {
      maxPerMinute: 60,
      maxPerHour: 1000,
      maxPerDay: 10000,
    },
    
    // Scheduling
    scheduling: {
      respectQuietHours: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '08:00',
      timezone: 'user_timezone', // Use user's timezone
    },
  },
  
  // Analytics tracking
  analytics: {
    enabled: true,
    trackDelivery: true,
    trackInteraction: true,
    
    events: {
      sent: 'notification_sent',
      delivered: 'notification_delivered',
      opened: 'notification_opened',
      dismissed: 'notification_dismissed',
    },
  },
};

/**
 * WebSocket connection management
 */
const websocketConfig = {
  // Connection pools
  pools: {
    maxConnections: 1000,
    maxConnectionsPerUser: 5,
    connectionTimeout: 30000,
    idleTimeout: 300000, // 5 minutes
  },
  
  // Message queuing
  messageQueue: {
    maxQueueSize: 1000,
    flushInterval: 1000, // 1 second
    priorityLevels: ['high', 'medium', 'low'],
    
    // Message persistence
    persistence: {
      enabled: true,
      maxAge: 86400000, // 24 hours
      storage: 'redis', // or 'memory'
    },
  },
  
  // Health monitoring
  health: {
    pingInterval: 30000,
    pongTimeout: 5000,
    maxMissedPings: 3,
    
    metrics: {
      trackConnectionCount: true,
      trackMessageRate: true,
      trackLatency: true,
    },
  },
};

/**
 * Helper functions for realtime operations
 */
const realtimeHelpers = {
  /**
   * Create channel subscription
   */
  createSubscription: (supabaseClient, channelType, userId, callbacks = {}) => {
    const channelConfig = realtimeChannels[channelType];
    if (!channelConfig) {
      throw new Error(`Unknown channel type: ${channelType}`);
    }
    
    const channelName = channelConfig.channelName(userId);
    const channel = supabaseClient.channel(channelName);
    
    // Configure postgres changes listener
    if (channelConfig.table) {
      channel.on(
        'postgres_changes',
        {
          event: '*',
          schema: channelConfig.schema,
          table: channelConfig.table,
          filter: channelConfig.filter(userId),
        },
        (payload) => {
          const eventType = payload.eventType;
          const handler = callbacks[channelConfig.clientHandlers[eventType]];
          if (handler) {
            handler(payload);
          }
        }
      );
    }
    
    return channel.subscribe((status, err) => {
      if (status === 'SUBSCRIBED') {
        console.log(`✅ Subscribed to ${channelName}`);
      } else if (status === 'CHANNEL_ERROR') {
        console.error(`❌ Error subscribing to ${channelName}:`, err);
      }
    });
  },
  
  /**
   * Send push notification
   */
  sendPushNotification: async (userId, templateName, templateData = {}, options = {}) => {
    const template = pushNotificationConfig.templates[templateName];
    if (!template) {
      throw new Error(`Unknown notification template: ${templateName}`);
    }
    
    // Replace template variables
    const notification = {
      ...template,
      title: realtimeHelpers.replaceTemplateVars(template.title, templateData),
      body: realtimeHelpers.replaceTemplateVars(template.body, templateData),
      ...options,
    };
    
    // Implementation would depend on the push service being used
    console.log(`📱 Sending notification to user ${userId}:`, notification);
    
    return notification;
  },
  
  /**
   * Replace template variables
   */
  replaceTemplateVars: (template, data) => {
    return template.replace(/\{(\w+)\}/g, (match, key) => {
      return data[key] || match;
    });
  },
  
  /**
   * Manage connection lifecycle
   */
  connectionManager: {
    connections: new Map(),
    
    addConnection: (userId, connection) => {
      if (!realtimeHelpers.connectionManager.connections.has(userId)) {
        realtimeHelpers.connectionManager.connections.set(userId, []);
      }
      realtimeHelpers.connectionManager.connections.get(userId).push(connection);
    },
    
    removeConnection: (userId, connection) => {
      const userConnections = realtimeHelpers.connectionManager.connections.get(userId);
      if (userConnections) {
        const index = userConnections.indexOf(connection);
        if (index > -1) {
          userConnections.splice(index, 1);
        }
        if (userConnections.length === 0) {
          realtimeHelpers.connectionManager.connections.delete(userId);
        }
      }
    },
    
    getConnectionCount: (userId) => {
      const userConnections = realtimeHelpers.connectionManager.connections.get(userId);
      return userConnections ? userConnections.length : 0;
    },
    
    cleanup: () => {
      // Clean up stale connections
      const now = Date.now();
      realtimeHelpers.connectionManager.connections.forEach((connections, userId) => {
        const activeConnections = connections.filter(conn => 
          conn.lastActivity && (now - conn.lastActivity) < websocketConfig.pools.idleTimeout
        );
        
        if (activeConnections.length !== connections.length) {
          if (activeConnections.length === 0) {
            realtimeHelpers.connectionManager.connections.delete(userId);
          } else {
            realtimeHelpers.connectionManager.connections.set(userId, activeConnections);
          }
        }
      });
    },
  },
};

module.exports = {
  realtimeChannels,
  realtimeConfig,
  pushNotificationConfig,
  websocketConfig,
  realtimeHelpers,
  
  // Convenience functions
  getChannelConfig: (channelType) => realtimeChannels[channelType],
  getNotificationTemplate: (templateName) => pushNotificationConfig.templates[templateName],
};