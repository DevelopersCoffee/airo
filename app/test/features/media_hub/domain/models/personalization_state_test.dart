import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';

void main() {
  group('PersonalizationState', () {
    // Test fixtures
    UnifiedMediaContent createTestContent(String id) {
      return UnifiedMediaContent(
        id: id,
        title: 'Test Content $id',
        type: MediaMode.music,
      );
    }

    group('constructor', () {
      test('creates empty state by default', () {
        const state = PersonalizationState();

        expect(state.continueWatching, isEmpty);
        expect(state.recentlyPlayed, isEmpty);
        expect(state.favoriteIds, isEmpty);
        expect(state.playbackPositions, isEmpty);
      });

      test('creates state with provided values', () {
        final content = createTestContent('1');
        final state = PersonalizationState(
          continueWatching: [content],
          recentlyPlayed: [content],
          favoriteIds: {'1', '2'},
          playbackPositions: {'1': const Duration(seconds: 30)},
        );

        expect(state.continueWatching.length, 1);
        expect(state.recentlyPlayed.length, 1);
        expect(state.favoriteIds.length, 2);
        expect(state.playbackPositions.length, 1);
      });
    });

    group('isFavorite', () {
      test('returns true for favorited content', () {
        final state = PersonalizationState(favoriteIds: {'content-1'});
        expect(state.isFavorite('content-1'), isTrue);
      });

      test('returns false for non-favorited content', () {
        final state = PersonalizationState(favoriteIds: {'content-1'});
        expect(state.isFavorite('content-2'), isFalse);
      });
    });

    group('getLastPosition', () {
      test('returns position for tracked content', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(minutes: 5)},
        );
        expect(state.getLastPosition('content-1'), const Duration(minutes: 5));
      });

      test('returns null for untracked content', () {
        const state = PersonalizationState();
        expect(state.getLastPosition('content-1'), isNull);
      });
    });

    group('canResume', () {
      test('returns true when position > 10 seconds', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(seconds: 11)},
        );
        expect(state.canResume('content-1'), isTrue);
      });

      test('returns false when position <= 10 seconds', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(seconds: 10)},
        );
        expect(state.canResume('content-1'), isFalse);
      });

      test('returns false when no position exists', () {
        const state = PersonalizationState();
        expect(state.canResume('content-1'), isFalse);
      });
    });

    group('getProgress', () {
      test('returns correct progress ratio', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(seconds: 30)},
        );
        final progress = state.getProgress(
          'content-1',
          const Duration(minutes: 1),
        );
        expect(progress, 0.5);
      });

      test('returns 0 when no position exists', () {
        const state = PersonalizationState();
        expect(state.getProgress('content-1', const Duration(minutes: 1)), 0.0);
      });

      test('returns 0 when total duration is null', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(seconds: 30)},
        );
        expect(state.getProgress('content-1', null), 0.0);
      });

      test('returns 0 when total duration is zero', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(seconds: 30)},
        );
        expect(state.getProgress('content-1', Duration.zero), 0.0);
      });

      test('clamps progress to 1.0 maximum', () {
        final state = PersonalizationState(
          playbackPositions: {'content-1': const Duration(minutes: 2)},
        );
        expect(state.getProgress('content-1', const Duration(minutes: 1)), 1.0);
      });
    });

    group('getters', () {
      test('favoritesCount returns correct count', () {
        final state = PersonalizationState(favoriteIds: {'1', '2', '3'});
        expect(state.favoritesCount, 3);
      });

      test('continueWatchingCount returns correct count', () {
        final state = PersonalizationState(
          continueWatching: [createTestContent('1'), createTestContent('2')],
        );
        expect(state.continueWatchingCount, 2);
      });
    });

    group('copyWith', () {
      test('copies with new continueWatching', () {
        const original = PersonalizationState();
        final updated = original.copyWith(
          continueWatching: [createTestContent('1')],
        );

        expect(original.continueWatching, isEmpty);
        expect(updated.continueWatching.length, 1);
      });

      test('preserves other fields when not specified', () {
        final original = PersonalizationState(
          favoriteIds: {'1'},
          playbackPositions: {'1': const Duration(seconds: 30)},
        );
        final updated = original.copyWith(
          continueWatching: [createTestContent('2')],
        );

        expect(updated.favoriteIds, {'1'});
        expect(updated.playbackPositions['1'], const Duration(seconds: 30));
      });
    });

    group('JSON serialization', () {
      test('toJson serializes favoriteIds correctly', () {
        final state = PersonalizationState(favoriteIds: {'id-1', 'id-2'});
        final json = state.toJson();

        expect(json['favoriteIds'], isA<List>());
        expect((json['favoriteIds'] as List).length, 2);
        expect((json['favoriteIds'] as List), containsAll(['id-1', 'id-2']));
      });

      test('toJson serializes playbackPositions correctly', () {
        final state = PersonalizationState(
          playbackPositions: {
            'id-1': const Duration(seconds: 30),
            'id-2': const Duration(minutes: 5),
          },
        );
        final json = state.toJson();

        expect(json['playbackPositions'], isA<Map>());
        expect(json['playbackPositions']['id-1'], 30000); // milliseconds
        expect(json['playbackPositions']['id-2'], 300000); // milliseconds
      });

      test('fromJson deserializes favoriteIds correctly', () {
        final json = {
          'favoriteIds': ['id-1', 'id-2'],
          'playbackPositions': <String, dynamic>{},
        };
        final state = PersonalizationState.fromJson(json);

        expect(state.favoriteIds, {'id-1', 'id-2'});
      });

      test('fromJson deserializes playbackPositions correctly', () {
        final json = {
          'favoriteIds': <String>[],
          'playbackPositions': {'id-1': 30000, 'id-2': 300000},
        };
        final state = PersonalizationState.fromJson(json);

        expect(state.playbackPositions['id-1'], const Duration(seconds: 30));
        expect(state.playbackPositions['id-2'], const Duration(minutes: 5));
      });

      test('fromJson handles null/missing fields gracefully', () {
        final json = <String, dynamic>{};
        final state = PersonalizationState.fromJson(json);

        expect(state.favoriteIds, isEmpty);
        expect(state.playbackPositions, isEmpty);
      });

      test('roundtrip serialization preserves data', () {
        final original = PersonalizationState(
          favoriteIds: {'id-1', 'id-2'},
          playbackPositions: {
            'id-1': const Duration(seconds: 30),
            'id-2': const Duration(minutes: 5),
          },
        );
        final json = original.toJson();
        final restored = PersonalizationState.fromJson(json);

        expect(restored.favoriteIds, original.favoriteIds);
        expect(restored.playbackPositions, original.playbackPositions);
      });
    });

    group('equality', () {
      test('equal states have same props', () {
        final state1 = PersonalizationState(
          favoriteIds: {'1'},
          playbackPositions: {'1': const Duration(seconds: 30)},
        );
        final state2 = PersonalizationState(
          favoriteIds: {'1'},
          playbackPositions: {'1': const Duration(seconds: 30)},
        );

        expect(state1, equals(state2));
      });

      test('different states have different props', () {
        final state1 = PersonalizationState(favoriteIds: {'1'});
        final state2 = PersonalizationState(favoriteIds: {'2'});

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
