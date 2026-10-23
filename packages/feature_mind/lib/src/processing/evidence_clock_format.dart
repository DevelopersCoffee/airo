/// `mm:ss` for evidence timestamps in the meeting reader (shorter than export's
/// bracketed `[hh:mm:ss]` timestamps).
String formatEvidenceClock(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
