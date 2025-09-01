import 'package:json_annotation/json_annotation.dart';

part 'chat_models.g.dart';

/// Chat message model for Hey-Bills assistant
@JsonSerializable()
class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  bool get isFromUser => role == 'user';
  bool get isFromAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Chat conversation model
@JsonSerializable()
class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ChatConversationToJson(this);

  ChatConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? messageCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Chat response from API
@JsonSerializable()
class ChatResponse {
  final String message;
  final String conversationId;
  final ChatResponseMetadata metadata;
  final DateTime timestamp;

  const ChatResponse({
    required this.message,
    required this.conversationId,
    required this.metadata,
    required this.timestamp,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);
}

/// Metadata from chat response
@JsonSerializable()
class ChatResponseMetadata {
  final int contextUsed;
  final String searchStrategy;
  final int processingTimeMs;
  final double confidence;
  final List<String> sources;

  const ChatResponseMetadata({
    required this.contextUsed,
    required this.searchStrategy,
    required this.processingTimeMs,
    required this.confidence,
    required this.sources,
  });

  factory ChatResponseMetadata.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$ChatResponseMetadataToJson(this);
}

/// Chat statistics model
@JsonSerializable()
class ChatStats {
  final int totalConversations;
  final int totalMessages;
  final int recentMessages7d;
  final int averageMessagesPerConversation;

  const ChatStats({
    required this.totalConversations,
    required this.totalMessages,
    required this.recentMessages7d,
    required this.averageMessagesPerConversation,
  });

  factory ChatStats.fromJson(Map<String, dynamic> json) =>
      _$ChatStatsFromJson(json);

  Map<String, dynamic> toJson() => _$ChatStatsToJson(this);
}

/// Chat request model
@JsonSerializable()
class ChatRequest {
  final String message;
  final String? conversationId;

  const ChatRequest({
    required this.message,
    this.conversationId,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}

/// Conversation list response
@JsonSerializable()
class ConversationListResponse {
  final List<ChatConversation> conversations;
  final PaginationInfo pagination;

  const ConversationListResponse({
    required this.conversations,
    required this.pagination,
  });

  factory ConversationListResponse.fromJson(Map<String, dynamic> json) =>
      _$ConversationListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationListResponseToJson(this);
}

/// Pagination information
@JsonSerializable()
class PaginationInfo {
  final int limit;
  final int offset;
  final bool hasMore;

  const PaginationInfo({
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) =>
      _$PaginationInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationInfoToJson(this);
}

/// Conversation history response
@JsonSerializable()
class ConversationHistoryResponse {
  final String conversationId;
  final List<ChatMessage> messages;
  final int count;

  const ConversationHistoryResponse({
    required this.conversationId,
    required this.messages,
    required this.count,
  });

  factory ConversationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$ConversationHistoryResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationHistoryResponseToJson(this);
}