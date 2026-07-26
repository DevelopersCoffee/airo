import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/relational_store.dart' as native_store;
import 'native_bridge.dart';

class AiroRelationalStoreStatus {
  const AiroRelationalStoreStatus({
    required this.schemaVersion,
    required this.foreignKeysEnabled,
  });

  final int schemaVersion;
  final bool foreignKeysEnabled;
}

class AiroRelationalSyncField {
  const AiroRelationalSyncField({
    required this.name,
    required this.value,
    required this.updatedAtMicros,
    required this.originNodeId,
    required this.clock,
  });

  final String name;
  final Object? value;
  final int updatedAtMicros;
  final String originNodeId;
  final Map<String, int> clock;
}

class AiroRelationalSyncEntity {
  const AiroRelationalSyncEntity({
    required this.uuid,
    required this.entityType,
    required this.schemaVersion,
    required this.entityVersion,
    required this.updatedAtMicros,
    required this.clock,
    required this.deletionClock,
    required this.fields,
    this.deletedAtMicros,
  });

  final String uuid;
  final String entityType;
  final String schemaVersion;
  final int entityVersion;
  final int updatedAtMicros;
  final int? deletedAtMicros;
  final Map<String, int> clock;
  final Map<String, int> deletionClock;
  final List<AiroRelationalSyncField> fields;
}

/// Applies the bundled relational schema using the Rust storage boundary.
///
/// Returns `null` on web or when the native library cannot initialize. Once
/// initialized, migration and SQLite failures are deliberately propagated.
Future<AiroRelationalStoreStatus?> initializeAiroRelationalStore(
  String path,
) async {
  if (path.trim().isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;

  final status = await native_store.initializeRelationalStore(path: path);
  return AiroRelationalStoreStatus(
    schemaVersion: status.schemaVersion,
    foreignKeysEnabled: status.foreignKeysEnabled,
  );
}

Future<bool> upsertAiroRelationalSyncEntity({
  required String path,
  required AiroRelationalSyncEntity entity,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return false;
  await native_store.upsertRelationalSyncEntity(
    path: path,
    entity: _toNativeEntity(entity),
  );
  return true;
}

Future<AiroRelationalSyncEntity?> readAiroRelationalSyncEntity({
  required String path,
  required String uuid,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  final entity = await native_store.readRelationalSyncEntity(
    path: path,
    uuid: uuid,
  );
  return entity == null ? null : _fromNativeEntity(entity);
}

native_store.RelationalSyncEntity _toNativeEntity(
  AiroRelationalSyncEntity entity,
) {
  return native_store.RelationalSyncEntity(
    uuid: entity.uuid,
    entityType: entity.entityType,
    schemaVersion: entity.schemaVersion,
    entityVersion: entity.entityVersion,
    updatedAtMicros: entity.updatedAtMicros,
    deletedAtMicros: entity.deletedAtMicros,
    clock: _toNativeClock(entity.clock),
    deletionClock: _toNativeClock(entity.deletionClock),
    fields: entity.fields.map(_toNativeField).toList(growable: false),
  );
}

native_store.RelationalSyncField _toNativeField(AiroRelationalSyncField field) {
  final value = field.value;
  return native_store.RelationalSyncField(
    name: field.name,
    valueType: switch (value) {
      null => 'null',
      String() => 'text',
      int() => 'integer',
      double() => 'real',
      bool() => 'boolean',
      _ => throw ArgumentError.value(value, field.name, 'unsupported scalar'),
    },
    textValue: value is String ? value : null,
    integerValue: value is int ? value : null,
    realValue: value is double ? value : null,
    booleanValue: value is bool ? value : null,
    updatedAtMicros: field.updatedAtMicros,
    originNodeId: field.originNodeId,
    clock: _toNativeClock(field.clock),
  );
}

List<native_store.RelationalSyncCounter> _toNativeClock(
  Map<String, int> clock,
) {
  return [
    for (final entry in clock.entries)
      native_store.RelationalSyncCounter(
        nodeId: entry.key,
        counter: BigInt.from(entry.value),
      ),
  ];
}

AiroRelationalSyncEntity _fromNativeEntity(
  native_store.RelationalSyncEntity entity,
) {
  return AiroRelationalSyncEntity(
    uuid: entity.uuid,
    entityType: entity.entityType,
    schemaVersion: entity.schemaVersion,
    entityVersion: entity.entityVersion,
    // PlatformInt64 is int on native and BigInt on web.
    // ignore: noop_primitive_operations
    updatedAtMicros: entity.updatedAtMicros.toInt(),
    // ignore: noop_primitive_operations
    deletedAtMicros: entity.deletedAtMicros?.toInt(),
    clock: _fromNativeClock(entity.clock),
    deletionClock: _fromNativeClock(entity.deletionClock),
    fields: entity.fields
        .map(
          (field) => AiroRelationalSyncField(
            name: field.name,
            value: switch (field.valueType) {
              'null' => null,
              'text' => field.textValue,
              // ignore: noop_primitive_operations
              'integer' => field.integerValue?.toInt(),
              'real' => field.realValue,
              'boolean' => field.booleanValue,
              _ => throw StateError('Unsupported persisted scalar type'),
            },
            // ignore: noop_primitive_operations
            updatedAtMicros: field.updatedAtMicros.toInt(),
            originNodeId: field.originNodeId,
            clock: _fromNativeClock(field.clock),
          ),
        )
        .toList(growable: false),
  );
}

Map<String, int> _fromNativeClock(
  List<native_store.RelationalSyncCounter> counters,
) {
  return {
    for (final counter in counters) counter.nodeId: counter.counter.toInt(),
  };
}
