import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/screens/mobile_favorites_screen.dart';
import 'package:feature_iptv/presentation/tv/iptv_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Found on the rig Pixel 9: with every playlist source unreachable the guide
/// and favorites surfaces printed the failure but offered no way to act on it,
/// so a user had to leave the tab and come back. The channel screen has had a
/// Retry since the failure started surfacing; these two now match it, and the
/// Retry has to reach the source loaders rather than replay a cached error.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWithDeadSource({
    required void Function() onFetch,
    Set<String> favoriteIds = const {},
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        favoriteChannelIdsProvider.overrideWith((ref) async => favoriteIds),
        m3uSourceParserFactoryProvider.overrideWithValue(
          (sourceId) => _DeadSourceParser(
            prefs: prefs,
            sourceId: sourceId,
            onFetch: onFetch,
          ),
        ),
      ],
    );
  }

  Future<void> seedDeadSource(ProviderContainer container) async {
    await container.read(contentSourceStoreProvider).replaceAll([
      const ContentSourceConfig(
        id: 'm3u-dead',
        kind: ContentSourceKind.m3u,
        label: 'Dead',
        url: 'https://example.com/dead.m3u',
      ),
    ]);
    container.invalidate(configuredContentSourcesProvider);
  }

  testWidgets('the guide offers a Retry that re-runs the source loaders', (
    tester,
  ) async {
    var fetchAttempts = 0;
    final container = containerWithDeadSource(onFetch: () => fetchAttempts++);
    addTearDown(container.dispose);
    await seedDeadSource(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: IptvGuideScreen(onChannelSelected: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load the guide'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('channel-load-error-retry')),
      findsOneWidget,
    );
    expect(fetchAttempts, 1);

    await tester.tap(find.byKey(const ValueKey('channel-load-error-retry')));
    await tester.pumpAndSettle();

    expect(
      fetchAttempts,
      2,
      reason: 'Retry must contact the source again, not replay its error',
    );
  });

  testWidgets('favorites offers a Retry that re-runs the source loaders', (
    tester,
  ) async {
    var fetchAttempts = 0;
    final container = containerWithDeadSource(
      onFetch: () => fetchAttempts++,
      // A user with no favorites never reaches the channel list, so the error
      // state needs a stored favorite to be reachable at all.
      favoriteIds: const {'kept'},
    );
    addTearDown(container.dispose);
    await seedDeadSource(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MobileFavoritesScreen(onChannelSelected: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load favorites'), findsOneWidget);
    expect(fetchAttempts, 1);

    await tester.tap(find.byKey(const ValueKey('channel-load-error-retry')));
    await tester.pumpAndSettle();

    expect(fetchAttempts, 2);
  });
}

void _noop() {}

class _DeadSourceParser extends M3UParserService {
  _DeadSourceParser({
    required super.prefs,
    required String sourceId,
    required this.onFetch,
  }) : super(dio: Dio(), sourceId: sourceId);

  final void Function() onFetch;
  String? _url;

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async {
    onFetch();
    return const PlaylistFetchOutcome.unavailable();
  }
}
