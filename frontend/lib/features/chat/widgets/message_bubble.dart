import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/chat_models.dart';
import '../../../core/theme/app_theme.dart';

/// Message bubble widget for chat messages
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    Key? key,
    required this.message,
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 4,
        top: isFirstInGroup ? 8 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, isUser),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Column(
                crossAxisAlignment: isUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // Message bubble
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? AppTheme.primaryColor 
                            : Colors.grey.shade100,
                        borderRadius: _getBorderRadius(isUser),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.content,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          
                          // Metadata for assistant messages
                          if (!isUser && message.metadata != null)
                            _buildMetadata(context),
                        ],
                      ),
                    ),
                  ),
                  
                  // Timestamp
                  if (isLastInGroup)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatTimestamp(message.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(context, isUser),
          ],
        ],
      ),
    );
  }

  /// Build avatar for message sender
  Widget _buildAvatar(BuildContext context, bool isUser) {
    if (!isLastInGroup) {
      return SizedBox(
        width: 32,
        height: 32,
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppTheme.primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: isUser ? Colors.white : Colors.grey.shade700,
        size: 18,
      ),
    );
  }

  /// Get border radius for message bubble
  BorderRadius _getBorderRadius(bool isUser) {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(4);

    if (isUser) {
      return BorderRadius.only(
        topLeft: radius,
        topRight: isFirstInGroup ? radius : smallRadius,
        bottomLeft: radius,
        bottomRight: isLastInGroup ? radius : smallRadius,
      );
    } else {
      return BorderRadius.only(
        topLeft: isFirstInGroup ? radius : smallRadius,
        topRight: radius,
        bottomLeft: isLastInGroup ? radius : smallRadius,
        bottomRight: radius,
      );
    }
  }

  /// Build metadata section for assistant messages
  Widget _buildMetadata(BuildContext context) {
    final metadata = message.metadata!;
    final contextUsed = metadata['context_used'] as int? ?? 0;
    final confidence = metadata['confidence'] as double? ?? 0.0;
    final sources = metadata['sources'] as List? ?? [];

    if (contextUsed == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  'Based on $contextUsed ${contextUsed == 1 ? 'source' : 'sources'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            
            if (sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sources: ${sources.join(', ')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ),
              
            if (confidence > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      'Confidence: ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: confidence,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(confidence),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(confidence * 100).round()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get confidence color based on confidence level
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Show message options (copy, etc.)
  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            
            if (!message.isFromUser)
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Report issue'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement feedback reporting
                },
              ),
          ],
        ),
      ),
    );
  }
}