import 'dart:io';

import 'compact_epg_models.dart';
import 'compact_epg_snapshot_codec.dart';

abstract class CompactEpgSnapshotStore {
  const CompactEpgSnapshotStore();

  Future<String?> readSnapshot();

  Future<void> writeSnapshot(String payload);

  Future<void> deleteSnapshot();
}

class FileCompactEpgSnapshotStore implements CompactEpgSnapshotStore {
  const FileCompactEpgSnapshotStore({required this.fileProvider});

  final Future<File> Function() fileProvider;

  @override
  Future<String?> readSnapshot() async {
    final file = await fileProvider();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> writeSnapshot(String payload) async {
    final file = await fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(payload, flush: true);
  }

  @override
  Future<void> deleteSnapshot() async {
    final file = await fileProvider();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class InMemoryCompactEpgSnapshotStore implements CompactEpgSnapshotStore {
  InMemoryCompactEpgSnapshotStore([this._payload]);

  String? _payload;

  String? get payload => _payload;

  @override
  Future<String?> readSnapshot() async => _payload;

  @override
  Future<void> writeSnapshot(String payload) async {
    _payload = payload;
  }

  @override
  Future<void> deleteSnapshot() async {
    _payload = null;
  }
}

class SnapshotBackedCompactEpgRepository implements CompactEpgRepository {
  const SnapshotBackedCompactEpgRepository({
    required this.store,
    this.fallback = const EmptyCompactEpgRepository(),
    this.returnExpiredSnapshots = true,
  });

  final CompactEpgSnapshotStore store;
  final CompactEpgRepository fallback;
  final bool returnExpiredSnapshots;

  Future<void> saveSnapshot(CompactEpgSlice slice) {
    return store.writeSnapshot(encodeCompactEpgSlice(slice));
  }

  Future<void> clearSnapshot() {
    return store.deleteSnapshot();
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final payload = await store.readSnapshot();
    if (payload == null || payload.trim().isEmpty) {
      return fallback.loadCurrentNext(channelIds: channelIds, now: now);
    }

    try {
      final slice = decodeCompactEpgSlice(payload);
      if (!returnExpiredSnapshots && slice.isExpired(now.toUtc())) {
        return fallback.loadCurrentNext(channelIds: channelIds, now: now);
      }
      return slice.filterForChannels(channelIds);
    } on FormatException {
      return fallback.loadCurrentNext(channelIds: channelIds, now: now);
    }
  }
}
