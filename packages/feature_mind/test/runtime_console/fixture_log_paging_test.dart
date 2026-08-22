import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// #1460 needs the fixture to page meaningfully past the nine ops the design
/// names — a Runtime Console with only nine real rows can't prove paging or
/// sorting the way a 12,481-row log actually behaves. These tests exercise
/// `FixtureMindRuntime.log` directly (never the barrel, which has an
/// unrelated pre-existing build break under `src/llama` and `src/whisper`).
void main() {
  test('range keeps returning distinct rows past the nine named ops', () async {
    final runtime = FixtureMindRuntime();

    final page = await runtime.log.range(offset: 9, limit: 20);

    expect(page.length, 20);
    expect(page.map((op) => op.sequence).toSet().length, 20);
    // Strictly descending, matching the port's contract.
    for (var i = 1; i < page.length; i++) {
      expect(page[i].sequence, lessThan(page[i - 1].sequence));
    }
  });

  test('a synthesized row never collides with a named one', () async {
    final runtime = FixtureMindRuntime();
    final namedPage = await runtime.log.range(offset: 0, limit: 9);
    final namedSequences = namedPage.map((op) => op.sequence).toSet();

    final syntheticPage = await runtime.log.range(offset: 9, limit: 500);

    expect(
      syntheticPage.every((op) => !namedSequences.contains(op.sequence)),
      isTrue,
    );
  });

  test(
    'bySequence resolves a synthesized row the same as range does',
    () async {
      final runtime = FixtureMindRuntime();
      final page = await runtime.log.range(offset: 50, limit: 1);
      final synthesizedOp = page.single;

      final bySequence = await runtime.log.bySequence(synthesizedOp.sequence);

      expect(bySequence, synthesizedOp);
    },
  );

  test(
    'paging past nine rows exercises more than one signature state',
    () async {
      final runtime = FixtureMindRuntime();

      final page = await runtime.log.range(offset: 0, limit: 500);

      expect(
        page.map((op) => op.signature).toSet(),
        containsAll(<SignatureState>{
          SignatureState.verified,
          SignatureState.unverified,
          SignatureState.unsigned,
        }),
      );
    },
  );

  test('paging past nine rows exercises every cited op type', () async {
    final runtime = FixtureMindRuntime();

    final page = await runtime.log.range(offset: 0, limit: 500);

    const cited = {
      MindOpKind.automation,
      MindOpKind.scan,
      MindOpKind.merge,
      MindOpKind.inference,
      MindOpKind.voice,
      MindOpKind.revoke,
      MindOpKind.import,
    };
    expect(page.map((op) => op.kind).toSet(), containsAll(cited));
  });

  test('count still reports the design number', () async {
    final runtime = FixtureMindRuntime();

    expect(await runtime.log.count(), 12481);
  });

  test(
    'the first three rows are unchanged from the design-named ops',
    () async {
      final runtime = FixtureMindRuntime();

      final page = await runtime.log.range(offset: 0, limit: 3);

      expect(page.map((op) => op.sequence), [12481, 12477, 12463]);
    },
  );
}
