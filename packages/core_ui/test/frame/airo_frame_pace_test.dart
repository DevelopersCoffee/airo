import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hd60 = AiroDisplayMode(
    id: 1,
    width: 1080,
    height: 2400,
    refreshRate: 60,
  );
  const hd120 = AiroDisplayMode(
    id: 2,
    width: 1080,
    height: 2400,
    refreshRate: 120,
  );
  const hd144 = AiroDisplayMode(
    id: 3,
    width: 1080,
    height: 2400,
    refreshRate: 144,
  );
  const uhd120 = AiroDisplayMode(
    id: 4,
    width: 3840,
    height: 2160,
    refreshRate: 120,
  );

  group('AiroFrameBudget', () {
    test('120 Hz is an 8.33 ms frame', () {
      expect(
        const AiroFrameBudget(120).duration,
        const Duration(microseconds: 8333),
      );
      expect(const AiroFrameBudget(120).isHighRefresh, isTrue);
    });

    test('60 Hz is a 16.67 ms frame', () {
      expect(
        const AiroFrameBudget(60).duration,
        const Duration(microseconds: 16667),
      );
      expect(const AiroFrameBudget(60).isHighRefresh, isFalse);
    });

    test('a non-positive rate falls back to 60 Hz', () {
      expect(
        const AiroFrameBudget(0).duration,
        const AiroFrameBudget(60).duration,
      );
    });
  });

  group('AiroFramePacePolicy.select', () {
    test('prefers 120 Hz at the active resolution over 144 Hz and 4K', () {
      final selected = AiroFramePacePolicy.select(
        supported: const [hd60, hd144, hd120, uhd120],
        active: hd60,
      );

      expect(selected, hd120);
    });

    test(
      'uses the fastest mode at the active resolution when 120 is absent',
      () {
        final selected = AiroFramePacePolicy.select(
          supported: const [hd60, hd144],
          active: hd60,
        );

        expect(selected, hd144);
      },
    );

    test('keeps the current resolution instead of switching to 4K for 120', () {
      final selected = AiroFramePacePolicy.select(
        supported: const [hd60, uhd120],
        active: hd60,
      );

      expect(selected, hd60);
    });

    test('breaks refresh-rate ties by the lower mode id', () {
      const other120 = AiroDisplayMode(
        id: 9,
        width: 1080,
        height: 2400,
        refreshRate: 120,
      );

      final selected = AiroFramePacePolicy.select(
        supported: const [other120, hd120],
        active: hd60,
      );

      expect(selected, hd120);
    });

    test('returns null when the device reports no modes', () {
      expect(AiroFramePacePolicy.select(supported: const []), isNull);
    });
  });

  group('AiroFramePace', () {
    testWidgets('applies 120 Hz and publishes that budget', (tester) async {
      final platform = _FakeFramePacePlatform(
        const AiroDisplayInventory(supported: [hd60, hd120], active: hd60),
      );
      late AiroFrameBudget budget;
      late AiroFramePaceSource source;

      await tester.pumpWidget(
        AiroFramePace(
          platform: platform,
          child: Builder(
            builder: (context) {
              final scope = AiroFramePaceScope.maybeOf(context)!;
              budget = scope.budget;
              source = scope.source;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(platform.applied, [hd120.id]);
      expect(budget.refreshRateHz, 120);
      expect(source, AiroFramePaceSource.operatingSystem);
      expect(
        AiroFrameBudget.of(tester.element(find.byType(SizedBox))).refreshRateHz,
        120,
      );
    });

    testWidgets('does not reapply a mode that is already active', (
      tester,
    ) async {
      final platform = _FakeFramePacePlatform(
        const AiroDisplayInventory(supported: [hd60, hd120], active: hd120),
      );

      await tester.pumpWidget(
        AiroFramePace(platform: platform, child: const SizedBox.shrink()),
      );
      await tester.pump();

      expect(platform.applied, isEmpty);
      expect(
        AiroFrameBudget.of(tester.element(find.byType(SizedBox))).refreshRateHz,
        120,
      );
    });

    testWidgets('follows the Flutter view when the OS channel is absent', (
      tester,
    ) async {
      final platform = _FakeFramePacePlatform(
        const AiroDisplayInventory(supported: []),
      );
      late AiroFramePaceSource source;

      await tester.pumpWidget(
        AiroFramePace(
          platform: platform,
          child: Builder(
            builder: (context) {
              source = AiroFramePaceScope.maybeOf(context)!.source;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(platform.applied, isEmpty);
      expect(source, AiroFramePaceSource.display);
      expect(
        AiroFrameBudget.of(tester.element(find.byType(SizedBox))).refreshRateHz,
        greaterThan(1),
      );
    });

    testWidgets('asks again when the app resumes', (tester) async {
      final platform = _FakeFramePacePlatform(
        const AiroDisplayInventory(supported: [hd120], active: hd120),
      );

      await tester.pumpWidget(
        AiroFramePace(platform: platform, child: const SizedBox.shrink()),
      );
      await tester.pump();
      expect(platform.reads, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(platform.reads, 2);
    });

    testWidgets('retries once when the activity window is not ready', (
      tester,
    ) async {
      final platform = _FakeFramePacePlatform(
        const AiroDisplayInventory(supported: [], transientFailure: true),
        then: const AiroDisplayInventory(supported: [hd120], active: hd60),
      );

      await tester.pumpWidget(
        AiroFramePace(platform: platform, child: const SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pump();

      expect(platform.reads, 2);
      expect(platform.applied, [hd120.id]);
    });
  });

  group('paint isolation', () {
    testWidgets('AiroRepaintIsland inserts a repaint boundary', (tester) async {
      await tester.pumpWidget(
        const AiroRepaintIsland(child: SizedBox.shrink()),
      );

      expect(find.byType(RepaintBoundary), findsOneWidget);
    });

    testWidgets('AiroLazyList builds only the visible window', (tester) async {
      final built = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 100,
            child: AiroLazyList(
              itemCount: 50,
              itemBuilder: (context, index) {
                built.add(index);
                return const SizedBox(height: 40);
              },
            ),
          ),
        ),
      );

      expect(built.length, lessThan(50));
      expect(built, contains(0));
      expect(
        find.descendant(
          of: find.byType(AiroLazyList),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('LoadingIndicator isolates the spinner', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoadingIndicator()));

      expect(
        find.descendant(
          of: find.byType(AiroRepaintIsland),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });
}

class _FakeFramePacePlatform implements AiroFramePacePlatform {
  _FakeFramePacePlatform(this.inventory, {this.then});

  final AiroDisplayInventory inventory;
  final AiroDisplayInventory? then;
  var reads = 0;
  final applied = <int>[];

  @override
  Future<AiroDisplayInventory> readInventory() async {
    reads += 1;
    if (reads > 1 && then != null) return then!;
    return inventory;
  }

  @override
  Future<bool> applyMode(int modeId) async {
    applied.add(modeId);
    return true;
  }
}
