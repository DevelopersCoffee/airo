import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

import 'content_source.dart';

/// The existing M3U playlist path, re-homed under [ContentSource].
///
/// No parsing/fetch/cache behavior changes here — [M3uContentSourceAdapter]
/// delegates directly to the unmodified [M3UParserService].
class M3uContentSource extends ContentSource {
  const M3uContentSource({
    required super.id,
    required super.label,
    required this.playlistUrl,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: false,
           hasCatchup: false,
         ),
       );

  final String playlistUrl;

  @override
  ContentSourceKind get kind => ContentSourceKind.m3u;

  @override
  List<Object?> get props => [...super.props, playlistUrl];
}

/// Adapts [M3uContentSource] to a channel-loading call, wrapping the
/// existing [M3UParserService] with no change to its fetch/parse/cache
/// behavior.
class M3uContentSourceAdapter {
  M3uContentSourceAdapter(this.source, this._parser);

  final M3uContentSource source;
  final M3UParserService _parser;

  Future<List<IPTVChannel>> loadChannels({bool forceRefresh = false}) {
    return _parser.fetchPlaylist(forceRefresh: forceRefresh);
  }
}
