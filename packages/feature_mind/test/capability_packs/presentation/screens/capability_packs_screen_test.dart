import 'package:feature_mind/src/capability_packs/presentation/screens/capability_detail_screen.dart';
import 'package:feature_mind/src/capability_packs/presentation/screens/capability_packs_screen.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/widgets/mind_presence_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_capability_port.dart';

/// Surface 06. Installed list/detail bound to [CapabilityPort]; the drafter
/// and marketplace regions render in position but disabled — milestone 20
/// scope, not this one.
void main() {
  const hospitalRecovery = InstalledCapability(
    id: 'hospital_recovery',
    name: 'Hospital Recovery',
    version: '1.4',
    isFirstParty: true,
    isActive: true,
    itemCount: 38,
    safetyClass: CapabilitySafetyClass.health,
  );

  const audioScribe = InstalledCapability(
    id: 'audio_scribe',
    name: 'Audio Scribe',
    version: '1.1',
    isFirstParty: true,
    isActive: true,
    itemCount: 4,
    safetyClass: CapabilitySafetyClass.general,
    requiresConsentFor: ['mic'],
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('installed list', () {
    testWidgets('renders each installed capability', (tester) async {
      final port = FakeCapabilityPort(
        installedResult: [hospitalRecovery, audioScribe],
      );

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hospital Recovery'), findsOneWidget);
      expect(find.text('Audio Scribe'), findsOneWidget);
    });

    testWidgets('shows the R01 presence pip', (tester) async {
      final port = FakeCapabilityPort(installedResult: [hospitalRecovery]);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MindPresencePip), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail view', (tester) async {
      final port = FakeCapabilityPort(installedResult: [hospitalRecovery]);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hospital Recovery'));
      await tester.pumpAndSettle();

      expect(find.byType(CapabilityDetailScreen), findsOneWidget);
      // What it does, and which port it touches.
      expect(find.text('38 items'), findsOneWidget);
      expect(find.textContaining('Capability'), findsWidgets);
    });

    testWidgets('a loading state is shown before data arrives', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedResult: [hospitalRecovery]);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('against the fixture runtime', () {
    testWidgets('the fixture seeds more than one installed capability', (
      tester,
    ) async {
      final runtime = FixtureMindRuntime();

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: runtime.capabilities)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hospital Recovery'), findsOneWidget);
      expect(find.text('Property Maintenance'), findsOneWidget);
      expect(find.text('Tax 2026'), findsOneWidget);
    });
  });

  group('non-happy states', () {
    testWidgets('no capabilities installed shows an empty state, not blank', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedResult: const []);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hospital Recovery'), findsNothing);
      expect(find.textContaining('No capability packs'), findsOneWidget);
    });

    testWidgets('a MindPortUnavailable names the missing port', (
      tester,
    ) async {
      final port = FakeCapabilityPort(
        installedError: const MindPortUnavailable(
          'capabilities',
          'milestone 19 has not landed this yet',
        ),
      );

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('capabilities'), findsWidgets);
      expect(
        find.textContaining('milestone 19 has not landed this yet'),
        findsOneWidget,
      );
    });

    testWidgets('a generic failure still renders a named error, not a crash', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedError: StateError('boom'));

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });
  });

  group('drafter and marketplace regions (out of scope, disabled)', () {
    testWidgets('the drafter region is present but disabled', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedResult: [hospitalRecovery]);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.capabilities.drafter')),
        findsOneWidget,
      );
      expect(find.textContaining('drafter'), findsWidgets);
      expect(find.textContaining('future release'), findsWidgets);

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('mind.capabilities.drafter')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('the marketplace region is present but disabled', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedResult: [hospitalRecovery]);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.capabilities.marketplace')),
        findsOneWidget,
      );
      expect(find.textContaining('marketplace'), findsWidgets);

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('mind.capabilities.marketplace')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('both regions still render when the list is empty', (
      tester,
    ) async {
      final port = FakeCapabilityPort(installedResult: const []);

      await tester.pumpWidget(
        wrap(CapabilityPacksScreen(capabilities: port)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mind.capabilities.drafter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mind.capabilities.marketplace')),
        findsOneWidget,
      );
    });
  });
}
