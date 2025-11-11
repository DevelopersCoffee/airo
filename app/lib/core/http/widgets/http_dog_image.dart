import 'package:flutter/material.dart';
import '../http_status.dart';

/// Widget to display HTTP status code with dog image from http.dog
class HttpDogImage extends StatelessWidget {
  final int statusCode;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showStatusText;
  final bool showDescription;
  final Widget? errorWidget;

  const HttpDogImage({
    super.key,
    required this.statusCode,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showStatusText = true,
    this.showDescription = false,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final status = HttpStatusCodes.fromCode(statusCode);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dog image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            status.dogImageUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: width ?? 200,
                height: height ?? 200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ??
                  Container(
                    width: width ?? 200,
                    height: height ?? 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pets,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$statusCode',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
            },
          ),
        ),

        // Status text
        if (showStatusText) ...[
          const SizedBox(height: 12),
          Text(
            status.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: _getColorFromCategory(theme, status.category),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Description
        if (showDescription) ...[
          const SizedBox(height: 4),
          Text(
            status.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Color _getColorFromCategory(ThemeData theme, HttpStatusCategory category) {
    return switch (category) {
      HttpStatusCategory.informational => Colors.blue,
      HttpStatusCategory.success => Colors.green,
      HttpStatusCategory.redirection => Colors.orange,
      HttpStatusCategory.clientError => Colors.deepOrange,
      HttpStatusCategory.serverError => Colors.red,
      HttpStatusCategory.unknown => theme.colorScheme.onSurface,
    };
  }
}

/// Compact HTTP status indicator with dog icon
class HttpDogIndicator extends StatelessWidget {
  final int statusCode;
  final bool showCode;

  const HttpDogIndicator({
    super.key,
    required this.statusCode,
    this.showCode = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = HttpStatusCodes.fromCode(statusCode);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColorFromCategory(theme, status.category).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColorFromCategory(theme, status.category).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pets,
            size: 16,
            color: _getColorFromCategory(theme, status.category),
          ),
          if (showCode) ...[
            const SizedBox(width: 6),
            Text(
              '$statusCode',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _getColorFromCategory(theme, status.category),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColorFromCategory(ThemeData theme, HttpStatusCategory category) {
    return switch (category) {
      HttpStatusCategory.informational => Colors.blue,
      HttpStatusCategory.success => Colors.green,
      HttpStatusCategory.redirection => Colors.orange,
      HttpStatusCategory.clientError => Colors.deepOrange,
      HttpStatusCategory.serverError => Colors.red,
      HttpStatusCategory.unknown => theme.colorScheme.onSurface,
    };
  }
}

/// Full error screen with HTTP dog
class HttpDogErrorScreen extends StatelessWidget {
  final int statusCode;
  final String? customMessage;
  final VoidCallback? onRetry;

  const HttpDogErrorScreen({
    super.key,
    required this.statusCode,
    this.customMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final status = HttpStatusCodes.fromCode(statusCode);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HttpDogImage(
                statusCode: statusCode,
                width: 300,
                height: 300,
                showStatusText: true,
                showDescription: true,
              ),
              if (customMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  customMessage!,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// HTTP Dog card widget
class HttpDogCard extends StatelessWidget {
  final int statusCode;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;

  const HttpDogCard({
    super.key,
    required this.statusCode,
    this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = HttpStatusCodes.fromCode(statusCode);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dog image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                status.dogImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.pets,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HttpDogIndicator(statusCode: statusCode),
                      const Spacer(),
                      Text(
                        status.message,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      title!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

