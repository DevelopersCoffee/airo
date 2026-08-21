import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/search/meeting_embedding_store.dart';
import 'package:feature_mind/src/search/meeting_text_chunker.dart';
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
            'transcript text minutes text': [-1.0, 0.0],
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
      'zero semantic similarity on a keyword hit is PM-05 provenance, not a drop',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'pricing question': [1.0, 0.0],
              'transcript text minutes text': [-1.0, 0.0],
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rankWithAlignment(
          query: 'pricing question',
          keywordHits: [_hit('m1')],
          meetings: [_meeting('m1')],
        );

        expect(result.hits.map((h) => h.meetingId), ['m1']);
        expect(result.hasEmbeddingMismatch, isTrue);
        expect(
          result.alignments.single.failureMode,
          FailureMode.pm05SemanticEmbeddingMismatch,
        );
        expect(result.alignments.single.retrievalScore, 1.0);
        expect(result.alignments.single.semanticScore, lessThan(0.5));
      },
    );

    test('re-ranks keyword hits by descending semantic similarity', () async {
      final ranker = SemanticSearchRanker(
        embeddingService: _FakeEmbeddingService(
          vectors: {
            'query': [1.0, 0.0],
            'far text': [0.7, 0.3],
            'close text': [0.9, 0.1],
          },
        ),
        embeddingStore: store,
      );

      final result = await ranker.rank(
        query: 'query',
        keywordHits: [_hit('far'), _hit('close')],
        meetings: [
          _meeting('far', transcript: 'far', minutes: 'text'),
          _meeting('close', transcript: 'close', minutes: 'text'),
        ],
      );

      expect(result.map((h) => h.meetingId), ['close', 'far']);
    });

    test(
      'adds a semantic-only match that clears the similarity threshold',
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
              'transcript text minutes text': [0.0, 1.0],
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
      expect(stored?.vectors, [
        [1.0, 0.0],
      ]);

      embeddingService.embedCallsByText.clear();
      embeddingService.taskTypes.clear();
      await ranker.rank(
        query: 'pricing question',
        keywordHits: const [],
        meetings: [meeting],
      );
      expect(embeddingService.embedCallsByText, ['pricing question']);
      expect(embeddingService.taskTypes, [EmbeddingTaskType.retrievalQuery]);
    });

    test('re-embeds when the stored model id is stale', () async {
      await store.put('m1', 'old-model', [0.0, 1.0]);
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

      await ranker.rank(
        query: 'pricing question',
        keywordHits: const [],
        meetings: [_meeting('m1')],
      );

      final stored = await store.get('m1');
      expect(stored?.modelId, 'fake-embedding-model');
      expect(stored?.vector, [1.0, 0.0]);
      expect(
        embeddingService.embedCallsByText,
        contains('transcript text minutes text'),
      );
    });

    test(
      'uses retrievalQuery for the query and retrievalDocument for meetings',
      () async {
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

        await ranker.rank(
          query: 'pricing question',
          keywordHits: const [],
          meetings: [_meeting('m1')],
        );

        expect(embeddingService.taskTypes, [
          EmbeddingTaskType.retrievalQuery,
          EmbeddingTaskType.retrievalDocument,
        ]);
      },
    );

    test(
      'embeds decision statements and action-item task/owner text',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'query': [1.0, 0.0],
              'transcript text minutes text Adopt Kubernetes for staging '
                  'Finish the migration Priya': [
                1.0,
                0.0,
              ],
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
                  'Finish the migration Priya': [
                1.0,
                0.0,
              ],
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
              'close text': [0.9, 0.1],
              'far text': [0.7, 0.3],
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

    test('scores a meeting by max similarity across chunks', () async {
      final ranker = SemanticSearchRanker(
        embeddingService: _FakeEmbeddingService(
          vectors: {
            'pricing': [1.0, 0.0],
            'early fluff': [0.0, 1.0],
            'the pricing discussion': [1.0, 0.0],
          },
        ),
        embeddingStore: store,
        // Force one segment per chunk so max-across-chunks is observable.
        chunker: const MeetingTextChunker(maxChars: 12, overlapChars: 0),
      );

      final result = await ranker.rank(
        query: 'pricing',
        keywordHits: const [],
        meetings: [_meeting('m1')],
        segmentTextsByMeetingId: {
          'm1': ['early fluff', 'the pricing discussion'],
        },
      );

      expect(result.map((h) => h.meetingId), ['m1']);
      final stored = await store.get('m1');
      expect(stored?.vectors, hasLength(2));
    });

    test(
      // Acceptance (#508): "pricing decision" finds a meeting about that
      // topic without those exact keywords — the fake embedder stands in
      // for EmbeddingGemma so CI never needs the 179 MB weights.
      'query "pricing decision" finds a meeting without those exact keywords',
      () async {
        final ranker = SemanticSearchRanker(
          embeddingService: _FakeEmbeddingService(
            vectors: {
              'pricing decision': [1.0, 0.0],
              'We agreed on the Q3 cost structure for enterprise seats '
                  'minutes text': [
                0.95,
                0.05,
              ],
            },
          ),
          embeddingStore: store,
        );

        final result = await ranker.rank(
          query: 'pricing decision',
          keywordHits: const [],
          meetings: [
            _meeting(
              'budget',
              transcript:
                  'We agreed on the Q3 cost structure for enterprise seats',
            ),
            _meeting(
              'unrelated',
              transcript: 'standup notes about the deploy pipeline',
              minutes: 'no budget talk',
            ),
          ],
        );

        expect(result.map((h) => h.meetingId), ['budget']);
        expect(result.first.snippet.toLowerCase().contains('pricing'), isFalse);
      },
    );
  });

  group('SemanticSearchRanker.indexMeeting', () {
    test('caches a document embedding for later rank calls', () async {
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

      expect(await ranker.indexMeeting(meeting), isTrue);
      expect(await store.get('m1'), isNotNull);
      expect(embeddingService.taskTypes, [EmbeddingTaskType.retrievalDocument]);

      embeddingService.embedCallsByText.clear();
      embeddingService.taskTypes.clear();
      await ranker.rank(
        query: 'pricing question',
        keywordHits: const [],
        meetings: [meeting],
      );
      expect(embeddingService.embedCallsByText, ['pricing question']);
    });

    test('returns false when no embedding model is installed', () async {
      final ranker = SemanticSearchRanker(
        embeddingService: _FakeEmbeddingService(),
        embeddingStore: store,
      );

      expect(await ranker.indexMeeting(_meeting('m1')), isFalse);
      expect(await store.get('m1'), isNull);
    });
  });
}

class _FakeEmbeddingService implements EmbeddingService {
  _FakeEmbeddingService({this.vectors = const {}});

  final Map<String, List<double>> vectors;
  final embedCallsByText = <String>[];
  final taskTypes = <EmbeddingTaskType>[];

  @override
  Future<EmbeddingResult> embed(
    String text, {
    EmbeddingTaskType taskType = EmbeddingTaskType.semanticSimilarity,
  }) async {
    embedCallsByText.add(text);
    taskTypes.add(taskType);
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
