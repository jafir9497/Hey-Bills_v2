import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_theme.dart';

class EnhancedMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onVoice;
  final bool enabled;
  final bool showAttachments;
  final bool showVoice;
  final String hintText;
  final int maxLines;

  const EnhancedMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttachment,
    this.onVoice,
    this.enabled = true,
    this.showAttachments = true,
    this.showVoice = true,
    this.hintText = 'Ask about your receipts, expenses, or warranties...',
    this.maxLines = 5,
  });

  @override
  State<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends State<EnhancedMessageInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _animationController.dispose();
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

  void _onSend() {
    if (!widget.enabled || !_hasText) return;
    
    final message = widget.controller.text.trim();
    if (message.isNotEmpty) {
      widget.onSend(message);
      widget.controller.clear();
      _collapse();
    }
  }

  void _expand() {
    setState(() {
      _isExpanded = true;
    });
  }

  void _collapse() {
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isExpanded ? 24 : 28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExpanded) _buildExpandedActions(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              if (widget.showAttachments)
                IconButton(
                  onPressed: widget.enabled ? widget.onAttachment : null,
                  icon: const Icon(Icons.attach_file),
                  color: AppTheme.primaryColor,
                  tooltip: 'Attach file',
                ),
              
              // Text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  maxLines: _isExpanded ? widget.maxLines : 1,
                  minLines: 1,
                  onTap: _expand,
                  onSubmitted: (_) => _onSend(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              
              // Voice/Send button
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      child: _hasText
                          ? _buildSendButton()
                          : _buildVoiceButton(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () {
              // TODO: Open camera
              _collapse();
            },
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () {
              // TODO: Open gallery
              _collapse();
            },
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            icon: Icons.receipt,
            label: 'Receipt',
            onTap: () {
              // TODO: Scan receipt
              _collapse();
            },
          ),
          const Spacer(),
          IconButton(
            onPressed: _collapse,
            icon: const Icon(Icons.keyboard_arrow_down),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _onSend,
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.enabled && _hasText 
              ? AppTheme.primaryColor 
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.send,
          color: widget.enabled && _hasText 
              ? Colors.white 
              : Colors.grey.shade500,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    if (!widget.showVoice) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: widget.enabled ? widget.onVoice : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.mic,
          color: widget.enabled 
              ? AppTheme.primaryColor 
              : Colors.grey.shade400,
          size: 20,
        ),
      ),
    );
  }
}