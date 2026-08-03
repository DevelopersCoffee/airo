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

  test('the gate refuses to run without ripgrep rather than passing', () {
    // Both gates find violations with rg inside `|| true`. Without rg that
    // returns no matches and the gate would report OK having checked nothing —
    // the exact failure these gates exist to prevent.
    //
    // A PATH holding only the tools the script needs to reach its own guard,
    // and provably not rg. Pointing PATH at a nonexistent directory would hide
    // bash too and the shebang would fail before the guard ran, which proves
    // nothing; naming real bin directories would still find rg on Linux.
    final bin = Directory.systemTemp.createTempSync('mind_no_rg');
    for (final tool in ['bash', 'env', 'dirname', 'pwd']) {
      final resolved = Process.runSync('which', [
        tool,
      ]).stdout.toString().trim();
      if (resolved.isEmpty) continue;
      Link('${bin.path}/$tool').createSync(resolved);
    }

    try {
      final result = Process.runSync(
        gate,
        const [],
        environment: {'PATH': bin.path},
        includeParentEnvironment: false,
      );

      expect(
        result.exitCode,
        127,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
      expect(result.stderr.toString(), contains('ripgrep'));
    } finally {
      bin.deleteSync(recursive: true);
    }
  });
}
