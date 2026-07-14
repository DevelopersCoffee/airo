import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo connected-node protocol', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroNodeIdentity identity({
      String nodeId = 'node-tv-1',
      AiroNodeRole role = AiroNodeRole.tvReceiver,
      AiroNodeProductProfile productProfile =
          AiroNodeProductProfile.liteReceiver,
      int protocolVersion = kAiroNodeProtocolVersion,
      String schemaVersion = kAiroNodeProtocolSchemaVersion,
    }) {
      return AiroNodeIdentity(
        nodeId: nodeId,
        role: role,
        productProfile: productProfile,
        platformCategory: AiroNodePlatformCategory.androidTv,
        protocolVersion: protocolVersion,
        schemaVersion: schemaVersion,
      );
    }

    AiroNodeCapabilityAdvertisement advertisement({
      AiroNodeIdentity? nodeIdentity,
      AiroNodeLifecycleState lifecycle = AiroNodeLifecycleState.available,
      AiroNodeTrustState trustState = AiroNodeTrustState.trusted,
      Set<AiroNodeCapability> capabilities = const {
        AiroNodeCapability.playback,
        AiroNodeCapability.remoteControl,
        AiroNodeCapability.compactEpg,
        AiroNodeCapability.basicSearch,
      },
      DateTime? issuedAt,
      DateTime? expiresAt,
      int protocolVersion = kAiroNodeProtocolVersion,
      String schemaVersion = kAiroNodeProtocolSchemaVersion,
    }) {
      return AiroNodeCapabilityAdvertisement(
        identity: nodeIdentity ?? identity(),
        lifecycle: lifecycle,
        trustState: trustState,
        capabilities: capabilities,
        issuedAt: issuedAt ?? now,
        expiresAt: expiresAt ?? now.add(const Duration(seconds: 30)),
        protocolVersion: protocolVersion,
        schemaVersion: schemaVersion,
      );
    }

    AiroNodeCompatibilityPolicy policy({
      bool requiresTrustedNode = true,
      Set<AiroNodeCapability> requiredCapabilities = const {
        AiroNodeCapability.playback,
        AiroNodeCapability.compactEpg,
      },
      int minProtocolVersion = kAiroNodeProtocolVersion,
      int maxProtocolVersion = kAiroNodeProtocolVersion,
      String acceptedSchemaVersion = kAiroNodeProtocolSchemaVersion,
    }) {
      return AiroNodeCompatibilityPolicy(
        requiredCapabilities: requiredCapabilities,
        requiresTrustedNode: requiresTrustedNode,
        minProtocolVersion: minProtocolVersion,
        maxProtocolVersion: maxProtocolVersion,
        acceptedSchemaVersion: acceptedSchemaVersion,
      );
    }

    test('identity exposes stable schema and role/profile identifiers', () {
      final node = identity();

      expect(node.schemaVersion, kAiroNodeProtocolSchemaVersion);
      expect(node.protocolVersion, kAiroNodeProtocolVersion);
      expect(node.role.stableId, 'tv_receiver');
      expect(node.productProfile.stableId, 'lite_receiver');
    });

    test('public advertisement omits private media and account fields', () {
      final publicMap = advertisement().toPublicMap();
      final rendered = publicMap.toString();

      expect(publicMap['nodeId'], 'node-tv-1');
      expect(publicMap['capabilities'], contains('playback'));
      expect(rendered, isNot(contains('playlist')));
      expect(rendered, isNot(contains('credential')));
      expect(rendered, isNot(contains('history')));
      expect(rendered, isNot(contains('mediaUrl')));
    });

    test(
      'compatible node passes schema, protocol, lifecycle, trust, and freshness',
      () {
        final result = policy().evaluate(
          advertisement: advertisement(),
          now: now,
        );

        expect(result.compatible, isTrue);
        expect(result.blockers, isEmpty);
      },
    );

    test('stale advertisement fails deterministically', () {
      final result = policy().evaluate(
        advertisement: advertisement(
          issuedAt: now.subtract(const Duration(minutes: 2)),
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
      );

      expect(result.compatible, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.staleAdvertisement),
      );
    });

    test('missing required capability fails deterministically', () {
      final result = policy().evaluate(
        advertisement: advertisement(
          capabilities: const {AiroNodeCapability.playback},
        ),
        now: now,
      );

      expect(result.compatible, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.missingCapability),
      );
    });

    test('untrusted nodes fail private compatibility checks', () {
      final result = policy().evaluate(
        advertisement: advertisement(trustState: AiroNodeTrustState.untrusted),
        now: now,
      );

      expect(result.compatible, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.untrustedNode),
      );
    });

    test('blocked and unavailable lifecycle states fail deterministically', () {
      final blocked = policy().evaluate(
        advertisement: advertisement(lifecycle: AiroNodeLifecycleState.blocked),
        now: now,
      );
      final sleeping = policy().evaluate(
        advertisement: advertisement(
          lifecycle: AiroNodeLifecycleState.sleeping,
        ),
        now: now,
      );

      expect(
        blocked.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.blockedNode),
      );
      expect(
        sleeping.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.lifecycleUnavailable),
      );
    });

    test('schema and protocol mismatches return stable blocker codes', () {
      final wrongSchema = policy().evaluate(
        advertisement: advertisement(
          nodeIdentity: identity(schemaVersion: '2.0.0'),
          schemaVersion: '2.0.0',
        ),
        now: now,
      );
      final oldProtocol = policy(
        minProtocolVersion: 2,
      ).evaluate(advertisement: advertisement(protocolVersion: 1), now: now);
      final newProtocol = policy(
        maxProtocolVersion: 1,
      ).evaluate(advertisement: advertisement(protocolVersion: 2), now: now);

      expect(
        wrongSchema.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.schemaMismatch),
      );
      expect(
        oldProtocol.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.protocolTooOld),
      );
      expect(
        newProtocol.blockers.map((blocker) => blocker.code),
        contains(AiroNodeCompatibilityBlockerCode.protocolTooNew),
      );
    });
  });
}
