import 'package:core_native/core_native.dart';
import 'package:core_orchestration_storage/core_orchestration_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseTime = DateTime.utc(2026, 7, 27, 12);
  const comparator = AiroNativeSyncClockComparator(
    engine: DartAiroNativeEngine(),
  );
  const resolver = AiroSyncConflictResolver(comparator: comparator);

  AiroSyncVectorClock clock(Map<String, int> values) =>
      AiroSyncVectorClock(values);

  AiroSyncField field(
    Object? value,
    Map<String, int> counters, {
    String origin = 'phone',
    DateTime? updatedAt,
  }) {
    return AiroSyncField(
      value: value,
      clock: clock(counters),
      updatedAt: updatedAt ?? baseTime,
      originNodeId: origin,
    );
  }

  AiroSyncEntity entity({
    required Map<String, AiroSyncField> fields,
    Map<String, int> counters = const {'base': 1},
    DateTime? deletedAt,
    AiroSyncVectorClock? deletionClock,
  }) {
    return AiroSyncEntity(
      uuid: 'favorite-a',
      type: AiroSyncEntityType.favorite,
      version: 1,
      clock: clock(counters),
      fields: fields,
      updatedAt: baseTime,
      deletedAt: deletedAt,
      deletionClock: deletionClock,
    );
  }

  test('concurrent phone favorite and TV rename both survive', () async {
    final phone = entity(
      counters: const {'base': 1, 'phone': 1},
      fields: {
        'favorite': field(true, const {'base': 1, 'phone': 1}),
        'name': field('Old name', const {'base': 1}),
      },
    );
    final tv = entity(
      counters: const {'base': 1, 'tv': 1},
      fields: {
        'favorite': field(false, const {'base': 1}),
        'name': field('New name', const {'base': 1, 'tv': 1}, origin: 'tv'),
      },
    );

    final forward = await resolver.merge(phone, tv);
    final reverse = await resolver.merge(tv, phone);

    expect(forward.entity.fields['favorite']?.value, isTrue);
    expect(forward.entity.fields['name']?.value, 'New name');
    expect(reverse.entity, forward.entity);
  });

  test(
    'concurrent same-field writes use stable timestamp and origin',
    () async {
      final earlier = entity(
        fields: {
          'name': field('Earlier', const {'phone': 1}, updatedAt: baseTime),
        },
      );
      final later = entity(
        fields: {
          'name': field(
            'Later',
            const {'tv': 1},
            origin: 'tv',
            updatedAt: baseTime.add(const Duration(seconds: 1)),
          ),
        },
      );

      final result = await resolver.merge(earlier, later);

      expect(result.entity.fields['name']?.value, 'Later');
      expect(result.has(AiroSyncMergeCode.concurrentFieldResolved), isTrue);
    },
  );

  test(
    'dominant tombstone applies and concurrent delete preserves data',
    () async {
      final live = entity(
        counters: const {'phone': 1},
        fields: {
          'favorite': field(true, const {'phone': 1}),
        },
      );
      final dominantDelete = entity(
        counters: const {'phone': 2},
        fields: const {},
        deletedAt: baseTime.add(const Duration(seconds: 1)),
        deletionClock: clock(const {'phone': 2}),
      );
      final concurrentDelete = entity(
        counters: const {'tv': 1},
        fields: const {},
        deletedAt: baseTime.add(const Duration(seconds: 1)),
        deletionClock: clock(const {'tv': 1}),
      );

      expect(
        (await resolver.merge(dominantDelete, live)).entity.isDeleted,
        isTrue,
      );
      final concurrent = await resolver.merge(concurrentDelete, live);
      expect(concurrent.entity.isDeleted, isFalse);
      expect(
        concurrent.has(AiroSyncMergeCode.concurrentDeletePreserved),
        isTrue,
      );
    },
  );

  test(
    'LAN and cloud adapters use one engine contract and reject insecure input',
    () async {
      final update = entity(
        fields: {
          'favorite': field(true, const {'phone': 1}),
        },
      );
      final envelope = AiroSyncEnvelope(
        envelopeId: 'envelope-1',
        entity: update,
        createdAt: baseTime,
      );
      const secure = AiroSyncTransportSecurity(
        encrypted: true,
        compressed: true,
        pairedIdentityRef: 'identity-1',
      );
      final lanExchange = _FakeSyncExchange([envelope]);
      final cloudExchange = _FakeSyncExchange([envelope]);
      final lan = AiroLanSyncTransport(security: secure, exchange: lanExchange);
      final cloud = AiroCloudSyncTransport(
        security: secure,
        exchange: cloudExchange,
      );
      final insecure = AiroCloudSyncTransport(
        security: const AiroSyncTransportSecurity(
          encrypted: false,
          compressed: true,
          pairedIdentityRef: 'identity-1',
        ),
        exchange: _FakeSyncExchange([envelope]),
      );
      final engine = AiroSyncEngine(resolver: resolver);

      expect((await engine.synchronize(lan)).appliedCount, 1);
      expect((await engine.synchronize(cloud)).duplicateCount, 1);
      expect((await engine.synchronize(insecure)).rejectedInsecure, isTrue);
      expect(engine.entity('favorite-a')?.fields['favorite']?.value, isTrue);
      await lan.push(envelope);
      await cloud.push(envelope);
      expect(lanExchange.pushed, [envelope]);
      expect(cloudExchange.pushed, [envelope]);
    },
  );

  test(
    'engine hydrates and writes through relational persistence port',
    () async {
      final stored = entity(
        fields: {
          'name': field('Stored', const {'tv': 1}, origin: 'tv'),
        },
        counters: const {'tv': 1},
      );
      final incoming = entity(
        fields: {
          'favorite': field(true, const {'phone': 1}),
        },
        counters: const {'phone': 1},
      );
      final persistence = _FakeSyncPersistence(stored);
      final engine = AiroSyncEngine(
        resolver: resolver,
        persistence: persistence,
      );
      final transport = AiroFakeSyncTransport(
        kind: AiroSyncTransportKind.lan,
        security: const AiroSyncTransportSecurity(
          encrypted: true,
          compressed: true,
          pairedIdentityRef: 'identity-1',
        ),
        incoming: [
          AiroSyncEnvelope(
            envelopeId: 'persisted-envelope',
            entity: incoming,
            createdAt: baseTime,
          ),
        ],
      );

      await engine.synchronize(transport);

      expect(persistence.readIds, ['favorite-a']);
      expect(persistence.writes, hasLength(1));
      expect(persistence.writes.single.fields['name']?.value, 'Stored');
      expect(persistence.writes.single.fields['favorite']?.value, isTrue);
    },
  );
}

class _FakeSyncExchange implements AiroSyncExchange {
  _FakeSyncExchange(Iterable<AiroSyncEnvelope> incoming)
    : _incoming = List.of(incoming);

  final List<AiroSyncEnvelope> _incoming;
  final List<AiroSyncEnvelope> pushed = [];

  @override
  Future<List<AiroSyncEnvelope>> pull() async {
    final result = List<AiroSyncEnvelope>.of(_incoming);
    _incoming.clear();
    return result;
  }

  @override
  Future<void> push(AiroSyncEnvelope envelope) async {
    pushed.add(envelope);
  }
}

class _FakeSyncPersistence implements AiroSyncEntityPersistence {
  _FakeSyncPersistence(this.stored);

  final AiroSyncEntity? stored;
  final List<String> readIds = [];
  final List<AiroSyncEntity> writes = [];

  @override
  Future<AiroSyncEntity?> read(String uuid) async {
    readIds.add(uuid);
    return stored;
  }

  @override
  Future<void> write(AiroSyncEntity entity) async {
    writes.add(entity);
  }
}
