import 'package:core_native/core_native.dart';
import 'package:equatable/equatable.dart';

const String kAiroSyncEntitySchemaVersion = '1.0.0';

enum AiroSyncEntityType {
  playlist,
  channel,
  favorite,
  history,
  continueWatching,
  profile,
  settings,
  collection,
}

class AiroSyncVectorClock extends Equatable {
  AiroSyncVectorClock(Map<String, int> counters)
    : counters = Map.unmodifiable(counters) {
    if (counters.entries.any(
      (entry) => entry.key.trim().isEmpty || entry.value < 0,
    )) {
      throw ArgumentError('Vector-clock nodes and counters must be valid');
    }
  }

  final Map<String, int> counters;

  AiroSyncVectorClock mergedWith(AiroSyncVectorClock other) {
    final merged = {...counters};
    for (final entry in other.counters.entries) {
      final current = merged[entry.key] ?? 0;
      if (entry.value > current) merged[entry.key] = entry.value;
    }
    return AiroSyncVectorClock(merged);
  }

  List<AiroVectorClockCounter> toNative() => [
    for (final entry in counters.entries)
      AiroVectorClockCounter(nodeId: entry.key, counter: entry.value),
  ];

  @override
  List<Object?> get props => [counters];
}

abstract interface class AiroSyncClockComparator {
  Future<AiroVectorClockRelation> compare(
    AiroSyncVectorClock left,
    AiroSyncVectorClock right,
  );
}

class AiroNativeSyncClockComparator implements AiroSyncClockComparator {
  const AiroNativeSyncClockComparator({
    this.engine = const NativePreferredAiroEngine(),
  });

  final AiroNativeEngine engine;

  @override
  Future<AiroVectorClockRelation> compare(
    AiroSyncVectorClock left,
    AiroSyncVectorClock right,
  ) {
    return engine.compareVectorClocks(
      left: left.toNative(),
      right: right.toNative(),
    );
  }
}

class AiroSyncField extends Equatable {
  const AiroSyncField({
    required this.value,
    required this.clock,
    required this.updatedAt,
    required this.originNodeId,
  }) : assert(
         value == null || value is String || value is num || value is bool,
         'Sync field values must be relational scalars',
       );

  final Object? value;
  final AiroSyncVectorClock clock;
  final DateTime updatedAt;
  final String originNodeId;

  @override
  List<Object?> get props => [value, clock, updatedAt, originNodeId];
}

class AiroSyncEntity extends Equatable {
  AiroSyncEntity({
    required this.uuid,
    required this.type,
    required this.version,
    required this.clock,
    required Map<String, AiroSyncField> fields,
    required this.updatedAt,
    this.deletedAt,
    this.deletionClock,
    this.schemaVersion = kAiroSyncEntitySchemaVersion,
  }) : fields = Map.unmodifiable(fields) {
    if (uuid.trim().isEmpty ||
        version < 1 ||
        (deletedAt == null) != (deletionClock == null) ||
        fields.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('Sync entity shape is invalid');
    }
  }

  final String schemaVersion;
  final String uuid;
  final AiroSyncEntityType type;
  final int version;
  final AiroSyncVectorClock clock;
  final Map<String, AiroSyncField> fields;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final AiroSyncVectorClock? deletionClock;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    schemaVersion,
    uuid,
    type,
    version,
    clock,
    fields,
    updatedAt,
    deletedAt,
    deletionClock,
  ];
}

enum AiroSyncMergeCode {
  identical,
  leftDominates,
  rightDominates,
  fieldsMerged,
  concurrentFieldResolved,
  tombstoneApplied,
  concurrentDeletePreserved,
  incompatibleEntity,
}

