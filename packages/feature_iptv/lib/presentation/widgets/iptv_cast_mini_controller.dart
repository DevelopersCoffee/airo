import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_cast_providers.dart';

/// CV-028 "After connection" surface: a one-time "Playing on {deviceName}"
/// confirmation the first time this widget observes a live transition into
/// an active Cast session, settling into the persistent compact controller
/// afterward (or immediately, for a session that was already connected when
/// this widget mounted -- e.g. a recovered/hydrated session at app start,
/// which is not a "new" handoff and must not show the confirmation).
class IptvCastMiniController extends ConsumerStatefulWidget {
  const IptvCastMiniController({super.key});

  @override
  ConsumerState<IptvCastMiniController> createState() =>
      _IptvCastMiniControllerState();
}

class _IptvCastMiniControllerState
    extends ConsumerState<IptvCastMiniController> {
  String? _confirmedDeviceId;
  bool _expanded = false;
  bool _initialized = false;

  void _confirm({required bool expand}) {
    final device = ref.read(iptvCastProvider).session.device;
    setState(() {
      _confirmedDeviceId = device?.id;
      _expanded = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // A session that's already connected the first time this widget
      // builds was hydrated/recovered, not just handed off by the user in
      // this app session -- suppress the one-time banner for it.
      final initialSession = ref.read(iptvCastProvider).session;
      if (initialSession.isConnected) {
        _confirmedDeviceId = initialSession.device?.id;
      }
      _initialized = true;
    }

    ref.listen<AiroCastSessionSnapshot>(
      iptvCastProvider.select((state) => state.session),
      (previous, next) {
        if (!next.isConnected) {
          if (_confirmedDeviceId != null || _expanded) {
            setState(() {
              _confirmedDeviceId = null;
              _expanded = false;
            });
          }
          return;
        }
        final wasConnectedToSameDevice =
            previous != null &&
            previous.isConnected &&
            previous.device?.id == next.device?.id;
        if (!wasConnectedToSameDevice && next.device?.id != _confirmedDeviceId) {
          setState(() {}); // rebuild to evaluate the banner below
        }
      },
    );

    final castState = ref.watch(iptvCastProvider);
    final session = castState.session;
    final device = session.device;
    final media = session.media;

    if (device == null ||
        session.phase == AiroCastSessionPhase.idle ||
        session.phase == AiroCastSessionPhase.disconnected) {
      return const SizedBox.shrink();
    }

    if (session.isConnected && device.id != _confirmedDeviceId) {
      return _ConnectionConfirmationBanner(
        device: device,
        media: media,
        onBrowseChannels: () => _confirm(expand: false),
        onOpenControls: () => _confirm(expand: true),
      );
    }

    return _CompactCastController(
      session: session,
      device: device,
      media: media,
      expanded: _expanded,
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
    );
  }
}

class _ConnectionConfirmationBanner extends ConsumerWidget {
  const _ConnectionConfirmationBanner({
    required this.device,
    required this.media,
    required this.onBrowseChannels,
    required this.onOpenControls,
  });

  final AiroCastDevice device;
  final AiroCastMediaRequest? media;
  final VoidCallback onBrowseChannels;
  final VoidCallback onOpenControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final channelName = media?.title ?? 'This channel';

    return Material(
      color: colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Playing on ${device.name}',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$channelName is playing on your TV. Keep browsing here or '
                'use this device as the remote.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    onPressed: onBrowseChannels,
                    child: const Text('Browse channels'),
                  ),
                  OutlinedButton(
                    onPressed: onOpenControls,
                    child: const Text('Open controls'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCastController extends ConsumerWidget {
  const _CompactCastController({
    required this.session,
    required this.device,
    required this.media,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final AiroCastSessionSnapshot session;
  final AiroCastDevice device;
  final AiroCastMediaRequest? media;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  IconButton(
                    tooltip: expanded ? 'Fewer controls' : 'More controls',
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: onToggleExpanded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasMedia)
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
                    tooltip: 'Stop receiver media',
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: isLoading
                        ? null
                        : () => ref.read(iptvCastProvider.notifier).stop(),
                  ),
                  if (expanded) ...[
                    if (hasMedia) ...[
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
                      tooltip: 'Disconnect from ${device.name}',
                      icon: Icons.cast_connected,
                      label: 'Disconnect',
                      onPressed: () =>
                          ref.read(iptvCastProvider.notifier).disconnect(),
                    ),
                  ],
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
