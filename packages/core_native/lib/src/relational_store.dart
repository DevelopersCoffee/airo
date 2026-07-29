import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show PlatformInt64Util;

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

class AiroRelationalMediaTitle {
  const AiroRelationalMediaTitle({
    required this.uuid,
    required this.title,
    required this.releaseYear,
    this.contentRating,
  });

  final String uuid;
  final String title;
  final int releaseYear;
  final String? contentRating;
}

class AiroRelationalMediaEntity {
  const AiroRelationalMediaEntity({
    required this.uuid,
    required this.entityType,
    required this.name,
  });

  final String uuid;
  final String entityType;
  final String name;
}

class AiroRelationalMediaEdge {
  const AiroRelationalMediaEdge({
    required this.titleUuid,
    required this.entityUuid,
  });

  final String titleUuid;
  final String entityUuid;
}

class AiroRelationalMediaPack {
  const AiroRelationalMediaPack({
    required this.packId,
    required this.schemaVersion,
    required this.titles,
    required this.entities,
    required this.edges,
  });

  final String packId;
  final String schemaVersion;
  final List<AiroRelationalMediaTitle> titles;
  final List<AiroRelationalMediaEntity> entities;
  final List<AiroRelationalMediaEdge> edges;
}

class AiroRelationalMediaQuery {
  const AiroRelationalMediaQuery({
    this.entityType,
    this.entityName,
    this.releasedAfter,
    this.releasedBefore,
    this.contentRating,
  });

  final String? entityType;
  final String? entityName;
  final int? releasedAfter;
  final int? releasedBefore;
  final String? contentRating;
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

Future<bool> loadAiroRelationalMediaPack({
  required String path,
  required AiroRelationalMediaPack pack,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return false;
  await native_store.loadRelationalMediaPack(
    path: path,
    pack: native_store.RelationalMediaKnowledgePack(
      packId: pack.packId,
      schemaVersion: pack.schemaVersion,
      titles: [
        for (final title in pack.titles)
          native_store.RelationalMediaTitle(
            uuid: title.uuid,
            title: title.title,
            releaseYear: title.releaseYear,
            contentRating: title.contentRating,
          ),
      ],
      entities: [
        for (final entity in pack.entities)
          native_store.RelationalMediaEntity(
            uuid: entity.uuid,
            entityType: entity.entityType,
            name: entity.name,
          ),
      ],
      edges: [
        for (final edge in pack.edges)
          native_store.RelationalMediaEdge(
            titleUuid: edge.titleUuid,
            entityUuid: edge.entityUuid,
          ),
      ],
    ),
  );
  return true;
}

Future<bool?> unloadAiroRelationalMediaPack({
  required String path,
  required String packId,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  return native_store.unloadRelationalMediaPack(path: path, packId: packId);
}

Future<List<AiroRelationalMediaTitle>?> queryAiroRelationalMediaGraph({
  required String path,
  required AiroRelationalMediaQuery query,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  final rows = await native_store.queryRelationalMediaGraph(
    path: path,
    query: native_store.RelationalMediaGraphQuery(
      entityType: query.entityType,
      entityName: query.entityName,
      releasedAfter: query.releasedAfter,
      releasedBefore: query.releasedBefore,
      contentRating: query.contentRating,
    ),
  );
  return [
    for (final row in rows)
      AiroRelationalMediaTitle(
        uuid: row.uuid,
        title: row.title,
        releaseYear: row.releaseYear,
        contentRating: row.contentRating,
      ),
  ];
}

native_store.RelationalSyncEntity _toNativeEntity(
  AiroRelationalSyncEntity entity,
) {
  return native_store.RelationalSyncEntity(
    uuid: entity.uuid,
    entityType: entity.entityType,
    schemaVersion: entity.schemaVersion,
    entityVersion: entity.entityVersion,
    updatedAtMicros: PlatformInt64Util.from(entity.updatedAtMicros),
    deletedAtMicros: entity.deletedAtMicros == null
        ? null
        : PlatformInt64Util.from(entity.deletedAtMicros!),
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
    integerValue: value is int ? PlatformInt64Util.from(value) : null,
    realValue: value is double ? value : null,
    booleanValue: value is bool ? value : null,
    updatedAtMicros: PlatformInt64Util.from(field.updatedAtMicros),
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
