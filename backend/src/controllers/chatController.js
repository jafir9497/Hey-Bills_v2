const ragService = require('../services/ragService');
const { supabase } = require('../../config/supabase');
const { v4: uuidv4 } = require('uuid');

/**
 * Chat Controller for Hey-Bills RAG Assistant
 * Handles chat endpoints and conversation management
 */
class ChatController {
  /**
   * Send a message and get AI response
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async sendMessage(req, res) {
    try {
      const { message, conversation_id } = req.body;
      const userId = req.user?.id;

      // Validate input
      if (!message?.trim()) {
        return res.status(400).json({
          error: 'Message is required',
          code: 'INVALID_MESSAGE'
        });
      }

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      // Generate conversation ID if not provided
      const conversationId = conversation_id || uuidv4();

      // Get conversation history
      const conversationHistory = conversation_id 
        ? await ragService.getConversationHistory(conversation_id, 10)
        : [];

      // Process query with RAG
      const result = await ragService.processQuery(
        userId,
        message.trim(),
        conversationId,
        conversationHistory
      );

      res.json({
        message: result.answer,
        conversation_id: conversationId,
        metadata: {
          context_used: result.context_used,
          search_strategy: result.search_strategy,
          processing_time_ms: result.processing_time_ms,
          confidence: result.confidence,
          sources: result.sources
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Send message error:', error);
      res.status(500).json({
        error: 'Failed to process message',
        code: 'PROCESSING_ERROR',
        message: 'An error occurred while processing your message. Please try again.'
      });
    }
  }

  /**
   * Get conversation history
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getConversation(req, res) {
    try {
      const { conversation_id } = req.params;
      const userId = req.user?.id;
      const limit = parseInt(req.query.limit) || 50;

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      if (!conversation_id) {
        return res.status(400).json({
          error: 'Conversation ID is required',
          code: 'INVALID_CONVERSATION_ID'
        });
      }

      // Get messages from database
      const { data: messages, error } = await supabase
        .from('chat_messages')
        .select('id, role, content, timestamp, metadata')
        .eq('conversation_id', conversation_id)
        .eq('user_id', userId)
        .order('timestamp', { ascending: true })
        .limit(limit);

      if (error) {
        console.error('Get conversation error:', error);
        return res.status(500).json({
          error: 'Failed to retrieve conversation',
          code: 'DATABASE_ERROR'
        });
      }

      res.json({
        conversation_id,
        messages: messages || [],
        count: (messages || []).length
      });

    } catch (error) {
      console.error('Get conversation error:', error);
      res.status(500).json({
        error: 'Failed to retrieve conversation',
        code: 'PROCESSING_ERROR'
      });
    }
  }

  /**
   * List user conversations
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async listConversations(req, res) {
    try {
      const userId = req.user?.id;
      const limit = parseInt(req.query.limit) || 20;
      const offset = parseInt(req.query.offset) || 0;

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      // Get conversations from database
      const { data: conversations, error } = await supabase
        .from('chat_conversations')
        .select(`
          id,
          title,
          created_at,
          last_message_at,
          updated_at
        `)
        .eq('user_id', userId)
        .order('last_message_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        console.error('List conversations error:', error);
        return res.status(500).json({
          error: 'Failed to retrieve conversations',
          code: 'DATABASE_ERROR'
        });
      }

      // Get message counts for each conversation
      const conversationsWithCounts = await Promise.all(
        (conversations || []).map(async (conv) => {
          const { count } = await supabase
            .from('chat_messages')
            .select('*', { count: 'exact', head: true })
            .eq('conversation_id', conv.id);

          return {
            ...conv,
            message_count: count || 0
          };
        })
      );

      res.json({
        conversations: conversationsWithCounts,
        pagination: {
          limit,
          offset,
          has_more: conversationsWithCounts.length === limit
        }
      });

    } catch (error) {
      console.error('List conversations error:', error);
      res.status(500).json({
        error: 'Failed to retrieve conversations',
        code: 'PROCESSING_ERROR'
      });
    }
  }

  /**
   * Delete a conversation
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async deleteConversation(req, res) {
    try {
      const { conversation_id } = req.params;
      const userId = req.user?.id;

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      if (!conversation_id) {
        return res.status(400).json({
          error: 'Conversation ID is required',
          code: 'INVALID_CONVERSATION_ID'
        });
      }

      // Delete messages first (due to foreign key constraint)
      const { error: messagesError } = await supabase
        .from('chat_messages')
        .delete()
        .eq('conversation_id', conversation_id)
        .eq('user_id', userId);

      if (messagesError) {
        console.error('Delete messages error:', messagesError);
        return res.status(500).json({
          error: 'Failed to delete conversation messages',
          code: 'DATABASE_ERROR'
        });
      }

      // Delete conversation
      const { error: conversationError } = await supabase
        .from('chat_conversations')
        .delete()
        .eq('id', conversation_id)
        .eq('user_id', userId);

      if (conversationError) {
        console.error('Delete conversation error:', conversationError);
        return res.status(500).json({
          error: 'Failed to delete conversation',
          code: 'DATABASE_ERROR'
        });
      }

      res.json({
        message: 'Conversation deleted successfully',
        conversation_id
      });

    } catch (error) {
      console.error('Delete conversation error:', error);
      res.status(500).json({
        error: 'Failed to delete conversation',
        code: 'PROCESSING_ERROR'
      });
    }
  }

  /**
   * Update conversation title
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async updateConversationTitle(req, res) {
    try {
      const { conversation_id } = req.params;
      const { title } = req.body;
      const userId = req.user?.id;

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      if (!conversation_id) {
        return res.status(400).json({
          error: 'Conversation ID is required',
          code: 'INVALID_CONVERSATION_ID'
        });
      }

      if (!title?.trim()) {
        return res.status(400).json({
          error: 'Title is required',
          code: 'INVALID_TITLE'
        });
      }

      // Update conversation title
      const { data, error } = await supabase
        .from('chat_conversations')
        .update({ 
          title: title.trim(),
          updated_at: new Date().toISOString()
        })
        .eq('id', conversation_id)
        .eq('user_id', userId)
        .select();

      if (error) {
        console.error('Update conversation title error:', error);
        return res.status(500).json({
          error: 'Failed to update conversation title',
          code: 'DATABASE_ERROR'
        });
      }

      if (!data || data.length === 0) {
        return res.status(404).json({
          error: 'Conversation not found',
          code: 'CONVERSATION_NOT_FOUND'
        });
      }

      res.json({
        message: 'Conversation title updated successfully',
        conversation: data[0]
      });

    } catch (error) {
      console.error('Update conversation title error:', error);
      res.status(500).json({
        error: 'Failed to update conversation title',
        code: 'PROCESSING_ERROR'
      });
    }
  }

  /**
   * Get chat statistics for user
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getChatStats(req, res) {
    try {
      const userId = req.user?.id;

      if (!userId) {
        return res.status(401).json({
          error: 'User authentication required',
          code: 'UNAUTHORIZED'
        });
      }

      // Get conversation count
      const { count: conversationCount } = await supabase
        .from('chat_conversations')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId);

      // Get message count
      const { count: messageCount } = await supabase
        .from('chat_messages')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId);

      // Get recent activity (last 7 days)
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);

      const { count: recentMessages } = await supabase
        .from('chat_messages')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId)
        .gte('timestamp', weekAgo.toISOString());

      res.json({
        total_conversations: conversationCount || 0,
        total_messages: messageCount || 0,
        recent_messages_7d: recentMessages || 0,
        average_messages_per_conversation: conversationCount > 0 
          ? Math.round((messageCount || 0) / conversationCount) 
          : 0
      });

    } catch (error) {
      console.error('Get chat stats error:', error);
      res.status(500).json({
        error: 'Failed to retrieve chat statistics',
        code: 'PROCESSING_ERROR'
      });
    }
  }
}

module.exports = new ChatController();