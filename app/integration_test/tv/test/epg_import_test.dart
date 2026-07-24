import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv/iptv_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/playlist_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'EPG import populates the TV guide and refreshes after a clock shift',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = MutableXmltvCompactEpgRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          compactEpgRepositoryProvider.overrideWithValue(repository),
          mutableXmltvCompactEpgRepositoryProvider.overrideWithValue(
            repository,
          ),
          iptvChannelsProvider.overrideWith(
            (ref) async => const [
              IPTVChannel(
                id: VevoPopFixture.tvgId,
                name: VevoPopFixture.displayName,
                streamUrl: VevoPopFixture.streamUrl,
                group: VevoPopFixture.groupTitle,
                category: ChannelCategory.music,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(PlaylistFixtureWriter.cleanup);

      final initialNow = DateTime.utc(2026, 7, 23, 12, 15);
      container
          .read(guidePagedWindowProvider.notifier)
          .debugSetNow(() => initialNow);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(1280, 720),
                navigationMode: NavigationMode.directional,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 1280,
                  height: 720,
                  child: IptvGuideScreen(
                    onChannelSelected: _noop,
                    overrideFormFactor: AiroFormFactor.tv,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(IptvGuideScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('epg_jump_to_present')), findsOneWidget);
      expect(
        find.textContaining('No guide data available yet'),
        findsOneWidget,
      );
      expect(find.text('Pop Essentials'), findsNothing);

      final epgPath = await PlaylistFixtureWriter.writeEpgFixture(
        now: initialNow,
      );
      final parsedRepository =
          await XmltvCompactEpgRepository.fromXmltvFileNative(
            path: epgPath,
            ingestedAt: initialNow,
            channelNamesById: const {
              VevoPopFixture.tvgId: VevoPopFixture.displayName,
            },
          );
      repository.updateSource(parsedRepository);

      container.invalidate(guidePagedWindowProvider);
      container
          .read(guidePagedWindowProvider.notifier)
          .debugSetNow(() => initialNow);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('No guide data available yet'), findsNothing);
      expect(find.text(VevoPopFixture.displayName), findsOneWidget);
      expect(find.text('Pop Essentials'), findsOneWidget);
      expect(find.text('Artist Spotlight'), findsOneWidget);

      final shiftedNow = initialNow.add(const Duration(hours: 2));
      container.invalidate(guidePagedWindowProvider);
      container
          .read(guidePagedWindowProvider.notifier)
          .debugSetNow(() => shiftedNow);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Pop Essentials'), findsNothing);
      expect(find.text('Artist Spotlight'), findsOneWidget);
      expect(find.text('Late Night Vibes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    tags: <String>{'tv_integration'},
  );
}

void _noop() {}
