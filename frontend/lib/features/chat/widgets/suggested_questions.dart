import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Widget to display suggested questions for users
class SuggestedQuestions extends StatelessWidget {
  final Function(String) onQuestionTap;

  const SuggestedQuestions({
    Key? key,
    required this.onQuestionTap,
  }) : super(key: key);

  static const List<Map<String, dynamic>> _suggestions = [
    {
      'question': 'When did I pay my 3rd term school fees?',
      'icon': Icons.school,
      'category': 'Education',
    },
    {
      'question': 'What\'s my total spending this month?',
      'icon': Icons.analytics,
      'category': 'Analytics',
    },
    {
      'question': 'Show me all receipts from grocery stores',
      'icon': Icons.shopping_cart,
      'category': 'Shopping',
    },
    {
      'question': 'Which warranties are expiring soon?',
      'icon': Icons.warning_amber,
      'category': 'Warranties',
    },
    {
      'question': 'What\'s my average monthly spending?',
      'icon': Icons.trending_up,
      'category': 'Trends',
    },
    {
      'question': 'Find receipts over \$100 from last month',
      'icon': Icons.search,
      'category': 'Search',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Try asking:',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            return _SuggestionChip(
              question: suggestion['question'],
              icon: suggestion['icon'],
              category: suggestion['category'],
              onTap: () => onQuestionTap(suggestion['question']),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Individual suggestion chip
class _SuggestionChip extends StatelessWidget {
  final String question;
  final IconData icon;
  final String category;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.question,
    required this.icon,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 14,
                color: _getCategoryColor(category),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
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

  /// Get color based on category
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Education':
        return Colors.blue;
      case 'Analytics':
        return Colors.green;
      case 'Shopping':
        return Colors.orange;
      case 'Warranties':
        return Colors.red;
      case 'Trends':
        return Colors.purple;
      case 'Search':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }
}

/// Animated suggested questions for better UX
class AnimatedSuggestedQuestions extends StatefulWidget {
  final Function(String) onQuestionTap;

  const AnimatedSuggestedQuestions({
    Key? key,
    required this.onQuestionTap,
  }) : super(key: key);

  @override
  State<AnimatedSuggestedQuestions> createState() =>
      _AnimatedSuggestedQuestionsState();
}

class _AnimatedSuggestedQuestionsState
    extends State<AnimatedSuggestedQuestions>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for each suggestion
    _animations = List.generate(
      SuggestedQuestions._suggestions.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.5,
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Try asking:',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SuggestedQuestions._suggestions.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value;
            
            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: _animations[index].value,
                  child: Opacity(
                    opacity: _animations[index].value,
                    child: _SuggestionChip(
                      question: suggestion['question'],
                      icon: suggestion['icon'],
                      category: suggestion['category'],
                      onTap: () => widget.onQuestionTap(suggestion['question']),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}