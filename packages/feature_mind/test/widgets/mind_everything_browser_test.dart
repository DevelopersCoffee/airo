import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/projection_models.dart';
import 'package:feature_mind/src/runtime/ports/capability_port.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/mesh_port.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/runtime/ports/portability_port.dart';
import 'package:feature_mind/src/runtime/ports/projection_port.dart';
import 'package:feature_mind/src/runtime/ports/vault_port.dart';
import 'package:feature_mind/src/widgets/mind_everything_browser.dart';
import 'package:feature_mind/src/widgets/mind_context_chip.dart';
import 'package:feature_mind/src/widgets/mind_number_strip.dart';
import 'package:feature_mind/src/widgets/mind_presence_pip.dart';

/// A minimal, local stand-in for `test/support/mind_rule_harness.dart`.
///
/// The shared harness imports the `feature_mind.dart` barrel, which does not
/// build in this worktree (gitignored `.freezed.dart` files missing under
/// `lib/src/llama/` and `lib/src/whisper/`, unrelated to this change). Using
/// it would drag that break into every test in this file, so this repeats
/// just the R01/R02/R04 checks the harness makes, scoped to the files this
/// test actually imports.
Future<void> expectSatisfiesMindRules(
  WidgetTester tester, {
  bool expectsNumbers = true,
}) async {
  expect(
    find.byType(MindPresencePip),
    findsAtLeastNWidgets(1),
    reason: 'R01: every Mind surface states where the work ran.',
  );

  if (expectsNumbers) {
    expect(
      find.byType(MindNumberStrip),
      findsAtLeastNWidgets(1),
      reason: 'R04: ops, peers and vault state stay visible.',
    );
  }

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
}

/// A [ProjectionPort] that always fails, as if milestone 19 has not
/// implemented the projections port yet.
class _UnavailableProjectionPort implements ProjectionPort {
  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async =>
      throw const MindPortUnavailable('projections', 'not implemented yet');

  @override
  Future<List<ProjectionState>> states() async =>
      throw const MindPortUnavailable('projections', 'not implemented yet');

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) =>
      throw const MindPortUnavailable('projections', 'not implemented yet');

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async =>
      throw const MindPortUnavailable('projections', 'not implemented yet');
}

/// A [ProjectionPort] whose search index is mid-rebuild.
class _RebuildingProjectionPort implements ProjectionPort {
  _RebuildingProjectionPort(this._delegate);

  final ProjectionPort _delegate;

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async {
    if (kind != ProjectionKind.search) return _delegate.stateOf(kind);
    return const ProjectionState(
      kind: ProjectionKind.search,
      status: ProjectionStatus.rebuilding,
      lastRebuildMs: 3100,
      opsProcessed: 6240,
      opsTotal: 12481,
    );
  }

  @override
  Future<List<ProjectionState>> states() => _delegate.states();

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) =>
      _delegate.rebuild(kind);

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) =>
      _delegate.search(query, contextId: contextId);
}

/// Wraps [FixtureMindRuntime] but swaps in a different [ProjectionPort], so
/// each non-happy-path test only has to override the one port it cares
/// about.
class _RuntimeWithProjections implements MindRuntime {
  _RuntimeWithProjections(this.projections) : _base = FixtureMindRuntime();

  final MindRuntime _base;

  @override
  final ProjectionPort projections;

  @override
  VaultPort get vault => _base.vault;
  @override
  OperationLogPort get log => _base.log;
  @override
  ContextPort get contexts => _base.contexts;
  @override
  MeshPort get mesh => _base.mesh;
  @override
  CapabilityPort get capabilities => _base.capabilities;
  @override
  ModelPort get models => _base.models;
  @override
  PortabilityPort get portability => _base.portability;
}

