/**
 * Supabase Service Layer
 * High-level service functions for Supabase operations
 * Handles authentication, data operations, and storage
 */

const { db } = require('../utils/database');
const { APIError } = require('../../utils/errorHandler');

/**
 * Authentication Service
 */
class AuthService {
  /**
   * Sign up a new user
   * @param {string} email - User email
   * @param {string} password - User password
   * @param {Object} metadata - Additional user metadata
   * @returns {Promise<Object>} Auth result
   */
  async signUp(email, password, metadata = {}) {
    return db.query(
      () => db.client.auth.signUp({
        email,
        password,
        options: {
          data: metadata
        }
      }),
      'user sign up'
    );
  }

  /**
   * Sign in a user
   * @param {string} email - User email
   * @param {string} password - User password
   * @returns {Promise<Object>} Auth result
   */
  async signIn(email, password) {
    return db.query(
      () => db.client.auth.signInWithPassword({ email, password }),
      'user sign in'
    );
  }

  /**
   * Sign in with OAuth provider
   * @param {string} provider - OAuth provider (google, facebook, etc.)
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Auth result
   */
  async signInWithOAuth(provider, options = {}) {
    return db.query(
      () => db.client.auth.signInWithOAuth({
        provider,
        options: {
          redirectTo: options.redirectTo || process.env.FRONTEND_URL,
          ...options
        }
      }),
      `OAuth sign in with ${provider}`
    );
  }

  /**
   * Sign out current user
   * @returns {Promise<Object>} Sign out result
   */
  async signOut() {
    return db.query(
      () => db.client.auth.signOut(),
      'user sign out'
    );
  }

  /**
   * Get current user session
   * @returns {Promise<Object>} Session data
   */
  async getSession() {
    return db.query(
      () => db.client.auth.getSession(),
      'get user session'
    );
  }

  /**
   * Refresh user session
   * @returns {Promise<Object>} Refreshed session
   */
  async refreshSession() {
    return db.query(
      () => db.client.auth.refreshSession(),
      'refresh user session'
    );
  }

  /**
   * Reset user password
   * @param {string} email - User email
   * @returns {Promise<Object>} Reset result
   */
  async resetPassword(email) {
    return db.query(
      () => db.client.auth.resetPasswordForEmail(email, {
        redirectTo: `${process.env.FRONTEND_URL}/auth/reset-password`
      }),
      'password reset request'
    );
  }

  /**
   * Update user password
   * @param {string} newPassword - New password
   * @returns {Promise<Object>} Update result
   */
  async updatePassword(newPassword) {
    return db.query(
      () => db.client.auth.updateUser({ password: newPassword }),
      'password update'
    );
  }

  /**
   * Verify user from JWT token
   * @param {string} token - JWT token
   * @returns {Promise<Object>} User data
   */
  async verifyToken(token) {
    return db.query(
      () => db.client.auth.getUser(token),
      'token verification'
    );
  }
}

/**
 * User Management Service
 */
class UserService {
  /**
   * Get user profile by ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} User profile
   */
  async getUserProfile(userId) {
    return db.query(
      () => db.buildQuery('users', {
        select: '*',
        filters: { id: userId }
      }).single(),
      'get user profile'
    );
  }

  /**
   * Update user profile
   * @param {string} userId - User ID
   * @param {Object} updates - Profile updates
   * @returns {Promise<Object>} Updated profile
   */
  async updateUserProfile(userId, updates) {
    const sanitizedUpdates = {
      ...updates,
      updated_at: new Date().toISOString(),
      // Remove sensitive fields that shouldn't be updated directly
      id: undefined,
      created_at: undefined,
      email_confirmed_at: undefined
    };

    return db.query(
      () => db.client
        .from('users')
        .update(sanitizedUpdates)
        .eq('id', userId)
        .select()
        .single(),
      'update user profile'
    );
  }

