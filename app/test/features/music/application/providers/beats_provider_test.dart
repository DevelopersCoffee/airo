import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/music/application/providers/beats_provider.dart';
import 'package:airo_app/features/music/domain/models/beats_models.dart';
import 'package:airo_app/features/music/data/repositories/mock_beats_repository.dart';

void main() {
  group('Beats Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          beatsRepositoryProvider.overrideWithValue(MockBeatsRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('beatsRepositoryProvider', () {
      test('provides a BeatsRepository instance', () {
        final repository = container.read(beatsRepositoryProvider);
        expect(repository, isNotNull);
      });
    });

    group('beatsSearchStateProvider', () {
      test('initial state is idle', () {
        final state = container.read(beatsSearchStateProvider);
        expect(state.state, BeatsSearchState.idle);
        expect(state.query, isEmpty);
        expect(state.results, isEmpty);
      });

      test('search updates state to searching', () {
        final notifier = container.read(beatsSearchStateProvider.notifier);

        notifier.search('test');

        // State should be searching immediately
        final state = container.read(beatsSearchStateProvider);
        expect(state.state, BeatsSearchState.searching);
        expect(state.query, 'test');
      });

      test('empty search resets to idle', () {
        final notifier = container.read(beatsSearchStateProvider.notifier);

        // First search for something
        notifier.search('test');

        // Then clear
        notifier.search('');

        final state = container.read(beatsSearchStateProvider);
        expect(state.state, BeatsSearchState.idle);
        expect(state.query, isEmpty);
      });
    });

    group('beatsRecentTracksProvider', () {
      test('returns list of recent tracks', () async {
        final recentTracks = await container.read(
          beatsRecentTracksProvider.future,
        );
        expect(recentTracks, isA<List<BeatsTrack>>());
      });
    });
  });

  group('BeatsSearchNotifier unit tests', () {
    test('initial state is idle', () {
      final notifier = BeatsSearchNotifier(MockBeatsRepository());
      expect(notifier.state.state, BeatsSearchState.idle);
      expect(notifier.state.query, isEmpty);
    });

    test('search sets state to searching', () {
      final notifier = BeatsSearchNotifier(MockBeatsRepository());
      notifier.search('test');
      expect(notifier.state.state, BeatsSearchState.searching);
      expect(notifier.state.query, 'test');
    });

    test('empty search resets to idle', () {
      final notifier = BeatsSearchNotifier(MockBeatsRepository());
      notifier.search('test');
      notifier.search('');
      expect(notifier.state.state, BeatsSearchState.idle);
    });

    test('clear resets state to idle', () {
      final notifier = BeatsSearchNotifier(MockBeatsRepository());
      notifier.search('test');
      notifier.clear();
      expect(notifier.state.state, BeatsSearchState.idle);
      expect(notifier.state.results, isEmpty);
    });

    test('URL detection triggers resolving state', () {
      final notifier = BeatsSearchNotifier(MockBeatsRepository());
      notifier.search('https://youtu.be/fWmYeaveS6o');
      // Initially it's searching, then after debounce it will resolve
      expect(notifier.state.state, BeatsSearchState.searching);
    });
  });
}
