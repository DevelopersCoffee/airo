/// Device journey for Airo Mind — the gated replacement for the deleted
/// Rust `user_journey.rs` (#1549 / #1771).
///
/// ## What this proves
///
/// Real engines, real models, one scripted path:
/// acquire scribe models (if missing) → initialize [MindService] →
/// fixture wav (or short mic capture) → transcribe → minutes → save →
/// search → open. Optionally asserts markdown export (`transcript.md` +
/// `mom.md`) once the meeting is durable.
///
/// Composition coverage (fakes) lives in `packages/feature_mind` and does
/// **not** replace this. This file must not use a fake that always passes.
///
/// ## Gate
///
/// Opt-in only. Default `flutter test integration_test/` and CI skip this
/// test — it needs ~570 MB of models and a physical device (Pixel 9).
///
/// Pass `--dart-define=AIRO_RUN_MIND_JOURNEY=true` to enable. The Mind shell
/// CI job analyses this file against `pubspec_mind.yaml` but never executes
/// it.
///
/// ## Prerequisites (~570 MB)
///
/// First enabled run downloads Multilingual Whisper tiny (`ggml-tiny.bin`)
/// plus the Qwen 0.5B GGUF through [buildMindDownloadService], then reuses
/// them from app support. Host-side seed (optional):
/// `app/tool/fetch_mind_models.sh`.
///
/// Push the whisper.cpp JFK fixture before a fixture-backed run:
///
/// ```bash
/// adb -s <pixel9-id> push rust/fixtures/jfk.wav \
///   /data/local/tmp/airo_mind_jfk.wav
/// ```
///
/// ## How to run (Pixel 9)
///
/// ```bash
/// cp app/pubspec_mind.yaml app/pubspec.yaml
/// cp app/analysis_options_mind.yaml app/analysis_options.yaml
/// cd app && flutter pub get
/// flutter test integration_test/mind_journey_device_test.dart \
///   --dart-define=APP_VARIANT=mind \
///   --dart-define=AIRO_RUN_MIND_JOURNEY=true \
///   -d <pixel9-id>
/// ```
///
/// Restore `app/pubspec.yaml` / `app/analysis_options.yaml` afterwards (they
/// must stay the phone profile by default). Or use
/// `AIRO_MIND_BUILD_MODE=release scripts/build-mind.sh` for an APK install,
/// then the same `flutter test …` command against the device.
///
/// Optional dart-defines:
/// - `AIRO_MIND_WAV_PATH` — device path to a 16 kHz mono WAV (default
///   `/data/local/tmp/airo_mind_jfk.wav`)
/// - `AIRO_MIND_DEVICE_RECORD=true` — short mic capture when no fixture
///
/// See `docs/superpowers/specs/2026-08-06-airo-mind-journey-coverage.md`.
library;

import 'dart:io';

