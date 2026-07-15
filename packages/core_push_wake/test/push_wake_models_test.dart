import 'package:core_cloud_orchestration/core_cloud_orchestration.dart';
import 'package:core_protocol/core_protocol.dart';
import 'package:core_push_wake/core_push_wake.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);
  const policy = AiroPushWakePolicy();

  group('AiroPushWakePolicy', () {
    test(
      'allows mobile data push when provider and silent wake are available',
      () {
        final decision = policy.evaluate(
          profile: AiroPushWakeCapabilityProfile.mobile(
            platformCategory: AiroNodePlatformCategory.androidMobile,
          ),
          request: _request(now),
          now: now,
        );

        expect(decision.accepted, isTrue);
        expect(decision.codes, [AiroPushWakeCode.accepted]);
      },
    );

    test(
      'requires visible notification on Android TV and Fire TV profiles',
      () {
        final androidTv = policy.evaluate(
          profile: AiroPushWakeCapabilityProfile.androidTv(),
          request: _request(now),
          now: now,
        );
        final fireTv = policy.evaluate(
          profile: AiroPushWakeCapabilityProfile.fireTv(),
          request: _request(now),
          now: now,
        );

        expect(androidTv.action, AiroPushWakeAction.visibleNotification);
        expect(
          androidTv.has(AiroPushWakeCode.visibleNotificationRequired),
          isTrue,
        );
        expect(androidTv.has(AiroPushWakeCode.silentWakeUnsupported), isTrue);
        expect(fireTv.action, AiroPushWakeAction.visibleNotification);
      },
    );

    test(
      'blocks cloud wake in local-only mode and chooses local reconnect',
      () {
        final decision = policy.evaluate(
          profile: AiroPushWakeCapabilityProfile.androidTv(),
          request: _request(
            now,
            cloudMode: AiroCloudOrchestrationMode.localOnly,
          ),
          now: now,
        );

        expect(decision.action, AiroPushWakeAction.localReconnect);
        expect(decision.has(AiroPushWakeCode.localOnlyMode), isTrue);
        expect(decision.has(AiroPushWakeCode.localReconnectAvailable), isTrue);
      },
    );

    test('falls back locally when provider is unavailable', () {
      final decision = policy.evaluate(
        profile: AiroPushWakeCapabilityProfile.homeNode(),
        request: _request(now, requiresSilentWake: false),
        now: now,
      );

      expect(decision.action, AiroPushWakeAction.localReconnect);
      expect(decision.has(AiroPushWakeCode.providerUnavailable), isTrue);
      expect(decision.has(AiroPushWakeCode.localReconnectAvailable), isTrue);
    });

    test('denies expired, unsafe, oversized, and offline requests', () {
      final decision = policy.evaluate(
        profile: AiroPushWakeCapabilityProfile.mobile(
          platformCategory: AiroNodePlatformCategory.ios,
        ),
        request: _request(
          now,
          wakeId: 'https://example.test/wake',
          expiresAt: now.subtract(const Duration(seconds: 1)),
          payloadBytes: kAiroPushWakeDefaultMaxPayloadBytes + 1,
          receiverLifecycle: AiroNodeLifecycleState.offline,
        ),
        now: now,
      );

      expect(decision.action, AiroPushWakeAction.deny);
      expect(decision.has(AiroPushWakeCode.expiredRequest), isTrue);
      expect(decision.has(AiroPushWakeCode.unsafeStableId), isTrue);
      expect(decision.has(AiroPushWakeCode.payloadTooLarge), isTrue);
      expect(decision.has(AiroPushWakeCode.lifecycleUnavailable), isTrue);
    });

    test('public diagnostics expose only stable decision metadata', () {
      final decision = policy.evaluate(
        profile: AiroPushWakeCapabilityProfile.mobile(
          platformCategory: AiroNodePlatformCategory.ios,
        ),
        request: _request(now),
        now: now,
      );

      expect(decision.toDiagnosticMap(), {
        'schemaVersion': kAiroPushWakeSchemaVersion,
        'wakeId': 'wake-1',
        'action': 'send',
        'codes': ['accepted'],
        'completedAt': now.toIso8601String(),
      });
    });
  });

  group('AiroPushWakeDispatcher', () {
    test('fake dispatcher records accepted wake attempts only', () async {
      final dispatcher = AiroFakePushWakeDispatcher(
        profile: AiroPushWakeCapabilityProfile.mobile(
          platformCategory: AiroNodePlatformCategory.androidMobile,
        ),
      );
      final accepted = await dispatcher.dispatch(
        request: _request(now),
        now: now,
      );
      final denied = await dispatcher.dispatch(
        request: _request(
          now,
          receiverLifecycle: AiroNodeLifecycleState.offline,
        ),
        now: now,
      );

      expect(accepted.accepted, isTrue);
      expect(denied.action, AiroPushWakeAction.deny);
      expect(dispatcher.acceptedRequests, hasLength(1));
    });

    test('no-op dispatcher fails closed', () async {
      const dispatcher = AiroNoOpPushWakeDispatcher();

      final decision = await dispatcher.dispatch(
        request: _request(now),
        now: now,
      );

      expect(decision.action, AiroPushWakeAction.noOp);
      expect(decision.codes, [AiroPushWakeCode.dispatcherUnavailable]);
    });
  });
}

AiroPushWakeRequest _request(
  DateTime now, {
  String wakeId = 'wake-1',
  AiroCloudOrchestrationMode cloudMode =
      AiroCloudOrchestrationMode.commandAndState,
  bool requiresSilentWake = true,
  int payloadBytes = 128,
  AiroNodeLifecycleState receiverLifecycle = AiroNodeLifecycleState.sleeping,
  DateTime? expiresAt,
}) {
  return AiroPushWakeRequest(
    wakeId: wakeId,
    actorNodeId: 'phone-node-1',
    receiverNodeId: 'tv-node-1',
    reason: AiroPushWakeReason.remoteControl,
    receiverLifecycle: receiverLifecycle,
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
    cloudMode: cloudMode,
    requiresSilentWake: requiresSilentWake,
    payloadBytes: payloadBytes,
  );
}
