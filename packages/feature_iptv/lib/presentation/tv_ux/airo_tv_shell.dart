import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../application/providers/channel_filters_provider.dart';
import '../../application/providers/channel_auto_scan_providers.dart';
import '../../application/providers/connectivity_provider.dart';
import '../../application/providers/control_row_visibility_provider.dart';
import '../../application/providers/hotbar_channels_provider.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/providers/multiview_provider.dart';
import '../../application/channel_metadata_enrichment.dart';
import '../../application/channel_warmup_policy.dart';
import 'sections/channel_info_bar.dart';
import 'sections/channel_library_grid.dart';
import 'sections/filter_dialogs.dart';
import 'sections/filter_row.dart';
import 'sections/hotbar.dart';
import 'sections/multiview_stage.dart';
import 'sections/playback_stats_bar.dart';
import 'sections/shell_help_dialog.dart';
import 'sections/shell_settings_dialog.dart';

typedef VideoFrameEncoder =
    Future<Uint8List> Function(RenderRepaintBoundary boundary);

class AiroTvShell extends ConsumerStatefulWidget {
  const AiroTvShell({
    super.key,
    required this.channels,
    required this.videoStage,
    required this.onChannelSelected,
    this.showVideoStage = true,
    this.focusPlayDelay,
    this.currentChannel,
    this.metadataByChannelId = const {},
    this.availabilityByChannelId = const {},
    this.enrichMetadata = false,
    this.onPlaylistSourceTap,
    this.onWaysToWatchTap,
    this.onShareVideoFrame,
    this.videoFrameEncoder,
  });

  final List<IPTVChannel> channels;
  final Widget videoStage;
  final ValueChanged<IPTVChannel> onChannelSelected;
  final bool showVideoStage;
  final Duration? focusPlayDelay;
  final IPTVChannel? currentChannel;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final bool enrichMetadata;

  /// Opens the playlist-source sheet from the LIVE bar. Wired on TV where
  /// the phone app bar is suppressed; null hides the entry.
  final VoidCallback? onPlaylistSourceTap;

  /// Opens the fit/full/floating/Cast chooser from the LIVE info bar.
  final VoidCallback? onWaysToWatchTap;

  /// Host-owned delivery for a frame-only PNG capture.
  final Future<void> Function(Uint8List pngBytes)? onShareVideoFrame;

  /// Test seam for deterministic rendering validation. Production uses the
  /// boundary's PNG encoder.
  final VideoFrameEncoder? videoFrameEncoder;

  @override
  ConsumerState<AiroTvShell> createState() => _AiroTvShellState();
}

class _AiroTvShellState extends ConsumerState<AiroTvShell> {
  final _snapshotCache = ChannelBrowserSnapshotCache();
  bool _countryPromptShowing = false;
  Timer? _visibleScanDebounce;
  String _visibleScanSignature = '';
  final _videoCaptureKey = GlobalKey();

