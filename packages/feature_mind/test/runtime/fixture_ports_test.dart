import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixtureMindRuntime runtime;

  setUp(() => runtime = FixtureMindRuntime());

  test('the three projections can be in three different states', () async {
    final states = await runtime.projections.states();

    expect(states.map((s) => s.kind), [
      ProjectionKind.graph,
      ProjectionKind.timeline,
      ProjectionKind.search,
    ]);
    expect(states.map((s) => s.status).toSet().length, greaterThan(1));
  });

  test('rebuild reports progress before it finishes', () async {
    final emitted = await runtime.projections
        .rebuild(ProjectionKind.search)
        .toList();

    expect(emitted.length, greaterThan(1));
    expect(emitted.first.status, ProjectionStatus.rebuilding);
    expect(emitted.last.status, ProjectionStatus.fresh);
    // The design prints "REBUILT 3.1S AGO". The fixture must produce a real
    // number for that copy rather than letting the screen invent one.
    expect(emitted.last.lastRebuildMs, 3100);
  });

  test('rebuild leaves the projection fresh afterwards', () async {
    await runtime.projections.rebuild(ProjectionKind.search).drain<void>();

    final after = await runtime.projections.stateOf(ProjectionKind.search);
    expect(after.status, ProjectionStatus.fresh);
  });

  test('search filters and points back at ops', () async {
    final hits = await runtime.projections.search('contractor');

    expect(hits, isNotEmpty);
    expect(hits.every((hit) => hit.opSequence > 0), isTrue);
    expect(
      hits.map((hit) => '${hit.title} ${hit.snippet}').join(' ').toLowerCase(),
      contains('contractor'),
    );
  });

  test('search can be scoped to one context', () async {
    final all = await runtime.projections.search('e');
    final scoped = await runtime.projections.search(
      'e',
      contextId: 'q3taxfiling',
    );

    expect(scoped.length, lessThan(all.length));
  });

  test('the mesh reports three peers with real ops-behind counts', () async {
    final peers = await runtime.mesh.peers().first;

    expect(peers.length, 3);
    expect(peers.map((p) => p.opsBehind), [0, 14, 212]);
  });

  test('a pending pairing request carries a six-digit code', () async {
    final request = await runtime.mesh.pendingRequest().first;

    expect(request?.code, hasLength(6));
    expect(request?.deviceName, 'Pixel Watch 3');
  });

  test('five capabilities are installed, one consent-gated', () async {
    final installed = await runtime.capabilities.installed();

    expect(installed.length, 5);
    final scribe = installed.singleWhere((c) => c.id == 'audio_scribe');
    expect(scribe.requiresConsentFor, contains('mic'));
  });

  test('removing a capability leaves its contexts alone', () async {
    final before = await runtime.contexts.all();
    await runtime.capabilities.remove('hospital_recovery');
    final after = await runtime.contexts.all();

    expect(after, equals(before));
    expect(await runtime.capabilities.byId('hospital_recovery'), isNull);
  });

  test('models report three residencies and a real storage budget', () async {
    final models = await runtime.models.all();
    final storage = await runtime.models.storage();

    expect(
      models.map((m) => m.residency).toSet(),
      containsAll([
        ModelResidency.loaded,
        ModelResidency.resident,
        ModelResidency.available,
      ]),
    );
    expect(storage.usedBytes, lessThan(storage.budgetBytes));
  });

  test('unloading a resident model names the capability that breaks', () async {
    await expectLater(
      runtime.models.unload('whisper_small'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Audio Scribe'),
        ),
      ),
    );
  });

  test('unloading a merely-available model is allowed', () async {
    await expectLater(runtime.models.unload('phi_4_mini'), completes);
  });

  test('a benchmark carries the thermal state it was measured under', () async {
    final bench = await runtime.models.benchmark('gemma_3n_e4b');

    expect(bench.tokensPerSecond, 24.1);
    expect(bench.measuredUnder, ThermalState.nominal);
  });

  test('a download reports bytes of total, not a bare percentage', () async {
    final progress = await runtime.models.download('qwen3_4b').toList();

    expect(progress, isNotEmpty);
    expect(progress.last.total, 2800000000);
    expect(progress.first.received, lessThan(progress.last.received));
  });

  test('a package plan shrinks when a context is unchecked', () async {
    final all = await runtime.portability.plan([
      'kneesurgery2026',
      'downtownapartment',
      'q3taxfiling',
      'airoarchitecture',
    ]);
    final fewer = await runtime.portability.plan(['kneesurgery2026']);

    expect(fewer.totalBytes, lessThan(all.totalBytes));
    expect(all.fileName, endsWith('.airobackup'));
  });

  test('sealing reports bytes written against the plan total', () async {
    final plan = await runtime.portability.plan(['kneesurgery2026']);
    final written = await runtime.portability
        .seal(
          plan: plan,
          passphrase: 'correct horse battery staple',
          destination: PackageDestination.usbDrive,
        )
        .toList();

    expect(written.last.total, plan.totalBytes);
  });
}
