import 'dart:async';

import 'package:airo_app/core/services/voice_search_service.dart';
import 'package:airo_app/features/mind/presentation/screens/audio_scribe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeVoiceService implements VoiceSearchService {
  _FakeVoiceService({
    List<VoiceSearchResult>? results,
    this.availabilityError,
    this.pendingResult,
  }) : _results = List<VoiceSearchResult>.from(
         results ??
             <VoiceSearchResult>[
               VoiceSearchResult.success('A test transcript.'),
             ],
       );

  final List<VoiceSearchResult> _results;
  final Object? availabilityError;
  final Completer<VoiceSearchResult>? pendingResult;
  var stopCount = 0;

  @override
  VoiceSearchState state = VoiceSearchState.idle;

  @override
  Stream<VoiceSearchState> get stateStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async {
    final error = availabilityError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<VoiceSearchResult> startListening() async {
    final pending = pendingResult;
    if (pending != null) return pending.future;
    return _results.removeAt(0);
  }

  @override
  Future<void> stopListening() async {
    stopCount += 1;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures speech and exposes translation handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceSearchServiceProvider.overrideWithValue(_FakeVoiceService()),
        ],
        child: const MaterialApp(home: AudioScribeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audio Scribe'), findsOneWidget);
    expect(
      find.text('Speech recognition is ready on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pumpAndSettle();

    expect(find.text('A test transcript.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Translate with Airo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Translate with Airo'), findsOneWidget);
  });

  testWidgets('appends follow-up captures and reports speech errors', (
    tester,
  ) async {
    final service = _FakeVoiceService(
      results: <VoiceSearchResult>[
        VoiceSearchResult.success('First note.'),
        VoiceSearchResult.success('Second note.'),
        VoiceSearchResult.error('Microphone permission denied.'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceSearchServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: AudioScribeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'First note.\n\nSecond note.');
    expect(find.text('Microphone permission denied.'), findsOneWidget);
  });

  testWidgets('stop capture cancels the active voice request', (tester) async {
    final pending = Completer<VoiceSearchResult>();
    final service = _FakeVoiceService(pendingResult: pending);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceSearchServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: AudioScribeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pump();
    expect(find.text('Stop capture'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audio_scribe_capture_button')));
    await tester.pump();

    expect(service.stopCount, 1);
    expect(find.text('Start capture'), findsOneWidget);
    pending.complete(VoiceSearchResult.empty());
    await tester.pumpAndSettle();
  });

  testWidgets('translation and model management use typed Mind routes', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AudioScribeScreen(),
        ),
        GoRoute(
          path: '/mind/chat',
          builder: (context, state) => Text(
            state.uri.queryParameters['prefill'] ?? '',
            key: const Key('prefill_text'),
          ),
        ),
        GoRoute(
          path: '/mind/models',
          builder: (context, state) => const Text('Models route'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceSearchServiceProvider.overrideWithValue(_FakeVoiceService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bonjour Airo');
    await tester.pump();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Translate with Airo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Translate with Airo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prefill_text')), findsOneWidget);
    expect(
      find.textContaining('Translate the following transcript into French'),
      findsOneWidget,
    );
    expect(find.textContaining('Bonjour Airo'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Manage local models'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Manage local models'));
    await tester.pumpAndSettle();

    expect(find.text('Models route'), findsOneWidget);
  });

  testWidgets('availability failures show the unavailable banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceSearchServiceProvider.overrideWithValue(
            _FakeVoiceService(availabilityError: StateError('no recognizer')),
          ),
        ],
        child: const MaterialApp(home: AudioScribeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Speech recognition is unavailable. Install or enable a speech service to capture audio.',
      ),
      findsOneWidget,
    );
  });
}