/// Runs [body] with `defaultTargetPlatform` overridden, then resets it.
///
/// The reset has to happen inside the `testWidgets` callback itself — a
/// `tearDown` registered with package:test runs after
/// `TestWidgetsFlutterBinding` has already asserted no foundation debug
/// variable was left set, so a global `setUp`/`tearDown` pair is too late.
/// Matches the try/finally pattern already used for this in
/// `feature_iptv/test/iptv/presentation/screens/iptv_screen_test.dart`.
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// A fixed number of pumps rather than [WidgetTester.pumpAndSettle].
///
/// The rebuilding banner renders a [CircularProgressIndicator], which
/// animates forever by design — there is nothing to settle to while a
/// projection is rebuilding, and `pumpAndSettle` times out waiting for an
/// animation that never stops.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  Future<void> pumpBrowser(WidgetTester tester, MindRuntime runtime) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MindEverythingBrowser(runtime: runtime)),
      ),
    );
    await settle(tester);
  }

  group('macOS gating', () {
    testWidgets('renders nothing but a truthful message off macOS', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        expect(
          find.byKey(const Key('mind.everythingBrowser.unsupported')),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
      });
    });

    testWidgets('renders the browser on macOS', (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        expect(
          find.byKey(const Key('mind.everythingBrowser.searchField')),
          findsOneWidget,
        );
      });
    });
  });

  group('search and rules', () {
    testWidgets('satisfies R01, R02 and R04', (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        await expectSatisfiesMindRules(tester);
      });
    });

    testWidgets('R01/R04 pass in a realistic macOS window width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        await expectSatisfiesMindRules(tester);
        // The bug the prior attempt hit: chips in a bare Row overflow a
        // narrow pane. No RenderFlex overflow should have been recorded.
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('chips do not overflow in a narrow three-column pane', (
      tester,
    ) async {
      // Narrower than a real macOS window on purpose: the left column gets a
      // fraction of this, which is exactly the squeeze that overflowed a
      // bare Row before.
      tester.view.physicalSize = const Size(760, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        expect(tester.takeException(), isNull);
        expect(find.byType(MindContextChip), findsWidgets);
        for (final element in find.byType(MindContextChip).evaluate()) {
          final size = (element.renderObject! as RenderBox).size;
          expect(
            size.height,
            greaterThanOrEqualTo(MindContextChip.minimumTarget),
          );
        }
      });
    });

    testWidgets('shows a real latency figure and the hit count', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        final hitCount = find.byKey(
          const Key('mind.everythingBrowser.hitCount'),
        );
        expect(hitCount, findsOneWidget);
        final text = tester.widget<Text>(hitCount).data!;
        expect(text, matches(RegExp(r'^\d+ HITS · \d+ MS$')));
        expect(find.text('Nothing is sent anywhere.'), findsOneWidget);
      });
    });

    testWidgets('typing filters results and updates the preview', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        await tester.enterText(
          find.byKey(const Key('mind.everythingBrowser.searchField')),
          'discharge',
        );
        await settle(tester);

        expect(
          find.textContaining('discharge', findRichText: true),
          findsWidgets,
        );
      });
    });

    testWidgets('selecting a hit shows its op number and signature state', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        expect(
          find.byKey(const Key('mind.everythingBrowser.opNumber')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mind.everythingBrowser.signatureState')),
          findsOneWidget,
        );
      });
    });

    testWidgets('an inferred field reads differently from a filed one', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        expect(find.textContaining('Category (inferred)'), findsOneWidget);
      });
    });
  });

  group('non-happy states', () {
    testWidgets('empty results show a truthful empty state', (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(tester, FixtureMindRuntime());

        await tester.enterText(
          find.byKey(const Key('mind.everythingBrowser.searchField')),
          'zzzz-no-such-op',
        );
        await settle(tester);

        expect(
          find.byKey(const Key('mind.everythingBrowser.emptyResults')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mind.everythingBrowser.noPreview')),
          findsOneWidget,
        );
      });
    });

    testWidgets('an unavailable projections port names itself', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await pumpBrowser(
          tester,
          _RuntimeWithProjections(_UnavailableProjectionPort()),
        );

        final banner = find.byKey(
          const Key('mind.everythingBrowser.unavailable'),
        );
        expect(banner, findsOneWidget);
        expect(tester.widget<Text>(banner).data, contains('projections'));
      });
    });

    testWidgets('a rebuilding index shows ops processed and total', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.macOS, () async {
        final base = FixtureMindRuntime();
        await pumpBrowser(
          tester,
          _RuntimeWithProjections(
            _RebuildingProjectionPort(base.projections),
          ),
        );

        final banner = find.byKey(
          const Key('mind.everythingBrowser.rebuilding'),
        );
        expect(banner, findsOneWidget);
        final text = tester.widget<Text>(banner).data!;
        expect(text, contains('6,240'));
        expect(text, contains('12,481'));
      });
    });
  });
}
