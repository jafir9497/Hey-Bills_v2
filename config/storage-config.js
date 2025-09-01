/**
 * Supabase Storage Configuration for Hey-Bills
 * Handles file upload, storage buckets, and media processing
 */

const { config } = require('./supabase-environment');

/**
 * Storage bucket configurations
 */
const storageBuckets = {
  receipts: {
    id: 'receipts',
    name: 'receipts',
    public: false,
    fileSizeLimit: 10 * 1024 * 1024, // 10MB
    allowedMimeTypes: [
      'image/jpeg',
      'image/png', 
      'image/webp',
      'application/pdf'
    ],
    
    // File organization
    pathStructure: '{userId}/{year}/{month}/{filename}',
    
    // Security settings
    security: {
      requireAuth: true,
      ownerOnly: true,
      allowPublicRead: false,
    },
    
    // Processing settings
    processing: {
      enableThumbnails: true,
      enableOCR: true,
      enableCompression: true,
      thumbnailSizes: [
        { name: 'thumb', width: 150, height: 150, quality: 80 },
        { name: 'medium', width: 600, height: 800, quality: 85 },
      ],
    },
    
    // Retention policy
    retention: {
      deleteAfterDays: null, // Keep forever
      archiveAfterDays: 365 * 2, // Archive after 2 years
    },
  },
  
  warranties: {
    id: 'warranties',
    name: 'warranties',
    public: false,
    fileSizeLimit: 20 * 1024 * 1024, // 20MB
    allowedMimeTypes: [
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ],
    
    pathStructure: '{userId}/warranties/{warrantyId}/{filename}',
    
    security: {
      requireAuth: true,
      ownerOnly: true,
      allowPublicRead: false,
    },
    
    processing: {
      enableThumbnails: true,
      enableOCR: false, // Usually not needed for warranty docs
      enableCompression: true,
      thumbnailSizes: [
        { name: 'thumb', width: 200, height: 260, quality: 80 },
      ],
    },
    
    retention: {
      deleteAfterDays: null, // Keep forever
      archiveAfterDays: 365 * 5, // Archive after 5 years
    },
  },
  
  profiles: {
    id: 'profiles',
    name: 'profiles',
    public: true,
    fileSizeLimit: 5 * 1024 * 1024, // 5MB
    allowedMimeTypes: [
      'image/jpeg',
      'image/png',
      'image/webp'
    ],
    
    pathStructure: '{userId}/profile/{filename}',
    
    security: {
      requireAuth: true,
      ownerOnly: false, // Public read access
      allowPublicRead: true,
    },
    
    processing: {
      enableThumbnails: true,
      enableOCR: false,
      enableCompression: true,
      thumbnailSizes: [
        { name: 'thumb', width: 100, height: 100, quality: 85 },
        { name: 'medium', width: 300, height: 300, quality: 90 },
      ],
    },
    
    retention: {
      deleteAfterDays: null,
      archiveAfterDays: null,
    },
  },
  
  temp: {
    id: 'temp',
    name: 'temp',
    public: false,
    fileSizeLimit: 50 * 1024 * 1024, // 50MB for processing
    allowedMimeTypes: [
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf'
    ],
    
    pathStructure: '{userId}/temp/{timestamp}/{filename}',
    
    security: {
      requireAuth: true,
      ownerOnly: true,
      allowPublicRead: false,
    },
    
    processing: {
      enableThumbnails: false,
      enableOCR: false,
      enableCompression: false,
    },
    
    retention: {
      deleteAfterDays: 1, // Clean up temp files after 1 day
      archiveAfterDays: null,
    },
  }
};

/**
 * File upload configuration
 */
