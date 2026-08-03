/// Formats an elapsed duration as the design's short relative stamps: "41s
/// ago", "6h ago", "04 JUL".
///
/// Takes `nowMs` explicitly rather than reading a clock. A surface with a
/// hidden `DateTime.now()` produces a golden that moves with wall time; this
/// keeps "now" a value a test controls, and a real caller supplies the actual
/// clock at the point where it renders, not buried inside the formatter.
String relativeTime(int atMs, int nowMs) {
  final elapsedMs = nowMs - atMs;
  if (elapsedMs < 0) return 'just now';

  final seconds = elapsedMs ~/ 1000;
  if (seconds < 60) return '${seconds}s ago';

  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';

  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';

  // Beyond a day, the design switches to an absolute date rather than "3d
  // ago" -- a revoked device from weeks back reads better as a fixed point.
  return _absoluteDate(atMs);
}

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String _absoluteDate(int atMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true);
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]}';
}
