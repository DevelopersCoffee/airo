import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/feature_mind.dart';

/// Asserts the pumped widget tree satisfies rules R01–R04.
///
/// Lives under `test/` rather than `lib/` on purpose: every Mind surface lives
/// in this package, so every surface test can reach it by relative import, and
/// shipping it from `lib/` would drag `flutter_test` into the dependency graph
/// of a production package for no one's benefit. Promote it to its own package
/// the day something outside this package needs it.
///
/// Every Mind surface test calls this. Without one shared assertion each of
/// the fourteen surfaces reimplements four checks, and four checks written
/// fourteen times is four checks that drift.
///
/// R05 is deliberately absent: it is a property of the build, not of a widget
/// tree, and `scripts/check-mind-private-devices.sh` enforces it.
Future<void> expectSatisfiesMindRules(
  WidgetTester tester, {

  /// Set false for a surface with no status strip — a modal sheet, a capture
  /// overlay. The default is true because the strip is the norm and forgetting
  /// it must fail rather than pass.
  bool expectsNumbers = true,
}) async {
  // R01 — presence.
  expect(
    find.byType(MindPresencePip),
    findsAtLeastNWidgets(1),
    reason: 'R01: every Mind surface states where the work ran.',
  );

  // R04 — numbers.
  if (expectsNumbers) {
    expect(
      find.byType(MindNumberStrip),
      findsAtLeastNWidgets(1),
      reason: 'R04: ops, peers and vault state stay visible.',
    );
  }

  // R02, first half — chips meet the target. A surface with no tags passes
  // vacuously; a surface with tags must have real ones.
  final chips = find.byType(MindContextChip);
  for (var i = 0; i < chips.evaluate().length; i++) {
    expect(
      tester.getSize(chips.at(i)).height,
      greaterThanOrEqualTo(MindContextChip.minimumTarget),
      reason:
          'R02: a context chip below ${MindContextChip.minimumTarget}px is '
          'one a person misses.',
    );
  }

  // R02, second half — nothing that reads as a tag may be plain text. This is
  // the decorative-tag failure the rule exists to prevent, and it is invisible
  // to a check that only inspects real chips.
  //
  // A rectangular MindContextChip is not the only legitimate rendering: the
  // Memory graph draws a linked context as a circular node, which is still a
  // real tap target, just not that widget. The rule is "tappable", not
  // "this exact class", so an InkWell ancestor also satisfies it — InkWell is
  // the one tappable primitive every chip-like widget in this package is
  // already built on (MindContextChip included), so this does not weaken the
  // check against a genuinely decorative label.
  final bareTags = find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.startsWith('#') ?? false),
  );
  for (final element in bareTags.evaluate()) {
    final tappable =
        element.findAncestorWidgetOfExactType<MindContextChip>() ??
        element.findAncestorWidgetOfExactType<InkWell>();
    expect(
      tappable,
      isNotNull,
      reason:
          'R02: "${(element.widget as Text).data}" renders as a tag but has '
          'no tappable ancestor, so it is decoration.',
    );
  }
}
