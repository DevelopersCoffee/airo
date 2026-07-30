import 'package:airo_app/core/services/voice_search_service.dart';
import 'package:airo_app/features/mind/presentation/screens/audio_scribe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVoiceService implements VoiceSearchService {
  @override
  VoiceSearchState state = VoiceSearchState.idle;

  @override
  Stream<VoiceSearchState> get stateStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VoiceSearchResult> startListening() async =>
      VoiceSearchResult.success('A test transcript.');

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}

void main() {
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
}
