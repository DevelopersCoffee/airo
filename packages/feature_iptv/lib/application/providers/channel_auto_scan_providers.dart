import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';

import '../channel_auto_scan_controller.dart';
import 'iptv_providers.dart';

/// App-level HTTP adapter; it inherits no credentials beyond the channel's
/// existing, in-memory stream headers.
final streamProbeTransportProvider = Provider<StreamProbeTransport>((ref) {
  return DioStreamProbeTransport(ref.watch(dioProvider));
});

final streamAvailabilityProbeProvider = Provider<StreamAvailabilityProbe>((
  ref,
) {
  return StreamAvailabilityProbe(
    transport: ref.watch(streamProbeTransportProvider),
  );
});

final channelAutoScanProvider =
    StateNotifierProvider<ChannelAutoScanController, ChannelAutoScanState>(
      (ref) => ChannelAutoScanController(
        probe: ref.watch(streamAvailabilityProbeProvider),
      ),
    );

/// Describes the exact filter snapshot to which a temporary removal applies.
/// The value is intentionally session-only and never sent to the probe.
final channelAutoScanScopeProvider = Provider<String>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final flavor = ref.watch(selectedFlavorProvider);
  final query = ref.watch(channelSearchQueryProvider).trim();
  final channelIds = ref
      .watch(filteredChannelsProvider)
      .map((channel) => channel.id)
      .join(',');
  return '${category.name}|${flavor?.name ?? ''}|$query|$channelIds';
});

/// The regular active filter with a completed Auto Scan's temporary hide set
/// applied only when its scope still matches.
final autoScanFilteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final channels = ref.watch(filteredChannelsProvider);
  final scopeId = ref.watch(channelAutoScanScopeProvider);
  ref.watch(channelAutoScanProvider);
  return ref
      .read(channelAutoScanProvider.notifier)
      .channelsForScope(scopeId: scopeId, channels: channels);
});

bool isChannelConfirmedUnavailable(StreamAvailability? availability) {
  return availability == StreamAvailability.unavailable;
}

bool canSelectChannelWithAvailability(StreamAvailability? availability) {
  return !isChannelConfirmedUnavailable(availability);
}

final nextSelectableChannelProvider = Provider<IPTVChannel?>((ref) {
  final availabilityByChannelId = ref
      .watch(channelAutoScanProvider)
      .availabilityByChannelId;
  return channelAfter(
    currentChannel: ref.watch(currentChannelProvider),
    channels: ref.watch(filteredChannelsProvider),
    canUseChannel: (channel) =>
        canSelectChannelWithAvailability(availabilityByChannelId[channel.id]),
  );
});

final previousSelectableChannelProvider = Provider<IPTVChannel?>((ref) {
  final availabilityByChannelId = ref
      .watch(channelAutoScanProvider)
      .availabilityByChannelId;
  return channelBefore(
    currentChannel: ref.watch(currentChannelProvider),
    channels: ref.watch(filteredChannelsProvider),
    canUseChannel: (channel) =>
        canSelectChannelWithAvailability(availabilityByChannelId[channel.id]),
  );
});
