import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

/// Shared bounded guide-window query with CV-015 match-override semantics:
/// each channel is queried under its override EPG id if one is set, hidden
/// groups are excluded (CV-021), and results are remapped back to the
/// original [IPTVChannel.id] so callers never need to know an override was
/// involved. Shared by the paged guide window (Live Grid Navigation) so all
/// guide surfaces use one query path.
Future<CompactEpgWindow> queryGuideWindowWithOverrides({
  required List<IPTVChannel> channels,
  required Map<String, String> overrides,
  required Set<String> hiddenGroupIds,
  required CompactEpgRepository repository,
  required DateTime windowStart,
  required DateTime windowEnd,
  required DateTime now,
}) async {
  final epgIdToChannelId = <String, String>{};
  final queryIds = <String>[];
  for (final channel in channels) {
    if (hiddenGroupIds.contains(channel.group)) continue;
    // Manual override wins; otherwise try the playlist's own xmltv-id
    // candidates (full id, then the id with `@quality` stripped). The
    // first playlist channel to claim an EPG id keeps it — later channels
    // sharing the same alias still get their own row via a distinct id.
    final override = overrides[channel.id];
    final candidates = override != null ? [override] : channel.epgLookupIds;
    for (final epgId in candidates) {
      if (epgId.trim().isEmpty) continue;
      epgIdToChannelId.putIfAbsent(epgId, () => channel.id);
      queryIds.add(epgId);
    }
  }

  final rawWindow = await repository.loadWindow(
    GuideWindowQuery(
      channelIds: queryIds,
      windowStart: windowStart,
      windowEnd: windowEnd,
      now: now,
    ),
  );

  // Never leak a raw EPG id (numeric or xmltv-org) into the returned
  // window: every entry is keyed by the playlist IPTVChannel.id so a Guide
  // tap can play that row's stream directly (click-through). One playlist
  // channel can match on more than one alias; keep only its first entry.
  final remappedByChannelId = <String, CompactEpgWindowEntry>{};
  for (final entry in rawWindow.entries) {
    final channelId = epgIdToChannelId[entry.channelId];
    if (channelId == null) continue;
    remappedByChannelId.putIfAbsent(
      channelId,
      () => CompactEpgWindowEntry(
        channelId: channelId,
        channelName: entry.channelName,
        channelNumber: entry.channelNumber,
        programs: entry.programs,
        sourceRef: entry.sourceRef,
      ),
    );
  }

  return CompactEpgWindow(
    entries: remappedByChannelId.values.toList(growable: false),
    windowStart: rawWindow.windowStart,
    windowEnd: rawWindow.windowEnd,
    generatedAt: rawWindow.generatedAt,
    expiresAt: rawWindow.expiresAt,
    source: rawWindow.source,
    schemaVersion: rawWindow.schemaVersion,
  );
}

/// Merges a freshly loaded page into the accumulated paged window: programs
/// are concatenated per channel, deduped by `programId` (pages can straddle
/// a program), and sorted by `startsAt`. The merged window spans
/// `[base.windowStart, page.windowEnd)`.
///
/// Precondition: pages merge in forward chronological order (each [page]
/// starts where [base] ended) — the paged window notifier only appends
/// forward pages.
CompactEpgWindow mergeGuideWindowPage(
  CompactEpgWindow? base,
  CompactEpgWindow page,
) {
  if (base == null) return page;

  final programsByChannel = <String, Map<String, CompactEpgProgram>>{};
  final metaByChannel = <String, CompactEpgWindowEntry>{};
  for (final entry in [...base.entries, ...page.entries]) {
    metaByChannel[entry.channelId] = entry;
    final programs = programsByChannel.putIfAbsent(
      entry.channelId,
      () => <String, CompactEpgProgram>{},
    );
    for (final program in entry.programs) {
      programs[program.programId] = program;
    }
  }

  final mergedEntries = [
    for (final channelId in programsByChannel.keys)
      CompactEpgWindowEntry(
        channelId: channelId,
        channelName: metaByChannel[channelId]!.channelName,
        channelNumber: metaByChannel[channelId]!.channelNumber,
        programs: programsByChannel[channelId]!.values.toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
        sourceRef: metaByChannel[channelId]!.sourceRef,
      ),
  ];

  return CompactEpgWindow(
    entries: mergedEntries,
    windowStart: base.windowStart,
    windowEnd: page.windowEnd,
    generatedAt: page.generatedAt,
    expiresAt: page.expiresAt,
    source: page.source,
    schemaVersion: page.schemaVersion,
  );
}
