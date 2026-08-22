/// Display label for a live transcript speaker (`P0`: no invented names).
String formatLiveSpeakerLabel(String? speakerLabel) {
  if (speakerLabel == null || speakerLabel.isEmpty) {
    return 'Speaker 1';
  }
  if (speakerLabel.startsWith('sp')) {
    final index = int.tryParse(speakerLabel.substring(2));
    if (index != null) {
      return 'Speaker ${index + 1}';
    }
  }
  return speakerLabel;
}

String formatLiveSegmentClock(int startMs) {
  final totalSeconds = startMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
