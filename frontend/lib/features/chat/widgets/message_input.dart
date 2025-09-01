import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Message input widget for chat interface
class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final String hintText;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'Ask me about your receipts, spending, or warranties...',
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSend() {
    if (_hasText && widget.enabled) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice input button (placeholder for future implementation)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.mic_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: widget.enabled ? _showVoiceInputDialog : null,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Text input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    suffixIcon: _hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: widget.enabled
                                ? () {
                                    widget.controller.clear();
                                    FocusScope.of(context).requestFocus();
                                  }
                                : null,
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _hasText && widget.enabled
                    ? AppTheme.primaryColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: _hasText && widget.enabled
                      ? Colors.white
                      : Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: _hasText && widget.enabled ? _handleSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show voice input dialog (placeholder)
  void _showVoiceInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Input'),
        content: const Text(
          'Voice input feature coming soon! For now, please type your question.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}