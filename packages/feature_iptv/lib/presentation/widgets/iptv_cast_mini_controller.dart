import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_cast_providers.dart';

Future<void> showIptvCastRemoteControlSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CastRemoteControlSheet(),
  );
}

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
  bool _initialized = false;

  void _confirm() {
    final device = ref.read(iptvCastProvider).session.device;
    setState(() => _confirmedDeviceId = device?.id);
  }

  void _openRemote() {
    _confirm();
    showIptvCastRemoteControlSheet(context);
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
          if (_confirmedDeviceId != null) {
            setState(() => _confirmedDeviceId = null);
          }
          return;
        }
        final wasConnectedToSameDevice =
            previous != null &&
            previous.isConnected &&
            previous.device?.id == next.device?.id;
        if (!wasConnectedToSameDevice &&
            next.device?.id != _confirmedDeviceId) {
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
        onBrowseChannels: _confirm,
        onOpenControls: _openRemote,
      );
    }

    return _CompactCastController(
      session: session,
      device: device,
      media: media,
      onOpenRemote: _openRemote,
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
    required this.onOpenRemote,
  });

  final AiroCastSessionSnapshot session;
  final AiroCastDevice device;
  final AiroCastMediaRequest? media;
  final VoidCallback onOpenRemote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = session.phase == AiroCastSessionPhase.paused;
    final isLoading = session.phase == AiroCastSessionPhase.loadingMedia;
    final isStopped = session.phase == AiroCastSessionPhase.stopped;
    final isFailed = session.phase == AiroCastSessionPhase.failed;
    final hasMedia = media != null;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    if (size.width > size.height && size.height < 600) {
      return _buildLandscape(
        context,
        ref,
        isPaused: isPaused,
        isLoading: isLoading,
        isStopped: isStopped,
        isFailed: isFailed,
        hasMedia: hasMedia,
      );
    }

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
                    tooltip: 'Open Cast remote',
                    icon: const Icon(Icons.settings_remote),
                    onPressed: onOpenRemote,
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

  Widget _buildLandscape(
    BuildContext context,
    WidgetRef ref, {
    required bool isPaused,
    required bool isLoading,
    required bool isStopped,
    required bool isFailed,
    required bool hasMedia,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(iptvCastProvider.notifier);

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(width: 10),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: isFailed
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasMedia)
                    IconButton(
                      tooltip: isPaused || isStopped
                          ? 'Start playback'
                          : 'Pause',
                      onPressed: isLoading
                          ? null
                          : () {
                              if (isStopped) {
                                notifier.reloadActiveMedia();
                              } else {
                                isPaused ? notifier.play() : notifier.pause();
                              }
                            },
                      icon: Icon(
                        isPaused || isStopped ? Icons.play_arrow : Icons.pause,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Stop receiver media',
                    onPressed: isLoading ? null : notifier.stop,
                    icon: const Icon(Icons.stop),
                  ),
                  const Icon(Icons.volume_down, size: 20),
                  SizedBox(
                    width: 180,
                    child: Slider(
                      value: session.volume.clamp(0.0, 1.0).toDouble(),
                      onChanged: notifier.setVolume,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open Cast remote',
                    icon: const Icon(Icons.settings_remote),
                    onPressed: onOpenRemote,
                  ),
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

class _CastRemoteControlSheet extends ConsumerWidget {
  const _CastRemoteControlSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(iptvCastProvider).session;
    final device = session.device;
    if (device == null || !session.isConnected) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final notifier = ref.read(iptvCastProvider.notifier);
    final mediaTitle = session.media?.title ?? 'No media loaded';
    final isPaused = session.phase == AiroCastSessionPhase.paused;
    final isStopped = session.phase == AiroCastSessionPhase.stopped;
    final isLoading = session.phase == AiroCastSessionPhase.loadingMedia;

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: landscape
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.cast_connected,
          size: 28,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          'Remote for ${device.name}',
          textAlign: landscape ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          mediaTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: landscape ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.volume_down),
            Expanded(
              child: Slider(
                value: session.volume.clamp(0.0, 1.0).toDouble(),
                onChanged: notifier.setVolume,
              ),
            ),
            const Icon(Icons.volume_up),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            notifier.disconnect();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.cast_connected),
          label: const Text('Disconnect TV'),
        ),
      ],
    );

    final pad = _CastRemotePad(
      diameter: landscape ? 210 : 280,
      isPaused: isPaused,
      isStopped: isStopped,
      isLoading: isLoading,
      onPrimary: () {
        if (isStopped) {
          notifier.reloadActiveMedia();
        } else {
          isPaused ? notifier.play() : notifier.pause();
        }
      },
      onVolumeUp: () =>
          notifier.setVolume((session.volume + 0.1).clamp(0.0, 1.0).toDouble()),
      onVolumeDown: () =>
          notifier.setVolume((session.volume - 0.1).clamp(0.0, 1.0).toDouble()),
      onMute: () => notifier.setVolume(0),
      onStop: notifier.stop,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: landscape
              ? Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 32),
                    pad,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [details, const SizedBox(height: 20), pad],
                ),
        ),
      ),
    );
  }
}

class _CastRemotePad extends StatelessWidget {
  const _CastRemotePad({
    required this.diameter,
    required this.isPaused,
    required this.isStopped,
    required this.isLoading,
    required this.onPrimary,
    required this.onVolumeUp,
    required this.onVolumeDown,
    required this.onMute,
    required this.onStop,
  });

  final double diameter;
  final bool isPaused;
  final bool isStopped;
  final bool isLoading;
  final VoidCallback onPrimary;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onMute;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final edgeOffset = diameter * 0.08;
    final centerSize = diameter * 0.42;

    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: edgeOffset,
              child: IconButton(
                tooltip: 'Volume up',
                onPressed: onVolumeUp,
                icon: const Icon(Icons.volume_up),
              ),
            ),
            Positioned(
              bottom: edgeOffset,
              child: IconButton(
                tooltip: 'Volume down',
                onPressed: onVolumeDown,
                icon: const Icon(Icons.volume_down),
              ),
            ),
            Positioned(
              left: edgeOffset,
              child: IconButton(
                tooltip: 'Mute',
                onPressed: onMute,
                icon: const Icon(Icons.volume_off),
              ),
            ),
            Positioned(
              right: edgeOffset,
              child: IconButton(
                tooltip: 'Stop receiver media',
                onPressed: isLoading ? null : onStop,
                icon: const Icon(Icons.stop),
              ),
            ),
            SizedBox.square(
              dimension: centerSize,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: isLoading ? null : onPrimary,
                child: Icon(
                  isPaused || isStopped ? Icons.play_arrow : Icons.pause,
                  size: centerSize * 0.42,
                  semanticLabel: isPaused || isStopped
                      ? 'Start playback'
                      : 'Pause',
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
