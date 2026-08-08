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

  test('the gate fails when the entrypoint imports the module', () {
    final entrypoint = File('${root.path}/app/lib/main.dart');
    final original = entrypoint.readAsStringSync();

    entrypoint.writeAsStringSync(
      "import 'package:feature_mind/feature_mind.dart';\n$original",
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(
        result.exitCode,
        isNonZero,
        reason:
            'The gate let the web entrypoint import feature_mind directly, '
            'which is how the module gets back into a shared-surface build '
            'without anyone naming MindModule.',
      );
    } finally {
      entrypoint.writeAsStringSync(original);
    }
  });

  // The registration seam is where R05 is actually decided now: `main.dart`
  // names no module at all, and the web compile resolves `registerMindModule`
  // to the file below. A gate that only read the entrypoint would report OK
  // having checked nothing — the same failure its own comments describe.
  test('the gate fails when the web registration imports the module', () {
    final web = File(
      '${root.path}/app/lib/core/mind/register_mind_module_web.dart',
    );
    final original = web.readAsStringSync();

    web.writeAsStringSync(
      "import 'package:feature_mind/feature_mind.dart';\n$original",
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(
        result.exitCode,
        isNonZero,
        reason:
            'The gate let the web half of the registration seam import '
            'feature_mind. A shared surface must not be able to reach a '
            'personal vault.',
      );
    } finally {
      web.writeAsStringSync(original);
    }
  });

  test('the gate fails when the web registration composes the module', () {
    final web = File(
      '${root.path}/app/lib/core/mind/register_mind_module_web.dart',
    );
    final original = web.readAsStringSync();

    web.writeAsStringSync(
      original.replaceFirst(
        'void registerMindModule(ModuleRegistry registry) {',
        'void registerMindModule(ModuleRegistry registry) {\n'
            '  registry.register(MindModule(hostAdapterBuilder: null));',
      ),
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, isNonZero, reason: result.stdout.toString());
    } finally {
      web.writeAsStringSync(original);
    }
  });

  test('the gate refuses to run when the entrypoint leaves the seam', () {
    // Not a violation but not verifiable either: an entrypoint that registers
    // Mind some other way leaves the gate reading a file nothing imports. It
    // must say so rather than report a clean tree.
    final entrypoint = File('${root.path}/app/lib/main.dart');
    final original = entrypoint.readAsStringSync();

    entrypoint.writeAsStringSync(
      original.replaceAll('registerMindModule(', 'someOtherRegistration('),
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, 127, reason: result.stdout.toString());
    } finally {
      entrypoint.writeAsStringSync(original);
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
