import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_network_discovery/platform_network_discovery.dart';

void main() {
  group('Airo local network discovery', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroNodeCapabilityAdvertisement advertisement({
      String nodeId = 'node-tv-1',
      DateTime? issuedAt,
      DateTime? expiresAt,
    }) {
      return AiroNodeCapabilityAdvertisement(
        identity: AiroNodeIdentity(
          nodeId: nodeId,
          role: AiroNodeRole.tvReceiver,
          productProfile: AiroNodeProductProfile.liteReceiver,
          platformCategory: AiroNodePlatformCategory.androidTv,
        ),
        lifecycle: AiroNodeLifecycleState.available,
        trustState: AiroNodeTrustState.unknown,
        capabilities: const {
          AiroNodeCapability.playback,
          AiroNodeCapability.compactEpg,
          AiroNodeCapability.basicSearch,
        },
        issuedAt: issuedAt ?? now,
        expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
      );
    }

    AiroDiscoveryServiceRecord record({
      String nodeId = 'node-tv-1',
      String recordId = 'record-1',
      DateTime? lastSeenAt,
      DateTime? expiresAt,
      Map<String, String> extraTxtRecords = const {},
    }) {
      return AiroDiscoveryServiceRecord(
        recordId: recordId,
        instanceName: 'Airo TV',
        hostName: 'airo-tv.local',
        port: 41234,
        advertisement: advertisement(nodeId: nodeId, expiresAt: expiresAt),
        discoveredAt: now,
        lastSeenAt: lastSeenAt ?? now,
        extraTxtRecords: extraTxtRecords,
      );
    }

    test('service record emits _airotv TXT metadata from core protocol', () {
      final txt = record().toTxtRecords();

      expect(txt['service'], kAiroDiscoveryServiceType);
      expect(txt['nodeId'], 'node-tv-1');
      expect(txt['role'], 'tv_receiver');
      expect(txt['profile'], 'lite_receiver');
      expect(txt['capabilities'], contains('playback'));
      expect(txt.toString(), isNot(contains('playlist')));
      expect(txt.toString(), isNot(contains('credential')));
      expect(txt.toString(), isNot(contains('history')));
    });

    test('privacy filter rejects prohibited discovery metadata', () {
      expect(
        () => record(extraTxtRecords: const {'playlistUrl': 'hidden'}),
        throwsArgumentError,
      );
      expect(
        () => record(extraTxtRecords: const {'note': 'https://example.com'}),
        throwsArgumentError,
      );
      expect(
        () => record(extraTxtRecords: const {'note': '/Users/example/list'}),
        throwsArgumentError,
      );
      expect(
        () => record(extraTxtRecords: const {'note': 'seen 192.168.1.10'}),
        throwsArgumentError,
      );
      expect(
        () => record(extraTxtRecords: const {'note': 'Bearer abc.def'}),
        throwsArgumentError,
      );
    });

    test('active snapshot merges duplicates to newest non-expired record', () {
      final older = record(
        recordId: 'older',
        lastSeenAt: now.subtract(const Duration(seconds: 5)),
      );
      final newer = record(recordId: 'newer', lastSeenAt: now);

      final snapshot = AiroDiscoverySnapshot.active(
        records: [older, newer],
        now: now,
      );

      expect(snapshot.records, hasLength(1));
      expect(snapshot.recordForNode('node-tv-1')?.recordId, 'newer');
    });

    test('active snapshot excludes stale discovery records', () {
      final snapshot = AiroDiscoverySnapshot.active(
        records: [
          record(
            recordId: 'stale',
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          record(recordId: 'fresh'),
        ],
        now: now,
      );

      expect(snapshot.records.map((record) => record.recordId), ['fresh']);
    });

    test('no-op adapter starts and stops without discovered nodes', () async {
      final adapter = AiroNoOpLocalDiscoveryAdapter();

      await adapter.start(AiroDiscoveryMode.browse);
      final started = await adapter.currentSnapshot(now);
      await adapter.stop();
      final stopped = await adapter.currentSnapshot(now);

      expect(started.records, isEmpty);
      expect(
        started.adapterState,
        AiroDiscoveryAdapterState.permissionRequired,
      );
      expect(started.permissionState, AiroDiscoveryPermissionState.unavailable);
      expect(stopped.adapterState, AiroDiscoveryAdapterState.stopped);
    });

    test('fake adapter emits discovered and lost snapshots', () async {
      final adapter = AiroFakeLocalDiscoveryAdapter();
      final events = <AiroDiscoverySnapshot>[];
      final subscription = adapter.snapshots.listen(events.add);

      await adapter.start(AiroDiscoveryMode.browse);
      adapter.upsert(record(), now);
      adapter.removeNode('node-tv-1', now.add(const Duration(seconds: 1)));

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(events.map((event) => event.records.length), [0, 1, 0]);
      expect(events.first.adapterState, AiroDiscoveryAdapterState.browsing);
    });
  });
}
