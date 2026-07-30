import 'package:flutter/material.dart';

/// Error state for a surface whose content comes from the channel libraries.
///
/// The channel screen has offered a Retry since the load failure started
/// surfacing; the guide and favorites surfaces only printed the message, so a
/// user whose playlist source was down had to leave the tab and come back.
/// [onRetry] is supplied per surface because what needs invalidating differs:
/// the guide only needs the channel libraries, favorites also needs its own
/// list, whose error can come from storage rather than the channels.
class ChannelLoadErrorView extends StatelessWidget {
  const ChannelLoadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// User-facing reason. Callers pass the provider's message, which never
  /// contains a source URL.
  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const ValueKey('channel-load-error-retry'),
              // Land D-pad focus here: on TV this is the only action on screen.
              autofocus: true,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
