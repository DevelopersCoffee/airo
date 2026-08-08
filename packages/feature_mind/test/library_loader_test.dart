import 'package:feature_mind/src/library_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for `RustLib.init`, including the part that matters: the real one
/// throws `Bad state: Should not initialize flutter_rust_bridge twice` if it
/// is ever called a second time.
class FakeRustInit {
  var calls = 0;
  Object? failWith;

  Future<void> call() async {
    calls++;
    if (failWith != null) throw failWith!;
    if (calls > 1) {
      throw StateError('Should not initialize flutter_rust_bridge twice');
    }
  }
}

void main() {
  late FakeRustInit whisper;
  late FakeRustInit llama;

  setUp(() {
    resetBridgeLoadersForTest();
    whisper = FakeRustInit();
    llama = FakeRustInit();
    whisperRustInit = whisper.call;
    llamaRustInit = llama.call;
  });

  tearDown(resetBridgeLoadersForTest);

  // The bug this guards: a successful model download re-runs startup, startup
  // loads the speech library, and the second `RustLib.init` threw — so the
  // app came back from its own download saying Airo Mind was not available on
  // this platform (#1554).
  test(
    'initializing the speech bridge twice loads once and does not throw',
    () async {
      await initializeWhisperBridge();
      await initializeWhisperBridge();

      expect(whisper.calls, 1);
      expect(isWhisperLoaded, isTrue);
    },
  );

  test('overlapping callers await one initialization', () async {
    await Future.wait([
      initializeWhisperBridge(),
      initializeWhisperBridge(),
      initializeWhisperBridge(),
    ]);

    expect(whisper.calls, 1);
  });

  // A load that failed loaded nothing, so the guard must not remember it —
  // otherwise a retry after a transient failure can never succeed.
  test('a failed load can be retried', () async {
    whisper.failWith = StateError('no library on this platform');

    await expectLater(initializeWhisperBridge(), throwsStateError);
    expect(isWhisperLoaded, isFalse);

    whisper
      ..failWith = null
      ..calls = 0;
    await initializeWhisperBridge();

    expect(isWhisperLoaded, isTrue);
  });

  test(
    'the generation bridge is guarded the same way, and separately',
    () async {
      await initializeWhisperBridge();
      expect(isLlamaLoaded, isFalse, reason: 'speech must not load generation');

      await initializeLlamaBridge();
      await initializeLlamaBridge();

      expect(llama.calls, 1);
      expect(isLlamaLoaded, isTrue);
    },
  );
}