  /**
   * Create user profile (usually called after auth signup)
   * @param {Object} userData - User data
   * @returns {Promise<Object>} Created profile
   */
  async createUserProfile(userData) {
    const profileData = {
      id: userData.id,
      email: userData.email,
      full_name: userData.user_metadata?.full_name,
      avatar_url: userData.user_metadata?.avatar_url,
      provider: userData.app_metadata?.provider,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    return db.query(
      () => db.client
        .from('users')
        .insert(profileData)
        .select()
        .single(),
      'create user profile'
    );
  }

  /**
   * Delete user profile
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Delete result
   */
  async deleteUserProfile(userId) {
    return db.adminQuery(
      (adminClient) => adminClient
        .from('users')
        .delete()
        .eq('id', userId),
      'delete user profile'
    );
  }

  /**
   * Get user statistics
   * @param {string} userId - User ID
   * @returns {Promise<Object>} User statistics
   */
  async getUserStats(userId) {
    const [receiptsResult, warrantiesResult, budgetsResult] = await Promise.all([
      db.query(
        () => db.client
          .from('receipts')
          .select('count')
          .eq('user_id', userId),
        'get receipts count'
      ),
      db.query(
        () => db.client
          .from('warranties')
          .select('count')
          .eq('user_id', userId),
        'get warranties count'
      ),
      db.query(
        () => db.client
          .from('budgets')
          .select('count')
          .eq('user_id', userId),
        'get budgets count'
      )
    ]);

    return {
      receipts_count: receiptsResult.count || 0,
      warranties_count: warrantiesResult.count || 0,
      budgets_count: budgetsResult.count || 0,
      member_since: (await this.getUserProfile(userId)).data?.created_at
    };
  }
}

/**
 * Storage Service
 */
class StorageService {
  /**
   * Upload file to Supabase Storage
   * @param {string} bucket - Storage bucket name
   * @param {string} path - File path
   * @param {File|Buffer} file - File to upload
   * @param {Object} options - Upload options
   * @returns {Promise<Object>} Upload result
   */
  async uploadFile(bucket, path, file, options = {}) {
    return db.query(
      () => db.client.storage
        .from(bucket)
        .upload(path, file, {
          cacheControl: '3600',
          upsert: false,
          ...options
        }),
      `upload file to ${bucket}/${path}`
    );
  }

  /**
   * Download file from Supabase Storage
   * @param {string} bucket - Storage bucket name
   * @param {string} path - File path
   * @returns {Promise<Object>} Download result
   */
  async downloadFile(bucket, path) {
    return db.query(
      () => db.client.storage
        .from(bucket)
        .download(path),
      `download file from ${bucket}/${path}`
    );
  }

  /**
   * Delete file from Supabase Storage
   * @param {string} bucket - Storage bucket name
   * @param {string} path - File path
   * @returns {Promise<Object>} Delete result
   */
  async deleteFile(bucket, path) {
    return db.query(
      () => db.client.storage
        .from(bucket)
        .remove([path]),
      `delete file from ${bucket}/${path}`
    );
  }

  /**
   * Get public URL for file
   * @param {string} bucket - Storage bucket name
   * @param {string} path - File path
   * @returns {Object} Public URL data
   */
  getPublicUrl(bucket, path) {
    return db.client.storage
      .from(bucket)
      .getPublicUrl(path);
  }

  /**
   * Create signed URL for private file
   * @param {string} bucket - Storage bucket name
   * @param {string} path - File path
   * @param {number} expiresIn - Expiry time in seconds
   * @returns {Promise<Object>} Signed URL
   */
  async createSignedUrl(bucket, path, expiresIn = 3600) {
    return db.query(
      () => db.client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn),
      `create signed URL for ${bucket}/${path}`
    );
  }

  /**
   * List files in bucket
   * @param {string} bucket - Storage bucket name
   * @param {string} folder - Folder path (optional)
   * @returns {Promise<Object>} File list
   */
  async listFiles(bucket, folder = '') {
    return db.query(
      () => db.client.storage
        .from(bucket)
        .list(folder),
      `list files in ${bucket}/${folder}`
    );
  }
}

/**
 * Real-time Service
 */
class RealtimeService {
  /**
   * Subscribe to table changes
   * @param {string} table - Table name
   * @param {Function} callback - Callback function
   * @param {Object} options - Subscription options
   * @returns {Object} Subscription
   */
  subscribe(table, callback, options = {}) {
    let subscription = db.client
      .channel(`${table}_changes`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table,
        ...options
      }, callback);

    subscription.subscribe();
    return subscription;
  }

  /**
   * Unsubscribe from changes
   * @param {Object} subscription - Subscription to remove
   */
  unsubscribe(subscription) {
    if (subscription) {
      subscription.unsubscribe();
    }
  }

  /**
   * Send real-time message to channel
   * @param {string} channel - Channel name
   * @param {string} event - Event name
   * @param {Object} payload - Message payload
   */
  async sendMessage(channel, event, payload) {
    const channelInstance = db.client.channel(channel);
    return channelInstance.send({
      type: 'broadcast',
      event,
      payload
    });
  }
}

// Create service instances
const authService = new AuthService();
const userService = new UserService();
const storageService = new StorageService();
const realtimeService = new RealtimeService();

module.exports = {
  AuthService,
  UserService,
  StorageService,
  RealtimeService,
  authService,
  userService,
  storageService,
  realtimeService
};