import 'package:airo_app/core/mind/mind_model_sources.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/src/library_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const runJourney = bool.fromEnvironment('AIRO_RUN_MIND_JOURNEY');
  const fixturePath = String.fromEnvironment(
    'AIRO_MIND_WAV_PATH',
    defaultValue: '/data/local/tmp/airo_mind_jfk.wav',
  );
  const allowRecord = bool.fromEnvironment('AIRO_MIND_DEVICE_RECORD');

  final isCi =
      Platform.environment['CI'] == 'true' ||
      Platform.environment['GITHUB_ACTIONS'] == 'true';
  final fixtureExists = File(fixturePath).existsSync();
  final shouldSkip = !runJourney || isCi || (!fixtureExists && !allowRecord);

  if (shouldSkip) {
    final reason = (!runJourney || isCi)
        ? 'Opt-in device journey (#1771): pass '
              '--dart-define=AIRO_RUN_MIND_JOURNEY=true on Pixel 9 with '
              'models; never executed in default CI.'
        : 'Push rust/fixtures/jfk.wav to $fixturePath, or pass '
              '--dart-define=AIRO_MIND_DEVICE_RECORD=true.';
    debugPrint('AIRO_MIND_DEVICE_JOURNEY skip: $reason');
  }

  testWidgets(
    'record → transcribe → minutes → save → search (real engines)',
    (tester) async {
      final service = buildMindDownloadService();
      addTearDown(service.dispose);

      // requiredModels() reads the whisper registry; load the library first.
      await initializeWhisperBridge();

      // ── 1. Models (~570 MB on first run) ─────────────────────────────────
      final missing = await service.missingModels();
      if (missing.isNotEmpty) {
        debugPrint(
          'AIRO_MIND_DEVICE_JOURNEY downloading '
          '${missing.map((m) => m.fileName).join(', ')} '
          '(~${missing.fold<int>(0, (s, m) => s + m.sizeBytes) ~/ (1024 * 1024)} MB)',
        );
        final failed = <String>[];
        await for (final event in service.acquireModels()) {
          switch (event) {
            case ModelAcquisitionProgress(
              :final fileName,
              :final fetched,
              :final total,
            ):
              if (total > 0 && fetched % (16 * 1024 * 1024) < 64 * 1024) {
                debugPrint(
                  'AIRO_MIND_DEVICE_JOURNEY $fileName '
                  '${(100 * fetched / total).toStringAsFixed(0)}%',
                );
              }
            case ModelAcquisitionDone(:final failedFileNames):
              failed.addAll(failedFileNames);
          }
        }
        expect(
          failed,
          isEmpty,
          reason: 'Model download failed: ${failed.join(', ')}',
        );
      }

      // ── 2. Initialize (multilingual whisper default) ─────────────────────
      final status = await service.initialize();
      expect(
        status.isReady,
        isTrue,
        reason:
            'MindService.initialize failed: '
            '${status.unavailable} ${status.detail}',
      );

      // ── 3. Audio: fixture wav, else short record ─────────────────────────
      final wavPath = await _resolveWavPath(
        service: service,
        fixturePath: fixturePath,
        allowRecord: allowRecord,
      );

      // ── 4–6. Transcribe → minutes → save ─────────────────────────────────
      final title = 'MindJourney${DateTime.now().millisecondsSinceEpoch}';
      MindProgress? last;
      final stages = <MindStage>[];
      await for (final progress in service.process(
        wavPath: wavPath,
        title: title,
      )) {
        last = progress;
        if (stages.isEmpty || stages.last != progress.stage) {
          stages.add(progress.stage);
        }
        debugPrint(
          'AIRO_MIND_DEVICE_JOURNEY stage=${progress.stage.name} '
          'transcriptChars=${progress.transcript.length} '
          'minutesChars=${progress.minutes.length}',
        );
      }

      expect(last, isNotNull);
      expect(
        last!.stage,
        MindStage.done,
        reason: last.error ?? 'pipeline ended at ${last.stage}',
      );
      expect(last.meetingId, isNotNull);
      expect(last.transcript.trim(), isNotEmpty);
      expect(last.minutes.trim(), isNotEmpty);
      expect(stages, contains(MindStage.transcribing));
      expect(stages, contains(MindStage.extracting));
      expect(stages, contains(MindStage.generating));
      expect(stages, contains(MindStage.saving));
      expect(stages.last, MindStage.done);

      final meetingId = last.meetingId!;
      final meeting = await service.meeting(meetingId);
      expect(meeting, isNotNull);
      expect(meeting!.transcript.trim(), isNotEmpty);
      expect(meeting.minutes.trim(), isNotEmpty);
      // Lenient IR check: real meetings often yield at least one decision or
      // action item, but short or silent recordings may legitimately produce none.
      final hasIrFacts =
          meeting.decisions.isNotEmpty || meeting.actionItems.isNotEmpty;
      debugPrint(
        'AIRO_MIND_DEVICE_JOURNEY ir decisions=${meeting.decisions.length} '
        'actionItems=${meeting.actionItems.length} metrics=${meeting.metrics.length} '
        'hasIrFacts=$hasIrFacts',
      );
      if (hasIrFacts) {
        expect(
          meeting.decisions.isNotEmpty || meeting.actionItems.isNotEmpty,
          isTrue,
        );
      }

      // ── 7. Search ────────────────────────────────────────────────────────
      final hits = await service.search(title);
      expect(
        hits.any((hit) => hit.meetingId == meetingId),
        isTrue,
        reason: 'search("$title") did not return meeting $meetingId',
      );

      // ── 8. Export markdown (durable evidence; uses #1768 mom.md path) ────
      final bundle = await MeetingExportService(
        service,
      ).exportMeeting(meetingId);
      expect(bundle, isNotNull);
      expect(bundle!.files.containsKey('transcript.md'), isTrue);
      expect(bundle.files['transcript.md']!.trim(), isNotEmpty);
      expect(bundle.files.containsKey('mom.md'), isTrue);
      expect(bundle.files['mom.md']!.trim(), isNotEmpty);

      debugPrint(
        'AIRO_MIND_DEVICE_JOURNEY ok meetingId=$meetingId '
        'folder=${bundle.folderName} '
        'files=${bundle.files.keys.join(',')}',
      );
    },
    skip: shouldSkip,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<String> _resolveWavPath({
  required MindService service,
  required String fixturePath,
  required bool allowRecord,
}) async {
  final fixture = File(fixturePath);
  if (fixture.existsSync()) {
    final dir = await service.modelsDirectory();
    final dest = File(
      p.join(
        dir.path,
        'journey-fixture-${DateTime.now().millisecondsSinceEpoch}.wav',
      ),
    );
    await fixture.copy(dest.path);
    return dest.path;
  }

  expect(
    allowRecord,
    isTrue,
    reason: 'No fixture at $fixturePath and AIRO_MIND_DEVICE_RECORD is false.',
  );
  expect(
    await service.hasMicrophonePermission(),
    isTrue,
    reason: 'Microphone permission required for record fallback.',
  );

  await service.startRecording();
  await Future<void>.delayed(const Duration(seconds: 3));
  final path = await service.stopRecording();
  expect(path, isNotNull);
  expect(File(path!).existsSync(), isTrue);
  return path;
}
