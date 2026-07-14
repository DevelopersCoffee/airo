import 'package:core_delegation/core_delegation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo delegation task framework', () {
    final now = DateTime.utc(2026, 7, 14, 10);

    AiroDelegationTaskRequest request({
      String taskId = 'task-1',
      String deduplicationKey = 'search:profile:query',
      AiroDelegationTaskKind kind = AiroDelegationTaskKind.search,
      Duration timeout = const Duration(seconds: 2),
      bool requiresEncryptedPayload = false,
      bool hasEncryptedPayload = false,
      int requiredResultVersion = kAiroDelegationResultVersion,
      DateTime? createdAt,
    }) {
      return AiroDelegationTaskRequest(
        taskId: taskId,
        deduplicationKey: deduplicationKey,
        kind: kind,
        createdAt: createdAt ?? now,
        timeout: timeout,
        requiresEncryptedPayload: requiresEncryptedPayload,
        hasEncryptedPayload: hasEncryptedPayload,
        requiredResultVersion: requiredResultVersion,
      );
    }

    AiroDelegationCandidate candidate({
      String nodeId = 'phone-1',
      Set<AiroDelegationTaskKind> taskKinds = const {
        AiroDelegationTaskKind.search,
        AiroDelegationTaskKind.epgProcessing,
      },
      bool isTrusted = true,
      bool isAvailable = true,
      Duration estimatedLatency = const Duration(milliseconds: 300),
      int maxResultVersion = kAiroDelegationResultVersion,
    }) {
      return AiroDelegationCandidate(
        nodeId: nodeId,
        displayName: nodeId,
        supportedTaskKinds: taskKinds,
        isTrusted: isTrusted,
        isAvailable: isAvailable,
        estimatedLatency: estimatedLatency,
        maxResultVersion: maxResultVersion,
      );
    }

    test('trusted capable node accepts delegated task', () {
      const policy = AiroDelegationPolicy();

      final decision = policy.select(
        request: request(),
        candidates: [
          candidate(
            nodeId: 'slow-phone',
            estimatedLatency: const Duration(seconds: 1),
          ),
          candidate(nodeId: 'fast-phone'),
        ],
        now: now,
      );

      expect(decision.accepted, isTrue);
      expect(decision.selectedCandidate?.nodeId, 'fast-phone');
      expect(decision.blockers, isEmpty);
    });

    test('sensitive payload must be encrypted before dispatch', () {
      const policy = AiroDelegationPolicy();

      final decision = policy.select(
        request: request(
          kind: AiroDelegationTaskKind.credentialAssistedPlayback,
          requiresEncryptedPayload: true,
          hasEncryptedPayload: false,
        ),
        candidates: [
          candidate(
            taskKinds: const {
              AiroDelegationTaskKind.credentialAssistedPlayback,
            },
          ),
        ],
        now: now,
      );

      expect(decision.accepted, isFalse);
      expect(
        decision.blockers.map((blocker) => blocker.validationCode),
        contains(AiroDelegationValidationCode.encryptedPayloadMissing),
      );
      expect(decision.fallbackDecision?.userVisibleUnavailable, isTrue);
    });

    test('expired and cancelled tasks are terminal before selection', () {
      const policy = AiroDelegationPolicy();
      final expired = request(
        createdAt: now.subtract(const Duration(seconds: 5)),
      );
      final cancelled = request(taskId: 'cancelled-task');

      final expiredDecision = policy.select(
        request: expired,
        candidates: [candidate()],
        now: now,
      );
      final cancelledDecision = policy.select(
        request: cancelled,
        candidates: [candidate()],
        now: now,
        cancelledTaskIds: const {'cancelled-task'},
      );

      expect(
        expiredDecision.blockers.map((blocker) => blocker.validationCode),
        contains(AiroDelegationValidationCode.expired),
      );
      expect(
        cancelledDecision.blockers.map((blocker) => blocker.validationCode),
        contains(AiroDelegationValidationCode.cancelled),
      );
      expect(expiredDecision.selectedCandidate, isNull);
      expect(cancelledDecision.selectedCandidate, isNull);
    });

    test('deduplication key suppresses duplicate execution', () {
      const policy = AiroDelegationPolicy();
      final existing = AiroDelegationTaskRecord(
        taskId: 'task-existing',
        deduplicationKey: 'search:profile:query',
        status: AiroDelegationTaskStatus.running,
        updatedAt: now,
      );

      final decision = policy.select(
        request: request(taskId: 'task-duplicate'),
        candidates: [candidate()],
        now: now,
        existingRecords: [existing],
      );

      expect(decision.accepted, isFalse);
      expect(decision.duplicateSuppressed, isTrue);
      expect(decision.existingRecord?.taskId, 'task-existing');
      expect(
        decision.blockers.map((blocker) => blocker.code),
        contains(AiroDelegationSelectionBlockerCode.duplicateSuppressed),
      );
    });

    test('fallback is selected when no candidate qualifies', () {
      const policy = AiroDelegationPolicy();

      final decision = policy.select(
        request: request(kind: AiroDelegationTaskKind.transcoding),
        candidates: [
          candidate(nodeId: 'missing-capability'),
          candidate(
            nodeId: 'untrusted',
            taskKinds: const {AiroDelegationTaskKind.transcoding},
            isTrusted: false,
          ),
          candidate(
            nodeId: 'unavailable',
            taskKinds: const {AiroDelegationTaskKind.transcoding},
            isAvailable: false,
          ),
          candidate(
            nodeId: 'slow',
            taskKinds: const {AiroDelegationTaskKind.transcoding},
            estimatedLatency: const Duration(seconds: 5),
          ),
        ],
        now: now,
      );

      expect(decision.accepted, isFalse);
      expect(
        decision.fallbackDecision?.kind,
        AiroDelegationFallbackKind.userActionRequired,
      );
      expect(
        decision.blockers.map((blocker) => blocker.code),
        containsAll(const {
          AiroDelegationSelectionBlockerCode.missingCapability,
          AiroDelegationSelectionBlockerCode.untrustedCandidate,
          AiroDelegationSelectionBlockerCode.unavailableCandidate,
          AiroDelegationSelectionBlockerCode.latencyBudgetExceeded,
          AiroDelegationSelectionBlockerCode.fallbackRequired,
        }),
      );
    });

    test('public maps and string output redact result refs', () {
      final taskRequest = request(
        requiresEncryptedPayload: true,
        hasEncryptedPayload: true,
      );
      final result = AiroDelegationResultEnvelope(
        taskId: taskRequest.taskId,
        status: AiroDelegationTaskStatus.succeeded,
        resultVersion: kAiroDelegationResultVersion,
        completedAt: now,
        resultRef: 'internal-result-ref-1',
      );
      final decision = const AiroDelegationPolicy().select(
        request: taskRequest,
        candidates: [candidate()],
        now: now,
      );
      final publicMap = decision.toPublicMap();
      final flattened = publicMap.toString();

      expect(taskRequest.toString(), contains('payload: redacted'));
      expect(result.toString(), isNot(contains('internal-result-ref-1')));
      expect(result.toPublicMap()['hasResultRef'], isTrue);
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });

    test('no-op dispatcher returns unavailable fallback result', () async {
      const dispatcher = AiroNoOpDelegationDispatcher();

      final result = await dispatcher.dispatch(request());

      expect(result.status, AiroDelegationTaskStatus.unavailable);
      expect(result.fallbackKind, AiroDelegationFallbackKind.noOpUnavailable);
      expect(result.resultVersion, kAiroDelegationResultVersion);
    });
  });
}
