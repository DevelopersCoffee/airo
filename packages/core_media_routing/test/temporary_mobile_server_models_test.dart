import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroTemporaryMobileServerPolicy', () {
    const policy = AiroTemporaryMobileServerPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroRouteAccessGrant grant({
      String audienceNodeId = 'tv-1',
      Set<AiroRouteAccessScope> scopes = const {
        AiroRouteAccessScope.playbackRead,
        AiroRouteAccessScope.rangeRead,
        AiroRouteAccessScope.probeRead,
      },
      DateTime? expiresAt,
    }) {
      return AiroRouteAccessGrant(
        grantId: 'grant-1',
        locationId: 'location-1',
        audienceNodeId: audienceNodeId,
        handle: AiroRouteAccessHandle.redacted('grant-handle'),
        issuedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 4)),
        scopes: scopes,
      );
    }

    AiroTemporaryMobileServerSnapshot snapshot({
      DateTime? expiresAt,
      DateTime? lastActivityAt,
      Set<String> allowedReceiverNodeIds = const {'tv-1'},
      Set<AiroTemporaryMobileServerCapability> capabilities = const {
        AiroTemporaryMobileServerCapability.lanOnly,
        AiroTemporaryMobileServerCapability.rangeRequests,
        AiroTemporaryMobileServerCapability.probeRequests,
        AiroTemporaryMobileServerCapability.entityValidation,
        AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        AiroTemporaryMobileServerCapability.idleShutdown,
      },
      AiroRouteAccessGrant? accessGrant,
      int batteryPercent = 60,
      bool isCharging = false,
      AiroTemporaryMobileThermalState thermalState =
          AiroTemporaryMobileThermalState.normal,
      int activeReceiverCount = 1,
    }) {
      return AiroTemporaryMobileServerSnapshot(
        serverId: 'server-1',
        hostNodeId: 'phone-1',
        locationId: 'location-1',
        mediaId: 'media-1',
        accessGrant: accessGrant ?? grant(),
        startedAt: now.subtract(const Duration(seconds: 20)),
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
        lastActivityAt:
            lastActivityAt ?? now.subtract(const Duration(seconds: 5)),
        allowedReceiverNodeIds: allowedReceiverNodeIds,
        capabilities: capabilities,
        batteryPercent: batteryPercent,
        isCharging: isCharging,
        thermalState: thermalState,
        activeReceiverCount: activeReceiverCount,
      );
    }

    final context = AiroTemporaryMobileServerValidationContext(
      now: DateTime.utc(2026, 7, 14, 12),
      receiverNodeId: 'tv-1',
      hasLocalNetworkScope: true,
      hasTrustedReceiverScope: true,
    );

    AiroTemporaryMobileServerServingRequest request({
      AiroTemporaryMobileServerRequestMethod method =
          AiroTemporaryMobileServerRequestMethod.get,
      String? rangeHeader = 'bytes=0-1023',
      int mediaLengthBytes = 4096,
      String entityValidator = 'etag-1',
      bool cancelled = false,
      bool requiresRangeRequest = true,
    }) {
      return AiroTemporaryMobileServerServingRequest(
        requestId: 'request-1',
        method: method,
        receiverNodeId: 'tv-1',
        now: now,
        mediaLengthBytes: mediaLengthBytes,
        entityValidator: entityValidator,
        rangeHeader: rangeHeader,
        hasLocalNetworkScope: true,
        hasTrustedReceiverScope: true,
        cancelled: cancelled,
        requiresRangeRequest: requiresRangeRequest,
      );
    }

    test('accepts trusted LAN receiver with required media-serving gates', () {
      final current = snapshot();

      final result = policy.validate(snapshot: current, context: context);

      expect(result.accepted, isTrue);
      expect(current.toString(), isNot(contains('grant-handle')));
      expect(current.toString(), contains('access: redacted'));
    });

    test('rejects expired and idle-timed-out sessions', () {
      final expired = snapshot(expiresAt: now);
      final idle = snapshot(
        lastActivityAt: now.subtract(const Duration(minutes: 3)),
      );

      final expiredResult = policy.validate(
        snapshot: expired,
        context: context,
      );
      final idleResult = policy.validate(snapshot: idle, context: context);

      expect(
        expiredResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.expired),
      );
      expect(
        idleResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.idleTimeoutExceeded),
      );
    });

    test('rejects non-LAN, untrusted, or unlisted receivers', () {
      final current = snapshot(allowedReceiverNodeIds: const {'tv-2'});
      final untrusted = AiroTemporaryMobileServerValidationContext(
        now: DateTime.utc(2026, 7, 14, 12),
        receiverNodeId: 'tv-1',
      );

      final untrustedResult = policy.validate(
        snapshot: current,
        context: untrusted,
      );
      final unlistedResult = policy.validate(
        snapshot: current,
        context: context,
      );

      expect(
        untrustedResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.localNetworkRequired),
      );
      expect(
        untrustedResult.codes,
        contains(
          AiroTemporaryMobileServerValidationCode.trustedReceiverRequired,
        ),
      );
      expect(
        unlistedResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.receiverNotAllowed),
      );
    });

    test('rejects mismatched or underscoped grants', () {
      final wrongAudience = snapshot(
        accessGrant: grant(audienceNodeId: 'tv-2'),
      );
      final underscoped = snapshot(
        accessGrant: grant(scopes: const {AiroRouteAccessScope.playbackRead}),
      );

      final wrongAudienceResult = policy.validate(
        snapshot: wrongAudience,
        context: context,
      );
      final underscopedResult = policy.validate(
        snapshot: underscoped,
        context: context,
      );

      expect(
        wrongAudienceResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.grantAudienceMismatch),
      );
      expect(
        underscopedResult.codes,
        contains(AiroTemporaryMobileServerValidationCode.grantScopeMissing),
      );
    });

    test('rejects missing range, probe, entity, and shutdown capabilities', () {
      final current = snapshot(
        capabilities: const {AiroTemporaryMobileServerCapability.lanOnly},
      );

      final result = policy.validate(snapshot: current, context: context);

      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.rangeRequestsRequired),
      );
      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.probeRequestsRequired),
      );
      expect(
        result.codes,
        contains(
          AiroTemporaryMobileServerValidationCode.entityValidationRequired,
        ),
      );
      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.autoShutdownRequired),
      );
      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.idleShutdownRequired),
      );
    });

    test('rejects low battery, high thermal state, and receiver overload', () {
      final current = snapshot(
        batteryPercent: 10,
        thermalState: AiroTemporaryMobileThermalState.hot,
        activeReceiverCount: 2,
      );

      final result = policy.validate(snapshot: current, context: context);

      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.batteryTooLow),
      );
      expect(
        result.codes,
        contains(AiroTemporaryMobileServerValidationCode.thermalTooHigh),
      );
      expect(
        result.codes,
        contains(
          AiroTemporaryMobileServerValidationCode
              .concurrentReceiverLimitExceeded,
        ),
      );
    });

    test('allows charging device below the battery threshold', () {
      final current = snapshot(batteryPercent: 10, isCharging: true);

      final result = policy.validate(snapshot: current, context: context);

      expect(
        result.codes,
        isNot(contains(AiroTemporaryMobileServerValidationCode.batteryTooLow)),
      );
      expect(result.accepted, isTrue);
    });

    test('serving GET range returns 206 with bounded public headers', () {
      const servingPolicy = AiroTemporaryMobileServerServingPolicy();
      final current = snapshot();

      final decision = servingPolicy.evaluate(
        snapshot: current,
        request: request(rangeHeader: 'bytes=10-19'),
      );
      final publicMap = decision.toPublicMap();
      final flattened = publicMap.toString();

      expect(decision.accepted, isTrue);
      expect(
        decision.status,
        AiroTemporaryMobileServerServingStatus.partialContent,
      );
      expect(decision.emitsBody, isTrue);
      expect(decision.range?.start, 10);
      expect(decision.range?.end, 19);
      expect(decision.responseHeaders['Accept-Ranges'], 'bytes');
      expect(decision.responseHeaders['Content-Length'], '10');
      expect(decision.responseHeaders['Content-Range'], 'bytes 10-19/4096');
      expect(decision.responseHeaders['ETag'], 'etag-1');
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('http://')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('providerPayload')));
    });

    test('serving HEAD probe returns headers without body bytes', () {
      const servingPolicy = AiroTemporaryMobileServerServingPolicy();
      final current = snapshot();

      final decision = servingPolicy.evaluate(
        snapshot: current,
        request: request(
          method: AiroTemporaryMobileServerRequestMethod.head,
          rangeHeader: null,
          requiresRangeRequest: false,
        ),
      );

      expect(decision.accepted, isTrue);
      expect(decision.status, AiroTemporaryMobileServerServingStatus.ok);
      expect(decision.emitsBody, isFalse);
      expect(decision.range, isNull);
      expect(decision.responseHeaders['Accept-Ranges'], 'bytes');
      expect(decision.responseHeaders['Content-Length'], '4096');
      expect(decision.responseHeaders['ETag'], 'etag-1');
    });

    test('serving rejects missing, multi, and out-of-bounds ranges', () {
      const servingPolicy = AiroTemporaryMobileServerServingPolicy();
      final current = snapshot();

      final missing = servingPolicy.evaluate(
        snapshot: current,
        request: request(rangeHeader: null),
      );
      final multi = servingPolicy.evaluate(
        snapshot: current,
        request: request(rangeHeader: 'bytes=0-1,3-4'),
      );
      final outOfBounds = servingPolicy.evaluate(
        snapshot: current,
        request: request(rangeHeader: 'bytes=5000-6000'),
      );

      expect(missing.accepted, isFalse);
      expect(
        missing.servingCodes,
        contains(AiroTemporaryMobileServerServingCode.rangeHeaderRequired),
      );
      expect(
        multi.servingCodes,
        contains(AiroTemporaryMobileServerServingCode.multiRangeUnsupported),
      );
      expect(
        outOfBounds.servingCodes,
        contains(AiroTemporaryMobileServerServingCode.rangeNotSatisfiable),
      );
    });

    test('serving rejects unsafe host and request states before streaming', () {
      const servingPolicy = AiroTemporaryMobileServerServingPolicy();
      final current = snapshot(
        batteryPercent: 5,
        thermalState: AiroTemporaryMobileThermalState.hot,
      );

      final decision = servingPolicy.evaluate(
        snapshot: current,
        request: request(cancelled: true),
      );

      expect(decision.accepted, isFalse);
      expect(
        decision.validationCodes,
        contains(AiroTemporaryMobileServerValidationCode.batteryTooLow),
      );
      expect(
        decision.validationCodes,
        contains(AiroTemporaryMobileServerValidationCode.thermalTooHigh),
      );
      expect(decision.servingCodes, isEmpty);
      expect(decision.status, AiroTemporaryMobileServerServingStatus.reject);
    });

    test('serving rejects cancellation and missing entity validator', () {
      const servingPolicy = AiroTemporaryMobileServerServingPolicy();
      final current = snapshot();

      final decision = servingPolicy.evaluate(
        snapshot: current,
        request: request(cancelled: true, entityValidator: ''),
      );

      expect(decision.accepted, isFalse);
      expect(
        decision.servingCodes,
        contains(AiroTemporaryMobileServerServingCode.cancelled),
      );
      expect(
        decision.servingCodes,
        contains(AiroTemporaryMobileServerServingCode.entityValidatorMissing),
      );
    });
  });

  group('AiroTemporaryMobileServerController fakes', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroTemporaryMobileServerSnapshot snapshot() {
      return AiroTemporaryMobileServerSnapshot(
        serverId: 'server-1',
        hostNodeId: 'phone-1',
        locationId: 'location-1',
        mediaId: 'media-1',
        accessGrant: AiroRouteAccessGrant(
          grantId: 'grant-1',
          locationId: 'location-1',
          audienceNodeId: 'tv-1',
          handle: AiroRouteAccessHandle.redacted('grant-handle'),
          issuedAt: now,
          expiresAt: now.add(const Duration(minutes: 4)),
          scopes: const {
            AiroRouteAccessScope.playbackRead,
            AiroRouteAccessScope.rangeRead,
            AiroRouteAccessScope.probeRead,
          },
        ),
        startedAt: now.subtract(const Duration(seconds: 20)),
        expiresAt: now.add(const Duration(minutes: 5)),
        lastActivityAt: now.subtract(const Duration(seconds: 5)),
        allowedReceiverNodeIds: const {'tv-1'},
        capabilities: const {
          AiroTemporaryMobileServerCapability.lanOnly,
          AiroTemporaryMobileServerCapability.rangeRequests,
          AiroTemporaryMobileServerCapability.probeRequests,
          AiroTemporaryMobileServerCapability.entityValidation,
          AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
          AiroTemporaryMobileServerCapability.idleShutdown,
        },
        batteryPercent: 80,
        thermalState: AiroTemporaryMobileThermalState.normal,
      );
    }

    test(
      'no-op controller reports unavailable without a platform backend',
      () async {
        const controller = AiroNoOpTemporaryMobileServerController();

        final result = await Future.value(
          controller.validate(
            AiroTemporaryMobileServerValidationContext(
              now: DateTime.utc(2026, 7, 14, 12),
              receiverNodeId: 'tv-1',
              hasLocalNetworkScope: true,
              hasTrustedReceiverScope: true,
            ),
          ),
        );

        expect(
          result.codes,
          contains(AiroTemporaryMobileServerValidationCode.serverUnavailable),
        );
      },
    );

    test(
      'fake controller validates and shuts down deterministic state',
      () async {
        final controller = AiroFakeTemporaryMobileServerController(
          snapshot: snapshot(),
        );

        final result = await Future.value(
          controller.validate(
            AiroTemporaryMobileServerValidationContext(
              now: DateTime.utc(2026, 7, 14, 12),
              receiverNodeId: 'tv-1',
              hasLocalNetworkScope: true,
              hasTrustedReceiverScope: true,
            ),
          ),
        );
        await Future.value(controller.shutdown('server-1'));

        expect(result.accepted, isTrue);
        expect(controller.shutdownCallCount, 1);
        expect(await Future.value(controller.currentSnapshot()), isNull);
      },
    );

    test('fake and no-op controllers expose serving decisions', () async {
      const noOp = AiroNoOpTemporaryMobileServerController();
      final fake = AiroFakeTemporaryMobileServerController(
        snapshot: snapshot(),
      );
      final request = AiroTemporaryMobileServerServingRequest(
        requestId: 'request-1',
        method: AiroTemporaryMobileServerRequestMethod.get,
        receiverNodeId: 'tv-1',
        now: now,
        mediaLengthBytes: 2048,
        entityValidator: 'etag-1',
        rangeHeader: 'bytes=-512',
        hasLocalNetworkScope: true,
        hasTrustedReceiverScope: true,
      );

      final unavailable = await Future.value(noOp.evaluateServing(request));
      final accepted = await Future.value(fake.evaluateServing(request));

      expect(unavailable.accepted, isFalse);
      expect(
        unavailable.validationCodes,
        contains(AiroTemporaryMobileServerValidationCode.serverUnavailable),
      );
      expect(accepted.accepted, isTrue);
      expect(accepted.range?.start, 1536);
      expect(accepted.range?.end, 2047);
      expect(accepted.responseHeaders['Content-Range'], 'bytes 1536-2047/2048');
    });
  });
}
