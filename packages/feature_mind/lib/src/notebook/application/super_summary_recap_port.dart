import 'package:core_ai/core_ai.dart';

import '../../bridges/mind_generation_bridge.dart';
import '../domain/notebook_note.dart';
import '../domain/super_summary_prompt.dart';

/// Generates a Super Summary recap, or returns null so the composer can
/// fall back to the extractive fold.
class SuperSummaryRecapPort {
  const SuperSummaryRecapPort(this.generate);

  final Future<String?> Function(List<NotebookNote> notes) generate;
}

/// Drains one [MindGenerationBridge.complete] stream into markdown.
///
/// Returns null when the engine is not ready, the user cancelled, the
/// model produced only whitespace, or the call threw — Super Summary must
/// still save an extractive recap in those cases.
Future<String?> drainGeneratedRecap({
  required bool engineReady,
  required Stream<GenerationEvent> Function() events,
}) async {
  if (!engineReady) return null;
  try {
    final buf = StringBuffer();
    await for (final event in events()) {
      switch (event) {
        case GenerationEventGenerating(:final text):
          buf.write(text);
        case GenerationEventMinutesReady(:final text):
          final ready = text.trim();
          return ready.isEmpty ? null : ready;
        case GenerationEventCancelled():
          return null;
      }
    }
    final text = buf.toString().trim();
    return text.isEmpty ? null : text;
  } on Object {
    return null;
  }
}

/// Builds the Super Summary prompt and completes it on [complete].
SuperSummaryRecapPort superSummaryRecapPort({
  required bool Function() isEngineReady,
  required Stream<GenerationEvent> Function({
    required String prompt,
    required int maxOutputTokens,
  })
  complete,
  int maxOutputTokens = 1024,
}) {
  return SuperSummaryRecapPort((notes) async {
    if (!AiroPromptRegistry.notebookSuperSummary.isRegistered) return null;
    return drainGeneratedRecap(
      engineReady: isEngineReady(),
      events: () => complete(
        prompt: SuperSummaryPrompt.build(notes),
        maxOutputTokens: maxOutputTokens,
      ),
    );
  });
}
