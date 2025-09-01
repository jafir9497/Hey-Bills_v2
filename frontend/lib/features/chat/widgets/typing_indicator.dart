import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Typing indicator widget to show when AI is responding
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();

    // Main controller for overall animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Individual controllers for each dot
    _dotControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    // Staggered animations for dots
    _dotAnimations = _dotControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      
      return Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start animations with delays
    _startStaggeredAnimations();
  }

  void _startStaggeredAnimations() {
    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _dotControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.grey.shade700,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Typing text
                Text(
                  'Thinking',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Animated dots
                Row(
                  children: _dotAnimations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final animation = entry.value;
                    
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600.withOpacity(animation.value),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Alternative typing indicator with bouncing dots
class BouncingTypingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const BouncingTypingIndicator({
    Key? key,
    this.color,
    this.size = 6.0,
  }) : super(key: key);

  @override
  State<BouncingTypingIndicator> createState() =>
      _BouncingTypingIndicatorState();
}

class _BouncingTypingIndicatorState extends State<BouncingTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, -0.5),
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start staggered bouncing
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.grey.shade700,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Bouncing dots container
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _animations.asMap().entries.map((entry) {
                final index = entry.key;
                final animation = entry.value;
                
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: animation.value * widget.size,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        margin: EdgeInsets.symmetric(
                          horizontal: widget.size * 0.2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(widget.size / 2),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}