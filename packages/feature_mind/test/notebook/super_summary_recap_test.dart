import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/notebook/application/super_summary_recap_port.dart';
import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_note.dart';
import 'package:feature_mind/src/notebook/domain/super_summary_prompt.dart';
import 'package:feature_mind/src/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

NotebookNote _note({
  required String id,
  required String title,
  NotebookDocument document = const NotebookDocument(),
}) {
  return NotebookNote(
    note: Note(id: id, title: title, body: document.encode(), updatedAtMs: 1),
    document: document,
  );
}

void main() {
  final notes = [
    _note(
      id: 'a',
      title: 'Standup',
      document: const NotebookDocument(
        summary: 'Ship Friday.',
        keyPoints: ['Ship Friday'],
        transcript: 'We ship Friday after QA.',
      ),
    ),
    _note(
      id: 'b',
      title: 'Lecture',
      document: const NotebookDocument(
        summary: 'Gradient descent recap.',
        keyPoints: ['Use a smaller learning rate'],
      ),
    ),
  ];

  test('prompt includes titles, summaries, and key points', () {
    final prompt = SuperSummaryPrompt.build(notes);
    expect(prompt, contains('Super Summary'));
    expect(prompt, contains('## Standup'));
    expect(prompt, contains('## Lecture'));
    expect(prompt, contains('Ship Friday.'));
    expect(prompt, contains('Use a smaller learning rate'));
    expect(prompt, contains('We ship Friday after QA.'));
    expect(prompt, contains('# Summary'));
    expect(prompt, contains('# Key points'));
  });

  test('prompt clips a long transcript', () {
    final long = _note(
      id: 'c',
      title: 'Long',
      document: NotebookDocument(transcript: 'word ' * 5000),
    );
    final prompt = SuperSummaryPrompt.build([long]);
    expect(prompt.length, lessThanOrEqualTo(SuperSummaryPrompt.maxPromptChars));
    expect(prompt, contains('[truncated]'));
  });

  test('drain returns generated markdown when the engine is ready', () async {
    final bridge = FakeMindGenerationBridge()
      ..completeEvents = [
        const GenerationEventMinutesReady(
          '# Summary\nDelay the launch.\n\n# Key points\n- Tell the customer',
        ),
      ];
    await bridge.ensureLoaded(modelsDir: '.', memoryBudgetMb: 1);

    final recap = await superSummaryRecapPort(
      isEngineReady: () => bridge.isEngineReady,
      complete: bridge.complete,
    ).generate(notes);

    expect(recap, contains('Delay the launch'));
    expect(bridge.lastCompletePrompt, contains('## Standup'));
    expect(bridge.lastCompleteMaxOutputTokens, 1024);
  });

  test(
    'drain concatenates streaming tokens when minutesReady is absent',
    () async {
      final bridge = FakeMindGenerationBridge()
        ..completeEvents = [
          const GenerationEventGenerating('# Summary\n'),
          const GenerationEventGenerating('Both teams agree.'),
        ];
      await bridge.ensureLoaded(modelsDir: '.', memoryBudgetMb: 1);

      final recap = await drainGeneratedRecap(
        engineReady: true,
        events: () => bridge.complete(prompt: 'p', maxOutputTokens: 8),
      );
      expect(recap, '# Summary\nBoth teams agree.');
    },
  );

  test('drain returns null when the engine is not ready', () async {
    final recap = await drainGeneratedRecap(
      engineReady: false,
      events: () => Stream.error(StateError('should not run')),
    );
    expect(recap, isNull);
  });

  test('drain returns null when generation is cancelled or throws', () async {
    expect(
      await drainGeneratedRecap(
        engineReady: true,
        events: () => Stream<GenerationEvent>.fromIterable([
          const GenerationEventCancelled(),
        ]),
      ),
      isNull,
    );
    expect(
      await drainGeneratedRecap(
        engineReady: true,
        events: () => Stream<GenerationEvent>.error(Exception('boom')),
      ),
      isNull,
    );
  });
}
