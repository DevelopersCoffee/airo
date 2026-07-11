import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cast/cast.dart';
import '../../application/providers/iptv_cast_providers.dart';

class IptvCastMiniController extends ConsumerWidget {
  const IptvCastMiniController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(iptvCastProvider);
    final session = castState.session;
    final device = session.device;
    final media = session.media;

    if (device == null || media == null) {
      return const SizedBox.shrink();
    }

    final isPaused = session.phase == AiroCastSessionPhase.paused;
    final isLoading = session.phase == AiroCastSessionPhase.loadingMedia;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: Icon(isLoading ? Icons.hourglass_top : Icons.cast_connected),
          title: Text(
            'Casting to ${device.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            media.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: isPaused ? 'Play' : 'Pause',
                onPressed: isLoading
                    ? null
                    : () {
                        final notifier = ref.read(iptvCastProvider.notifier);
                        isPaused ? notifier.play() : notifier.pause();
                      },
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              ),
              IconButton(
                tooltip: 'Stop casting',
                onPressed: () => ref.read(iptvCastProvider.notifier).stop(),
                icon: const Icon(Icons.stop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
