import 'package:platform_epg/platform_epg.dart';

import 'jellyfin_client.dart';

/// [CompactEpgRepository] backed by Jellyfin's `/LiveTv/Programs`.
///
/// Unlike Xtream/Stalker, Jellyfin's endpoint accepts a list of channel
/// IDs and an implicit "now" window in one call, so both
/// [loadCurrentNext] and [loadWindow] issue a single request rather than
/// one per channel.
class JellyfinEpgRepository implements CompactEpgRepository {
  JellyfinEpgRepository(
    this._client, {
    required this.accessToken,
    required this.userId,
  });

  final JellyfinClient _client;
  final String accessToken;
  final String userId;

  Future<List<JellyfinProgram>> _fetch(Iterable<String> channelIds) {
    final rawIds = [
      for (final id in channelIds) id.replaceFirst('jellyfin-', ''),
    ];
    return _client.getPrograms(
      accessToken: accessToken,
      userId: userId,
      channelIds: rawIds,
    );
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final programs = await _fetch(channelIds);
    final byChannel = <String, List<CompactEpgProgram>>{};
    for (final program in programs) {
      final channelId = 'jellyfin-${program.channelId}';
      (byChannel[channelId] ??= []).add(
        CompactEpgProgram(
          programId: program.id,
          title: program.name,
          subtitle: program.overview,
          startsAt: program.startDate.toUtc(),
          endsAt: program.endDate.toUtc(),
        ),
      );
    }

    final entries = [
      for (final channelId in channelIds)
        CompactEpgEntry.fromPrograms(
          channelId: channelId,
          channelName: channelId,
          now: now,
          programs: byChannel[channelId] ?? const [],
        ),
    ];

    return CompactEpgSlice(
      entries: entries,
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: CompactEpgSliceSource.delegatedNode,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final programs = await _fetch(query.channelIds);
    final byChannel = <String, List<CompactEpgProgram>>{};
    for (final program in programs) {
      final channelId = 'jellyfin-${program.channelId}';
      final startsAt = program.startDate.toUtc();
      final endsAt = program.endDate.toUtc();
      if (!endsAt.isAfter(query.windowStart) ||
          !startsAt.isBefore(query.windowEnd)) {
        continue;
      }
      (byChannel[channelId] ??= []).add(
        CompactEpgProgram(
          programId: program.id,
          title: program.name,
          subtitle: program.overview,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
    }

    final entries = [
      for (final channelId in query.channelIds)
        CompactEpgWindowEntry(
          channelId: channelId,
          channelName: channelId,
          programs: byChannel[channelId] ?? const [],
        ),
    ];

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
