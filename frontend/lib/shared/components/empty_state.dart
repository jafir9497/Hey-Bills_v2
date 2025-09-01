import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty state widget for showing when there's no data
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? illustration;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.illustration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (illustration != null) 
            illustration!
          else
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Specialized empty states for different features
class NoReceiptsEmpty extends StatelessWidget {
  final VoidCallback? onAddReceipt;

  const NoReceiptsEmpty({Key? key, this.onAddReceipt}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_outlined,
      title: 'No receipts found',
      message: 'Start by adding your first receipt to track your expenses',
      actionText: 'Add Receipt',
      onAction: onAddReceipt,
    );
  }
}

class NoWarrantiesEmpty extends StatelessWidget {
  final VoidCallback? onAddWarranty;

  const NoWarrantiesEmpty({Key? key, this.onAddWarranty}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.verified_user_outlined,
      title: 'No warranties found',
      message: 'Add your product warranties to never miss important dates',
      actionText: 'Add Warranty',
      onAction: onAddWarranty,
    );
  }
}

class NoAnalyticsEmpty extends StatelessWidget {
  const NoAnalyticsEmpty({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.analytics_outlined,
      title: 'No data available',
      message: 'Add some receipts to see your spending analytics',
    );
  }
}

class SearchEmpty extends StatelessWidget {
  final String searchTerm;
  final VoidCallback? onClearSearch;

  const SearchEmpty({
    Key? key,
    required this.searchTerm,
    this.onClearSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No results found',
      message: 'No results found for "$searchTerm".\nTry different keywords.',
      actionText: 'Clear Search',
      onAction: onClearSearch,
    );
  }
}

class NetworkErrorEmpty extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorEmpty({Key? key, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off,
      title: 'Connection Error',
      message: 'Please check your internet connection and try again.',
      actionText: 'Retry',
      onAction: onRetry,
    );
  }
}