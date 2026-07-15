import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:airo_app/features/media_hub/application/providers/personalization_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/personalization_state.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const track = UnifiedMediaContent(
    id: 'track-1',
    mode: MediaMode.music,
    category: MediaCategory.music,
    title: 'Track',
    subtitle: 'Artist',
    imageUrl: null,
    streamUrl: 'https://example.com/audio.mp3',
    duration: Duration(minutes: 3),
  );

  test(
    'loads personalization state from shared preferences on startup',
    () async {
      SharedPreferences.setMockInitialValues({
        mediaHubPersonalizationStorageKey: const PersonalizationState(
          favorites: [track],
        ).toStorageValue(),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final state = await container.read(personalizationProvider.future);

      expect(state.favorites, [track]);
    },
  );

  test('toggleFavorite persists favorite state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(personalizationProvider.notifier);
    await notifier.toggleFavorite(track);
    final updated = container.read(personalizationProvider).value!;

    expect(updated.favorites, [track]);
    expect(prefs.getString(mediaHubPersonalizationStorageKey), isNotNull);
  });

  test('rejects oversized personalization JSON before persisting', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaHubPersonalizationStoreProvider.overrideWithValue(
          PreferencesStore(prefs, maxValueBytes: 64),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(personalizationProvider.notifier);
    final oversized = track.copyWith(title: 'Track ${'x' * 128}');

    await expectLater(
      notifier.toggleFavorite(oversized),
      throwsA(isA<KeyValueStoreValueTooLargeException>()),
    );

    expect(prefs.getString(mediaHubPersonalizationStorageKey), isNull);
    final state = await container.read(personalizationProvider.future);
    expect(state.favorites, isEmpty);
  });

  test('updateProgress tracks recents and continue watching', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(personalizationProvider.notifier);
    await notifier.updateProgress(track, const Duration(minutes: 1));
    final updated = container.read(personalizationProvider).value!;

    expect(updated.recentlyPlayed, hasLength(1));
    expect(updated.continueWatching, hasLength(1));
    expect(updated.continueWatching.first.canResume, isTrue);
    expect(
      updated.continueWatching.first.lastPosition,
      const Duration(minutes: 1),
    );
  });
}