  @override
  void dispose() {
    _snapshotCache.clear();
    _visibleScanDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(channelFiltersProvider);
    final metadata = widget.enrichMetadata
        ? ref.watch(channelBrowseMetadataProvider).value ??
              widget.metadataByChannelId
        : widget.metadataByChannelId;
    final sort = ref.watch(channelSortProvider);
    final countryPrompt = ref.watch(channelCountryPromptProvider);
    final hasHotbar = ref.watch(hotbarChannelsProvider).isNotEmpty;
    final rowVisibility = ref.watch(controlRowVisibilityProvider);
    final multiview = ref.watch(multiviewProvider);
    final playbackStats = ref
        .watch(streamingStateProvider)
        .asData
        ?.value
        .playbackStats;
    final autoScanState = ref.watch(channelAutoScanProvider);
    final availabilityByChannelId = {
      ...widget.availabilityByChannelId,
      ...autoScanState.availabilityByChannelId,
    };
    final snapshot = _snapshotCache.resolve(
      channels: widget.channels,
      metadataByChannelId: metadata,
      filters: filters,
      sort: sort,
    );
    _maybeAskForCountry(
      filters: filters,
      dimensions: snapshot.dimensions,
      countryPrompt: countryPrompt,
    );
    final table = ChannelLibraryGrid(
      key: const ValueKey('airo-tv-channel-library'),
      channels: snapshot.visibleChannels,
      metadataByChannelId: metadata,
      availabilityByChannelId: availabilityByChannelId,
      sort: sort,
      onSort: (column) =>
          ref.read(channelSortProvider.notifier).state = sort.toggle(column),
      onChannelSelected: (channel) => _selectChannel(
        context,
        channel,
        snapshot.visibleChannels,
        availabilityByChannelId,
      ),
      focusPlayDelay: widget.focusPlayDelay,
      onVisibleChannelsChanged: _scheduleVisibleChannelScan,
      multiviewChannelIds: {
        for (final session in multiview.sessions) session.id,
      },
      onMultiviewToggle: (channel) => _toggleMultiview(context, channel),
    );
    final infoBar = ChannelInfoBar(
      channel: widget.currentChannel,
      onHelpTap: widget.showVideoStage
          ? null
          : () => showAiroTvShellHelpDialog(context),
      onPlaylistSourceTap: widget.onPlaylistSourceTap,
      onWaysToWatchTap: widget.onWaysToWatchTap,
      onScreenshotTap: widget.onShareVideoFrame == null
          ? null
          : () => _captureVideoFrame(context),
    );
    final hotbar = Hotbar(
      channels: widget.channels,
      onChannelSelected: widget.onChannelSelected,
    );
    final filterRow = FilterRow(dimensions: snapshot.dimensions);
    final videoStage = _VideoStageWithActions(
      child: KeyedSubtree(
        key: const ValueKey('airo-tv-video-capture-scope'),
        child: RepaintBoundary(
          key: _videoCaptureKey,
          child: multiview.sessions.isEmpty
              ? widget.videoStage
              : MultiviewStage(
                  sessions: multiview.sessions,
                  featuredChannelId: multiview.featuredChannelId,
                  onPromote: (channelId) =>
                      ref.read(multiviewProvider.notifier).promote(channelId),
                  onSwap: (firstId, secondId) => ref
                      .read(multiviewProvider.notifier)
                      .swap(firstId, secondId),
                ),
        ),
      ),
      onSettings: () => showAiroTvShellSettingsDialog(context),
      onHelp: () => showAiroTvShellHelpDialog(context),
    );
    final showChannel = rowVisibility.isVisible(AiroTvControlRow.channel);
    final showStats =
        rowVisibility.isVisible(AiroTvControlRow.stats) &&
        widget.currentChannel != null &&
        playbackStats != null &&
        playbackStats.hasValues;
    final showHotbar =
        rowVisibility.isVisible(AiroTvControlRow.hotbar) && hasHotbar;
    final showFilter = rowVisibility.isVisible(AiroTvControlRow.filter);
    final showPlaylist = rowVisibility.isVisible(AiroTvControlRow.playlist);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chrome = [
          const _OfflineBanner(),
          if (showChannel)
            _ExplorerSection(label: 'LIVE', height: 60, child: infoBar),
          if (showStats)
            _ExplorerSection(
              label: 'STATS',
              height: 48,
              child: PlaybackStatsBar(stats: playbackStats),
            ),
          if (showHotbar)
            _ExplorerSection(label: 'HOTBAR', height: 56, child: hotbar),
          if (showFilter)
            _ExplorerSection(label: 'FILTER', height: 48, child: filterRow),
        ];
        final compactChrome = [
          const _OfflineBanner(),
          if (showChannel) infoBar,
          if (showStats)
            SizedBox(height: 48, child: PlaybackStatsBar(stats: playbackStats)),
          if (showHotbar) hotbar,
          if (showFilter) filterRow,
        ];
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              if (widget.showVideoStage) Flexible(flex: 3, child: videoStage),
              ...compactChrome,
              if (showPlaylist) Expanded(flex: 4, child: table),
            ],
          );
        }
        final previewWidth = (constraints.maxWidth * 0.34)
            .clamp(320.0, 480.0)
            .toDouble();
        final previewHeight = previewWidth * 9 / 16;
        final panelWidth = widget.showVideoStage
            ? (constraints.maxWidth * 0.88).clamp(720.0, 1120.0).toDouble()
            : constraints.maxWidth;

        return Container(
          key: const ValueKey('airo-tv-explorer-wide-shell'),
          color: Colors.black,
          child: Column(
            children: [
              if (widget.showVideoStage)
                Flexible(
                  flex: 3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        key: const ValueKey('airo-tv-explorer-video-stage'),
                        width: previewWidth,
                        height: previewHeight,
                        child: ClipRect(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 640,
                              height: 360,
                              child: videoStage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: widget.showVideoStage ? 5 : 1,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const ValueKey('airo-tv-explorer-panel'),
                    constraints: BoxConstraints(maxWidth: panelWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF020419),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          ...chrome,
                          if (showPlaylist) Expanded(child: table),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleMultiview(
    BuildContext context,
    IPTVChannel channel,
  ) async {
    final result = await ref.read(multiviewProvider.notifier).toggle(channel);
    if (!context.mounted) return;
    final message = switch (result) {
      MultiviewToggleResult.added => '${channel.name} added to multiview',
      MultiviewToggleResult.removed => '${channel.name} removed from multiview',
      MultiviewToggleResult.capacityReached =>
        'This device supports up to '
            '${ref.read(multiviewProvider).capacity} multiview streams.',
      MultiviewToggleResult.failed =>
        '${channel.name} could not be opened in multiview.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _captureVideoFrame(BuildContext context) async {
    final share = widget.onShareVideoFrame;
    final boundary =
        _videoCaptureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (share == null || boundary == null) {
      _showCaptureMessage(context, 'Video frame is not ready to share.');
      return;
    }
    try {
      final bytes =
          await (widget.videoFrameEncoder?.call(boundary) ??
              _encodeVideoBoundary(boundary));
      await share(bytes);
      if (!context.mounted) return;
      _showCaptureMessage(context, 'Video frame ready to share.');
    } catch (error) {
      debugPrint('[AiroTvShell] video-frame capture failed: $error');
      if (!context.mounted) return;
      _showCaptureMessage(context, 'Could not capture this video frame.');
    }
  }

  Future<Uint8List> _encodeVideoBoundary(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void _showCaptureMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectChannel(
    BuildContext context,
    IPTVChannel channel,
    List<IPTVChannel> visibleChannels,
    Map<String, StreamAvailability> availabilityByChannelId,
  ) {
    if (!isChannelConfirmedUnavailable(availabilityByChannelId[channel.id])) {
      widget.onChannelSelected(channel);
      return;
    }

    final fallback = visibleChannels
        .where(
          (candidate) =>
              candidate.id != channel.id &&
              canSelectChannelWithAvailability(
                availabilityByChannelId[candidate.id],
              ),
        )
        .firstOrNull;
    if (fallback != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${channel.name} is unavailable. Skipping.')),
        );
      widget.onChannelSelected(fallback);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${channel.name} is unavailable right now.')),
      );
  }

  void _scheduleVisibleChannelScan(List<IPTVChannel> channels) {
    final autoScanState = ref.read(channelAutoScanProvider);
    final plan = planChannelWarmup(
      totalChannelCount: ref.read(filteredChannelsProvider).length,
      candidateCount: channels.length,
      cachedChannelCount: autoScanState.availabilityByChannelId.length,
      playbackState: ref.read(playbackStateProvider),
    );
    if (plan.isEmpty) return;
    final visible = channels.take(plan.limit).toList(growable: false);
    final signature = visible.map((channel) => channel.id).join(',');
    if (signature.isEmpty || signature == _visibleScanSignature) return;
    _visibleScanSignature = signature;
    _visibleScanDebounce?.cancel();
    _visibleScanDebounce = Timer(plan.debounce, () {
      if (!mounted) return;
      ref
          .read(channelAutoScanProvider.notifier)
          .start(
            scopeId: 'airo-tv-visible|$signature',
            channels: visible,
            maxConcurrentRequests: plan.maxConcurrentRequests,
            currentPlayingChannelId: ref
                .read(iptvStreamingServiceProvider)
                .currentState
                .currentChannel
                ?.id,
          );
    });
  }

  void _maybeAskForCountry({
    required ChannelFilters filters,
    required ChannelFilterDimensions dimensions,
    required AsyncValue<bool> countryPrompt,
  }) {
    final completed = _countryPromptCompleted(countryPrompt);
    if (completed != false || _countryPromptShowing) return;
    if (filters.country != null) {
      unawaited(
        ref.read(channelCountryPromptProvider.notifier).markCompleted(),
      );
      return;
    }
    if (dimensions.countries.isEmpty) return;

    _countryPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final latestCompleted = ref
          .read(channelCountryPromptProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      final latestFilters = ref.read(channelFiltersProvider);
      if (latestCompleted != false || latestFilters.country != null) {
        _countryPromptShowing = false;
        return;
      }

      final notifier = ref.read(channelFiltersProvider.notifier);
      await showTvLongListPicker(
        context: context,
        title: 'Choose your country',
        options: dimensions.countries.toList(growable: false),
        selectedValue: latestFilters.country,
        onSelected: notifier.setCountry,
        onClear: () => notifier.setCountry(null),
        optionLabel: countryDisplayLabel,
      );
      if (mounted) {
        await ref.read(channelCountryPromptProvider.notifier).markCompleted();
        _countryPromptShowing = false;
      }
    });
  }
}

class _VideoStageWithActions extends StatelessWidget {
  const _VideoStageWithActions({
    required this.child,
    required this.onSettings,
    required this.onHelp,
  });

  final Widget child;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StageAction(
                key: const ValueKey('airo-tv-shell-help-action'),
                icon: Icons.help_outline,
                tooltip: 'Airo TV Help',
                onPressed: onHelp,
              ),
              const SizedBox(width: 4),
              _StageAction(
                key: const ValueKey('airo-tv-shell-settings-action'),
                icon: Icons.tune,
                tooltip: 'Explorer rows',
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageAction extends StatelessWidget {
  const _StageAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: tooltip,
      onSelect: onPressed,
      child: Material(
        color: Colors.black.withValues(alpha: 0.56),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

bool? _countryPromptCompleted(AsyncValue<bool> prompt) {
  return prompt.maybeWhen(data: (value) => value, orElse: () => null);
}

class _ExplorerSection extends StatelessWidget {
  const _ExplorerSection({
    required this.label,
    required this.height,
    required this.child,
  });

  final String label;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// AiroTV D-pad design's "OFFLINE" screen, condensed to a non-blocking
/// banner instead of a full-screen takeover: the playlist is cached, so
/// channels stay browsable and (if already playing) video keeps playing —
/// only new stream starts would actually need the connection. Renders
/// nothing while online.
class _OfflineBanner extends ConsumerStatefulWidget {
  const _OfflineBanner();

  @override
  ConsumerState<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<_OfflineBanner> {
  bool _checking = false;

  // issues/04-recovery-states.md acceptance criterion 4: Retry must report
  // success or failure, not just spin -- and must not be a fake button
  // (isOnlineProvider is watched from the same ConnectivityService this
  // re-checks, so a real change is what actually dismisses the banner).
  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    final isConnected = await ref.read(connectivityServiceProvider).isConnected;
    if (!mounted) return;
    setState(() => _checking = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? 'Back online'
                : 'Still no connection — check your network and try again',
          ),
        ),
      );
  }

  // issues/04-recovery-states.md acceptance criterion 4, second half: a
  // real platform adapter, or omitted where unsupported -- never a
  // disabled button (WifiSettingsLauncher.isSupported gates whether this
  // renders at all, see build()).
  Future<void> _openWifiSettings() async {
    final opened = await ref.read(wifiSettingsLauncherProvider).open();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text("Couldn't open Wi-Fi settings")),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;
    if (isOnline) return const SizedBox.shrink();
    final wifiSettingsSupported = ref
        .watch(wifiSettingsLauncherProvider)
        .isSupported;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF3A2A0A),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No network connection — your playlist is cached, but '
              'streams need a connection.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.amber.shade100),
            ),
          ),
          const SizedBox(width: 8),
          TvFocusable(
            key: const ValueKey('offline-banner-retry'),
            semanticLabel: 'Retry connection',
            onSelect: _checking ? null : _retry,
            borderRadius: 6,
            child: TextButton.icon(
              onPressed: _checking ? null : _retry,
              icon: _checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
              label: Text(
                'Retry',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.amber),
              ),
            ),
          ),
          if (wifiSettingsSupported) ...[
            const SizedBox(width: 4),
            TvFocusable(
              key: const ValueKey('offline-banner-wifi-settings'),
              semanticLabel: 'Open Wi-Fi settings',
              onSelect: _openWifiSettings,
              borderRadius: 6,
              child: TextButton.icon(
                onPressed: _openWifiSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: Colors.amber,
                ),
                label: Text(
                  'Wi-Fi Settings',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.amber),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
