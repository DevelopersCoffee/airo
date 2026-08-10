import 'dart:async';

import 'package:feature_mind/src/quick_capture/application/quick_capture_controller.dart';
import 'package:feature_mind/src/quick_capture/application/quick_capture_state.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [ContextPort] whose [all] never completes until the test resolves it,
/// standing in for classification that has not finished by the time a
/// capture is committed.
class _StallingContextPort implements ContextPort {
  final Completer<List<MindContext>> _allCompleter =
      Completer<List<MindContext>>();

  void resolve(List<MindContext> contexts) => _allCompleter.complete(contexts);

  @override
  Future<List<MindContext>> all() => _allCompleter.future;

  @override
  Future<MindContext?> byId(String id) async => null;

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => const [];

  @override
  Future<MindContext> create({required String label}) =>
      throw UnimplementedError();

  @override
  Future<void> link(String fromId, String toId) async {}

  @override
  Future<void> unlink(String fromId, String toId) async {}

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async => const [];
}

class _FakeContextPort implements ContextPort {
  _FakeContextPort(this._contexts);

  final List<MindContext> _contexts;

  @override
  Future<List<MindContext>> all() async => _contexts;

  @override
  Future<MindContext?> byId(String id) async {
    for (final context in _contexts) {
      if (context.id == id) return context;
    }
    return null;
  }

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => const [];

  @override
  Future<MindContext> create({required String label}) =>
      throw UnimplementedError();

  @override
  Future<void> link(String fromId, String toId) async {}

  @override
  Future<void> unlink(String fromId, String toId) async {}

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async => const [];
}

/// A [ContextPort] whose sub-port is not implemented on this runtime yet.
class _UnavailableContextPort implements ContextPort {
  @override
  Future<List<MindContext>> all() =>
      throw const MindPortUnavailable('contexts', 'M19 has not landed it');

  @override
  Future<MindContext?> byId(String id) => throw UnimplementedError();

  @override
  Future<List<ContextLink>> linksFor(String contextId) =>
      throw UnimplementedError();

  @override
  Future<MindContext> create({required String label}) =>
      throw UnimplementedError();

  @override
  Future<void> link(String fromId, String toId) => throw UnimplementedError();

  @override
  Future<void> unlink(String fromId, String toId) => throw UnimplementedError();

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) =>
      throw UnimplementedError();
}

class _FakeLog implements OperationLogPort {
  final List<MindOp> appended = [];
  int baseCount;

  /// When set, [append] waits on this before completing, so a test can
  /// observe [QuickCapturePhase.filing] deterministically instead of racing
  /// a same-microtask-queue fake.
  Completer<void>? appendGate;

  _FakeLog({this.baseCount = 0});

  @override
  Future<int> count() async => baseCount + appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      const [];

  @override
  Future<MindOp?> bySequence(int sequence) async => null;

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    final gate = appendGate;
    if (gate != null) await gate.future;
    final sequence = await count() + 1;
    appended.add(
      MindOp(
        sequence: sequence,
        kind: kind,
        title: title,
        contextId: contextId,
        deviceName: 'test-device',
        signature: SignatureState.verified,
        recordedAtMs: 0,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<SignatureState> verify(int sequence) async => SignatureState.verified;

  @override
  Stream<double> replayFrom(int sequence) => const Stream.empty();
}

/// A log whose [append] reports the port as not implemented, standing in for
/// `RustMindRuntime` before M19 lands.
class _UnavailableLog implements OperationLogPort {
  @override
  Future<int> count() async => 0;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      const [];

  @override
  Future<MindOp?> bySequence(int sequence) async => null;

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) => throw const MindPortUnavailable('log', 'M19 has not landed it');

  @override
  Future<SignatureState> verify(int sequence) async => SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) => const Stream.empty();
}

const _context = MindContext(
  id: 'q3taxfiling',
  label: '#Q3TaxFiling',
  itemCount: 52,
  opCount: 900,
  openedAtMs: 5000,
  safetyClass: CapabilitySafetyClass.financial,
);

const _olderContext = MindContext(
  id: 'downtownapartment',
  label: '#DowntownApartment',
  itemCount: 17,
  opCount: 300,
  openedAtMs: 1000,
  safetyClass: CapabilitySafetyClass.general,
);