const uploadConfig = {
  // General limits
  maxFileSize: config.upload.maxFileSize,
  maxFilesPerRequest: config.upload.maxFilesPerRequest,
  maxTotalSize: 100 * 1024 * 1024, // 100MB total per request
  
  // Allowed file types
  allowedMimeTypes: [
    ...storageBuckets.receipts.allowedMimeTypes,
    ...storageBuckets.warranties.allowedMimeTypes,
    ...storageBuckets.profiles.allowedMimeTypes
  ],
  
  // File name sanitization
  sanitization: {
    maxFilenameLength: 255,
    allowedCharacters: /^[a-zA-Z0-9\-_\.\s]+$/,
    replaceSpaces: true,
    replaceWith: '_',
    addTimestamp: true,
  },
  
  // Temporary storage
  tempStorage: {
    directory: config.upload.tempUploadDir,
    cleanupInterval: 60 * 60 * 1000, // 1 hour
    maxAge: config.upload.tempFileMaxAge,
    autoCleanup: config.upload.cleanupTempFiles,
  },
  
  // Security settings
  security: {
    scanForMalware: process.env.ENABLE_MALWARE_SCAN === 'true',
    checkFileHeaders: true,
    preventExecutables: true,
    maxDimensions: {
      width: 10000,
      height: 10000,
    },
  },
  
  // Progress tracking
  progress: {
    enableProgress: true,
    chunkSize: 1024 * 1024, // 1MB chunks
    enableResumable: true,
  },
};

/**
 * Image processing configuration
 */
const imageProcessing = {
  // Compression settings
  compression: {
    quality: config.imageProcessing.quality,
    progressive: true,
    optimizeScans: true,
    quantizationTable: 3,
  },
  
  // Resize settings
  resize: {
    maxWidth: config.imageProcessing.maxWidth,
    maxHeight: config.imageProcessing.maxHeight,
    fit: 'inside', // 'cover', 'contain', 'fill', 'inside', 'outside'
    withoutEnlargement: true,
  },
  
  // Format conversion
  formats: {
    input: ['jpeg', 'png', 'webp', 'tiff', 'gif'],
    output: 'webp', // Default output format
    fallback: 'jpeg',
  },
  
  // Metadata handling
  metadata: {
    stripExif: true,
    preserveColorProfile: false,
    preserveOrientation: true,
  },
  
  // Watermark settings (for receipts)
  watermark: {
    enabled: process.env.ENABLE_WATERMARK === 'true',
    text: 'Hey-Bills',
    position: 'bottom-right',
    opacity: 0.3,
    fontSize: 24,
    color: '#ffffff',
  },
};

/**
 * CDN and delivery configuration
 */
const deliveryConfig = {
  // CDN settings
  cdn: {
    enabled: process.env.ENABLE_CDN === 'true',
    baseUrl: process.env.CDN_BASE_URL,
    cacheDuration: 365 * 24 * 60 * 60, // 1 year
  },
  
  // Image transformation on-the-fly
  transforms: {
    enabled: true,
    baseUrl: `${config.supabase.url}/storage/v1/render/image/public`,
    allowedTransforms: [
      'width',
      'height',
      'quality',
      'format',
      'resize',
    ],
    
    // Preset transformations
    presets: {
      'receipt-thumb': {
        width: 150,
        height: 150,
        quality: 80,
        format: 'webp',
      },
      'receipt-preview': {
        width: 600,
        height: 800,
        quality: 85,
        format: 'webp',
      },
      'profile-avatar': {
        width: 100,
        height: 100,
        quality: 85,
        format: 'webp',
      },
    },
  },
  
  // Caching headers
  caching: {
    maxAge: 31536000, // 1 year
    sMaxAge: 31536000,
    staleWhileRevalidate: 86400, // 1 day
    immutable: true,
  },
};

/**
 * Storage policies configuration
 */
