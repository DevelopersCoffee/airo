import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('Distributed EPG worker contracts', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final capability = _capability();
    final policy = DistributedEpgWorkerPolicy();

    test('accepts bounded compact snapshot request and manifest', () {
      final request = _request(now: now);
      final manifest = _manifest(request: request, now: now);

      final requestResult = policy.validateRequest(
        capability: capability,
        request: request,
      );
      final snapshotResult = policy.validateSnapshot(
        capability: capability,
        request: request,
        manifest: manifest,
        now: now,
      );

      expect(requestResult.accepted, isTrue);
      expect(snapshotResult.accepted, isTrue);
      expect(
        manifest.toDiagnosticMap(),
        containsPair('payloadBytes', manifest.payloadBytes),
      );
    });

    test('rejects unsupported capability and invalid request shape', () {
      final weakCapability = _capability(
        roles: const {DistributedEpgWorkerRole.parser},
        tasks: const {DistributedEpgTaskKind.cachePrune},
        formats: const {DistributedEpgPayloadFormat.binaryDelta},
        transferModes: const {DistributedEpgTransferMode.incrementalPatch},
        maxChannelCount: 1,
        maxWindow: const Duration(hours: 1),
      );
      final result = policy.validateRequest(
        capability: weakCapability,
        request: _request(
          now: now,
          windowStart: now,
          windowEnd: now.add(const Duration(hours: 2)),
          channelIds: const ['one', 'two'],
        ),
      );
      final invalidWindowResult = policy.validateRequest(
        capability: capability,
        request: _request(
          now: now,
          windowStart: now.add(const Duration(hours: 2)),
          windowEnd: now,
        ),
      );

      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.missingRequiredRole),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.unsupportedTask),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.unsupportedFormat),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.unsupportedTransferMode),
      );
      expect(
        invalidWindowResult.codes,
        contains(DistributedEpgWorkerBlockerCode.invalidWindow),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.windowTooLarge),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.tooManyChannels),
      );
    });

    test('rejects stale oversized uncovered snapshot manifests', () {
      final request = _request(now: now);
      final result = policy.validateSnapshot(
        capability: _capability(maxSnapshotBytes: 100, cacheBudgetBytes: 90),
        request: request,
        now: now,
        manifest: _manifest(
          request: request,
          now: now.subtract(const Duration(minutes: 30)),
          expiresAt: now.subtract(const Duration(minutes: 1)),
          windowStart: now.subtract(const Duration(minutes: 15)),
          windowEnd: now.add(const Duration(minutes: 15)),
          entryCount: kDistributedEpgDefaultMaxEntryCount + 1,
          payloadBytes: 120,
        ),
      );

      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.tooManyEntries),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.snapshotTooLarge),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.cacheBudgetExceeded),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.staleSnapshot),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.expiredSnapshot),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.windowNotCovered),
      );
    });

    test('rejects future and invalid snapshot manifests', () {
      final request = _request(now: now);
      final result = policy.validateSnapshot(
        capability: capability,
        request: request,
        now: now,
        manifest: _manifest(
          request: request,
          now: now.add(const Duration(minutes: 5)),
          sequence: 0,
          windowStart: now.add(const Duration(hours: 1)),
          windowEnd: now,
        ),
      );

      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.futureSnapshot),
      );
      expect(
        result.codes,
        contains(DistributedEpgWorkerBlockerCode.invalidWindow),
      );
    });

    test('stable values reject raw network and credential material', () {
      expect(
        () => DistributedEpgStableValue.stable('https://example.com/guide.xml'),
        throwsArgumentError,
      );
      expect(
        () => DistributedEpgStableValue.stable('/Users/me/guide.xml'),
        throwsArgumentError,
      );
      expect(
        () => DistributedEpgStableValue.stable('10.0.0.12'),
        throwsArgumentError,
      );
      expect(
        () => DistributedEpgStableValue.stable('Bearer abc123'),
        throwsArgumentError,
      );
    });

    test('no-op worker emits unavailable event', () async {
      final worker = NoOpDistributedEpgWorker(capability);
      final events = await worker.run(_request(now: now)).toList();

      expect(events, hasLength(1));
      expect(events.single.state, DistributedEpgWorkerEventState.failed);
      expect(
        events.single.validation?.codes,
        contains(DistributedEpgWorkerBlockerCode.workerUnavailable),
      );
    });

    test(
      'fake worker emits queued running and snapshot-ready events',
      () async {
        final worker = FakeDistributedEpgWorker(
          capability: capability,
          policy: policy,
        );

        final events = await worker.run(_request(now: now)).toList();

        expect(events.map((event) => event.state), [
          DistributedEpgWorkerEventState.queued,
          DistributedEpgWorkerEventState.running,
          DistributedEpgWorkerEventState.snapshotReady,
        ]);
        expect(events.last.validation?.accepted, isTrue);
        expect(events.last.manifest?.channelCount, 2);
      },
    );

    test(
      'fake worker emits cancelled event for cancelled request id',
      () async {
        final worker = FakeDistributedEpgWorker(
          capability: capability,
          policy: policy,
        );
        final request = _request(now: now);

        await worker.cancel(request.requestId);
        final events = await worker.run(request).toList();

        expect(events.map((event) => event.state), [
          DistributedEpgWorkerEventState.queued,
          DistributedEpgWorkerEventState.cancelled,
        ]);
        expect(
          events.last.validation?.codes,
          contains(DistributedEpgWorkerBlockerCode.cancelled),
        );
      },
    );
  });
}

