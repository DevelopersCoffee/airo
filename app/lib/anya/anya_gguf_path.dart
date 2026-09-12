import 'dart:io';

/// Resolves a local GGUF for Anya repair. Never downloads.
///
/// [configuredPath] wins when non-empty (`ANYA_GGUF_PATH` dart-define in
/// production). A configured path that does not exist returns null — it does
/// not fall through to [searchRoots].
String? resolveAnyaGgufPath({
  String? configuredPath,
  Iterable<Directory> searchRoots = const [],
}) {
  final configured =
      (configuredPath ?? const String.fromEnvironment('ANYA_GGUF_PATH')).trim();
  if (configured.isNotEmpty) {
    final file = File(configured);
    return file.existsSync() ? file.path : null;
  }
  for (final root in searchRoots) {
    if (!root.existsSync()) continue;
    final matches =
        root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.gguf'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (matches.isNotEmpty) return matches.first.path;
  }
  return null;
}
