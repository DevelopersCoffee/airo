import 'package:flutter/material.dart';

import '../theme/airo_colors.dart';
import '../theme/airo_spacing.dart';
import 'app_button.dart';

/// Standard error view widget
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    super.key,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AiroSpacing.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.error_outline, size: 64, color: AiroColors.error),
          const SizedBox(height: AiroSpacing.md),
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AiroSpacing.sm),
          ],
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AiroSpacing.lg),
            AppButton(
              label: retryLabel,
              onPressed: onRetry,
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    ),
  );
}

/// Inline error widget for smaller spaces
class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.error_outline,
        size: 20,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(width: AiroSpacing.sm),
      Expanded(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
      if (onRetry != null)
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRetry,
          tooltip: 'Retry',
        ),
    ],
  );
}
