import 'notebook_note.dart';

/// Prompt for on-device Super Summary generation.
///
/// Prompt-as-is for the generation engine. Source text is clipped so a
/// long transcript cannot blow the context window.
class SuperSummaryPrompt {
  const SuperSummaryPrompt._();

  static const maxPromptChars = 16000;
  static const maxTranscriptChars = 4000;

  static String build(List<NotebookNote> notes) {
    final buf = StringBuffer()
      ..writeln(
        'You are writing one Super Summary of ${notes.length} on-device notes.',
      )
      ..writeln('Stay faithful to the sources. Do not invent facts.')
      ..writeln()
      ..writeln('Write:')
      ..writeln('# Summary')
      ..writeln('A short recap of the combined notes.')
      ..writeln()
      ..writeln('# Key points')
      ..writeln('- bullet facts and actions from the sources')
      ..writeln()
      ..writeln('Notes:');

    for (final note in notes) {
      final doc = note.document;
      buf
        ..writeln()
        ..writeln('## ${note.title}');
      if (doc.summary.trim().isNotEmpty) {
        buf.writeln('Summary: ${doc.summary.trim()}');
      }
      if (doc.keyPoints.isNotEmpty) {
        buf.writeln('Key points:');
        for (final point in doc.keyPoints) {
          buf.writeln('- $point');
        }
      }
      if (doc.body.trim().isNotEmpty) {
        buf.writeln(doc.body.trim());
      }
      final transcript = doc.transcript.trim();
      if (transcript.isNotEmpty) {
        buf
          ..writeln('Transcript:')
          ..writeln(_clip(transcript, maxTranscriptChars));
      }
    }

    final prompt = buf.toString().trimRight();
    return _clip(prompt, maxPromptChars);
  }

  static String _clip(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}\n[truncated]';
  }
}
