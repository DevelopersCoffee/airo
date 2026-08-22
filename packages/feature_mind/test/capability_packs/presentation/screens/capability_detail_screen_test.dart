import 'package:feature_mind/src/capability_packs/presentation/screens/capability_detail_screen.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/ports/capability_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_capability_port.dart';

void main() {
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

  testWidgets('shows what it does and which port it touches', (tester) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);

    await tester.pumpWidget(
      wrap(CapabilityDetailScreen(capability: audioScribe, port: port)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audio Scribe'), findsOneWidget);
    expect(find.textContaining('1.1'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.textContaining('Capability'), findsWidgets);
  });

  testWidgets('names the resource a consent-gated capability requires', (
    tester,
  ) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);

    await tester.pumpWidget(
      wrap(CapabilityDetailScreen(capability: audioScribe, port: port)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mic'), findsOneWidget);
  });

  testWidgets('toggling active calls the port and flips the switch', (
    tester,
  ) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);

    await tester.pumpWidget(
      wrap(CapabilityDetailScreen(capability: audioScribe, port: port)),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(port.setActiveCalls, [(id: 'audio_scribe', active: false)]);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });

  testWidgets('removing asks for confirmation before calling the port', (
    tester,
  ) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);
    var changed = false;

    await tester.pumpWidget(
      wrap(
        CapabilityDetailScreen(
          capability: audioScribe,
          port: port,
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // A confirmation dialog, not an immediate destructive action.
    expect(port.removeCalls, isEmpty);
    expect(find.text('Remove Audio Scribe?'), findsOneWidget);

    await tester.tap(find.text('Remove pack'));
    await tester.pumpAndSettle();

    expect(port.removeCalls, ['audio_scribe']);
    expect(changed, isTrue);
  });

  testWidgets('cancelling the remove dialog does not touch the port', (
    tester,
  ) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);

    await tester.pumpWidget(
      wrap(CapabilityDetailScreen(capability: audioScribe, port: port)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(port.removeCalls, isEmpty);
    expect(find.text('Audio Scribe'), findsOneWidget);
  });

  testWidgets('a failed removal surfaces an error, not a silent no-op', (
    tester,
  ) async {
    final port = FakeCapabilityPort(installedResult: [audioScribe]);
    port.installedError = null;

    await tester.pumpWidget(
      wrap(
        CapabilityDetailScreen(
          capability: audioScribe,
          port: _ThrowingRemovePort(port),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove pack'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not remove'), findsOneWidget);
  });
}

/// Wraps a [FakeCapabilityPort] to make [remove] fail, so the detail screen's
/// error path can be exercised without adding failure modes to the fake
/// itself.
class _ThrowingRemovePort implements CapabilityPort {
  _ThrowingRemovePort(this._inner);

  final FakeCapabilityPort _inner;

  @override
  Future<void> setActive(String id, {required bool active}) =>
      _inner.setActive(id, active: active);

  @override
  Future<List<InstalledCapability>> installed() => _inner.installed();

  @override
  Future<InstalledCapability?> byId(String id) => _inner.byId(id);

  @override
  Future<void> remove(String id) async {
    throw StateError('disk full');
  }
}
