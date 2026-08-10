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

  test(
    'the gate fails when the web entrypoint constructs MindModule directly',
    () {
      // The web build compiles app/lib/main.dart, not app/web (which holds
      // only index.html and assets, never a .dart file) -- so the gate reads
      // the entrypoint's module registry rather than scanning app/web. See
      // the "real question" comment in check-mind-private-devices.sh for why
      // the app/web scan this replaced was a vacuous positive control.
      final entrypoint = File('${root.path}/app/lib/main.dart');
      final original = entrypoint.readAsStringSync();

      entrypoint.writeAsStringSync(
        '$original\n'
        '// r05 mutation probe\n'
        'final _r05Probe = MindModule(hostAdapterBuilder: (_, __) {});\n',
      );

      try {
        final result = Process.runSync(gate, const []);
        expect(
          result.exitCode,
          isNonZero,
          reason:
              'A web build that constructs MindModule directly -- bypassing '
              'the conditional-import registration -- must fail the gate.',
        );
      } finally {
        entrypoint.writeAsStringSync(original);
      }
    },
  );

  test('the gate fails when the entrypoint imports the module', () {
    // A type reference needs no `MindModule(` token, so the construction
    // mutation above cannot see this route back in.
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

  // The two below are the ones the entrypoint checks cannot reach. Since the
  // registration moved behind a conditional import, `main.dart` names no
  // module at all and the web compile resolves `registerMind` to the stub --
  // so a gate that only read the entrypoint would report OK having checked
  // nothing. That is the same vacuous-search failure the gate's own comments
  // describe about the `app/web` scan, one file further along.
  test('the gate fails when the web registration imports the module', () {
    final stub = File(
      '${root.path}/app/lib/core/mind/mind_registration_stub.dart',
    );
    final original = stub.readAsStringSync();

    stub.writeAsStringSync(
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
      stub.writeAsStringSync(original);
    }
  });

  test('the gate fails when the web registration composes the module', () {
    final stub = File(
      '${root.path}/app/lib/core/mind/mind_registration_stub.dart',
    );
    final original = stub.readAsStringSync();

    stub.writeAsStringSync(
      original.replaceFirst(
        'void registerMind(ModuleRegistry registry) {}',
        'void registerMind(ModuleRegistry registry) {\n'
            '  registry.register(MindModule(hostAdapterBuilder: null));\n'
            '}',
      ),
    );

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, isNonZero, reason: result.stdout.toString());
    } finally {
      stub.writeAsStringSync(original);
    }
  });

  test('the gate refuses to run when the entrypoint leaves the seam', () {
    // Not a violation, but not verifiable either: an entrypoint that
    // registers Mind some other way leaves the gate inspecting a stub nothing
    // imports. It must say so rather than report a clean tree.
    final entrypoint = File('${root.path}/app/lib/main.dart');
    final original = entrypoint.readAsStringSync();

    entrypoint.writeAsStringSync(
      original.replaceAll('registerMind(', 'someOtherRegistration('),
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
