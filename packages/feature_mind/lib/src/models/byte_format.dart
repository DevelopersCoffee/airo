/// Human-readable byte sizes for the model download manager (#1457).
///
/// A separate helper from `core_ai`'s `OfflineModelInfo.fileSizeDisplay`
/// deliberately: that one formats a single size, this one always renders
/// "used of total" pairs (`6.8 GB of 12 GB`) the way the storage budget and
/// download-progress rows need, and `ModelPort` speaks in bare `int` bytes,
/// never `OfflineModelInfo`.
library;

/// `1500000000` -> `1.4 GB`. Binary units (1024-based), matching how
/// operating systems report free disk space, so the number a person sees
/// here matches the number their OS shows them.
String formatBytes(int bytes) {
  if (bytes < 0) return '-${formatBytes(-bytes)}';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final decimals = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

/// `(received: 3, total: 10)` -> `3 B of 10 B`. What every progress row and
/// the storage budget bar render, so the "X of Y" phrasing is written once.
String formatBytesOf(int used, int total) =>
    '${formatBytes(used)} of ${formatBytes(total)}';
