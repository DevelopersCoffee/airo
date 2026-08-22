/// Compares dotted plugin versions (`1.0.0`). Missing segments count as 0.
int comparePluginVersions(String left, String right) {
  final a = _parts(left);
  final b = _parts(right);
  for (var i = 0; i < 3; i++) {
    final delta = a[i].compareTo(b[i]);
    if (delta != 0) return delta;
  }
  return 0;
}

bool pluginVersionIsNewer(String candidate, String installed) {
  return comparePluginVersions(candidate, installed) > 0;
}

List<int> _parts(String version) {
  final parsed = version
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  while (parsed.length < 3) {
    parsed.add(0);
  }
  return parsed.take(3).toList();
}