DistributedEpgWorkerCapability _capability({
  Set<DistributedEpgWorkerRole> roles = const {
    DistributedEpgWorkerRole.downloader,
    DistributedEpgWorkerRole.parser,
    DistributedEpgWorkerRole.normalizer,
    DistributedEpgWorkerRole.compactor,
    DistributedEpgWorkerRole.cacheHost,
  },
  Set<DistributedEpgTaskKind> tasks = const {
    DistributedEpgTaskKind.compactSnapshot,
    DistributedEpgTaskKind.incrementalPatch,
  },
  Set<DistributedEpgPayloadFormat> formats = const {
    DistributedEpgPayloadFormat.compactJson,
    DistributedEpgPayloadFormat.protobufEnvelope,
  },
  Set<DistributedEpgTransferMode> transferModes = const {
    DistributedEpgTransferMode.currentNextOnly,
    DistributedEpgTransferMode.incrementalPatch,
  },
  Duration maxWindow = kDistributedEpgDefaultMaxWindow,
  int maxChannelCount = kDistributedEpgDefaultMaxChannelCount,
  int maxSnapshotBytes = kDistributedEpgDefaultMaxSnapshotBytes,
  int cacheBudgetBytes = kDistributedEpgDefaultMaxSnapshotBytes,
}) {
  return DistributedEpgWorkerCapability(
    workerId: DistributedEpgStableValue.stable('home-node-epg-worker'),
    roles: roles,
    supportedTasks: tasks,
    supportedFormats: formats,
    supportedTransferModes: transferModes,
    maxWindow: maxWindow,
    maxChannelCount: maxChannelCount,
    maxSnapshotBytes: maxSnapshotBytes,
    cacheBudgetBytes: cacheBudgetBytes,
  );
}

DistributedEpgSyncRequest _request({
  required DateTime now,
  DateTime? windowStart,
  DateTime? windowEnd,
  Iterable<String> channelIds = const ['channel-1', 'channel-2'],
}) {
  return DistributedEpgSyncRequest(
    requestId: DistributedEpgStableValue.stable('epg-request-1'),
    sourceRef: CompactEpgSourceRef.redacted('epg-source-ref-1'),
    requestedAt: now,
    windowStart: windowStart ?? now,
    windowEnd: windowEnd ?? now.add(const Duration(hours: 2)),
    channelIds: channelIds,
    taskKind: DistributedEpgTaskKind.compactSnapshot,
    payloadFormat: DistributedEpgPayloadFormat.compactJson,
    transferMode: DistributedEpgTransferMode.currentNextOnly,
  );
}

DistributedEpgSnapshotManifest _manifest({
  required DistributedEpgSyncRequest request,
  required DateTime now,
  DateTime? expiresAt,
  DateTime? windowStart,
  DateTime? windowEnd,
  int entryCount = 4,
  int payloadBytes = 1024,
  int sequence = 1,
}) {
  return DistributedEpgSnapshotManifest(
    snapshotId: DistributedEpgStableValue.stable('epg-snapshot-1'),
    sourceRef: request.sourceRef,
    generatedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
    windowStart: windowStart ?? request.windowStart,
    windowEnd: windowEnd ?? request.windowEnd,
    channelCount: request.channelIds.length,
    entryCount: entryCount,
    payloadBytes: payloadBytes,
    payloadFormat: request.payloadFormat,
    transferMode: request.transferMode,
    sequence: sequence,
  );
}
