import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../core/config/app_config.dart';
import '../core/services/api_service.dart';
import '../core/utils/logger.dart';

/// Chat service for Hey-Bills RAG assistant
class ChatService {
  final ApiService _apiService;
  static const String _baseEndpoint = '/chat';

  ChatService({ApiService? apiService}) 
    : _apiService = apiService ?? ApiService();

  /// Send a message and get AI response
  Future<ChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    try {
      Logger.info('Sending chat message: ${message.length} characters');

      final request = ChatRequest(
        message: message,
        conversationId: conversationId,
      );

      final response = await _apiService.post(
        '$_baseEndpoint/message',
        body: request.toJson(),
      );

      Logger.info('Chat response received: ${response.statusCode}');
      return ChatResponse.fromJson(response.data);
    } catch (e) {
      Logger.error('Failed to send message', e);
      rethrow;
    }
  }

  /// Get conversation history
  Future<ConversationHistoryResponse> getConversation({
    required String conversationId,
    int limit = 50,
  }) async {
    try {
      Logger.info('Fetching conversation: $conversationId');

      final response = await _apiService.get(
        '$_baseEndpoint/conversations/$conversationId',
        queryParameters: {
          'limit': limit.toString(),
        },
      );

      return ConversationHistoryResponse.fromJson(response.data);
    } catch (e) {
      Logger.error('Failed to get conversation', e);
      rethrow;
    }
  }

  /// List user conversations
  Future<ConversationListResponse> listConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Logger.info('Fetching conversations: limit=$limit, offset=$offset');

      final response = await _apiService.get(
        '$_baseEndpoint/conversations',
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      return ConversationListResponse.fromJson(response.data);
    } catch (e) {
      Logger.error('Failed to list conversations', e);
      rethrow;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      Logger.info('Deleting conversation: $conversationId');

      await _apiService.delete('$_baseEndpoint/conversations/$conversationId');
      Logger.info('Conversation deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete conversation', e);
      rethrow;
    }
  }

  /// Update conversation title
  Future<ChatConversation> updateConversationTitle({
    required String conversationId,
    required String title,
  }) async {
    try {
      Logger.info('Updating conversation title: $conversationId');

      final response = await _apiService.put(
        '$_baseEndpoint/conversations/$conversationId/title',
        body: {'title': title},
      );

      return ChatConversation.fromJson(response.data['conversation']);
    } catch (e) {
      Logger.error('Failed to update conversation title', e);
      rethrow;
    }
  }

  /// Get chat statistics
  Future<ChatStats> getChatStats() async {
    try {
      Logger.info('Fetching chat statistics');

      final response = await _apiService.get('$_baseEndpoint/stats');
      return ChatStats.fromJson(response.data);
    } catch (e) {
      Logger.error('Failed to get chat stats', e);
      rethrow;
    }
  }

  /// Stream for real-time chat updates (placeholder for future implementation)
  Stream<ChatMessage> getChatStream(String conversationId) async* {
    // TODO: Implement WebSocket or Server-Sent Events for real-time updates
    // For now, this is a placeholder that can be implemented later
    Logger.info('Chat streaming not yet implemented for: $conversationId');
  }

  /// Validate message before sending
  bool isValidMessage(String message) {
    if (message.trim().isEmpty) return false;
    if (message.length > 2000) return false; // Reasonable limit
    return true;
  }

  /// Get suggested questions based on user data
  Future<List<String>> getSuggestedQuestions() async {
    try {
      // For now, return static suggestions
      // TODO: Make this dynamic based on user's receipt data
      return [
        "When did I pay my 3rd term school fees?",
        "What's my total spending this month?",
        "Show me all receipts from grocery stores",
        "Which warranties are expiring soon?",
        "What's my average monthly spending?",
        "Find receipts over \$100 from last month",
        "Show me all electronics purchases",
        "What did I buy at Target last week?",
      ];
    } catch (e) {
      Logger.error('Failed to get suggested questions', e);
      return [];
    }
  }

  /// Clear conversation cache (for memory management)
  void clearCache() {
    Logger.info('Clearing chat service cache');
    // TODO: Implement caching and cache clearing
  }
}

/// Chat service exception
class ChatServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ChatServiceException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    return 'ChatServiceException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}