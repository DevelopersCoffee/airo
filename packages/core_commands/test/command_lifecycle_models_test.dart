import 'package:core_commands/core_commands.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  group('AiroCommandLifecyclePolicy', () {
    test('accepts scoped unexpired command with no prior record', () {
      final decision = _policy().evaluate(
        envelope: _envelope(now),
        now: now,
        currentRevision: 7,
      );

      expect(decision.accepted, isTrue);
      expect(decision.result.status, AiroCommandResultStatus.accepted);
      expect(decision.toDiagnosticMap(), {
        'commandId': 'command-1',
        'action': 'execute',
        'status': 'accepted',
        'codes': ['accepted'],
        'existingStatus': null,
      });
    });

    test(
      'returns duplicate for same command id or idempotency across paths',
      () {
        final existing = _record(
          now,
          deliveryPath: AiroCommandDeliveryPath.lan,
        );

        final cloudDuplicate = _policy().evaluate(
          envelope: _envelope(now, deliveryPath: AiroCommandDeliveryPath.cloud),
          now: now,
          currentRevision: 7,
          records: [existing],
        );
        final commandDuplicate = _policy().evaluate(
          envelope: _envelope(
            now,
            idempotencyKey: 'idempotency-cloud',
            deliveryPath: AiroCommandDeliveryPath.cloud,
          ),
          now: now,
          currentRevision: 7,
          records: [existing],
        );

        expect(cloudDuplicate.action, AiroCommandLifecycleAction.duplicate);
        expect(cloudDuplicate.result.status, AiroCommandResultStatus.duplicate);
        expect(cloudDuplicate.codes, [
          AiroCommandLifecycleCode.duplicateCommandId,
          AiroCommandLifecycleCode.duplicateIdempotencyKey,
        ]);
        expect(commandDuplicate.action, AiroCommandLifecycleAction.duplicate);
        expect(commandDuplicate.codes, [
          AiroCommandLifecycleCode.duplicateCommandId,
        ]);
      },
    );

    test(
      'rejects expired, target mismatch, missing scope, and receiver down',
      () {
        final decision =
            _policy(
              grantedScopes: const {AiroPairingScope.textInput},
              receiverAvailable: false,
            ).evaluate(
              envelope: _envelope(
                now,
                targetNodeId: 'other-tv',
                expiresAt: now.subtract(const Duration(seconds: 1)),
              ),
              now: now,
              currentRevision: 7,
            );

        expect(decision.action, AiroCommandLifecycleAction.reject);
        expect(decision.result.status, AiroCommandResultStatus.expired);
        expect(decision.codes, [
          AiroCommandLifecycleCode.expired,
          AiroCommandLifecycleCode.targetMismatch,
          AiroCommandLifecycleCode.scopeMissing,
          AiroCommandLifecycleCode.receiverUnavailable,
        ]);
      },
    );

    test('rejects stale expected revision and same-revision conflicts', () {
      final stale = _policy().evaluate(
        envelope: _envelope(now, expectedRevision: 6),
        now: now,
        currentRevision: 7,
      );
      final conflict = _policy().evaluate(
        envelope: _envelope(
          now,
          commandId: 'command-2',
          idempotencyKey: 'idempotency-2',
          senderNodeId: 'tablet-1',
          expectedRevision: 7,
        ),
        now: now,
        currentRevision: 7,
        records: [_record(now, revision: 7, senderNodeId: 'phone-1')],
      );

      expect(stale.codes, [AiroCommandLifecycleCode.staleExpectedRevision]);
      expect(stale.result.status, AiroCommandResultStatus.rejected);
      expect(conflict.codes, [AiroCommandLifecycleCode.revisionConflict]);
      expect(conflict.result.status, AiroCommandResultStatus.conflict);
    });

    test('rejects unsupported actions with typed result status', () {
      final decision =
          _policy(supportedActions: const {AiroCommandAction.pause}).evaluate(
            envelope: _envelope(now, action: AiroCommandAction.play),
            now: now,
            currentRevision: 7,
          );

      expect(decision.codes, [AiroCommandLifecycleCode.unsupportedAction]);
      expect(decision.result.status, AiroCommandResultStatus.unsupported);
    });

    test('diagnostics and records do not expose payload values', () {
      final envelope = _envelope(
        now,
        payload: AiroCommandPayload.safe(const {'positionMs': '12000'}),
      );
      final decision = _policy().evaluate(
        envelope: envelope,
        now: now,
        currentRevision: 7,
      );
      final record = _record(now);

      expect(envelope.toPublicMap().toString(), isNot(contains('12000')));
      expect(decision.toDiagnosticMap().toString(), isNot(contains('12000')));
      expect(record.toPublicMap().toString(), isNot(contains('12000')));
      expect(record.toString(), isNot(contains('12000')));
    });
  });

  group('AiroCommandLifecycleStore implementations', () {
    test(
      'fake store accepts once, deduplicates, and records terminal result',
      () async {
        final store = AiroFakeCommandLifecycleStore(policy: _policy());

        final accepted = await store.accept(
          envelope: _envelope(now),
          now: now,
          currentRevision: 7,
        );
        final duplicate = await store.accept(
          envelope: _envelope(now, deliveryPath: AiroCommandDeliveryPath.cloud),
          now: now.add(const Duration(seconds: 1)),
          currentRevision: 7,
        );
        final completed = await store.recordResult(
          result: AiroCommandResult(
            commandId: 'command-1',
            status: AiroCommandResultStatus.completed,
            completedAt: now.add(const Duration(seconds: 2)),
          ),
          now: now.add(const Duration(seconds: 2)),
        );

        expect(accepted.accepted, isTrue);
        expect(duplicate.action, AiroCommandLifecycleAction.duplicate);
        expect(completed?.status, AiroCommandResultStatus.completed);
        expect((await store.list()).single.terminal, isTrue);
      },
    );

    test(
      'no-op store returns receiver-unavailable result without side effects',
      () async {
        const store = AiroNoOpCommandLifecycleStore();

        final decision = await store.accept(envelope: _envelope(now), now: now);

        expect(decision.action, AiroCommandLifecycleAction.noOp);
        expect(decision.codes, [AiroCommandLifecycleCode.storeUnavailable]);
        expect(
          decision.result.status,
          AiroCommandResultStatus.receiverUnavailable,
        );
        expect(await store.list(), isEmpty);
      },
    );
  });
}

