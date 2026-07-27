import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/connectivity_providers.dart';

/// Surfaces a distinct "you're offline" state on touch devices, per the
/// reliability checklist's "Offline state" item -- without this, a dropped
/// connection during playback only ever showed a generic player error,
/// indistinguishable from a bad stream URL or a dead source.
///
/// Renders nothing while online.
class OfflinePlaybackBanner extends ConsumerWidget {
  const OfflinePlaybackBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    if (!isOffline) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('iptv-offline-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Playback and channel updates are paused "
              'until your connection is back.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
