import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_cast_providers.dart';

class IptvCastMiniController extends ConsumerWidget {
  const IptvCastMiniController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(iptvCastProvider);
    final session = castState.session;
    final device = session.device;
    final media = session.media;

    if (device == null ||
        session.phase == AiroCastSessionPhase.idle ||
        session.phase == AiroCastSessionPhase.disconnected) {
      return const SizedBox.shrink();
    }

    final isPaused = session.phase == AiroCastSessionPhase.paused;
    final isLoading = session.phase == AiroCastSessionPhase.loadingMedia;
    final isStopped = session.phase == AiroCastSessionPhase.stopped;
    final isFailed = session.phase == AiroCastSessionPhase.failed;
    final hasMedia = media != null;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isLoading
                        ? Icons.hourglass_top
                        : isFailed
                        ? Icons.error_outline
                        : Icons.cast_connected,
                    color: isFailed ? colorScheme.error : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _statusLabel(session.phase, device.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          _subtitle(session, media),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isFailed
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasMedia) ...[
                    _CastControlButton(
                      tooltip: isPaused || isStopped
                          ? 'Start playback'
                          : 'Pause',
                      icon: isPaused || isStopped
                          ? Icons.play_arrow
                          : Icons.pause,
                      label: isPaused || isStopped ? 'Start' : 'Pause',
                      onPressed: isLoading
                          ? null
                          : () {
                              final notifier = ref.read(
                                iptvCastProvider.notifier,
                              );
                              if (isStopped) {
                                notifier.reloadActiveMedia();
                              } else {
                                isPaused ? notifier.play() : notifier.pause();
                              }
                            },
                    ),
                    _CastControlButton(
                      tooltip: 'Reload current stream',
                      icon: Icons.refresh,
                      label: 'Reload',
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(iptvCastProvider.notifier)
                                .reloadActiveMedia(),
                    ),
                    _CastControlButton(
                      tooltip: 'Start a new Cast session',
                      icon: Icons.restart_alt,
                      label: 'New session',
                      onPressed: () => ref
                          .read(iptvCastProvider.notifier)
                          .restartActiveSession(),
                    ),
                  ],
                  _CastControlButton(
                    tooltip: 'Stop receiver media',
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: isLoading
                        ? null
                        : () => ref.read(iptvCastProvider.notifier).stop(),
                  ),
                  _CastControlButton(
                    tooltip: 'Disconnect from ${device.name}',
                    icon: Icons.cast_connected,
                    label: 'Disconnect',
                    onPressed: () =>
                        ref.read(iptvCastProvider.notifier).disconnect(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20),
                  Expanded(
                    child: Slider(
                      value: session.volume.clamp(0.0, 1.0).toDouble(),
                      onChanged: (value) =>
                          ref.read(iptvCastProvider.notifier).setVolume(value),
                    ),
                  ),
                  const Icon(Icons.volume_up, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(AiroCastSessionPhase phase, String deviceName) {
    return switch (phase) {
      AiroCastSessionPhase.loadingMedia => 'Loading on $deviceName',
      AiroCastSessionPhase.paused => 'Paused on $deviceName',
      AiroCastSessionPhase.stopped => 'Stopped on $deviceName',
      AiroCastSessionPhase.failed => 'Cast needs attention',
      AiroCastSessionPhase.connected => 'Connected to $deviceName',
      _ => 'Casting to $deviceName',
    };
  }

  String _subtitle(
    AiroCastSessionSnapshot session,
    AiroCastMediaRequest? media,
  ) {
    if (session.phase == AiroCastSessionPhase.failed) {
      return session.error?.message ?? media?.title ?? 'Receiver needs action.';
    }
    return media?.title ?? 'Choose a channel to cast, or disconnect the TV.';
  }
}

class _CastControlButton extends StatelessWidget {
  const _CastControlButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
