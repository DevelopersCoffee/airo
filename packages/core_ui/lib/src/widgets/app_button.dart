import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard application button widget
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildButton(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: _getLoadingSize(),
            height: _getLoadingSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getForegroundColor(context),
              ),
            ),
          )
        : _buildContent();

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: _getButtonStyle(context),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: _getButtonStyle(context),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: _getButtonStyle(context),
          child: child,
        ),
    };
  }

  Widget _buildContent() {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }
    return Text(label);
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    final padding = switch (size) {
      AppButtonSize.small =>
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      AppButtonSize.medium =>
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      AppButtonSize.large =>
        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    };

    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
    );
  }

  double _getLoadingSize() => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 20,
        AppButtonSize.large => 24,
      };

  double _getIconSize() => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 20,
        AppButtonSize.large => 24,
      };

  Color _getForegroundColor(BuildContext context) => switch (variant) {
        AppButtonVariant.primary =>
          Theme.of(context).colorScheme.onPrimary,
        AppButtonVariant.secondary ||
        AppButtonVariant.text =>
          Theme.of(context).colorScheme.primary,
      };
}

enum AppButtonVariant { primary, secondary, text }

enum AppButtonSize { small, medium, large }

