import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixtureMindRuntime runtime;

  setUp(() => runtime = FixtureMindRuntime());

  test(
    'carries the design numbers so a golden can hold them to account',
    () async {
      expect(await runtime.log.count(), 12481);

      final contexts = await runtime.contexts.all();
      expect(contexts.map((c) => c.label), [
        '#KneeSurgery2026',
        '#DowntownApartment',
        '#Q3TaxFiling',
        '#AiroArchitecture',
      ]);
      expect(contexts.map((c) => c.itemCount), [38, 17, 52, 9]);
    },
  );

  test('is deterministic across instances', () async {
    final first = await FixtureMindRuntime().log.range(offset: 0, limit: 5);
    final second = await FixtureMindRuntime().log.range(offset: 0, limit: 5);

    expect(first, equals(second));
  });

  test('the log reads newest first and pages', () async {
    final page = await runtime.log.range(offset: 0, limit: 3);

    expect(page.first.sequence, 12481);
    expect(page.length, 3);
    expect(page.map((op) => op.sequence), orderedEquals([12481, 12477, 12463]));
  });

  test('appending advances the sequence and is readable back', () async {
    final before = await runtime.log.count();

    final sequence = await runtime.log.append(
      kind: MindOpKind.note,
      title: 'Carrier 24V filter — order two before the fifteenth',
      contextId: 'downtownapartment',
    );

    expect(sequence, before + 1);
    final op = await runtime.log.bySequence(sequence);
    expect(op?.title, contains('Carrier 24V'));
    expect(op?.signature, SignatureState.verified);
  });

  test('an appended op reads back at the head of the log', () async {
    await runtime.log.append(
      kind: MindOpKind.voice,
      title: 'Call the plumber',
      contextId: 'downtownapartment',
    );
    final page = await runtime.log.range(offset: 0, limit: 1);

    expect(page.single.title, 'Call the plumber');
  });

  test('the vault reports one revoked device and keeps it listed', () async {
    final state = await runtime.vault.state();
    expect(state.isSealed, isTrue);
    expect(state.keyCount, 4);
    expect(state.revokedCount, 1);

    final devices = await runtime.vault.devices();
    expect(devices.where((d) => d.isRevoked).map((d) => d.name), [
      'MacBook · Old',
    ]);
    expect(devices.singleWhere((d) => d.isThisDevice).name, 'Pixel 9 Pro');
  });

  test('destroying a context previews what survives', () async {
    final survivors = await runtime.contexts.survivorsIfDestroyed(
      'kneesurgery2026',
    );

    // The discharge note is linked into tax filing too, so it survives.
    expect(survivors, contains('#Q3TaxFiling'));
  });

  test('a context with no links has nothing that survives it', () async {
    final survivors = await runtime.contexts.survivorsIfDestroyed(
      'airoarchitecture',
    );

    expect(survivors, isEmpty);
  });
}