void main() {
  group('capture flow states', () {
    test('idle to capturing to transcribed to filed as an op', () async {
      final log = _FakeLog(baseCount: 40);
      final controller = QuickCaptureController(
        log: log,
        contexts: _FakeContextPort([_context, _olderContext]),
      );

      expect(controller.state.phase, QuickCapturePhase.idle);

      controller.startCapture();
      expect(controller.state.phase, QuickCapturePhase.capturing);

      controller.updateTranscript('call the surgeon');
      expect(controller.state.transcript, 'call the surgeon');
      // Still capturing: the transcript lands before release, not after it.
      expect(controller.state.phase, QuickCapturePhase.capturing);

      controller.releaseCapture();
      expect(controller.state.phase, QuickCapturePhase.transcribed);
      expect(controller.state.transcript, 'call the surgeon');

      await controller.commit(title: 'call the surgeon');

      expect(controller.state.phase, QuickCapturePhase.filed);
      expect(controller.state.filedSequence, 41);
      expect(log.appended, hasLength(1));
      expect(log.appended.single.title, 'call the surgeon');
      expect(log.appended.single.kind, MindOpKind.voice);
    });

    test('updateTranscript before capturing, or after release, is a no-op', () {
      final controller = QuickCaptureController(
        log: _FakeLog(),
        contexts: _FakeContextPort(const []),
      );

      controller.updateTranscript('too early');
      expect(controller.state.transcript, '');

      controller.startCapture();
      controller.releaseCapture();
      controller.updateTranscript('too late');
      expect(controller.state.transcript, '');
    });

    test(
      'the context guess resolves onto the state once classification lands',
      () async {
        final contexts = _StallingContextPort();
        final controller = QuickCaptureController(
          log: _FakeLog(),
          contexts: contexts,
        );

        controller.startCapture();
        expect(controller.state.isClassifying, isTrue);
        expect(controller.state.suggestedContextId, isNull);

        contexts.resolve([_context, _olderContext]);
        // Let the pending _guessContext future run to completion.
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.isClassifying, isFalse);
        // Newest openedAtMs wins the guess.
        expect(controller.state.suggestedContextId, _context.id);
      },
    );

    test(
      'a person overriding the context always wins over the guess',
      () async {
        final controller = QuickCaptureController(
          log: _FakeLog(),
          contexts: _FakeContextPort([_context, _olderContext]),
        );

        controller.startCapture();
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.suggestedContextId, _context.id);

        controller.overrideContext(_olderContext.id);
        expect(controller.state.effectiveContextId, _olderContext.id);
      },
    );
  });

  group('capture is never blocked by classification', () {
    test('capturing, releasing and committing complete while the context guess '
        'is still stalled', () async {
      final log = _FakeLog(baseCount: 5);
      final controller = QuickCaptureController(
        log: log,
        // Deliberately never resolved -- if commit() awaited this in any
        // way, this test would hang until the framework's own timeout.
        contexts: _StallingContextPort(),
      );

      controller.startCapture();
      controller.updateTranscript('pick up milk');
      controller.releaseCapture();
      await controller.commit(title: 'pick up milk');

      expect(controller.state.phase, QuickCapturePhase.filed);
      expect(controller.state.filedSequence, 6);
      // No suggestion ever arrived, and the op still filed -- with no
      // context, not blocked pending one.
      expect(controller.state.suggestedContextId, isNull);
      expect(log.appended.single.contextId, '');
    });

    test(
      'a late-arriving guess does not resurrect an already-filed capture',
      () async {
        final log = _FakeLog();
        final contexts = _StallingContextPort();
        final controller = QuickCaptureController(log: log, contexts: contexts);

        controller.startCapture();
        controller.updateTranscript('note');
        controller.releaseCapture();
        await controller.commit(title: 'note');
        expect(controller.state.phase, QuickCapturePhase.filed);

        // The guess finally resolves after the capture is already filed.
        contexts.resolve([_context]);
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.phase, QuickCapturePhase.filed);
        expect(controller.state.suggestedContextId, isNull);
      },
    );
  });

  group('non-happy states', () {
    test(
      'a missing OperationLogPort names "log" rather than a generic error',
      () async {
        final controller = QuickCaptureController(
          log: _UnavailableLog(),
          contexts: _FakeContextPort(const []),
        );

        controller.startCapture();
        controller.updateTranscript('note');
        controller.releaseCapture();
        await controller.commit(title: 'note');

        expect(controller.state.phase, QuickCapturePhase.error);
        expect(controller.state.missingPort, 'log');
        expect(controller.state.errorMessage, isNotEmpty);
      },
    );

    test(
      'a missing ContextPort costs the suggestion, not the capture',
      () async {
        final log = _FakeLog();
        final controller = QuickCaptureController(
          log: log,
          contexts: _UnavailableContextPort(),
        );

        controller.startCapture();
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.isClassifying, isFalse);
        expect(controller.state.phase, QuickCapturePhase.capturing);

        controller.updateTranscript('note');
        controller.releaseCapture();
        await controller.commit(title: 'note');

        expect(controller.state.phase, QuickCapturePhase.filed);
        expect(controller.state.suggestedContextId, isNull);
      },
    );

    test(
      'filing carries a provisional op number rather than a bare wait',
      () async {
        final log = _FakeLog(baseCount: 99)..appendGate = Completer<void>();
        final controller = QuickCaptureController(
          log: log,
          contexts: _FakeContextPort(const []),
        );

        controller.startCapture();
        controller.updateTranscript('note');
        controller.releaseCapture();

        final commitFuture = controller.commit(title: 'note');
        // The append is held open by the gate, but the surface already has a
        // concrete number to show -- never a state with isClassifying/filing
        // and nothing to render alongside it.
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.phase, QuickCapturePhase.filing);
        expect(controller.state.provisionalSequence, 100);

        log.appendGate!.complete();
        await commitFuture;
        expect(controller.state.filedSequence, 100);
      },
    );
  });
}
