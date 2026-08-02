import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R05: Mind renders only on a device one person owns.
///
/// The gate asserts no shared-surface flavor links feature_mind. The mutation
/// tests assert the gate can fail — a check that has never failed is not
/// enforcement, it is decoration that survives review by being green.
void main() {
  late Directory root;
  late String gate;

  setUp(() {
    root = Directory.current.parent.parent;
    gate = '${root.path}/scripts/check-mind-private-devices.sh';
  });

  test('the gate passes the current tree', () {
    final result = Process.runSync(gate, const []);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('the gate fails when a shared flavor links feature_mind', () {
    final tv = File('${root.path}/app/pubspec_tv.yaml');
    final original = tv.readAsStringSync();

    tv.writeAsStringSync(
      '$original\n  feature_mind:\n    path: ../packages/feature_mind\n',
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(
        result.exitCode,
        isNonZero,
        reason:
            'The gate let the TV flavor link feature_mind. A shared screen '
            'must not be able to render a personal vault.',
      );
    } finally {
      tv.writeAsStringSync(original);
    }
  });

  test('the gate accepts a shared flavor that swaps in the stub', () {
    // The rule is "not the real module", not "no dependency at all" — a flavor
    // may name feature_mind so long as it resolves to the stub.
    final tv = File('${root.path}/app/pubspec_tv.yaml');
    final original = tv.readAsStringSync();

    tv.writeAsStringSync(
      '$original\n  feature_mind:\n'
      '    path: ../packages/stubs/feature_mind_stub\n',
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      tv.writeAsStringSync(original);
    }
  });

  test('the gate fails when web sources reach the module', () {
    final probe = File('${root.path}/app/web/r05_mutation_probe.dart');
    probe.writeAsStringSync("import 'package:feature_mind/feature_mind.dart';");

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, isNonZero);
    } finally {
      if (probe.existsSync()) probe.deleteSync();
    }
  });

  test('the stub answers to the same package name', () {
    final stub = File(
      '${root.path}/packages/stubs/feature_mind_stub/pubspec.yaml',
    ).readAsStringSync();

    // The override only works if the swap declares the name it replaces.
    expect(stub, contains('name: feature_mind'));
  });

  test('the stub re-exports nothing from the real module', () {
    final library = File(
      '${root.path}/packages/stubs/feature_mind_stub/lib/feature_mind.dart',
    ).readAsStringSync();

    // A shared build must fail to compile if it reaches for a Mind surface,
    // rather than compiling and rendering an empty screen.
    expect(library, isNot(contains('export ')));
    expect(library, contains('AiroMindAbsent'));
  });
}
