import '../../mind_service.dart';

/// User-facing label for a [MindStage] during queue processing.
String meetingProcessingStageLabel(MindStage stage) => switch (stage) {
  MindStage.recording => 'Recording…',
  MindStage.transcribing => 'Transcribing audio…',
  MindStage.extracting => 'Identifying speakers & topics…',
  MindStage.generating => 'Writing minutes…',
  MindStage.saving => 'Saving meeting…',
  MindStage.done => 'Finishing up…',
  MindStage.failed => 'Processing failed',
  MindStage.idle => 'Processing…',
};

/// Short detail line for the processing banner.
String meetingProcessingDetail(MindProgress progress) {
  final snippet = progress.transcript.trim();
  if (snippet.isNotEmpty) {
    final tail = snippet.length > 72
        ? '…${snippet.substring(snippet.length - 72)}'
        : snippet;
    return tail;
  }
  return meetingProcessingStageLabel(progress.stage);
}
