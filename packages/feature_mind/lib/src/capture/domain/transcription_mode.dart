/// When meeting audio is transcribed — live, after stop, or both (#248 / ADR-0025).
library;

enum TranscriptionMode {
  afterRecording(
    storageValue: 'after_recording',
    menuLabel: 'After recording',
    settingsSubtitle: 'Transcribe when you stop — best battery and accuracy per watt',
  ),
  live(
    storageValue: 'live',
    menuLabel: 'Live',
    settingsSubtitle: 'Transcript while you record — uses more CPU and battery',
  ),
  liveRefine(
    storageValue: 'live_refine',
    menuLabel: 'Live + refine',
    settingsSubtitle: 'Live transcript, then a second pass on the recording for quality',
  );

  const TranscriptionMode({
    required this.storageValue,
    required this.menuLabel,
    required this.settingsSubtitle,
  });

  final String storageValue;
  final String menuLabel;
  final String settingsSubtitle;

  static const TranscriptionMode fallback = afterRecording;

  bool get usesLivePipeline => this == live || this == liveRefine;

  bool get runsPostRecordingPass =>
      this == afterRecording || this == liveRefine;

  static TranscriptionMode fromStorageValue(String? value) {
    return TranscriptionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => fallback,
    );
  }
}
