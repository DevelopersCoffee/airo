import 'package:core_native/core_native.dart';
import 'package:equatable/equatable.dart';

const String kMediaGraphSchemaVersion = '1.0.0';

enum MediaEntityType {
  actor,
  director,
  studio,
  language,
  genre,
  award,
  collection,
}

class MediaTitleRow extends Equatable {
  const MediaTitleRow({
    required this.id,
    required this.title,
    required this.releaseYear,
    this.contentRating,
  });

  final String id;
  final String title;
  final int releaseYear;
  final String? contentRating;

  @override
  List<Object?> get props => [id, title, releaseYear, contentRating];
}

class MediaEntityRow extends Equatable {
  const MediaEntityRow({
    required this.id,
    required this.type,
    required this.name,
  });

  final String id;
  final MediaEntityType type;
  final String name;

  @override
  List<Object?> get props => [id, type, name];
}

class MediaGraphEdge extends Equatable {
  const MediaGraphEdge({required this.titleId, required this.entityId});

  final String titleId;
  final String entityId;

  @override
  List<Object?> get props => [titleId, entityId];
}

class MediaKnowledgePack extends Equatable {
  MediaKnowledgePack({
    required this.id,
    required Iterable<MediaTitleRow> titles,
    required Iterable<MediaEntityRow> entities,
    required Iterable<MediaGraphEdge> edges,
    this.schemaVersion = kMediaGraphSchemaVersion,
  }) : titles = List.unmodifiable(titles),
       entities = List.unmodifiable(entities),
       edges = List.unmodifiable(edges);

  final String schemaVersion;
  final String id;
  final List<MediaTitleRow> titles;
  final List<MediaEntityRow> entities;
  final List<MediaGraphEdge> edges;

  @override
  List<Object?> get props => [schemaVersion, id, titles, entities, edges];
}

class MediaGraphQuery extends Equatable {
  const MediaGraphQuery({
    this.entityType,
    this.entityName,
    this.releasedAfter,
    this.releasedBefore,
    this.contentRating,
  }) : assert(
         (entityType == null) == (entityName == null),
         'entityType and entityName must be supplied together',
       );

  final MediaEntityType? entityType;
  final String? entityName;
  final int? releasedAfter;
  final int? releasedBefore;
  final String? contentRating;

  @override
  List<Object?> get props => [
    entityType,
    entityName,
    releasedAfter,
    releasedBefore,
    contentRating,
  ];
}

class MediaGraphSnapshot extends Equatable {
  MediaGraphSnapshot({
    required Iterable<MediaTitleRow> titles,
    required Iterable<MediaEntityRow> entities,
    required Iterable<MediaGraphEdge> edges,
    required Iterable<String> loadedPackIds,
    this.schemaVersion = kMediaGraphSchemaVersion,
  }) : titles = List.unmodifiable(titles),
       entities = List.unmodifiable(entities),
       edges = List.unmodifiable(edges),
       loadedPackIds = Set.unmodifiable(loadedPackIds);

  final String schemaVersion;
  final List<MediaTitleRow> titles;
  final List<MediaEntityRow> entities;
  final List<MediaGraphEdge> edges;
  final Set<String> loadedPackIds;

  @override
  List<Object?> get props => [
    schemaVersion,
    titles,
    entities,
    edges,
    loadedPackIds,
  ];
}

abstract interface class MediaGraph {
  Set<String> get loadedPackIds;

  void load(MediaKnowledgePack pack);

  bool unload(String packId);

  List<MediaTitleRow> query(MediaGraphQuery query);

  MediaGraphSnapshot snapshot();
}

abstract interface class AsyncMediaGraph {
  Future<void> load(MediaKnowledgePack pack);

  Future<bool> unload(String packId);

  Future<List<MediaTitleRow>> query(MediaGraphQuery query);
}

abstract interface class MediaGraphRelationalBackend {
  Future<bool> load(AiroRelationalMediaPack pack);

  Future<bool?> unload(String packId);

  Future<List<AiroRelationalMediaTitle>?> query(AiroRelationalMediaQuery query);
}

