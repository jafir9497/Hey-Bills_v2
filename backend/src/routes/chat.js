const express = require('express');
const chatController = require('../controllers/chatController');
const supabaseAuth = require('../middleware/supabaseAuth');

const router = express.Router();

/**
 * Chat Routes for Hey-Bills RAG Assistant
 * All routes require authentication
 */

// Apply authentication middleware to all chat routes
router.use(supabaseAuth);

/**
 * @route   POST /api/chat/message
 * @desc    Send a message and get AI response
 * @access  Private
 * @body    { message: string, conversation_id?: string }
 */
router.post('/message', chatController.sendMessage);

/**
 * @route   GET /api/chat/conversations
 * @desc    List user conversations
 * @access  Private
 * @query   { limit?: number, offset?: number }
 */
router.get('/conversations', chatController.listConversations);

/**
 * @route   GET /api/chat/conversations/:conversation_id
 * @desc    Get conversation history
 * @access  Private
 * @query   { limit?: number }
 */
router.get('/conversations/:conversation_id', chatController.getConversation);

/**
 * @route   PUT /api/chat/conversations/:conversation_id/title
 * @desc    Update conversation title
 * @access  Private
 * @body    { title: string }
 */
router.put('/conversations/:conversation_id/title', chatController.updateConversationTitle);

/**
 * @route   DELETE /api/chat/conversations/:conversation_id
 * @desc    Delete a conversation
 * @access  Private
 */
router.delete('/conversations/:conversation_id', chatController.deleteConversation);

/**
 * @route   GET /api/chat/stats
 * @desc    Get user chat statistics
 * @access  Private
 */
router.get('/stats', chatController.getChatStats);

module.exports = router;