AiroCommandLifecyclePolicy _policy({
  Set<AiroPairingScope> grantedScopes = const {
    AiroPairingScope.playbackControl,
  },
  Set<AiroCommandAction> supportedActions = const {
    AiroCommandAction.play,
    AiroCommandAction.pause,
    AiroCommandAction.stop,
    AiroCommandAction.seek,
  },
  bool receiverAvailable = true,
}) {
  return AiroCommandLifecyclePolicy(
    targetNodeId: 'receiver-tv-1',
    grantedScopes: grantedScopes,
    supportedActions: supportedActions,
    receiverAvailable: receiverAvailable,
  );
}

AiroCommandEnvelope _envelope(
  DateTime now, {
  String commandId = 'command-1',
  String idempotencyKey = 'idempotency-1',
  String senderNodeId = 'phone-1',
  String targetNodeId = 'receiver-tv-1',
  AiroCommandAction action = AiroCommandAction.play,
  int expectedRevision = 7,
  DateTime? expiresAt,
  AiroCommandDeliveryPath deliveryPath = AiroCommandDeliveryPath.lan,
  AiroCommandPayload? payload,
}) {
  return AiroCommandEnvelope(
    commandId: commandId,
    sessionId: 'session-1',
    senderNodeId: senderNodeId,
    targetNodeId: targetNodeId,
    kind: AiroCommandKind.playback,
    action: action,
    requiredScope: AiroPairingScope.playbackControl,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
    idempotencyKey: idempotencyKey,
    expectedRevision: expectedRevision,
    deliveryPath: deliveryPath,
    payload: payload,
  );
}

AiroCommandLifecycleRecord _record(
  DateTime now, {
  int revision = 7,
  String senderNodeId = 'phone-1',
  AiroCommandDeliveryPath deliveryPath = AiroCommandDeliveryPath.lan,
}) {
  return AiroCommandLifecycleRecord(
    commandId: 'command-1',
    sessionId: 'session-1',
    idempotencyKey: 'idempotency-1',
    senderNodeId: senderNodeId,
    targetNodeId: 'receiver-tv-1',
    action: AiroCommandAction.play,
    status: AiroCommandResultStatus.accepted,
    revision: revision,
    deliveryPath: deliveryPath,
    updatedAt: now,
  );
}
