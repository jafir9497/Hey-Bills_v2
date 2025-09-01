import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../core/utils/logger.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/suggested_questions.dart';
import 'widgets/typing_indicator.dart';

/// Chat screen for Hey-Bills AI assistant
class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? initialMessage;

  const ChatScreen({
    Key? key,
    this.conversationId,
    this.initialMessage,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  List<ChatMessage> _messages = [];
  String? _currentConversationId;
  bool _isLoading = false;
  bool _isTyping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;
    
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage();
      });
    } else if (_currentConversationId != null) {
      _loadConversationHistory();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Load conversation history
  Future<void> _loadConversationHistory() async {
    if (_currentConversationId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _chatService.getConversation(
        conversationId: _currentConversationId!,
      );

      setState(() {
        _messages = response.messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      Logger.error('Failed to load conversation history', e);
      setState(() {
        _error = 'Failed to load conversation history';
        _isLoading = false;
      });
    }
  }

  /// Send a message
  Future<void> _sendMessage([String? customMessage]) async {
    final message = customMessage ?? _messageController.text.trim();
    
    if (!_chatService.isValidMessage(message)) {
      _showSnackBar('Please enter a valid message');
      return;
    }

    // Add user message to UI immediately
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: _currentConversationId ?? '',
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
      _error = null;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(
        message: message,
        conversationId: _currentConversationId,
      );

      // Update conversation ID if this is a new conversation
      if (_currentConversationId == null) {
        _currentConversationId = response.conversationId;
      }

      // Add assistant response
      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: response.conversationId,
        role: 'assistant',
        content: response.message,
        timestamp: response.timestamp,
        metadata: response.metadata.toJson(),
      );

      setState(() {
        _messages.add(assistantMessage);
        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      Logger.error('Failed to send message', e);
      setState(() {
        _error = 'Failed to send message. Please try again.';
        _isTyping = false;
        // Remove the user message that failed to send
        _messages.removeLast();
      });
      
      // Put the message back in the input field
      _messageController.text = message;
    }
  }

  /// Scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handle suggested question tap
  void _onSuggestedQuestionTap(String question) {
    _messageController.text = question;
    _sendMessage();
  }

  /// Retry last failed message
  void _retryLastMessage() {
    if (_messages.isNotEmpty && _messages.last.isFromUser) {
      final lastMessage = _messages.last.content;
      setState(() {
        _messages.removeLast();
        _error = null;
      });
      _sendMessage(lastMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hey Bills Assistant'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentConversationId != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showConversationInfo,
            ),
        ],
      ),
      body: Column(
        children: [
          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _retryLastMessage,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isTyping) {
                            return const TypingIndicator();
                          }
                          
                          final message = _messages[index];
                          return MessageBubble(
                            message: message,
                            isFirstInGroup: _isFirstInGroup(index),
                            isLastInGroup: _isLastInGroup(index),
                          );
                        },
                      ),
          ),

          // Message input
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            enabled: !_isTyping,
          ),
        ],
      ),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Hi! I\'m your Hey Bills assistant',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me about your receipts, warranties, and spending patterns',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SuggestedQuestions(
            onQuestionTap: _onSuggestedQuestionTap,
          ),
        ],
      ),
    );
  }

  /// Check if message is first in group (for styling)
  bool _isFirstInGroup(int index) {
    if (index == 0) return true;
    
    final current = _messages[index];
    final previous = _messages[index - 1];
    
    return current.role != previous.role;
  }

  /// Check if message is last in group (for styling)
  bool _isLastInGroup(int index) {
    if (index == _messages.length - 1) return true;
    
    final current = _messages[index];
    final next = _messages[index + 1];
    
    return current.role != next.role;
  }

  /// Show conversation info dialog
  void _showConversationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversation Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messages: ${_messages.length}'),
            if (_currentConversationId != null)
              Text('ID: ${_currentConversationId!.substring(0, 8)}...'),
            const SizedBox(height: 16),
            const Text(
              'This conversation uses RAG (Retrieval-Augmented Generation) '
              'to provide accurate answers about your receipts and spending data.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}