const storagePolicy = {
  // RLS policies for each bucket
  policies: {
    receipts: [
      {
        name: 'Users can upload own receipts',
        action: 'INSERT',
        check: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can view own receipts',
        action: 'SELECT',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can update own receipts',
        action: 'UPDATE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can delete own receipts',
        action: 'DELETE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      }
    ],
    
    warranties: [
      {
        name: 'Users can upload own warranties',
        action: 'INSERT',
        check: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can view own warranties',
        action: 'SELECT',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can update own warranties',
        action: 'UPDATE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can delete own warranties',
        action: 'DELETE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      }
    ],
    
    profiles: [
      {
        name: 'Anyone can view profiles',
        action: 'SELECT',
        using: 'true'
      },
      {
        name: 'Users can upload own profile',
        action: 'INSERT',
        check: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can update own profile',
        action: 'UPDATE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      },
      {
        name: 'Users can delete own profile',
        action: 'DELETE',
        using: `auth.uid()::text = (storage.foldername(name))[1]`
      }
    ]
  }
};

/**
 * Helper functions for storage operations
 */
const storageHelpers = {
  /**
   * Generate file path based on bucket configuration
   */
  generateFilePath: (bucketId, userId, filename, metadata = {}) => {
    const bucket = storageBuckets[bucketId];
    if (!bucket) throw new Error(`Unknown bucket: ${bucketId}`);
    
    const now = new Date();
    const sanitizedFilename = storageHelpers.sanitizeFilename(filename);
    
    return bucket.pathStructure
      .replace('{userId}', userId)
      .replace('{year}', now.getFullYear().toString())
      .replace('{month}', (now.getMonth() + 1).toString().padStart(2, '0'))
      .replace('{warrantyId}', metadata.warrantyId || '')
      .replace('{timestamp}', now.getTime().toString())
      .replace('{filename}', sanitizedFilename);
  },
  
  /**
   * Sanitize filename for storage
   */
  sanitizeFilename: (filename) => {
    const config = uploadConfig.sanitization;
    let sanitized = filename
      .replace(/[^a-zA-Z0-9\-_\.\s]/g, '')
      .substring(0, config.maxFilenameLength);
    
    if (config.replaceSpaces) {
      sanitized = sanitized.replace(/\s+/g, config.replaceWith);
    }
    
    if (config.addTimestamp) {
      const ext = sanitized.split('.').pop();
      const nameWithoutExt = sanitized.replace(`.${ext}`, '');
      sanitized = `${nameWithoutExt}_${Date.now()}.${ext}`;
    }
    
    return sanitized;
  },
  
  /**
   * Validate file upload
   */
  validateFile: (file, bucketId) => {
    const bucket = storageBuckets[bucketId];
    if (!bucket) {
      return { valid: false, error: 'Invalid bucket' };
    }
    
    // Check file size
    if (file.size > bucket.fileSizeLimit) {
      return { 
        valid: false, 
        error: `File size exceeds limit of ${bucket.fileSizeLimit / (1024 * 1024)}MB` 
      };
    }
    
    // Check MIME type
    if (!bucket.allowedMimeTypes.includes(file.mimetype || file.type)) {
      return { 
        valid: false, 
        error: `File type ${file.mimetype || file.type} not allowed` 
      };
    }
    
    // Additional security checks
    if (uploadConfig.security.checkFileHeaders) {
      const isValidHeader = storageHelpers.validateFileHeader(file);
      if (!isValidHeader) {
        return { valid: false, error: 'Invalid file header' };
      }
    }
    
    return { valid: true };
  },
  
  /**
   * Validate file header against MIME type
   */
  validateFileHeader: (file) => {
    // This would need to be implemented with proper file header checking
    // For now, return true as placeholder
    return true;
  },
  
  /**
   * Get file URL with transformations
   */
  getFileUrl: (bucketId, filePath, transformations = {}) => {
    const bucket = storageBuckets[bucketId];
    const baseUrl = `${config.supabase.url}/storage/v1/object`;
    
    if (bucket.public) {
      return `${baseUrl}/public/${bucketId}/${filePath}`;
    } else {
      // For private files, would need signed URL
      return `${baseUrl}/${bucketId}/${filePath}`;
    }
  },
  
  /**
   * Generate thumbnail URLs
   */
  getThumbnailUrls: (bucketId, filePath) => {
    const bucket = storageBuckets[bucketId];
    if (!bucket.processing.enableThumbnails) {
      return {};
    }
    
    const thumbnails = {};
    bucket.processing.thumbnailSizes.forEach(size => {
      const transformedPath = filePath.replace(/(\.[^.]+)$/, `_${size.name}$1`);
      thumbnails[size.name] = storageHelpers.getFileUrl(bucketId, transformedPath);
    });
    
    return thumbnails;
  },
};

module.exports = {
  storageBuckets,
  uploadConfig,
  imageProcessing,
  deliveryConfig,
  storagePolicy,
  storageHelpers,
  
  // Convenience getters
  getStorageBucket: (bucketId) => storageBuckets[bucketId],
  getAllowedMimeTypes: (bucketId) => storageBuckets[bucketId]?.allowedMimeTypes || [],
  getFileSizeLimit: (bucketId) => storageBuckets[bucketId]?.fileSizeLimit || uploadConfig.maxFileSize,
};