import 'package:feature_mind/src/agent_chat/domain/services/research/comparison_matrix.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library_log.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_operation_log.dart';

void main() {
  test('library record roundtrips sources and findings', () {
    final entry = ResearchLibraryEntry.fromQuestion(
      question: 'What is Qwen?',
      retrievedAt: '2026-08-22T00:00:00Z',
      sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen?utm_source=x'],
      findings: const ['Qwen is a family of large language models.'],
    );

    final restored = ResearchLibraryEntry.fromRecord(entry.toRecord());
    expect(restored.topicKey, 'what is qwen?');
    expect(restored.sourceUrls, ['https://en.wikipedia.org/wiki/Qwen']);
    expect(restored.findings, ['Qwen is a family of large language models.']);
  });

  test('follow-up research keeps only the url delta', () {
    expect(
      deltaUrls(
        const ['https://en.wikipedia.org/wiki/Qwen'],
        const [
          'https://en.wikipedia.org/wiki/Qwen?utm_source=x',
          'https://arxiv.org/abs/2401.12345',
        ],
      ),
      ['https://arxiv.org/abs/2401.12345'],
    );
  });

  test(
    'appends a researchLibrary op whose detail is the durable record',
    () async {
      final log = RecordingOperationLog();
      final entry = ResearchLibraryEntry.fromQuestion(
        question: 'What is Qwen?',
        retrievedAt: '2026-08-22T00:00:00Z',
        sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
        findings: const ['Qwen is a family of large language models.'],
      );

      await appendResearchLibraryOp(log: log, entry: entry);

      expect(log.appended.single.kind, MindOpKind.researchLibrary);
      expect(log.appended.single.detail, entry.toRecord());
    },
  );

  test('latest library lookup scans at most 200 newest ops', () async {
    final log = RecordingOperationLog();
    final match = ResearchLibraryEntry.fromQuestion(
      question: 'What is Qwen?',
      retrievedAt: '2026-08-22T00:00:00Z',
      sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
      findings: const ['Qwen is a family of large language models.'],
    );
    await appendResearchLibraryOp(log: log, entry: match);
    for (var i = 0; i < 200; i++) {
      await log.append(
        kind: MindOpKind.note,
        title: 'note $i',
        contextId: 'note-$i',
      );
    }

    expect(await latestLibraryEntryFor(log, 'What is Qwen?'), isNull);

    await appendResearchLibraryOp(log: log, entry: match);
    expect((await latestLibraryEntryFor(log, 'What is Qwen?'))?.sourceUrls, [
      'https://en.wikipedia.org/wiki/Qwen',
    ]);
  });

  test(
    'comparison cells stay cited and contested rows are not silent winners',
    () {
      const subjects = ['Qwen', 'Llama'];
      final cells = comparisonMatrix(
        subjects: subjects,
        criteria: const ['memory'],
        claims: const [
          (
            'Qwen 7B memory is 4 GB on device.',
            'https://en.wikipedia.org/wiki/Qwen',
          ),
          (
            'Llama 8B memory is 6 GB on device.',
            'https://en.wikipedia.org/wiki/Llama',
          ),
        ],
      );

      expect(cells, hasLength(2));
      expect(matrixMarkdown(cells), contains('| Qwen | memory |'));
      final rows = decide(subjects: subjects, cells: cells, conflicts: 1);
      expect(
        rows.where((row) => row.coveredCriteria > 0 && !row.contested),
        isEmpty,
      );
    },
  );
}
