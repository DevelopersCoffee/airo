import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard loading indicator widget
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = LoadingIndicatorSize.medium,
    this.message,
    this.color,
  });

  final LoadingIndicatorSize size;
  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: _getSize(),
      height: _getSize(),
      child: CircularProgressIndicator(
        strokeWidth: _getStrokeWidth(),
        valueColor: color != null ? AlwaysStoppedAnimation<Color>(color!) : null,
      ),
    );

    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return indicator;
  }

  double _getSize() => switch (size) {
        LoadingIndicatorSize.small => 20,
        LoadingIndicatorSize.medium => 36,
        LoadingIndicatorSize.large => 48,
      };

  double _getStrokeWidth() => switch (size) {
        LoadingIndicatorSize.small => 2,
        LoadingIndicatorSize.medium => 3,
        LoadingIndicatorSize.large => 4,
      };
}

enum LoadingIndicatorSize { small, medium, large }

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: AppSpacing.paddingLg,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: LoadingIndicator(
                size: LoadingIndicatorSize.large,
                message: message,
              ),
            ),
          ),
        ),
      );
}

