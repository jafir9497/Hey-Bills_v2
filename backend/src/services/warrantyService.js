/**
 * Warranty Service
 * Handles warranty management business logic
 */

const { supabase } = require('../../config/supabase');
const { APIError } = require('../../utils/errorHandler');
const { logger } = require('../utils/logger');

/**
 * Get warranties for a specific user with filtering and pagination
 * @param {string} userId - User ID
 * @param {Object} filters - Filter and pagination options
 * @returns {Promise<Object>} Warranties with pagination info
 */
const getUserWarranties = async (userId, filters) => {
  try {
    const {
      page,
      limit,
      category,
      status,
      product_name,
      purchase_date_from,
      purchase_date_to,
      expiry_date_from,
      expiry_date_to,
      min_value,
      max_value,
      search,
      sort_by,
      sort_order
    } = filters;

    let query = supabase
      .from('warranties')
      .select(`
        *,
        receipts (
          id,
          merchant_name,
          total_amount,
          purchase_date,
          image_url
        )
      `, { count: 'exact' })
      .eq('user_id', userId)
      .eq('is_deleted', false);

    // Apply filters
    if (category) {
      query = query.eq('category', category);
    }

    if (status) {
      const now = new Date().toISOString().split('T')[0];
      switch (status) {
        case 'active':
          query = query.gte('warranty_end_date', now);
          break;
        case 'expired':
          query = query.lt('warranty_end_date', now);
          break;
        case 'expiring_soon':
          const futureDate = new Date();
          futureDate.setDate(futureDate.getDate() + 30);
          query = query
            .gte('warranty_end_date', now)
            .lte('warranty_end_date', futureDate.toISOString().split('T')[0]);
          break;
      }
    }

    if (product_name) {
      query = query.ilike('product_name', `%${product_name}%`);
    }

    if (purchase_date_from) {
      query = query.gte('purchase_date', purchase_date_from);
    }

    if (purchase_date_to) {
      query = query.lte('purchase_date', purchase_date_to);
    }

    if (expiry_date_from) {
      query = query.gte('warranty_end_date', expiry_date_from);
    }

    if (expiry_date_to) {
      query = query.lte('warranty_end_date', expiry_date_to);
    }

    if (min_value !== undefined) {
      query = query.gte('product_value', min_value);
    }

    if (max_value !== undefined) {
      query = query.lte('product_value', max_value);
    }

    if (search) {
      query = query.or(`product_name.ilike.%${search}%,brand.ilike.%${search}%,model.ilike.%${search}%,serial_number.ilike.%${search}%,warranty_provider.ilike.%${search}%`);
    }

    // Apply sorting
    const validSortFields = ['purchase_date', 'expiry_date', 'product_name', 'product_value', 'created_at'];
    const sortField = validSortFields.includes(sort_by) ? sort_by : 'warranty_end_date';
    const sortDirection = sort_order === 'desc' ? false : true;
    
    query = query.order(sortField, { ascending: sortDirection });

    // Apply pagination
    const offset = (page - 1) * limit;
    query = query.range(offset, offset + limit - 1);

    const { data: warranties, error, count } = await query;

    if (error) {
      logger.error('Error fetching warranties:', error);
      throw new APIError('Failed to fetch warranties', 500, 'DATABASE_ERROR');
    }

    // Calculate warranty status for each warranty
    const now = new Date();
    const enrichedWarranties = warranties.map(warranty => {
      const endDate = new Date(warranty.warranty_end_date);
      const daysUntilExpiry = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      
      let status = 'active';
      if (daysUntilExpiry < 0) {
        status = 'expired';
      } else if (daysUntilExpiry <= 30) {
        status = 'expiring_soon';
      }

      return {
        ...warranty,
        status,
        days_until_expiry: daysUntilExpiry
      };
    });

    return {
      warranties: enrichedWarranties,
      total: count
    };
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in getUserWarranties:', error);
    throw new APIError('Failed to fetch warranties', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Get warranties expiring within specified days
 * @param {string} userId - User ID
 * @param {number} days - Number of days to look ahead
 * @returns {Promise<Array>} Array of expiring warranties
 */
const getExpiringWarranties = async (userId, days = 30) => {
  try {
    const now = new Date().toISOString().split('T')[0];
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);
    const futureDateStr = futureDate.toISOString().split('T')[0];

    const { data: warranties, error } = await supabase
      .from('warranties')
      .select(`
        *,
        receipts (
          id,
          merchant_name,
          total_amount,
          purchase_date,
          image_url
        )
      `)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .gte('warranty_end_date', now)
      .lte('warranty_end_date', futureDateStr)
      .order('warranty_end_date', { ascending: true });

    if (error) {
      logger.error('Error fetching expiring warranties:', error);
      throw new APIError('Failed to fetch expiring warranties', 500, 'DATABASE_ERROR');
    }

    // Calculate exact days until expiry
    const nowDate = new Date();
    return warranties.map(warranty => {
      const endDate = new Date(warranty.warranty_end_date);
      const daysUntilExpiry = Math.ceil((endDate - nowDate) / (1000 * 60 * 60 * 24));
      
      return {
        ...warranty,
        days_until_expiry: daysUntilExpiry
      };
    });
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in getExpiringWarranties:', error);
    throw new APIError('Failed to fetch expiring warranties', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Get warranty analytics
 * @param {string} userId - User ID
 * @param {Object} options - Analytics options
 * @returns {Promise<Object>} Analytics data
 */
const getWarrantyAnalytics = async (userId, options) => {
  try {
    const { period, date_from, date_to, group_by } = options;

    let dateFilter = '';
    if (period === 'custom' && date_from && date_to) {
      dateFilter = `AND purchase_date BETWEEN '${date_from}' AND '${date_to}'`;
    } else {
      const now = new Date();
      let startDate;
      
      switch (period) {
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        case 'quarter':
          startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
          break;
        case 'year':
          startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
          break;
        default:
          startDate = new Date(0); // All time
      }
      
      dateFilter = startDate.getTime() > 0 ? `AND purchase_date >= '${startDate.toISOString().split('T')[0]}'` : '';
    }

    // Get overall statistics
    const { data: stats, error: statsError } = await supabase
      .rpc('get_warranty_stats', { 
        p_user_id: userId,
        p_date_filter: dateFilter
      });

    if (statsError) {
      logger.error('Error fetching warranty stats:', statsError);
      throw new APIError('Failed to fetch warranty statistics', 500, 'DATABASE_ERROR');
    }

    // Get grouped data based on group_by parameter
    let groupedData = [];
    if (group_by) {
      const groupQuery = buildGroupByQuery(userId, group_by, dateFilter);
      const { data: grouped, error: groupError } = await supabase.rpc('execute_dynamic_query', {
        query: groupQuery
      });

      if (groupError) {
        logger.warn('Error fetching grouped warranty data:', groupError);
      } else {
        groupedData = grouped;
      }
    }

    return {
      overview: stats[0] || {
        total_warranties: 0,
        active_warranties: 0,
        expired_warranties: 0,
        expiring_soon: 0,
        total_value: 0,
        average_value: 0
      },
      grouped_data: groupedData,
      period: period || 'all_time',
      date_range: {
        from: date_from,
        to: date_to
      }
    };
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in getWarrantyAnalytics:', error);
    throw new APIError('Failed to fetch warranty analytics', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Build SQL query for group by operations
 * @param {string} userId - User ID
 * @param {string} groupBy - Field to group by
 * @param {string} dateFilter - Date filter SQL
 * @returns {string} SQL query
 */
const buildGroupByQuery = (userId, groupBy, dateFilter) => {
  const validGroupFields = {
    category: 'category',
    status: `CASE 
      WHEN warranty_end_date < CURRENT_DATE THEN 'expired'
      WHEN warranty_end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_soon'
      ELSE 'active'
    END`,
    month: "TO_CHAR(purchase_date, 'YYYY-MM')"
  };

  const groupField = validGroupFields[groupBy] || 'category';
  
  return `
    SELECT 
      ${groupField} as group_key,
      COUNT(*) as count,
      SUM(product_value) as total_value,
      AVG(product_value) as average_value
    FROM warranties 
    WHERE user_id = '${userId}' 
      AND is_deleted = false 
      ${dateFilter}
    GROUP BY ${groupField}
    ORDER BY count DESC
  `;
};

/**
 * Get warranty by ID
 * @param {string} warrantyId - Warranty ID
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Warranty data
 */
const getWarrantyById = async (warrantyId, userId) => {
  try {
    const { data: warranty, error } = await supabase
      .from('warranties')
      .select(`
        *,
        receipts (
          id,
          merchant_name,
          total_amount,
          purchase_date,
          image_url,
          merchant_address
        ),
        warranty_claims (
          id,
          claim_reason,
          claim_description,
          claim_date,
          claim_status,
          resolution_date,
          resolution_notes
        )
      `)
      .eq('id', warrantyId)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null; // Not found
      }
      logger.error('Error fetching warranty by ID:', error);
      throw new APIError('Failed to fetch warranty', 500, 'DATABASE_ERROR');
    }

    // Calculate warranty status
    const now = new Date();
    const endDate = new Date(warranty.warranty_end_date);
    const daysUntilExpiry = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
    
    let status = 'active';
    if (daysUntilExpiry < 0) {
      status = 'expired';
    } else if (daysUntilExpiry <= 30) {
      status = 'expiring_soon';
    }

    return {
      ...warranty,
      status,
      days_until_expiry: daysUntilExpiry
    };
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in getWarrantyById:', error);
    throw new APIError('Failed to fetch warranty', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Create new warranty
 * @param {Object} warrantyData - Warranty data
 * @returns {Promise<Object>} Created warranty
 */
const createWarranty = async (warrantyData) => {
  try {
    // Validate warranty dates
    const startDate = new Date(warrantyData.warranty_start_date);
    const endDate = new Date(warrantyData.warranty_end_date);
    
    if (endDate <= startDate) {
      throw new APIError('Warranty end date must be after start date', 400, 'INVALID_DATE_RANGE');
    }

    // Calculate warranty duration in months if not provided
    if (!warrantyData.warranty_duration_months) {
      const monthsDiff = (endDate.getFullYear() - startDate.getFullYear()) * 12 + 
                        (endDate.getMonth() - startDate.getMonth());
      warrantyData.warranty_duration_months = monthsDiff;
    }

    const { data: warranty, error } = await supabase
      .from('warranties')
      .insert({
        ...warrantyData,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) {
      logger.error('Error creating warranty:', error);
      throw new APIError('Failed to create warranty', 500, 'DATABASE_ERROR');
    }

    logger.info(`Warranty created: ${warranty.id} for user: ${warrantyData.user_id}`);
    return warranty;
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in createWarranty:', error);
    throw new APIError('Failed to create warranty', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Update warranty
 * @param {string} warrantyId - Warranty ID
 * @param {string} userId - User ID
 * @param {Object} updateData - Update data
 * @returns {Promise<Object>} Updated warranty
 */
const updateWarranty = async (warrantyId, userId, updateData) => {
  try {
    // Remove fields that shouldn't be updated directly
    const { id, user_id, created_at, ...validUpdateData } = updateData;

    // Validate warranty dates if being updated
    if (validUpdateData.warranty_start_date && validUpdateData.warranty_end_date) {
      const startDate = new Date(validUpdateData.warranty_start_date);
      const endDate = new Date(validUpdateData.warranty_end_date);
      
      if (endDate <= startDate) {
        throw new APIError('Warranty end date must be after start date', 400, 'INVALID_DATE_RANGE');
      }
    }

    const { data: warranty, error } = await supabase
      .from('warranties')
      .update({
        ...validUpdateData,
        updated_at: new Date().toISOString()
      })
      .eq('id', warrantyId)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null; // Not found
      }
      logger.error('Error updating warranty:', error);
      throw new APIError('Failed to update warranty', 500, 'DATABASE_ERROR');
    }

    logger.info(`Warranty updated: ${warrantyId} for user: ${userId}`);
    return warranty;
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in updateWarranty:', error);
    throw new APIError('Failed to update warranty', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Update warranty reminder settings
 * @param {string} warrantyId - Warranty ID
 * @param {string} userId - User ID
 * @param {Object} reminderSettings - Reminder settings
 * @returns {Promise<Object>} Updated warranty
 */
const updateWarrantyReminder = async (warrantyId, userId, reminderSettings) => {
  try {
    const { data: warranty, error } = await supabase
      .from('warranties')
      .update({
        reminder_settings: reminderSettings,
        updated_at: new Date().toISOString()
      })
      .eq('id', warrantyId)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null; // Not found
      }
      logger.error('Error updating warranty reminder:', error);
      throw new APIError('Failed to update warranty reminder', 500, 'DATABASE_ERROR');
    }

    return warranty;
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in updateWarrantyReminder:', error);
    throw new APIError('Failed to update warranty reminder', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Create warranty claim
 * @param {Object} claimData - Claim data
 * @returns {Promise<Object>} Created claim
 */
const createWarrantyClaim = async (claimData) => {
  try {
    const { data: claim, error } = await supabase
      .from('warranty_claims')
      .insert({
        ...claimData,
        claim_status: 'submitted',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) {
      logger.error('Error creating warranty claim:', error);
      throw new APIError('Failed to create warranty claim', 500, 'DATABASE_ERROR');
    }

    logger.info(`Warranty claim created: ${claim.id} for warranty: ${claimData.warranty_id}`);
    return claim;
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in createWarrantyClaim:', error);
    throw new APIError('Failed to create warranty claim', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Delete warranty
 * @param {string} warrantyId - Warranty ID
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} Success status
 */
const deleteWarranty = async (warrantyId, userId) => {
  try {
    const { data: warranty, error } = await supabase
      .from('warranties')
      .update({
        is_deleted: true,
        deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', warrantyId)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .select('id')
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return false; // Not found
      }
      logger.error('Error deleting warranty:', error);
      throw new APIError('Failed to delete warranty', 500, 'DATABASE_ERROR');
    }

    logger.info(`Warranty deleted: ${warrantyId} for user: ${userId}`);
    return true;
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in deleteWarranty:', error);
    throw new APIError('Failed to delete warranty', 500, 'INTERNAL_ERROR');
  }
};

/**
 * Bulk delete warranties
 * @param {Array} warrantyIds - Array of warranty IDs
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Delete result
 */
const bulkDeleteWarranties = async (warrantyIds, userId) => {
  try {
    const { data: warranties, error } = await supabase
      .from('warranties')
      .update({
        is_deleted: true,
        deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .in('id', warrantyIds)
      .eq('user_id', userId)
      .eq('is_deleted', false)
      .select('id');

    if (error) {
      logger.error('Error bulk deleting warranties:', error);
      throw new APIError('Failed to delete warranties', 500, 'DATABASE_ERROR');
    }

    const deletedCount = warranties.length;
    logger.info(`Bulk deleted ${deletedCount} warranties for user: ${userId}`);
    
    return { deletedCount };
  } catch (error) {
    if (error instanceof APIError) {
      throw error;
    }
    logger.error('Error in bulkDeleteWarranties:', error);
    throw new APIError('Failed to delete warranties', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getUserWarranties,
  getExpiringWarranties,
  getWarrantyAnalytics,
  getWarrantyById,
  createWarranty,
  updateWarranty,
  updateWarrantyReminder,
  createWarrantyClaim,
  deleteWarranty,
  bulkDeleteWarranties
};