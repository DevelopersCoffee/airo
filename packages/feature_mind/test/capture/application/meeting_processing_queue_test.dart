import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/capture/application/meeting_processing_queue.dart';
import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_processing_queue_store.dart';

MeetingProcessingJob _job(String id, {int enqueuedAtMs = 0}) {
  return MeetingProcessingJob(
    id: id,
    audioPath: '/tmp/$id.m4a',
    title: id,
    enqueuedAtMs: enqueuedAtMs,
  );
}

void main() {
  group('MeetingProcessingQueue', () {
    test('processes a single enqueued job to completion', () async {
      final store = InMemoryProcessingQueueStore();
      final processed = <String>[];
      final queue = MeetingProcessingQueue(
        store: store,
        deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
          LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
        ),
        processJob: (job) async {
          processed.add(job.id);
        },
      );
      await queue.restore();

      await queue.enqueue(_job('m1'));
      await pumpEventQueue();

      expect(processed, ['m1']);
      // Completed jobs are pruned, not kept as `completed` -- see the
      // dedicated pruning test below and the class doc's "Retention
      // discipline" section.
      expect(queue.current, isEmpty);

      await queue.dispose();
    });

    test(
      'never runs two jobs concurrently -- second waits behind the first',
      () async {
        final store = InMemoryProcessingQueueStore();
        final started = <String>[];
        final completers = <String, Completer<void>>{};
        final queue = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
            LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
          ),
          processJob: (job) async {
            started.add(job.id);
            final completer = Completer<void>();
            completers[job.id] = completer;
            await completer.future;
          },
        );
        await queue.restore();

        await queue.enqueue(_job('first'));
        await queue.enqueue(_job('second'));
        await pumpEventQueue();

        // Only the first job may be running -- the second must still be queued.
        expect(started, ['first']);
        expect(
          queue.current.firstWhere((j) => j.id == 'second').status,
          MeetingProcessingStatus.queued,
        );

        completers['first']!.complete();
        await pumpEventQueue();

        expect(started, ['first', 'second']);
        completers['second']!.complete();
        await pumpEventQueue();

        // Both completed -- and pruned, so nothing is left in the queue.
        expect(queue.current, isEmpty);

        await queue.dispose();
      },
    );

    test(
      'pauses the whole queue under thermal pressure instead of throttling',
      () async {
        final store = InMemoryProcessingQueueStore();
        var pressure = LlmThermalPressure.critical;
        final processed = <String>[];
        final queue = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: _DynamicProbe(() => pressure),
          thermalPollInterval: const Duration(milliseconds: 5),
          processJob: (job) async {
            processed.add(job.id);
          },
        );
        await queue.restore();

        await queue.enqueue(_job('hot'));
        await pumpEventQueue();

        // Thermal pressure is critical -- nothing should have run.
        expect(processed, isEmpty);
        expect(queue.current.single.status, MeetingProcessingStatus.queued);

        // Pressure eases; the poll timer should pick the job back up.
        pressure = LlmThermalPressure.nominal;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await pumpEventQueue();

        expect(processed, ['hot']);

        await queue.dispose();
      },
    );

    test('restore demotes a job left in "processing" back to queued', () async {
      final store = InMemoryProcessingQueueStore([
        _job('orphaned').copyWith(status: MeetingProcessingStatus.processing),
      ]);
      final processed = <String>[];
      final queue = MeetingProcessingQueue(
        store: store,
        deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
          LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
        ),
        processJob: (job) async {
          processed.add(job.id);
        },
      );

      await queue.restore();
      await pumpEventQueue();

      // The job that "died" mid-process is picked back up from scratch, not
      // left stuck in `processing` forever.
      expect(processed, ['orphaned']);
      expect(queue.current, isEmpty);

      await queue.dispose();
    });

    test(
      'completed jobs are pruned from the persisted list, not kept forever',
      () async {
        final store = InMemoryProcessingQueueStore();
        final queue = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
            LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
          ),
          processJob: (job) async {},
        );
        await queue.restore();

        await queue.enqueue(_job('m1'));
        await pumpEventQueue();

        expect(queue.current, isEmpty);
        // Also gone from disk, not just the in-memory list -- a fresh queue
        // reading the same store must not see it either.
        expect(await store.load(), isEmpty);

        await queue.dispose();
      },
    );

    test('a terminally-failed job still runs the retention cleanup callback '
        '(chief-security-officer review, #1656)', () async {
      final store = InMemoryProcessingQueueStore();
      final cleanedUp = <String>[];
      final queue = MeetingProcessingQueue(
        store: store,
        deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
          LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
        ),
        maxAttempts: 1,
        processJob: (job) async => throw Exception('unrecoverable'),
        onTerminalFailure: (job) async => cleanedUp.add(job.id),
      );
      await queue.restore();

      await queue.enqueue(_job('doomed'));
      await pumpEventQueue();
      await pumpEventQueue();

      expect(cleanedUp, ['doomed']);
      // Unlike a completed job, a failed one stays visible -- it is
      // diagnostic state a future "needs attention" surface can show, not
      // a job the person can act on again automatically.
      expect(queue.current.single.status, MeetingProcessingStatus.failed);

      await queue.dispose();
    });

    test('a throwing onTerminalFailure callback does not stop the queue '
        'from moving on to the next job', () async {
      final store = InMemoryProcessingQueueStore();
      final processed = <String>[];
      final queue = MeetingProcessingQueue(
        store: store,
        deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
          LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
        ),
        maxAttempts: 1,
        processJob: (job) async {
          if (job.id == 'doomed') throw Exception('unrecoverable');
          processed.add(job.id);
        },
        onTerminalFailure: (job) async =>
            throw Exception('cleanup also failed'),
      );
      await queue.restore();

      await queue.enqueue(_job('doomed'));
      await queue.enqueue(_job('fine'));
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(processed, ['fine']);

      await queue.dispose();
    });

    test(
      'a job that keeps failing stops retrying after the attempt cap',
      () async {
        final store = InMemoryProcessingQueueStore();
        var attempts = 0;
        final queue = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
            LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
          ),
          maxAttempts: 2,
          processJob: (job) async {
            attempts++;
            throw Exception('boom');
          },
        );
        await queue.restore();

        await queue.enqueue(_job('doomed'));
        await pumpEventQueue();
        await pumpEventQueue();
        await pumpEventQueue();

        expect(attempts, 2);
        expect(queue.current.single.status, MeetingProcessingStatus.failed);
        expect(queue.current.single.lastError, contains('boom'));

        await queue.dispose();
      },
    );

    test(
      'the queue file round-trips a job list across a fresh queue instance',
      () async {
        final store = InMemoryProcessingQueueStore();
        final firstLifetime = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
            LlmDeviceSignals(
              totalRamMb: 8000,
              availableStorageMb: 8000,
              thermalPressure: LlmThermalPressure.critical,
            ),
          ),
          processJob: (job) async {},
        );
        await firstLifetime.restore();
        await firstLifetime.enqueue(_job('survives-restart'));
        await pumpEventQueue();
        await firstLifetime.dispose();

        final secondLifetime = MeetingProcessingQueue(
          store: store,
          deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
            LlmDeviceSignals(totalRamMb: 8000, availableStorageMb: 8000),
          ),
          processJob: (job) async {},
        );
        await secondLifetime.restore();

        expect(secondLifetime.current.single.id, 'survives-restart');
        await secondLifetime.dispose();
      },
    );
  });
}

class _DynamicProbe implements LlmDeviceSignalsProbe {
  _DynamicProbe(this._read);

  final LlmThermalPressure Function() _read;

  @override
  Future<LlmDeviceSignals> probe() async => LlmDeviceSignals(
    totalRamMb: 8000,
    availableStorageMb: 8000,
    thermalPressure: _read(),
  );
}
