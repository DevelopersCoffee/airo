import 'package:feature_mind/src/assistant/consent/audio_scribe_consent_gate.dart';
import 'package:feature_mind/src/assistant/consent/jurisdiction_consent_rules.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLog implements OperationLogPort {
  final List<MindOp> appended = [];

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
        deviceName: 'Test device',
        signature: SignatureState.verified,
        recordedAtMs: 1000 + sequence,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<int> count() async => appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      appended.reversed.skip(offset).take(limit).toList();

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      appended.where((op) => op.sequence == sequence).firstOrNull;

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    yield 1.0;
  }
}

void main() {
  const contextId = 'audio-scribe-test';
  const twoParty = ConsentJurisdiction(
    code: 'US-CA',
    label: 'California',
    rule: ConsentRule.twoPartyConsent,
  );
  const oneParty = ConsentJurisdiction(
    code: 'GB',
    label: 'United Kingdom',
    rule: ConsentRule.onePartyConsent,
  );

  group('the gate blocks the encoder until consent is granted', () {
    test(
      'startRecording throws before grant, and never calls the encoder',
      () async {
        final gate = AudioScribeConsentGate();
        var encoderCalls = 0;

        await expectLater(
          gate.startRecording(() async {
            encoderCalls += 1;
            return 'audio';
          }),
          throwsA(isA<ConsentRequiredException>()),
        );

        expect(
          encoderCalls,
          0,
          reason:
              'The gate must refuse to invoke the encoder callback at all when '
              'consent has not been granted -- this is the check the mutation '
              'test in test/rules proves can fail.',
        );
      },
    );

    test('startRecording runs the encoder exactly once after grant', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();
      var encoderCalls = 0;

      await gate.grant(
        log: log,
        contextId: contextId,
        jurisdiction: oneParty,
        allPartiesNotified: false,
        nowMs: 5000,
      );

      final result = await gate.startRecording(() async {
        encoderCalls += 1;
        return 'audio-bytes';
      });

      expect(result, 'audio-bytes');
      expect(encoderCalls, 1);
    });

    test('startRecording throws again once consent is revoked', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();
      await gate.grant(
        log: log,
        contextId: contextId,
        jurisdiction: oneParty,
        allPartiesNotified: false,
        nowMs: 5000,
      );
      await gate.revoke(log: log, contextId: contextId, nowMs: 6000);

      var encoderCalls = 0;
      await expectLater(
        gate.startRecording(() async {
          encoderCalls += 1;
          return 'audio';
        }),
        throwsA(isA<ConsentRequiredException>()),
      );
      expect(encoderCalls, 0);
    });
  });

  group('jurisdiction handling', () {
    test(
      'grant refuses a two-party jurisdiction without all-party notification',
      () async {
        final gate = AudioScribeConsentGate();
        final log = _RecordingLog();

        await expectLater(
          gate.grant(
            log: log,
            contextId: contextId,
            jurisdiction: twoParty,
            allPartiesNotified: false,
            nowMs: 1000,
          ),
          throwsA(isA<ConsentRequiredException>()),
        );
        expect(
          log.appended,
          isEmpty,
          reason:
              'An unacknowledged two-party jurisdiction must not produce a '
              'consent op -- there is nothing to authorise recording with.',
        );
        expect(gate.isGranted, isFalse);
      },
    );

    test('grant succeeds for a two-party jurisdiction once notified', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();

      final record = await gate.grant(
        log: log,
        contextId: contextId,
        jurisdiction: twoParty,
        allPartiesNotified: true,
        nowMs: 1000,
      );

      expect(gate.isGranted, isTrue);
      expect(record.allPartiesNotified, isTrue);
      expect(log.appended, hasLength(1));
      expect(log.appended.single.kind, MindOpKind.consent);
      expect(log.appended.single.detail, contains('All parties notified'));
    });

    test('grant succeeds for a one-party jurisdiction without notification, '
        'and still logs the consent op', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();

      final record = await gate.grant(
        log: log,
        contextId: contextId,
        jurisdiction: oneParty,
        allPartiesNotified: false,
        nowMs: 1000,
      );

      expect(gate.isGranted, isTrue);
      expect(record.allPartiesNotified, isFalse);
      expect(log.appended, hasLength(1));
      expect(log.appended.single.kind, MindOpKind.consent);
      expect(log.appended.single.detail, contains('recorded for the record'));
    });
  });

  group('the consent event is a signed op visible in the timeline', () {
    test(
      'grant appends a MindOpKind.consent op with a sequence number',
      () async {
        final gate = AudioScribeConsentGate();
        final log = _RecordingLog();

        final record = await gate.grant(
          log: log,
          contextId: contextId,
          jurisdiction: oneParty,
          allPartiesNotified: false,
          nowMs: 2000,
        );

        final op = await log.bySequence(record.logSequence);
        expect(op, isNotNull);
        expect(op!.kind, MindOpKind.consent);
        expect(op.signature, SignatureState.verified);
        expect(op.contextId, contextId);
        expect(op.recordedAtMs, greaterThan(0));
      },
    );
  });

  group('mid-recording revocation', () {
    test('revoke appends a MindOpKind.consentRevoked op referencing the '
        'original consent', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();
      final granted = await gate.grant(
        log: log,
        contextId: contextId,
        jurisdiction: oneParty,
        allPartiesNotified: false,
        nowMs: 1000,
      );

      await gate.revoke(log: log, contextId: contextId, nowMs: 4000);

      expect(log.appended, hasLength(2));
      final revokedOp = log.appended.last;
      expect(revokedOp.kind, MindOpKind.consentRevoked);
      expect(revokedOp.detail, contains('#${granted.logSequence}'));
      expect(gate.isGranted, isFalse);
      expect(gate.consent!.isRevoked, isTrue);
    });

    test('revoke without a prior grant throws', () async {
      final gate = AudioScribeConsentGate();
      final log = _RecordingLog();

      await expectLater(
        gate.revoke(log: log, contextId: contextId, nowMs: 1000),
        throwsA(isA<ConsentRequiredException>()),
      );
    });
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
