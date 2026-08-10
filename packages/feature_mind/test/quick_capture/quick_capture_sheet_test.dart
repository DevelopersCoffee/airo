import 'package:feature_mind/src/quick_capture/application/quick_capture_controller.dart';
import 'package:feature_mind/src/quick_capture/application/quick_capture_state.dart';
import 'package:feature_mind/src/quick_capture/presentation/quick_capture_sheet.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/widgets/mind_context_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeContextPort implements ContextPort {
  _FakeContextPort(this._contexts);
  final List<MindContext> _contexts;

  @override
  Future<List<MindContext>> all() async => _contexts;

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

class _FakeLog implements OperationLogPort {
  final List<MindOp> appended = [];

  @override
  Future<int> count() async => appended.length;

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
    final sequence = appended.length + 1;
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

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('idle state shows the hold-to-talk prompt', (tester) async {
    final controller = QuickCaptureController(
      log: _FakeLog(),
      contexts: _FakeContextPort(const []),
    );
    await tester.pumpWidget(
      _wrap(
        QuickCaptureSheet(controller: controller, contextCandidates: const []),
      ),
    );

    expect(find.text('Hold to talk'), findsOneWidget);
    expect(find.byKey(const Key('quickCapture.holdTarget')), findsOneWidget);
  });

  testWidgets(
    'holding the target starts capture, and the transcript renders live',
    (tester) async {
      final controller = QuickCaptureController(
        log: _FakeLog(),
        contexts: _FakeContextPort(const []),
      );
      await tester.pumpWidget(
        _wrap(
          QuickCaptureSheet(
            controller: controller,
            contextCandidates: const [],
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('quickCapture.holdTarget'))),
      );
      await tester.pump();
      // Past the long-press recognizer's timeout, before lifting -- this is
      // the "thumb still down" moment the design calls out.
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.state.phase, QuickCapturePhase.capturing);

      controller.updateTranscript('hold to talk works');
      await tester.pump();
      expect(find.text('hold to talk works'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(controller.state.phase, QuickCapturePhase.transcribed);
    },
  );

  testWidgets(
    'committing a transcribed capture files it and shows the op number',
    (tester) async {
      final log = _FakeLog();
      final controller = QuickCaptureController(
        log: log,
        contexts: _FakeContextPort(const [_context]),
      );
      controller.startCapture();
      controller.updateTranscript('call the surgeon');
      controller.releaseCapture();

      await tester.pumpWidget(
        _wrap(
          QuickCaptureSheet(
            controller: controller,
            contextCandidates: const [_context],
          ),
        ),
      );

      expect(find.text('call the surgeon'), findsOneWidget);
      // The suggested/override context stays tappable -- rule R02.
      expect(find.byType(MindContextChip), findsOneWidget);

      await tester.tap(find.byKey(const Key('quickCapture.commit')));
      await tester.pumpAndSettle();

      expect(controller.state.phase, QuickCapturePhase.filed);
      expect(find.byKey(const Key('quickCapture.filed')), findsOneWidget);
      expect(log.appended, hasLength(1));
    },
  );

  testWidgets('a person can override the suggested context before committing', (
    tester,
  ) async {
    const other = MindContext(
      id: 'downtownapartment',
      label: '#DowntownApartment',
      itemCount: 17,
      opCount: 300,
      openedAtMs: 1000,
      safetyClass: CapabilitySafetyClass.general,
    );
    final log = _FakeLog();
    final controller = QuickCaptureController(
      log: log,
      contexts: _FakeContextPort(const [_context, other]),
    );
    controller.startCapture();
    controller.updateTranscript('note');
    controller.releaseCapture();
    controller.overrideContext(_context.id);

    await tester.pumpWidget(
      _wrap(
        QuickCaptureSheet(
          controller: controller,
          contextCandidates: const [_context, other],
        ),
      ),
    );

    await tester.tap(find.text('#DowntownApartment'));
    await tester.pump();
    expect(controller.state.overriddenContextId, other.id);

    await tester.tap(find.byKey(const Key('quickCapture.commit')));
    await tester.pumpAndSettle();

    expect(log.appended.single.contextId, other.id);
  });

  testWidgets(
    'a runtime-unavailable commit names the missing port, not a generic error',
    (tester) async {
      final controller = QuickCaptureController(
        log: _UnavailableLog(),
        contexts: _FakeContextPort(const []),
      );
      controller.startCapture();
      controller.updateTranscript('note');
      controller.releaseCapture();

      await tester.pumpWidget(
        _wrap(
          QuickCaptureSheet(
            controller: controller,
            contextCandidates: const [],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('quickCapture.commit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quickCapture.error')), findsOneWidget);
      expect(find.text('The log is not available.'), findsOneWidget);
    },
  );

  testWidgets(
    'filing never renders a bare spinner -- always a numbered state',
    (tester) async {
      final log = _FakeLog();
      final controller = QuickCaptureController(
        log: log,
        contexts: _FakeContextPort(const []),
      );
      controller.startCapture();
      controller.updateTranscript('note');
      controller.releaseCapture();

      await tester.pumpWidget(
        _wrap(
          QuickCaptureSheet(
            controller: controller,
            contextCandidates: const [],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('quickCapture.commit')));
      // One frame in: filing should already carry a number, never a bare
      // CircularProgressIndicator.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quickCapture.filed')), findsOneWidget);
    },
  );
}
