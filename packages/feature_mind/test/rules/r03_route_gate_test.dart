import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mutation test for R03's route gate.
///
/// Writes a file that violates the rule, runs the gate, asserts it fails, then
/// removes the file. Without this, a gate with a broken pattern passes forever
/// and reads as enforcement — a green check that cannot fail is worse than no
/// check, because it survives review.
void main() {
  late Directory root;
  late String gate;

  setUp(() {
    root = Directory.current.parent.parent;
    gate = '${root.path}/scripts/check-mind-projection-routes.sh';
  });

  test('the gate passes a clean tree', () {
    final result = Process.runSync(gate, const []);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('the gate fails on a route that targets one projection', () {
    final offender = File('${root.path}/app/lib/r03_mutation_probe.dart');
    offender.writeAsStringSync('''
// Temporary probe written by r03_route_gate_test.dart. Deleted in its teardown.
const route = GoRoute(path: '/mind/graph', name: 'mind_graph');
''');

    try {
      final result = Process.runSync(gate, const []);
      expect(
        result.exitCode,
        isNonZero,
        reason:
            'The gate passed a route that targets a single projection. Its '
            'pattern is broken and it is enforcing nothing.',
      );
    } finally {
      if (offender.existsSync()) offender.deleteSync();
    }
  });

  test('the gate fails on a bare timeline route too', () {
    // Three projections, three ways to break the rule. A gate that only
    // catches "graph" is a gate that lets two through.
    final offender = File('${root.path}/app/lib/r03_mutation_probe_two.dart');
    offender.writeAsStringSync('''
const route = GoRoute(path: 'timeline', name: 'timeline');
''');

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, isNonZero);
    } finally {
      if (offender.existsSync()) offender.deleteSync();
    }
  });

  test('the gate refuses to run when its search finds nothing at all', () {
    // The gate's job is to find something that should not be there, so a
    // broken search — missing tool, wrong flags, wrong paths — reports OK
    // having checked nothing. The positive control must catch that.
    //
    // Simulated by copying the gate into a tree whose sources exist but do not
    // contain MindProjectionSwitcher, which is what a broken search looks like
    // from the gate's point of view. This replaced a `command -v rg` check:
    // GitHub's ubuntu-latest runner has no ripgrep, both gates exited 127 on
    // their first real CI run, and the lesson was that asserting a tool exists
    // is weaker than asserting the search actually finds a known string.
    final fake = Directory.systemTemp.createTempSync('mind_broken_search');
    try {
      Directory('${fake.path}/scripts').createSync();
      Directory('${fake.path}/packages').createSync();
      File(
        '${fake.path}/packages/unrelated.dart',
      ).writeAsStringSync('class Unrelated {}');
      final copied = File('${fake.path}/scripts/gate.sh')
        ..writeAsStringSync(File(gate).readAsStringSync());
      Process.runSync('chmod', ['+x', copied.path]);

      final result = Process.runSync('bash', [copied.path]);

      expect(
        result.exitCode,
        127,
        reason:
            'The gate reported OK from a tree where its positive control '
            'cannot match.\nstdout: ${result.stdout}\n'
            'stderr: ${result.stderr}',
      );
      expect(result.stderr.toString(), contains('cannot verify anything'));
    } finally {
      fake.deleteSync(recursive: true);
    }
  });
}
