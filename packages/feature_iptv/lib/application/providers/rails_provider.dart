import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import 'iptv_providers.dart';

/// The generated browse rails. UI renders this list verbatim — rail
/// content, ordering, and visibility are decided by the Media Engine
/// (and later the Edge Intelligence SDK), never by widgets.
final railsProvider = FutureProvider<List<RailResult>>((ref) async {
  final channels = await ref.watch(iptvChannelsProvider.future);

  List<IPTVChannel> favorites;
  try {
    favorites = await ref.watch(favoriteChannelsProvider.future);
  } catch (_) {
    // Favorites are an enhancement signal; rails must render without them.
    favorites = const <IPTVChannel>[];
  }

  List<IPTVChannel> recents;
  try {
    recents = await ref.watch(recentlyWatchedChannelsProvider.future);
  } catch (_) {
    // Recents are an enhancement signal; rails must render without them.
    recents = const <IPTVChannel>[];
  }

  final provider = DefaultRailProvider(
    channels: channels,
    favoriteIds: favorites.map((ch) => ch.id).toSet(),
    recentIds: [for (final ch in recents) ch.id],
    // Watch counts arrive when core_watch_progress wiring lands
    // (spec §9 — Continue Watching reserved).
  );
  return provider.buildAll(DefaultRailCatalog.definitions());
});
