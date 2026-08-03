import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Airo Mind claims `/mind` in P4. Until then nothing else may hold it, and
/// the wellbeing hub held it for four months. This test is what stops it
/// coming back.
void main() {
  test('no route, tab, or directory called mind outside feature_mind', () {
    final offenders = <String>[];

    final lib = Directory('lib');
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Migration code has to name the old path to rewrite it. The marker
        // is per-line and deliberate, so it cannot quietly cover a real route
        // added to the same file later.
        if (lines[i].contains('mind-name-exempt')) continue;

        for (final pattern in [r"'/mind'", r"'/mind/", r'features/mind/']) {
          if (lines[i].contains(pattern)) {
            offenders.add('${entity.path}:${i + 1}: $pattern');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The wellbeing hub must not hold the Mind name:\n'
          '${offenders.join('\n')}',
    );
  });
}