class AiroSyncMergeResult extends Equatable {
  AiroSyncMergeResult({
    required this.entity,
    required Iterable<AiroSyncMergeCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroSyncEntity entity;
  final List<AiroSyncMergeCode> codes;

  bool has(AiroSyncMergeCode code) => codes.contains(code);

  @override
  List<Object?> get props => [entity, codes];
}

class AiroSyncConflictResolver {
  const AiroSyncConflictResolver({required this.comparator});

  final AiroSyncClockComparator comparator;

  Future<AiroSyncMergeResult> merge(
    AiroSyncEntity left,
    AiroSyncEntity right,
  ) async {
    if (left.uuid != right.uuid ||
        left.type != right.type ||
        left.schemaVersion != right.schemaVersion) {
      return AiroSyncMergeResult(
        entity: left,
        codes: const [AiroSyncMergeCode.incompatibleEntity],
      );
    }
    final deletion = await _resolveDeletion(left, right);
    if (deletion != null) return deletion;

    final fields = <String, AiroSyncField>{};
    final codes = <AiroSyncMergeCode>{};
    final fieldNames = {...left.fields.keys, ...right.fields.keys}.toList()
      ..sort();
    for (final name in fieldNames) {
      final leftField = left.fields[name];
      final rightField = right.fields[name];
      if (leftField == null) {
        fields[name] = rightField!;
        codes.add(AiroSyncMergeCode.fieldsMerged);
        continue;
      }
      if (rightField == null) {
        fields[name] = leftField;
        codes.add(AiroSyncMergeCode.fieldsMerged);
        continue;
      }
      final relation = await comparator.compare(
        leftField.clock,
        rightField.clock,
      );
      fields[name] = switch (relation) {
        AiroVectorClockRelation.equal => _stableField(leftField, rightField),
        AiroVectorClockRelation.leftDominates => leftField,
        AiroVectorClockRelation.rightDominates => rightField,
        AiroVectorClockRelation.concurrent => _stableField(
          leftField,
          rightField,
        ),
      };
      codes.add(switch (relation) {
        AiroVectorClockRelation.equal => AiroSyncMergeCode.identical,
        AiroVectorClockRelation.leftDominates =>
          AiroSyncMergeCode.leftDominates,
        AiroVectorClockRelation.rightDominates =>
          AiroSyncMergeCode.rightDominates,
        AiroVectorClockRelation.concurrent =>
          AiroSyncMergeCode.concurrentFieldResolved,
      });
    }
    return AiroSyncMergeResult(
      entity: AiroSyncEntity(
        uuid: left.uuid,
        type: left.type,
        version: left.version > right.version ? left.version : right.version,
        clock: left.clock.mergedWith(right.clock),
        fields: fields,
        updatedAt: left.updatedAt.isAfter(right.updatedAt)
            ? left.updatedAt
            : right.updatedAt,
      ),
      codes: codes,
    );
  }

  Future<AiroSyncMergeResult?> _resolveDeletion(
    AiroSyncEntity left,
    AiroSyncEntity right,
  ) async {
    if (!left.isDeleted && !right.isDeleted) return null;
    if (left.isDeleted && right.isDeleted) {
      final winner = _stableEntity(left, right);
      return AiroSyncMergeResult(
        entity: winner,
        codes: const [AiroSyncMergeCode.tombstoneApplied],
      );
    }
    final deleted = left.isDeleted ? left : right;
    final live = left.isDeleted ? right : left;
    final relation = await comparator.compare(
      deleted.deletionClock!,
      live.clock,
    );
    if (relation == AiroVectorClockRelation.leftDominates ||
        relation == AiroVectorClockRelation.equal) {
      return AiroSyncMergeResult(
        entity: deleted,
        codes: const [AiroSyncMergeCode.tombstoneApplied],
      );
    }
    return AiroSyncMergeResult(
      entity: live,
      codes: const [AiroSyncMergeCode.concurrentDeletePreserved],
    );
  }

  AiroSyncField _stableField(AiroSyncField left, AiroSyncField right) {
    final time = left.updatedAt.compareTo(right.updatedAt);
    if (time != 0) return time > 0 ? left : right;
    final origin = left.originNodeId.compareTo(right.originNodeId);
    if (origin != 0) return origin < 0 ? left : right;
    return '${left.value}'.compareTo('${right.value}') <= 0 ? left : right;
  }

  AiroSyncEntity _stableEntity(AiroSyncEntity left, AiroSyncEntity right) {
    final time = left.deletedAt!.compareTo(right.deletedAt!);
    if (time != 0) return time > 0 ? left : right;
    return _canonicalClock(
              left.clock,
            ).compareTo(_canonicalClock(right.clock)) <=
            0
        ? left
        : right;
  }

  String _canonicalClock(AiroSyncVectorClock clock) {
    final entries = clock.counters.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries.map((entry) => '${entry.key}:${entry.value}').join('|');
  }
}

enum AiroSyncTransportKind { lan, bluetooth, cloud, qr, usb, nearby }

class AiroSyncTransportSecurity extends Equatable {
  const AiroSyncTransportSecurity({
    required this.encrypted,
    required this.compressed,
    required this.pairedIdentityRef,
  });

  final bool encrypted;
  final bool compressed;
  final String pairedIdentityRef;

  bool get accepted =>
      encrypted && compressed && pairedIdentityRef.trim().isNotEmpty;

  @override
  List<Object?> get props => [encrypted, compressed, pairedIdentityRef];
}

class AiroSyncEnvelope extends Equatable {
  const AiroSyncEnvelope({
    required this.envelopeId,
    required this.entity,
    required this.createdAt,
  });

  final String envelopeId;
  final AiroSyncEntity entity;
  final DateTime createdAt;

  @override
  List<Object?> get props => [envelopeId, entity, createdAt];
}

abstract interface class AiroSyncTransport {
  AiroSyncTransportKind get kind;

  AiroSyncTransportSecurity get security;

  Future<void> push(AiroSyncEnvelope envelope);

  Future<List<AiroSyncEnvelope>> pull();
}

abstract interface class AiroSyncExchange {
  Future<void> push(AiroSyncEnvelope envelope);

  Future<List<AiroSyncEnvelope>> pull();
}

abstract base class AiroExchangeSyncTransport implements AiroSyncTransport {
  const AiroExchangeSyncTransport(this._exchange, {required this.security});

  @override
  final AiroSyncTransportSecurity security;

  final AiroSyncExchange _exchange;

  @override
  Future<List<AiroSyncEnvelope>> pull() => _exchange.pull();

  @override
  Future<void> push(AiroSyncEnvelope envelope) => _exchange.push(envelope);
}

final class AiroLanSyncTransport extends AiroExchangeSyncTransport {
  const AiroLanSyncTransport({
    required AiroSyncTransportSecurity security,
    required AiroSyncExchange exchange,
  }) : super(exchange, security: security);

  @override
  AiroSyncTransportKind get kind => AiroSyncTransportKind.lan;
}

final class AiroCloudSyncTransport extends AiroExchangeSyncTransport {
  const AiroCloudSyncTransport({
    required AiroSyncTransportSecurity security,
    required AiroSyncExchange exchange,
  }) : super(exchange, security: security);

  @override
  AiroSyncTransportKind get kind => AiroSyncTransportKind.cloud;
}

class AiroFakeSyncTransport implements AiroSyncTransport {
  AiroFakeSyncTransport({
    required this.kind,
    required this.security,
    Iterable<AiroSyncEnvelope> incoming = const [],
  }) : _incoming = List.of(incoming);

  @override
  final AiroSyncTransportKind kind;

  @override
  final AiroSyncTransportSecurity security;

  final List<AiroSyncEnvelope> _incoming;
  final List<AiroSyncEnvelope> pushed = [];

  @override
  Future<List<AiroSyncEnvelope>> pull() async {
    final result = List<AiroSyncEnvelope>.unmodifiable(_incoming);
    _incoming.clear();
    return result;
  }

  @override
  Future<void> push(AiroSyncEnvelope envelope) async {
    pushed.add(envelope);
  }
}

class AiroSyncRunResult extends Equatable {
  const AiroSyncRunResult({
    required this.appliedCount,
    required this.duplicateCount,
    required this.rejectedInsecure,
  });

  final int appliedCount;
  final int duplicateCount;
  final bool rejectedInsecure;

  @override
  List<Object?> get props => [appliedCount, duplicateCount, rejectedInsecure];
}

abstract interface class AiroSyncEntityPersistence {
  Future<AiroSyncEntity?> read(String uuid);

  Future<void> write(AiroSyncEntity entity);
}

class AiroRelationalSyncEntityPersistence implements AiroSyncEntityPersistence {
  const AiroRelationalSyncEntityPersistence({required this.databasePath});

  final String databasePath;

  @override
  Future<AiroSyncEntity?> read(String uuid) async {
    final row = await readAiroRelationalSyncEntity(
      path: databasePath,
      uuid: uuid,
    );
    return row == null ? null : _fromRelational(row);
  }

  @override
  Future<void> write(AiroSyncEntity entity) async {
    final written = await upsertAiroRelationalSyncEntity(
      path: databasePath,
      entity: _toRelational(entity),
    );
    if (!written) {
      throw StateError('relational_sync_store_unavailable');
    }
  }

  AiroRelationalSyncEntity _toRelational(AiroSyncEntity entity) {
    return AiroRelationalSyncEntity(
      uuid: entity.uuid,
      entityType: entity.type.name,
      schemaVersion: entity.schemaVersion,
      entityVersion: entity.version,
      updatedAtMicros: entity.updatedAt.microsecondsSinceEpoch,
      deletedAtMicros: entity.deletedAt?.microsecondsSinceEpoch,
      clock: entity.clock.counters,
      deletionClock: entity.deletionClock?.counters ?? const {},
      fields: [
        for (final entry in entity.fields.entries)
          AiroRelationalSyncField(
            name: entry.key,
            value: entry.value.value,
            updatedAtMicros: entry.value.updatedAt.microsecondsSinceEpoch,
            originNodeId: entry.value.originNodeId,
            clock: entry.value.clock.counters,
          ),
      ],
    );
  }

  AiroSyncEntity _fromRelational(AiroRelationalSyncEntity entity) {
    final type = AiroSyncEntityType.values
        .where((value) => value.name == entity.entityType)
        .firstOrNull;
    if (type == null) throw StateError('unsupported_sync_entity_type');
    return AiroSyncEntity(
      uuid: entity.uuid,
      type: type,
      version: entity.entityVersion,
      clock: AiroSyncVectorClock(entity.clock),
      fields: {
        for (final field in entity.fields)
          field.name: AiroSyncField(
            value: field.value,
            clock: AiroSyncVectorClock(field.clock),
            updatedAt: DateTime.fromMicrosecondsSinceEpoch(
              field.updatedAtMicros,
              isUtc: true,
            ),
            originNodeId: field.originNodeId,
          ),
      },
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(
        entity.updatedAtMicros,
        isUtc: true,
      ),
      deletedAt: entity.deletedAtMicros == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(
              entity.deletedAtMicros!,
              isUtc: true,
            ),
      deletionClock: entity.deletedAtMicros == null
          ? null
          : AiroSyncVectorClock(entity.deletionClock),
      schemaVersion: entity.schemaVersion,
    );
  }
}

class AiroSyncEngine {
  AiroSyncEngine({required this.resolver, this.persistence});

  final AiroSyncConflictResolver resolver;
  final AiroSyncEntityPersistence? persistence;
  final Map<String, AiroSyncEntity> _entities = {};
  final Set<String> _appliedEnvelopeIds = {};

  AiroSyncEntity? entity(String uuid) => _entities[uuid];

  Future<AiroSyncRunResult> synchronize(AiroSyncTransport transport) async {
    if (!transport.security.accepted) {
      return const AiroSyncRunResult(
        appliedCount: 0,
        duplicateCount: 0,
        rejectedInsecure: true,
      );
    }
    var applied = 0;
    var duplicates = 0;
    for (final envelope in await transport.pull()) {
      if (!_appliedEnvelopeIds.add(envelope.envelopeId)) {
        duplicates++;
        continue;
      }
      final current =
          _entities[envelope.entity.uuid] ??
          await persistence?.read(envelope.entity.uuid);
      final merged = current == null
          ? envelope.entity
          : (await resolver.merge(current, envelope.entity)).entity;
      _entities[envelope.entity.uuid] = merged;
      await persistence?.write(merged);
      applied++;
    }
    return AiroSyncRunResult(
      appliedCount: applied,
      duplicateCount: duplicates,
      rejectedInsecure: false,
    );
  }
}
