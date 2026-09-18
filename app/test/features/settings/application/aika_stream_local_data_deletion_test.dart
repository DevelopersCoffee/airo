import 'package:airo_app/features/settings/application/aika_stream_local_data_deletion.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test-supplied fixture only. Not a production or Play Store preset.
/// The live catalog is ~2.5 MB; this test stores the URL and does not fetch it.
const _testPlaylistUrl = 'https://iptv-org.github.io/iptv/index.m3u';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'deleteAikaStreamLocalData removes iptv-org fixture sources and preference keys',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          xtreamAuthenticatorProvider.overrideWithValue(
            ({
              required String serverUrl,
              required String username,
              required String password,
            }) async => const XtreamAuthResult(
              isAuthenticated: true,
              status: 'Active',
              maxConnections: 2,
            ),
          ),
          stalkerAuthenticatorProvider.overrideWithValue(
            ({required String portalUrl, required String macAddress}) async {},
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(
        addM3uContentSourceProvider((
          label: 'iptv-org index',
          url: _testPlaylistUrl,
        )).future,
      );
      await prefs.setString('iptv_favorite_channel_ids', '["news"]');

      final sourcesBefore = await container
          .read(contentSourceStoreProvider)
          .getAll();
      expect(sourcesBefore, hasLength(1));
      expect(sourcesBefore.single.url, _testPlaylistUrl);

      await container.read(aikaStreamLocalDataDeleterProvider)();

      expect(
        await container.read(contentSourceStoreProvider).getAll(),
        isEmpty,
      );
      expect(prefs.getString('iptv_favorite_channel_ids'), isNull);
    },
  );
}
