import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../music/application/providers/music_tracks_provider.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';

final mediaHubDiscoveryProvider =
    Provider.family<AsyncValue<List<UnifiedMediaContent>>, MediaMode>((
      ref,
      mode,
    ) {
      switch (mode) {
        case MediaMode.music:
          final tracks = ref.watch(musicTracksProvider);
          return tracks.whenData(
            (items) => items.map(UnifiedMediaContent.fromTrack).toList(),
          );
        case MediaMode.tv:
          final channels = ref.watch(iptvChannelsProvider);
          return channels.whenData(
            (items) => items.map(UnifiedMediaContent.fromChannel).toList(),
          );
      }
    });
