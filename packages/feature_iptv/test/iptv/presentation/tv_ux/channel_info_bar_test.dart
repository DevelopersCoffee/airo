import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_info_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.test/stream.m3u8',
  );

  testWidgets(
    'favorite action persists and reflects the active channel state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ChannelInfoBar(channel: channel)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Favorite'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Favorite'));
      await tester.pumpAndSettle();

      expect(preferences.getStringList('iptv_favorite_channel_ids'), [
        'channel-1',
      ]);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(preferences.getStringList('iptv_favorite_channel_ids'), isEmpty);
      expect(find.byTooltip('Favorite'), findsOneWidget);
    },
  );

  testWidgets('favorite action is disabled until a channel is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ChannelInfoBar())),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'share copies channel details and no placeholder actions remain',
    (tester) async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      String? clipboardText;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = Map<String, Object?>.from(call.arguments as Map);
            clipboardText = data['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const MaterialApp(
            home: Scaffold(body: ChannelInfoBar(channel: channel)),
          ),
        ),
      );

      expect(find.byTooltip('Like'), findsNothing);
      expect(find.byTooltip('Ways to watch'), findsNothing);
      expect(find.byTooltip('Share'), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pump();

      expect(
        clipboardText,
        'Example Channel\nhttps://example.test/stream.m3u8',
      );
      expect(find.text('Example Channel copied to clipboard'), findsOneWidget);
    },
  );
}
