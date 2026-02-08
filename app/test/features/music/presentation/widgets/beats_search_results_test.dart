import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/music/presentation/widgets/beats_search_results.dart';
import 'package:airo_app/features/music/application/providers/beats_provider.dart';
import 'package:airo_app/features/music/application/providers/music_provider.dart';
import 'package:airo_app/features/music/domain/models/beats_models.dart';
import 'package:airo_app/features/music/data/repositories/mock_beats_repository.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';

// Mock MusicService for testing
class MockMusicService implements MusicService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> playTrack(MusicTrack track) async {}

  @override
  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<MusicPlayerState> getStateStream() async* {
    yield const MusicPlayerState(
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      currentTrack: null,
      queue: [],
      currentIndex: 0,
    );
  }
}

// Mock MusicController for testing
class MockMusicController extends MusicController {
  MockMusicController() : super(MockMusicService());
}

void main() {
  Widget createTestWidget({BeatsSearchUiState? initialState}) {
    return ProviderScope(
      overrides: [
        beatsRepositoryProvider.overrideWithValue(MockBeatsRepository()),
        if (initialState != null)
          beatsSearchStateProvider.overrideWith(
            (ref) =>
                BeatsSearchNotifier(MockBeatsRepository())
                  ..setStateForTest(initialState),
          ),
        musicControllerProvider.overrideWithValue(MockMusicController()),
      ],
      child: const MaterialApp(home: Scaffold(body: BeatsSearchResults())),
    );
  }

  group('BeatsSearchResults', () {
    testWidgets('shows nothing when idle', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show SizedBox.shrink() which has no visible content
      expect(find.byType(BeatsSearchResults), findsOneWidget);
    });

    testWidgets('shows loading indicator when searching', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const BeatsSearchUiState(
            state: BeatsSearchState.searching,
            query: 'test',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on error state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const BeatsSearchUiState(
            state: BeatsSearchState.error,
            query: 'test',
            errorMessage: 'Something went wrong',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows results when search succeeds', (tester) async {
      const testTrack = BeatsTrack(
        id: 'test_1',
        title: 'Test Track',
        artist: 'Test Artist',
        duration: Duration(minutes: 3),
        source: BeatsSource.youtube,
      );

      await tester.pumpWidget(
        createTestWidget(
          initialState: const BeatsSearchUiState(
            state: BeatsSearchState.success,
            query: 'test',
            results: [testTrack],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Track'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    });
  });
}

// Extension to allow setting state for testing
extension BeatsSearchNotifierTestExtension on BeatsSearchNotifier {
  void setStateForTest(BeatsSearchUiState newState) {
    state = newState;
  }
}
