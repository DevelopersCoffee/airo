import 'package:platform_epg/platform_epg.dart';

/// [CompactEpgRepository] backed by Stalker's `get_epg_info`.
///
/// Takes a fetch callback rather than a `StalkerClient` directly: Stalker's
/// EPG endpoint needs the same handshake token as channel listing, and the
/// call site (feature_iptv's provider layer) already holds a valid token
/// from loading channels — re-deriving it here would mean a second
/// handshake per guide request.
///
/// The callback returns already-parsed [CompactEpgProgram]s with UTC
/// `startsAt`/`endsAt` — any raw-JSON timestamp parsing (and the
/// timezone-marker pitfalls that come with it) happens at the call site,
/// not in this repository.
class StalkerEpgRepository implements CompactEpgRepository {
  StalkerEpgRepository(this._fetchProgrammes);

  /// Returns programmes for [channelId] with `startsAt`/`endsAt` already
  /// in UTC, in start-time order.
  final Future<List<CompactEpgProgram>> Function(String channelId)
  _fetchProgrammes;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final entries = <CompactEpgEntry>[];
    for (final channelId in channelIds) {
      final programs = await _fetchProgrammes(channelId);
      entries.add(
        CompactEpgEntry.fromPrograms(
          channelId: channelId,
          channelName: channelId,
          now: now,
          programs: programs,
        ),
      );
    }
    return CompactEpgSlice(
      entries: entries,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final entries = <CompactEpgWindowEntry>[];
    for (final channelId in query.channelIds) {
      final programs = await _fetchProgrammes(channelId);
      entries.add(
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: [
            for (final program in programs)
              if (program.endsAt.isAfter(query.windowStart) &&
                  program.startsAt.isBefore(query.windowEnd))
                program,
          ],
        ),
      );
    }
    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: query.now,
      expiresAt: query.now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }
}
