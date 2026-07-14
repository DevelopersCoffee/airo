import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroEdgeMediaNodePolicy', () {
    const policy = AiroEdgeMediaNodePolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroNodeCapabilityAdvertisement advertisement({
      AiroNodeRole role = AiroNodeRole.homeNode,
      AiroNodeLifecycleState lifecycle = AiroNodeLifecycleState.available,
      AiroNodeTrustState trustState = AiroNodeTrustState.trusted,
      Set<AiroNodeCapability> capabilities = const {
        AiroNodeCapability.mediaIndexing,
        AiroNodeCapability.diagnostics,
        AiroNodeCapability.commandRouting,
        AiroNodeCapability.recording,
        AiroNodeCapability.transcoding,
        AiroNodeCapability.aiDelegation,
        AiroNodeCapability.metadataProcessing,
      },
      DateTime? expiresAt,
    }) {
      return AiroNodeCapabilityAdvertisement(
        identity: AiroNodeIdentity(
          nodeId: 'edge-1',
          role: role,
          productProfile: AiroNodeProductProfile.homeNode,
          platformCategory: AiroNodePlatformCategory.server,
        ),
        lifecycle: lifecycle,
        trustState: trustState,
        capabilities: capabilities,
        issuedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
      );
    }

    AiroEdgeMediaNodeProfile profile({
      AiroNodeCapabilityAdvertisement? nodeAdvertisement,
      List<AiroEdgeMediaNodeServiceDescriptor> services = const [
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.mediaIndexing,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.streamHealth,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.relay,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.recording,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.transcoding,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
      ],
    }) {
      return AiroEdgeMediaNodeProfile(
        profileId: 'edge-profile-1',
        advertisement: nodeAdvertisement ?? advertisement(),
        services: services,
        observedAt: now,
      );
    }

    AiroEdgeMediaNodeRequest request({
      AiroEdgeMediaNodeService service = AiroEdgeMediaNodeService.mediaIndexing,
      bool hasLocalNetworkScope = true,
      bool allowRelay = false,
      bool allowRecording = false,
      bool allowTranscoding = false,
    }) {
      return AiroEdgeMediaNodeRequest(
        requestId: 'request-1',
        requestedByNodeId: 'tv-1',
        service: service,
        hasLocalNetworkScope: hasLocalNetworkScope,
        allowRelay: allowRelay,
        allowRecording: allowRecording,
        allowTranscoding: allowTranscoding,
      );
    }

    test('accepts trusted fresh home node with available indexing service', () {
      final result = policy.evaluate(
        profile: profile(),
        request: request(),
        now: now,
      );

      expect(result.accepted, isTrue);
    });

    test('accepts trusted desktop companion as future edge node candidate', () {
      final result = policy.evaluate(
        profile: profile(
          nodeAdvertisement: advertisement(role: AiroNodeRole.desktopCompanion),
        ),
        request: request(service: AiroEdgeMediaNodeService.streamHealth),
        now: now,
      );

      expect(result.accepted, isTrue);
    });

    test('rejects stale untrusted blocked and incompatible nodes', () {
      final stale = policy.evaluate(
        profile: profile(nodeAdvertisement: advertisement(expiresAt: now)),
        request: request(),
        now: now,
      );
      final untrusted = policy.evaluate(
        profile: profile(
          nodeAdvertisement: advertisement(
            trustState: AiroNodeTrustState.untrusted,
          ),
        ),
        request: request(),
        now: now,
      );
      final blocked = policy.evaluate(
        profile: profile(
          nodeAdvertisement: advertisement(
            lifecycle: AiroNodeLifecycleState.blocked,
          ),
        ),
        request: request(),
        now: now,
      );
      final incompatible = policy.evaluate(
        profile: profile(
          nodeAdvertisement: advertisement(role: AiroNodeRole.tvReceiver),
        ),
        request: request(),
        now: now,
      );

      expect(
        stale.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.staleAdvertisement),
      );
      expect(
        untrusted.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.untrustedNode),
      );
      expect(
        blocked.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.blockedNode),
      );
      expect(
        incompatible.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.incompatibleRole),
      );
    });

    test('rejects missing capability service descriptor and local scope', () {
      final result = policy.evaluate(
        profile: profile(
          nodeAdvertisement: advertisement(capabilities: const {}),
          services: const [],
        ),
        request: request(hasLocalNetworkScope: false),
        now: now,
      );

      expect(
        result.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.missingConnectedNodeCapability),
      );
      expect(
        result.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.serviceMissing),
      );
    });

    test('rejects placeholder-only and disabled services', () {
      final placeholder = policy.evaluate(
        profile: profile(
          services: const [
            AiroEdgeMediaNodeServiceDescriptor(
              service: AiroEdgeMediaNodeService.mediaIndexing,
              state: AiroEdgeMediaNodeServiceState.placeholder,
            ),
          ],
        ),
        request: request(),
        now: now,
      );
      final disabled = policy.evaluate(
        profile: profile(
          services: const [
            AiroEdgeMediaNodeServiceDescriptor(
              service: AiroEdgeMediaNodeService.mediaIndexing,
              state: AiroEdgeMediaNodeServiceState.disabled,
            ),
          ],
        ),
        request: request(),
        now: now,
      );

      expect(
        placeholder.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.serviceNotExecutable),
      );
      expect(
        disabled.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.serviceNotExecutable),
      );
    });

    test('riskier relay recording and transcoding services require opt-in', () {
      final relay = policy.evaluate(
        profile: profile(),
        request: request(service: AiroEdgeMediaNodeService.relay),
        now: now,
      );
      final recording = policy.evaluate(
        profile: profile(),
        request: request(service: AiroEdgeMediaNodeService.recording),
        now: now,
      );
      final transcoding = policy.evaluate(
        profile: profile(),
        request: request(service: AiroEdgeMediaNodeService.transcoding),
        now: now,
      );
      final allowedTranscoding = policy.evaluate(
        profile: profile(),
        request: request(
          service: AiroEdgeMediaNodeService.transcoding,
          allowTranscoding: true,
        ),
        now: now,
      );

      expect(
        relay.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.relayNotAllowed),
      );
      expect(
        recording.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.recordingNotAllowed),
      );
      expect(
        transcoding.blockers,
        contains(AiroEdgeMediaNodeBlockerCode.transcodingNotAllowed),
      );
      expect(allowedTranscoding.accepted, isTrue);
    });

    test('diagnostics expose stable ids without private media fields', () {
      final edgeProfile = profile();
      final rendered = edgeProfile.toString();

      expect(rendered, contains('edge-profile-1'));
      expect(rendered, contains('media_indexing:available'));
      expect(rendered, isNot(contains('credential')));
      expect(rendered, isNot(contains('mediaUrl')));
      expect(rendered, isNot(contains('/Users/')));
    });
  });

  group('AiroEdgeMediaNodeRegistry adapters', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    final profile = AiroEdgeMediaNodeProfile(
      profileId: 'edge-profile-1',
      advertisement: AiroNodeCapabilityAdvertisement(
        identity: const AiroNodeIdentity(
          nodeId: 'edge-1',
          role: AiroNodeRole.homeNode,
          productProfile: AiroNodeProductProfile.homeNode,
          platformCategory: AiroNodePlatformCategory.server,
        ),
        lifecycle: AiroNodeLifecycleState.available,
        trustState: AiroNodeTrustState.trusted,
        capabilities: const {AiroNodeCapability.mediaIndexing},
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
      services: const [
        AiroEdgeMediaNodeServiceDescriptor(
          service: AiroEdgeMediaNodeService.mediaIndexing,
          state: AiroEdgeMediaNodeServiceState.available,
        ),
      ],
      observedAt: now,
    );

    test('no-op registry returns no candidates', () async {
      const registry = AiroNoOpEdgeMediaNodeRegistry();

      final candidates = await Future.value(registry.candidates());

      expect(candidates, isEmpty);
    });

    test('fake registry returns deterministic candidates', () async {
      final registry = AiroFakeEdgeMediaNodeRegistry(profiles: [profile]);

      final candidates = await Future.value(registry.candidates());

      expect(candidates.single.profileId, 'edge-profile-1');
    });
  });
}
