import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract checks on the package itself rather than on its behaviour.
void main() {
  test('the module manifest allows every first-party dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final module = File('module.yaml').readAsStringSync();

    // module.yaml governs first-party packages; pub.dev packages are governed
    // by the dependency scorecard instead.
    final firstParty = RegExp(
      r'^\s{2}(core_\w+|platform_\w+|feature_\w+):',
      multiLine: true,
    ).allMatches(pubspec).map((match) => match.group(1)!).toSet();

    for (final dependency in firstParty) {
      expect(
        module,
        contains(dependency),
        reason:
            'module.yaml must list $dependency in allowed_dependencies '
            'before the pubspec depends on it.',
      );
    }
  });

  test('the public library exports the runtime, not the bridge', () {
    final library = File('lib/feature_mind.dart').readAsStringSync();

    expect(library, contains("export 'src/runtime/mind_runtime.dart'"));
    // The word appears in this file's own doc comment explaining the rule, so
    // match an export directive rather than a mention.
    expect(
      RegExp(r"^export .*frb_generated", multiLine: true).hasMatch(library),
      isFalse,
      reason:
          'The generated bridge is an implementation detail. Only '
          'rust_mind_runtime.dart may reach it.',
    );
  });

  test('nothing in the runtime or widget layer reaches the bridge', () {
    // Scoped to the layers milestone 22 owns rather than carrying an exemption
    // list. The meeting recorder predates the port and legitimately uses the
    // bridge; a check that exempted it file by file would be diluted one file
    // at a time until it enforced nothing.
    final offenders = <String>[];
    const layers = ['lib/src/runtime', 'lib/src/widgets'];

    for (final layer in layers) {
      for (final entity in Directory(layer).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('rust_mind_runtime')) continue;

        final source = entity.readAsStringSync();
        if (RegExp(r"import .*(frb_generated|/api/)").hasMatch(source)) {
          offenders.add(entity.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A Mind surface that reaches into the generated bridge has coupled '
          'itself to a code generator output:\n${offenders.join('\n')}',
    );
  });
}
