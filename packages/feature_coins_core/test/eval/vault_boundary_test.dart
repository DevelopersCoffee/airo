import 'dart:io';

import 'package:test/test.dart';

/// Narrower cousin of Mind's R05 gate (`scripts/check-mind-private-devices.sh`):
/// where R05 proves a private-device build can't link a shared surface,
/// this proves the COINS-AI extraction/categorization code (COINS-AI-5,
/// COINS-AI-6, this harness) never references the vault package at all.
/// #1650's "injection & vault-boundary tests" acceptance criterion, scoped
/// to what's actually buildable before COINS-AI-1's real extraction
/// pipeline exists: a prompt-injection attempt via a merchant string can't
/// reach a vault repository if the code path that reads that string never
/// imports one.
const _scannedDirs = ['lib/src/services', 'lib/src/eval'];

const _forbiddenPatterns = [
  'platform_coin_vault',
  'VaultRepository',
  'VaultSecureStorage',
];

List<File> _dartFilesUnder(String relativeDir) {
  final dir = Directory('${Directory.current.path}/$relativeDir');
  if (!dir.existsSync()) return [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

List<String> _findVaultReferences() {
  final violations = <String>[];
  for (final relativeDir in _scannedDirs) {
    for (final file in _dartFilesUnder(relativeDir)) {
      final content = file.readAsStringSync();
      for (final pattern in _forbiddenPatterns) {
        if (content.contains(pattern)) {
          violations.add('${file.path}: contains "$pattern"');
        }
      }
    }
  }
  return violations;
}

void main() {
  group('COINS-AI vault boundary', () {
    test(
      'categorization and detection services never reference the vault',
      () {
        expect(_findVaultReferences(), isEmpty);
      },
    );

    test('the check can actually fail -- proven by a mutation probe', () {
      final probe = File(
        '${Directory.current.path}/lib/src/services/_vault_boundary_mutation_probe.dart',
      );
      probe.writeAsStringSync(
        "// Temporary probe written by vault_boundary_test.dart.\n"
        "import 'package:platform_coin_vault/platform_coin_vault.dart';\n",
      );

      try {
        final violations = _findVaultReferences();
        expect(
          violations,
          isNotEmpty,
          reason:
              'The scan did not flag a direct platform_coin_vault import. '
              'Its pattern list is broken and it is enforcing nothing.',
        );
      } finally {
        if (probe.existsSync()) probe.deleteSync();
      }
    });
  });
}