class NativeMediaGraphRelationalBackend implements MediaGraphRelationalBackend {
  const NativeMediaGraphRelationalBackend({required this.databasePath});

  final String databasePath;

  @override
  Future<bool> load(AiroRelationalMediaPack pack) =>
      loadAiroRelationalMediaPack(path: databasePath, pack: pack);

  @override
  Future<bool?> unload(String packId) =>
      unloadAiroRelationalMediaPack(path: databasePath, packId: packId);

  @override
  Future<List<AiroRelationalMediaTitle>?> query(
    AiroRelationalMediaQuery query,
  ) => queryAiroRelationalMediaGraph(path: databasePath, query: query);
}

class RelationalMediaGraph implements AsyncMediaGraph {
  const RelationalMediaGraph({required this.backend});

  final MediaGraphRelationalBackend backend;

  @override
  Future<void> load(MediaKnowledgePack pack) async {
    final loaded = await backend.load(
      AiroRelationalMediaPack(
        packId: pack.id,
        schemaVersion: pack.schemaVersion,
        titles: [
          for (final title in pack.titles)
            AiroRelationalMediaTitle(
              uuid: title.id,
              title: title.title,
              releaseYear: title.releaseYear,
              contentRating: title.contentRating,
            ),
        ],
        entities: [
          for (final entity in pack.entities)
            AiroRelationalMediaEntity(
              uuid: entity.id,
              entityType: entity.type.name,
              name: entity.name,
            ),
        ],
        edges: [
          for (final edge in pack.edges)
            AiroRelationalMediaEdge(
              titleUuid: edge.titleId,
              entityUuid: edge.entityId,
            ),
        ],
      ),
    );
    if (!loaded) throw StateError('relational_media_graph_unavailable');
  }

  @override
  Future<bool> unload(String packId) async {
    final unloaded = await backend.unload(packId);
    if (unloaded == null) {
      throw StateError('relational_media_graph_unavailable');
    }
    return unloaded;
  }

  @override
  Future<List<MediaTitleRow>> query(MediaGraphQuery query) async {
    final rows = await backend.query(
      AiroRelationalMediaQuery(
        entityType: query.entityType?.name,
        entityName: query.entityName,
        releasedAfter: query.releasedAfter,
        releasedBefore: query.releasedBefore,
        contentRating: query.contentRating,
      ),
    );
    if (rows == null) throw StateError('relational_media_graph_unavailable');
    return [
      for (final row in rows)
        MediaTitleRow(
          id: row.uuid,
          title: row.title,
          releaseYear: row.releaseYear,
          contentRating: row.contentRating,
        ),
    ];
  }
}

class InMemoryRelationalMediaGraph implements MediaGraph {
  final Map<String, MediaKnowledgePack> _packs = {};
  final Map<String, MediaTitleRow> _titles = {};
  final Map<String, MediaEntityRow> _entities = {};
  final Set<MediaGraphEdge> _edges = {};
  final Map<String, Set<String>> _titleOwners = {};
  final Map<String, Set<String>> _entityOwners = {};
  final Map<MediaGraphEdge, Set<String>> _edgeOwners = {};

  @override
  Set<String> get loadedPackIds => Set.unmodifiable(_packs.keys);

  @override
  void load(MediaKnowledgePack pack) {
    _validatePack(pack);
    final existing = _packs[pack.id];
    if (existing == pack) return;
    if (existing != null) {
      throw StateError('Knowledge pack ID already contains different rows');
    }

    _packs[pack.id] = pack;
    for (final title in pack.titles) {
      _titles[title.id] = title;
      _titleOwners.putIfAbsent(title.id, () => {}).add(pack.id);
    }
    for (final entity in pack.entities) {
      _entities[entity.id] = entity;
      _entityOwners.putIfAbsent(entity.id, () => {}).add(pack.id);
    }
    for (final edge in pack.edges) {
      _edges.add(edge);
      _edgeOwners.putIfAbsent(edge, () => {}).add(pack.id);
    }
  }

