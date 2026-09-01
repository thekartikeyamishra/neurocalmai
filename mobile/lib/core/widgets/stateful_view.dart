import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

enum ViewState { loading, empty, error, content }

class StatefulView extends StatelessWidget {
  final ViewState state;
  final Widget content;
  final String? emptyMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? customSkeleton;

  const StatefulView({
    super.key,
    required this.state,
    required this.content,
    this.emptyMessage,
    this.errorMessage,
    this.onRetry,
    this.customSkeleton,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildStateView(context),
    );
  }

  Widget _buildStateView(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return customSkeleton ?? const Center(child: CircularProgressIndicator(color: AppTokens.primary));
      case ViewState.empty:
        return _buildFeedbackView(
          context,
          icon: Icons.inbox_rounded,
          title: "Nothing here yet",
          message: emptyMessage ?? "Your activity will appear here once you start.",
        );
      case ViewState.error:
        return _buildFeedbackView(
          context,
          icon: Icons.error_outline_rounded,
          title: "We couldn't load this right now",
          message: errorMessage ?? "Check your connection and try again.",
          action: onRetry,
          actionLabel: "Try Again",
          isError: true,
        );
      case ViewState.content:
        return content;
    }
  }

  Widget _buildFeedbackView(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? action,
    String? actionLabel,
    bool isError = false,
  }) {
    final color = isError ? AppTokens.error : AppTokens.primary;
    final containerColor = isError ? AppTokens.errorContainer : AppTokens.primaryContainer;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.spacing24),
              decoration: BoxDecoration(color: containerColor, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: AppTokens.spacing24),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTokens.onSurface)),
            const SizedBox(height: AppTokens.spacing8),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTokens.onSurfaceVariant)),
            if (action != null) ...[
              const SizedBox(height: AppTokens.spacing32),
              OutlinedButton(
                onPressed: action,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMedium)),
                  minimumSize: const Size(120, AppTokens.minTouchTarget),
                ),
                child: Text(actionLabel ?? "Action"),
              ),
            ]
          ],
        ),
      ),
    );
  }
}