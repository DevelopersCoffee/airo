import 'package:platform_epg/platform_epg.dart';

import 'xtream_client.dart';

/// [CompactEpgRepository] backed by Xtream's `get_short_epg`.
///
/// Xtream's short-EPG endpoint only returns a bounded listing per channel
/// (current + a handful of upcoming), which is exactly the shape
/// [CompactEpgRepository] expects — no full-timetable materialization
/// needed, unlike [XmltvCompactEpgRepository].
class XtreamEpgRepository implements CompactEpgRepository {
  XtreamEpgRepository(this._client, {required this.channelIdToStreamId});

  final XtreamClient _client;

  /// Maps the [IPTVChannel.id] values used elsewhere in the app (e.g.
  /// `'xtream-101'`) back to the raw Xtream `stream_id` this client needs.
  final int? Function(String channelId) channelIdToStreamId;

  Future<CompactEpgEntry?> _entryFor(String channelId, DateTime now) async {
    final streamId = channelIdToStreamId(channelId);
    if (streamId == null) return null;

    final listings = await _client.getShortEpg(streamId: streamId);
    final programs = [
      for (final listing in listings)
        CompactEpgProgram(
          programId: listing.id,
          title: listing.title,
          subtitle: listing.description,
          startsAt: listing.start.toUtc(),
          endsAt: listing.end.toUtc(),
        ),
    ];

    return CompactEpgEntry.fromPrograms(
      channelId: channelId,
      channelName: channelId,
      now: now,
      programs: programs,
    );
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final entries = <CompactEpgEntry>[];
    for (final channelId in channelIds) {
      final entry = await _entryFor(channelId, now);
      if (entry != null) entries.add(entry);
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
      final streamId = channelIdToStreamId(channelId);
      if (streamId == null) continue;

      final listings = await _client.getShortEpg(streamId: streamId);
      final programs = [
        for (final listing in listings)
          if (listing.end.toUtc().isAfter(query.windowStart) &&
              listing.start.toUtc().isBefore(query.windowEnd))
            CompactEpgProgram(
              programId: listing.id,
              title: listing.title,
              subtitle: listing.description,
              startsAt: listing.start.toUtc(),
              endsAt: listing.end.toUtc(),
            ),
      ];
      entries.add(
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: programs,
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
