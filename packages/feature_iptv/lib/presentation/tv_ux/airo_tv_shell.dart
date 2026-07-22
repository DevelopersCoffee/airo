import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../application/providers/channel_filters_provider.dart';
import '../../application/providers/channel_auto_scan_providers.dart';
import '../../application/providers/hotbar_channels_provider.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/channel_metadata_enrichment.dart';
import 'sections/channel_info_bar.dart';
import 'sections/channel_table.dart';
import 'sections/filter_dialogs.dart';
import 'sections/filter_row.dart';
import 'sections/hotbar.dart';

class AiroTvShell extends ConsumerStatefulWidget {
  const AiroTvShell({
    super.key,
    required this.channels,
    required this.videoStage,
    required this.onChannelSelected,
    this.currentChannel,
    this.metadataByChannelId = const {},
    this.availabilityByChannelId = const {},
    this.enrichMetadata = false,
  });

  final List<IPTVChannel> channels;
  final Widget videoStage;
  final ValueChanged<IPTVChannel> onChannelSelected;
  final IPTVChannel? currentChannel;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final bool enrichMetadata;

  @override
  ConsumerState<AiroTvShell> createState() => _AiroTvShellState();
}

class _AiroTvShellState extends ConsumerState<AiroTvShell> {
  final _snapshotCache = ChannelBrowserSnapshotCache();
  bool _countryPromptShowing = false;
  Timer? _visibleScanDebounce;
  String _visibleScanSignature = '';

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
    final table = ChannelTable(
      key: const ValueKey('airo-tv-channel-table'),
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
      onVisibleChannelsChanged: _scheduleVisibleChannelScan,
    );
    final infoBar = ChannelInfoBar(channel: widget.currentChannel);
    final hotbar = Hotbar(
      channels: widget.channels,
      onChannelSelected: widget.onChannelSelected,
    );
    final filterRow = FilterRow(dimensions: snapshot.dimensions);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chrome = [
          _ExplorerSection(label: 'LIVE', height: 60, child: infoBar),
          if (hasHotbar)
            _ExplorerSection(label: 'HOTBAR', height: 56, child: hotbar),
          _ExplorerSection(label: 'FILTER', height: 48, child: filterRow),
        ];
        final compactChrome = [infoBar, if (hasHotbar) hotbar, filterRow];
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Flexible(flex: 3, child: widget.videoStage),
              ...compactChrome,
              Expanded(flex: 4, child: table),
            ],
          );
        }
        final previewWidth = (constraints.maxWidth * 0.34)
            .clamp(320.0, 480.0)
            .toDouble();
        final previewHeight = previewWidth * 9 / 16;
        final panelWidth = (constraints.maxWidth * 0.88)
            .clamp(720.0, 1120.0)
            .toDouble();

        return Container(
          key: const ValueKey('airo-tv-explorer-wide-shell'),
          color: Colors.black,
          child: Column(
            children: [
              Flexible(
                flex: 3,
                child: Center(
                  child: ConstrainedBox(
                    key: const ValueKey('airo-tv-explorer-video-stage'),
                    constraints: BoxConstraints.tightFor(
                      width: previewWidth,
                      height: previewHeight,
                    ),
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 640,
                          height: 360,
                          child: widget.videoStage,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
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
                          Expanded(child: table),
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
    final visible = channels.take(18).toList(growable: false);
    final signature = visible.map((channel) => channel.id).join(',');
    if (signature.isEmpty || signature == _visibleScanSignature) return;
    _visibleScanSignature = signature;
    _visibleScanDebounce?.cancel();
    _visibleScanDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref
          .read(channelAutoScanProvider.notifier)
          .start(
            scopeId: 'airo-tv-visible|$signature',
            channels: visible,
            maxConcurrentRequests: ref.read(
              channelAutoScanMaxConcurrentRequestsProvider,
            ),
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
      await showFilterOptionDialog(
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
