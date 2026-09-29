import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/music/domain/services/beats_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeatsAudioHandler Android Auto & Sync Tests', () {
    late BeatsAudioHandler handler;

    setUp(() {
      handler = BeatsAudioHandler();
    });

    tearDown(() async {
      await handler.dispose();
    });

    test('getChildren returns root navigation categories', () async {
      final rootItems = await handler.getChildren('root');
      expect(rootItems.length, 3);
      expect(rootItems[0].id, 'favorites');
      expect(rootItems[1].id, 'recents');
      expect(rootItems[2].id, 'all_tracks');
    });

    test('setFavorites updates favorites node and optimizes artwork', () async {
      final testItem = MediaItem(
        id: 'fav-1',
        title: 'Jazz Stream',
        artist: 'Station 1',
        artUri: Uri.parse('https://example.com/logo.png'),
      );

      handler.setFavorites([testItem]);

      final favorites = await handler.getChildren('favorites');
      expect(favorites.length, 1);
      expect(favorites.first.id, 'fav-1');
      expect(favorites.first.artUri?.queryParameters['w'], '320');
      expect(favorites.first.extras?['android.media.browse.CONTENT_STYLE_BROWSABLE_HINT'], 2);
    });

    test('addRecent inserts item and caps list at 10', () async {
      for (var i = 0; i < 15; i++) {
        handler.addRecent(
          MediaItem(
            id: 'recent-$i',
            title: 'Station $i',
          ),
        );
      }

      final recents = await handler.getChildren('recents');
      expect(recents.length, 10);
      expect(recents.first.id, 'recent-14'); // Most recent first
    });

    test('playFromSearch handles unmatched queries gracefully', () async {
      await handler.playFromSearch('NonExistentStation');

      final state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.error);
      expect(state.errorMessage, contains('No stream matching'));
    });
  });
}
