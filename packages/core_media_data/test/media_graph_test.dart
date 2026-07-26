import 'package:core_media_data/core_media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tomHanks = MediaEntityRow(
    id: 'actor:tom-hanks',
    type: MediaEntityType.actor,
    name: 'Tom Hanks',
  );
  final movies = MediaKnowledgePack(
    id: 'movies',
    titles: const [
      MediaTitleRow(id: 'apollo-13', title: 'Apollo 13', releaseYear: 1995),
      MediaTitleRow(id: 'greyhound', title: 'Greyhound', releaseYear: 2020),
      MediaTitleRow(id: 'sully', title: 'Sully', releaseYear: 2016),
    ],
    entities: const [tomHanks],
    edges: const [
      MediaGraphEdge(titleId: 'apollo-13', entityId: 'actor:tom-hanks'),
      MediaGraphEdge(titleId: 'greyhound', entityId: 'actor:tom-hanks'),
      MediaGraphEdge(titleId: 'sully', entityId: 'actor:tom-hanks'),
    ],
  );

  test('actor and year query is deterministic and structured', () {
    final graph = InMemoryRelationalMediaGraph()..load(movies);
    final result = graph.query(
      const MediaGraphQuery(
        entityType: MediaEntityType.actor,
        entityName: 'tom hanks',
        releasedAfter: 2015,
      ),
    );
    expect(result.map((row) => row.id), ['greyhound', 'sully']);
  });

  test('knowledge packs load and unload independently', () {
    final graph = InMemoryRelationalMediaGraph()..load(movies);
    final sports = MediaKnowledgePack(
      id: 'sports',
      titles: const [
        MediaTitleRow(id: 'match-1', title: 'Final Replay', releaseYear: 2026),
      ],
      entities: const [
        MediaEntityRow(
          id: 'collection:finals',
          type: MediaEntityType.collection,
          name: 'Finals',
        ),
      ],
      edges: const [
        MediaGraphEdge(titleId: 'match-1', entityId: 'collection:finals'),
      ],
    );

    graph
      ..load(sports)
      ..load(movies);
    expect(graph.unload('movies'), isTrue);
    expect(graph.unload('movies'), isFalse);

    final snapshot = graph.snapshot();
    expect(snapshot.loadedPackIds, {'sports'});
    expect(snapshot.titles.map((row) => row.id), ['match-1']);
  });

  test('shared relational rows survive one pack unloading', () {
    final graph = InMemoryRelationalMediaGraph()..load(movies);
    graph.load(
      MediaKnowledgePack(
        id: 'awards',
        titles: const [
          MediaTitleRow(id: 'sully', title: 'Sully', releaseYear: 2016),
        ],
        entities: const [
          MediaEntityRow(
            id: 'award:nbr',
            type: MediaEntityType.award,
            name: 'NBR',
          ),
        ],
        edges: const [MediaGraphEdge(titleId: 'sully', entityId: 'award:nbr')],
      ),
    );

    graph.unload('movies');

    expect(graph.snapshot().titles.single.id, 'sully');
    expect(graph.snapshot().entities.single.id, 'award:nbr');
  });

  test('invalid pack fails atomically without partial mutation', () {
    final graph = InMemoryRelationalMediaGraph()..load(movies);
    final before = graph.snapshot();

    expect(
      () => graph.load(
        MediaKnowledgePack(
          id: 'broken',
          titles: const [
            MediaTitleRow(id: 'new', title: 'New', releaseYear: 2026),
          ],
          entities: const [],
          edges: const [MediaGraphEdge(titleId: 'new', entityId: 'missing')],
        ),
      ),
      throwsStateError,
    );
    expect(graph.snapshot(), before);
  });

  test('conflicting relational row IDs are rejected', () {
    final graph = InMemoryRelationalMediaGraph()..load(movies);
    expect(
      () => graph.load(
        MediaKnowledgePack(
          id: 'conflict',
          titles: const [
            MediaTitleRow(id: 'sully', title: 'Different', releaseYear: 2016),
          ],
          entities: const [],
          edges: const [],
        ),
      ),
      throwsStateError,
    );
  });

  test('snapshot exports separate title, entity, and edge rows', () {
    final snapshot = (InMemoryRelationalMediaGraph()..load(movies)).snapshot();
    expect(snapshot.schemaVersion, kMediaGraphSchemaVersion);
    expect(snapshot.titles, hasLength(3));
    expect(snapshot.entities, hasLength(1));
    expect(snapshot.edges, hasLength(3));
  });
}