  void _validatePack(MediaKnowledgePack pack) {
    if (pack.schemaVersion != kMediaGraphSchemaVersion ||
        pack.id.trim().isEmpty) {
      throw ArgumentError('Unsupported schema or empty knowledge pack ID');
    }
    final packTitles = <String, MediaTitleRow>{};
    for (final title in pack.titles) {
      _validateText(title.id, 'title.id');
      _validateText(title.title, 'title.title');
      final duplicate = packTitles[title.id];
      if (duplicate != null && duplicate != title) {
        throw StateError('Conflicting title row: ${title.id}');
      }
      final loaded = _titles[title.id];
      if (loaded != null && loaded != title) {
        throw StateError('Conflicting loaded title row: ${title.id}');
      }
      packTitles[title.id] = title;
    }
    final packEntities = <String, MediaEntityRow>{};
    for (final entity in pack.entities) {
      _validateText(entity.id, 'entity.id');
      _validateText(entity.name, 'entity.name');
      final duplicate = packEntities[entity.id];
      if (duplicate != null && duplicate != entity) {
        throw StateError('Conflicting entity row: ${entity.id}');
      }
      final loaded = _entities[entity.id];
      if (loaded != null && loaded != entity) {
        throw StateError('Conflicting loaded entity row: ${entity.id}');
      }
      packEntities[entity.id] = entity;
    }
    for (final edge in pack.edges) {
      if (!packTitles.containsKey(edge.titleId) &&
          !_titles.containsKey(edge.titleId)) {
        throw StateError('Dangling title edge: ${edge.titleId}');
      }
      if (!packEntities.containsKey(edge.entityId) &&
          !_entities.containsKey(edge.entityId)) {
        throw StateError('Dangling entity edge: ${edge.entityId}');
      }
    }
  }

  void _validateText(String value, String field) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, field);
  }

  @override
  bool unload(String packId) {
    final pack = _packs.remove(packId);
    if (pack == null) return false;
    for (final edge in pack.edges) {
      final owners = _edgeOwners[edge]!..remove(packId);
      if (owners.isEmpty) {
        _edgeOwners.remove(edge);
        _edges.remove(edge);
      }
    }
    for (final title in pack.titles) {
      final owners = _titleOwners[title.id]!..remove(packId);
      if (owners.isEmpty) {
        _titleOwners.remove(title.id);
        _titles.remove(title.id);
      }
    }
    for (final entity in pack.entities) {
      final owners = _entityOwners[entity.id]!..remove(packId);
      if (owners.isEmpty) {
        _entityOwners.remove(entity.id);
        _entities.remove(entity.id);
      }
    }
    return true;
  }

  @override
  List<MediaTitleRow> query(MediaGraphQuery query) {
    Set<String>? relatedTitleIds;
    if (query.entityType != null) {
      final normalizedName = query.entityName!.trim().toLowerCase();
      final entityIds = _entities.values
          .where(
            (entity) =>
                entity.type == query.entityType &&
                entity.name.trim().toLowerCase() == normalizedName,
          )
          .map((entity) => entity.id)
          .toSet();
      relatedTitleIds = _edges
          .where((edge) => entityIds.contains(edge.entityId))
          .map((edge) => edge.titleId)
          .toSet();
    }
    final result = _titles.values.where((title) {
      if (relatedTitleIds != null && !relatedTitleIds.contains(title.id)) {
        return false;
      }
      if (query.releasedAfter != null &&
          title.releaseYear <= query.releasedAfter!) {
        return false;
      }
      if (query.releasedBefore != null &&
          title.releaseYear >= query.releasedBefore!) {
        return false;
      }
      if (query.contentRating != null &&
          title.contentRating?.toLowerCase() !=
              query.contentRating!.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
    result.sort((left, right) {
      final title = left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      );
      if (title != 0) return title;
      return left.id.compareTo(right.id);
    });
    return List.unmodifiable(result);
  }

  @override
  MediaGraphSnapshot snapshot() {
    final titles = _titles.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final entities = _entities.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final edges = _edges.toList()
      ..sort((left, right) {
        final title = left.titleId.compareTo(right.titleId);
        return title != 0 ? title : left.entityId.compareTo(right.entityId);
      });
    return MediaGraphSnapshot(
      titles: titles,
      entities: entities,
      edges: edges,
      loadedPackIds: _packs.keys,
    );
  }
}
