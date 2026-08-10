import 'dart:io';

import 'package:feature_mind/src/search/meeting_embedding_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'meeting_embedding_store_test_',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MeetingEmbeddingStore', () {
    test('get returns null for a meeting that was never stored', () async {
      final store = MeetingEmbeddingStore(tempDir);

      expect(await store.get('unknown'), isNull);
    });

    test('put then get round-trips the model id and vector', () async {
      final store = MeetingEmbeddingStore(tempDir);

      await store.put('meeting-1', 'embed-model-v1', [0.1, 0.2, 0.3]);
      final result = await store.get('meeting-1');

      expect(result?.modelId, 'embed-model-v1');
      expect(result?.vector, [0.1, 0.2, 0.3]);
    });

    test('put overwrites a previous entry for the same meeting', () async {
      final store = MeetingEmbeddingStore(tempDir);

      await store.put('meeting-1', 'embed-model-v1', [0.1, 0.2]);
      await store.put('meeting-1', 'embed-model-v2', [0.9, 0.9]);
      final result = await store.get('meeting-1');

      expect(result?.modelId, 'embed-model-v2');
      expect(result?.vector, [0.9, 0.9]);
    });

    test('all returns every stored meeting, keyed by id', () async {
      final store = MeetingEmbeddingStore(tempDir);

      await store.put('meeting-1', 'embed-model', [0.1]);
      await store.put('meeting-2', 'embed-model', [0.2]);
      final result = await store.all();

      expect(result.keys, containsAll(['meeting-1', 'meeting-2']));
      expect(result['meeting-1']?.vector, [0.1]);
      expect(result['meeting-2']?.vector, [0.2]);
    });

    test(
      'survives a process restart -- a fresh instance reads what a prior one wrote',
      () async {
        final first = MeetingEmbeddingStore(tempDir);
        await first.put('meeting-1', 'embed-model', [0.4, 0.5]);

        final second = MeetingEmbeddingStore(tempDir);
        final result = await second.get('meeting-1');

        expect(result?.modelId, 'embed-model');
        expect(result?.vector, [0.4, 0.5]);
      },
    );

    test(
      'a corrupt store file degrades to empty rather than throwing',
      () async {
        final file = File('${tempDir.path}/meeting_embeddings.json');
        file.writeAsStringSync('{not valid json');
        final store = MeetingEmbeddingStore(tempDir);

        expect(await store.get('meeting-1'), isNull);
        expect(await store.all(), isEmpty);
      },
    );

    test('creates the target directory if it does not exist yet', () async {
      final missingDir = Directory('${tempDir.path}/not-yet-created');
      final store = MeetingEmbeddingStore(missingDir);

      await store.put('meeting-1', 'embed-model', [0.1]);

      expect(await store.get('meeting-1'), isNotNull);
    });
  });
}
