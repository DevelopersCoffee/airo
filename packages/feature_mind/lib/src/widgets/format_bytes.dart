/// Formats a byte count the way the design does: "2.4 GB", "780MB", "420MB".
///
/// One decimal place above a gigabyte, none below. The space before the unit
/// follows the design's own two examples exactly -- "2.4 GB" for the
/// headline figure, "780MB" for a per-class legend entry -- rather than
/// inventing one consistent convention the source does not use.
String formatBytes(int bytes) {
  if (bytes >= 1000000000) {
    final gb = bytes / 1000000000;
    return '${gb.toStringAsFixed(1)} GB';
  }
  final mb = (bytes / 1000000).round();
  return '${mb}MB';
}
