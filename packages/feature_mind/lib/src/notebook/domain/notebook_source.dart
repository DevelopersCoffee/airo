/// How a notebook note was captured.
enum NotebookSource {
  /// Typed by the person.
  manual,

  /// In-app microphone capture, then whisper.
  live,

  /// A local audio file they picked.
  upload,

  /// A podcast / remote audio URL downloaded then transcribed.
  podcast,

  /// Folded from several other notes.
  superSummary;

  static NotebookSource fromName(String? name) {
    return NotebookSource.values.firstWhere(
      (value) => value.name == name,
      orElse: () => NotebookSource.manual,
    );
  }

  static NotebookSource fromProcessingSource(String name) {
    return switch (name) {
      'live' => NotebookSource.live,
      'upload' => NotebookSource.upload,
      'podcast' => NotebookSource.podcast,
      _ => NotebookSource.manual,
    };
  }
}
