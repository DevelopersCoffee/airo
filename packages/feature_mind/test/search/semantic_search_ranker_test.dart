import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/search/meeting_embedding_store.dart';
import 'package:feature_mind/src/search/semantic_search_ranker.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

rust.MeetingRecord _meeting(
  String id, {
  String title = 'Meeting',
  String transcript = 'transcript text',
  String minutes = 'minutes text',
  List<rust.MeetingDecisionRecord> decisions = const [],
  List<rust.MeetingActionItemRecord> actionItems = const [],
}) => rust.MeetingRecord(
  id: id,
  title: title,
  recordedAt: BigInt.zero,
  transcript: transcript,
  minutes: minutes,
  model: 'test-model',
  decisions: decisions,
  actionItems: actionItems,
  metrics: const [],
);

rust.SearchHit _hit(String meetingId) => rust.SearchHit(
  meetingId: meetingId,
  title: 'Meeting $meetingId',
  recordedAt: BigInt.zero,
  snippet: 'matched line',
);

void main() {
  late Directory tempDir;
  late MeetingEmbeddingStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('semantic_ranker_test_');
    store = MeetingEmbeddingStore(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('SemanticSearchRanker.rank', () {
    test(
      'returns keyword hits unchanged when no embedding model is installed',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(),
          embeddingStore: store,
        );
        final keywordHits = [_hit('m1')];

        final result = await ranker.rank(
          query: 'anything',
          keywordHits: keywordHits,
          meetings: [_meeting('m1'), _meeting('m2')],
        );

        expect(result, keywordHits);
      },
    );

    test('a keyword hit survives even with zero semantic similarity', () async {
      final ranker = SemanticSearchRanker(
        embeddingService: _FakeEmbeddingService(
          vectors: {
            'pricing question': [1.0, 0.0],
            'm1': [-1.0, 0.0], // opposite direction: similarity -1
          },
        ),
        embeddingStore: store,
      );
      final keywordHits = [_hit('m1')];

      final result = await ranker.rank(
        query: 'pricing question',
        keywordHits: keywordHits,
        meetings: [_meeting('m1')],
      );

      expect(result.map((h) => h.meetingId), ['m1']);
    });

    test(
      'adds a semantic-only match that clears the similarity threshold',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'pricing question': [1.0, 0.0],
              // meeting text embeds to the same direction as the query.
              'transcript text minutes text': [1.0, 0.0],
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rank(
          query: 'pricing question',
          keywordHits: const [],
          meetings: [_meeting('m1')],
        );

        expect(result.map((h) => h.meetingId), ['m1']);
      },
    );

    test(
      'does not add a semantic match below the similarity threshold',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'pricing question': [1.0, 0.0],
              'transcript text minutes text': [
                0.0,
                1.0,
              ], // orthogonal: similarity 0
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rank(
          query: 'pricing question',
          keywordHits: const [],
          meetings: [_meeting('m1')],
        );

        expect(result, isEmpty);
      },
    );

    test(
      'never duplicates a meeting that is both a keyword and semantic match',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'pricing question': [1.0, 0.0],
              'transcript text minutes text': [1.0, 0.0],
            },
          ),
          embeddingStore: store,
        );
        final keywordHits = [_hit('m1')];

        final result = await ranker.rank(
          query: 'pricing question',
          keywordHits: keywordHits,
          meetings: [_meeting('m1')],
        );

        expect(result.length, 1);
        expect(result.first, keywordHits.first);
      },
    );

    test('caches a computed meeting embedding for the next call', () async {
      final embeddingService = _FakeEmbeddingService(
        vectors: {
          'pricing question': [1.0, 0.0],
          'transcript text minutes text': [1.0, 0.0],
        },
      );
      final ranker = SemanticSearchRanker(
        embeddingService: embeddingService,
        embeddingStore: store,
      );
      final meeting = _meeting('m1');

      await ranker.rank(
        query: 'pricing question',
        keywordHits: const [],
        meetings: [meeting],
      );
      final stored = await store.get('m1');

      expect(stored, isNotNull);
      expect(stored?.modelId, 'fake-embedding-model');

      // Second call must not re-embed the meeting text -- only the query.
      embeddingService.embedCallsByText.clear();
      await ranker.rank(
        query: 'pricing question',
        keywordHits: const [],
        meetings: [meeting],
      );
      expect(embeddingService.embedCallsByText, ['pricing question']);
    });

    test(
      // `ADR-0022 §3`: the embedded text extends to decision statements and
      // action-item task/owner text, the same text `SearchIndex::insert`
      // feeds its lexical index -- union, not a second embedding path.
      'embeds decision statements and action-item task/owner text',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'query': [1.0, 0.0],
              'transcript text minutes text Adopt Kubernetes for staging '
                      'Finish the migration Priya':
                  [1.0, 0.0],
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rank(
          query: 'query',
          keywordHits: const [],
          meetings: [
            _meeting(
              'm1',
              decisions: const [
                rust.MeetingDecisionRecord(
                  id: 'd0',
                  statement: 'Adopt Kubernetes for staging',
                  status: rust.MeetingDecisionStatus.agreed,
                  evidenceSegmentIds: ['s1'],
                ),
              ],
              actionItems: const [
                rust.MeetingActionItemRecord(
                  id: 'a0',
                  task: 'Finish the migration',
                  owner: 'Priya',
                  status: rust.MeetingActionStatus.open,
                  evidenceSegmentIds: ['s2'],
                ),
              ],
            ),
          ],
        );

        expect(result.map((h) => h.meetingId), ['m1']);
      },
    );

    test(
      'ranks multiple semantic-only matches by descending similarity',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'query': [1.0, 0.0],
              'close text': [0.9, 0.1], // higher similarity
              'far text': [0.7, 0.3], // lower, still above threshold
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rank(
          query: 'query',
          keywordHits: const [],
          meetings: [
            _meeting('far', transcript: 'far', minutes: 'text'),
            _meeting('close', transcript: 'close', minutes: 'text'),
          ],
        );

        expect(result.map((h) => h.meetingId), ['close', 'far']);
      },
    );
  });
}

class _FakeEmbeddingService implements EmbeddingService {
  _FakeEmbeddingService({this.vectors = const {}});

  /// Keyed by the exact text passed to [embed] — the test builds this map to
  /// control what each call returns.
  final Map<String, List<double>> vectors;
  final embedCallsByText = <String>[];

  @override
  Future<EmbeddingResult> embed(String text) async {
    embedCallsByText.add(text);
    final vector = vectors[text];
    if (vector == null) {
      return const EmbeddingResult.unavailable(
        EmbeddingUnavailable.noModelInstalled,
        'no vector configured for this text in the fake',
      );
    }
    return EmbeddingResult.ready(vector, 'fake-embedding-model');
  }
}
