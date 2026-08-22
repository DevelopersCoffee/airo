import 'dart:io';

import 'package:feature_mind/src/assistant/consent/mind_runtime_provider.dart';
import 'package:feature_mind/src/assistant/consent/recording_consent_prompt.dart';
import 'package:feature_mind/src/capture/application/meeting_capture_providers.dart';
import 'package:feature_mind/src/capture/data/meeting_recording_service_gateway.dart';
import 'package:feature_mind/src/capture/presentation/meeting_capture_screen.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/runtime/scribe_mind_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_audio_recorder_port.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool showConsentPrompt = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    // Tall surface so consent + trust strip + controls fit without scrolling
    // (the trust strip (#1774) pushed the start button off a default phone
    // viewport and broke key lookups).
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mindRuntimeProvider.overrideWith(
            (ref) => ScribeMindRuntime(log: _MemoryLog()),
          ),
          recordingConsentPromptProvider.overrideWithValue(showConsentPrompt),
        ],
        child: const MaterialApp(home: MeetingCaptureScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hides the consent picker and enables Start when the prompt is off',
    (tester) async {
      await pumpScreen(tester, showConsentPrompt: false);

      expect(
        find.byKey(const Key('meeting_capture_consent_reminder_copy')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
        findsNothing,
      );
      final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_start_button')),
      );
      expect(startButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'shows the explicit consent-reminder copy before anything else (AC6)',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('meeting_capture_consent_reminder_copy')),
        findsOneWidget,
      );
      expect(find.textContaining('checking it is on you'), findsOneWidget);
    },
  );

  testWidgets(
    'shows Multilingual · auto-detect badge and offline copy by default (#1774)',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('scribe_trust_signals')), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_language_badge')),
        findsOneWidget,
      );
      expect(find.text('Multilingual · auto-detect'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_offline_copy')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sharing is always an explicit'),
        findsOneWidget,
      );
    },
  );

  testWidgets('start recording is disabled until consent is confirmed', (
    tester,
  ) async {
    await pumpScreen(tester);

    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('meeting_capture_start_button')),
    );
    expect(startButton.onPressed, isNull);
    final confirmButton = tester.widget<FilledButton>(
      find.byKey(const Key('meeting_capture_confirm_consent_button')),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets(
    'a two-party jurisdiction blocks confirm until the notify-everyone box is checked',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
      );
      await tester.pumpAndSettle();
      // California is a two-party consent jurisdiction.
      await tester.tap(find.text('United States — California').last);
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('meeting_capture_all_parties_checkbox')),
      );
      await tester.pumpAndSettle();

      final confirmAfterAck = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmAfterAck.onPressed, isNotNull);
    },
  );

  testWidgets('confirming consent unlocks the start-recording button', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('United States — California').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('meeting_capture_all_parties_checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('meeting_capture_confirm_consent_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('meeting_capture_consent_granted')),
      findsOneWidget,
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('meeting_capture_start_button')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets(
    'a one-party jurisdiction confirms without the notify-everyone box',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
      );
      await tester.pumpAndSettle();
      // United Kingdom is a one-party consent jurisdiction -- no checkbox
      // should even appear. It's low in a long dropdown list, so scroll it
      // into view first (the menu is a lazily-built ListView, so it isn't in
      // the tree at all until scrolled close enough to build).
      await tester.scrollUntilVisible(
        find.text('United Kingdom'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('United Kingdom'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('meeting_capture_all_parties_checkbox')),
        findsNothing,
      );
      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmButton.onPressed, isNotNull);
    },
  );

  testWidgets('confirming consent then start talks to the encoder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('meeting_capture_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    final recorder = FakeAudioRecorderPort();
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mindRuntimeProvider.overrideWith(
            (ref) => ScribeMindRuntime(log: _MemoryLog()),
          ),
          recordingConsentPromptProvider.overrideWithValue(true),
          audioRecorderPortProvider.overrideWith(
            (ref) =>
                () => recorder,
          ),
          meetingRecordingPathProvider.overrideWith(
            (ref) =>
                () async => '${tempDir.path}/meeting.m4a',
          ),
          meetingRecordingServiceGatewayProvider.overrideWith(
            (ref) => const NoopMeetingRecordingServiceGateway(),
          ),
        ],
        child: const MaterialApp(home: MeetingCaptureScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('United Kingdom'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('United Kingdom'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('meeting_capture_confirm_consent_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meeting_capture_start_button')));
    // The capture ticker is periodic — pumpAndSettle never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      recorder.calls.where((call) => call.startsWith('start:')),
      isNotEmpty,
    );
    expect(find.byKey(const Key('meeting_capture_visualizer')), findsOneWidget);
    expect(
      find.byKey(const Key('meeting_capture_pause_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('meeting_capture_stop_button')),
      findsOneWidget,
    );
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

class _MemoryLog implements OperationLogPort {
  var _seq = 0;

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => ++_seq;

  @override
  Future<int> count() async => _seq;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      const [];

  @override
  Future<MindOp?> bySequence(int sequence) async => null;

  @override
  Future<SignatureState> verify(int sequence) async => SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) => const Stream.empty();
}
