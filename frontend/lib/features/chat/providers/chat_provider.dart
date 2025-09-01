import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import '../../../core/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../models/chat_models.dart';
import '../../../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final chatProvider = StateNotifierProvider.family<ChatNotifier, AsyncValue<ChatConversation?>, String?>((ref, conversationId) {
  final service = ref.watch(chatServiceProvider);
  final authState = ref.watch(authProvider);
  return ChatNotifier(service, authState, conversationId);
});

final activeChatProvider = StateNotifierProvider<ActiveChatNotifier, String?>((ref) {
  return ActiveChatNotifier();
});

final chatHistoryProvider = StateNotifierProvider<ChatHistoryNotifier, AsyncValue<List<ChatConversation>>>((ref) {
  final service = ref.watch(chatServiceProvider);
  final authState = ref.watch(authProvider);
  return ChatHistoryNotifier(service, authState);
});

final realTimeChatProvider = StateNotifierProvider<RealTimeChatNotifier, Map<String, dynamic>>((ref) {
  final authState = ref.watch(authProvider);
  return RealTimeChatNotifier(authState);
});

class ChatNotifier extends StateNotifier<AsyncValue<ChatConversation?>> {
  final ChatService _service;
  final dynamic _authState;
  final String? _conversationId;
  final Logger _logger = Logger();

  ChatNotifier(this._service, this._authState, this._conversationId) 
      : super(const AsyncValue.loading()) {
    if (_conversationId != null) {
      loadConversation();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> loadConversation() async {
    if (_conversationId == null) return;
    
    try {
      state = const AsyncValue.loading();
      
      final conversation = await _service.getConversation(
        conversationId: _conversationId!,
      );
      
      state = AsyncValue.data(conversation);
    } catch (error, stack) {
      _logger.e('Error loading conversation: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<ChatMessage> sendMessage({
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _service.sendMessage(
        message: message,
        conversationId: _conversationId,
        metadata: metadata,
      );

      // Update local state with new message
      state.whenData((conversation) {
        if (conversation != null) {
          final userMessage = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            conversationId: response.conversationId,
            role: 'user',
            content: message,
            timestamp: DateTime.now(),
            metadata: metadata,
          );

          final assistantMessage = ChatMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            conversationId: response.conversationId,
            role: 'assistant',
            content: response.message,
            timestamp: response.timestamp,
            metadata: response.metadata.toJson(),
          );

          final updatedMessages = [
            ...conversation.messages,
            userMessage,
            assistantMessage,
          ];

          state = AsyncValue.data(conversation.copyWith(messages: updatedMessages));
        }
      });

      return ChatMessage(
        id: response.conversationId,
        conversationId: response.conversationId,
        role: 'assistant',
        content: response.message,
        timestamp: response.timestamp,
        metadata: response.metadata.toJson(),
      );
    } catch (error) {
      _logger.e('Error sending message: $error');
      rethrow;
    }
  }

  Future<void> regenerateResponse(String messageId) async {
    try {
      final response = await _service.regenerateResponse(messageId);
      
      state.whenData((conversation) {
        if (conversation != null) {
          final messages = conversation.messages.map((msg) {
            if (msg.id == messageId) {
              return msg.copyWith(
                content: response.message,
                timestamp: response.timestamp,
              );
            }
            return msg;
          }).toList();

          state = AsyncValue.data(conversation.copyWith(messages: messages));
        }
      });
    } catch (error) {
      _logger.e('Error regenerating response: $error');
      rethrow;
    }
  }

  Future<void> clearConversation() async {
    if (_conversationId == null) return;
    
    try {
      await _service.clearConversation(_conversationId!);
      state = const AsyncValue.data(null);
    } catch (error) {
      _logger.e('Error clearing conversation: $error');
      rethrow;
    }
  }
}

class ActiveChatNotifier extends StateNotifier<String?> {
  ActiveChatNotifier() : super(null);

  void setActiveChat(String? conversationId) {
    state = conversationId;
  }
}

class ChatHistoryNotifier extends StateNotifier<AsyncValue<List<ChatConversation>>> {
  final ChatService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  ChatHistoryNotifier(this._service, this._authState) : super(const AsyncValue.loading()) {
    if (_authState?.user?.id != null) {
      loadChatHistory();
    }
  }

  Future<void> loadChatHistory() async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final conversations = await _service.getChatHistory(
        userId: _authState.user.id,
      );
      
      state = AsyncValue.data(conversations);
    } catch (error, stack) {
      _logger.e('Error loading chat history: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _service.deleteConversation(conversationId);
      
      // Remove from local state
      state.whenData((conversations) {
        final filtered = conversations.where((c) => c.id != conversationId).toList();
        state = AsyncValue.data(filtered);
      });
    } catch (error) {
      _logger.e('Error deleting conversation: $error');
      rethrow;
    }
  }
}

class RealTimeChatNotifier extends StateNotifier<Map<String, dynamic>> {
  final dynamic _authState;
  final Logger _logger = Logger();
  WebSocketChannel? _channel;

  RealTimeChatNotifier(this._authState) : super({
    'isConnected': false,
    'isTyping': false,
    'presenceUsers': <String>[],
    'notifications': <Map<String, dynamic>>[],
  });

  void connect(String conversationId) {
    if (_authState?.user?.id == null) return;
    
    try {
      final wsUrl = AppConfig.wsBaseUrl;
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/chat/$conversationId?userId=${_authState.user.id}'),
      );

      _channel!.stream.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) => _handleWebSocketError(error),
        onDone: () => _handleWebSocketClosed(),
      );

      state = {...state, 'isConnected': true};
    } catch (error) {
      _logger.e('Error connecting to WebSocket: $error');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    state = {...state, 'isConnected': false, 'isTyping': false};
  }

  void sendTypingIndicator(bool isTyping) {
    if (_channel != null) {
      _channel!.sink.add(json.encode({
        'type': 'typing',
        'isTyping': isTyping,
        'userId': _authState?.user?.id,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final message = json.decode(data);
      
      switch (message['type']) {
        case 'typing':
          state = {...state, 'isTyping': message['isTyping']};
          break;
        
        case 'presence':
          state = {...state, 'presenceUsers': message['users'] ?? []};
          break;
        
        case 'notification':
          final notifications = List<Map<String, dynamic>>.from(state['notifications']);
          notifications.add(message);
          state = {...state, 'notifications': notifications};
          break;
        
        case 'message':
          // Handle real-time message updates
          _logger.i('Real-time message received: ${message['content']}');
          break;
      }
    } catch (error) {
      _logger.e('Error parsing WebSocket message: $error');
    }
  }

  void _handleWebSocketError(error) {
    _logger.e('WebSocket error: $error');
    state = {...state, 'isConnected': false};
  }

  void _handleWebSocketClosed() {
    _logger.i('WebSocket connection closed');
    state = {...state, 'isConnected': false, 'isTyping': false};
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}