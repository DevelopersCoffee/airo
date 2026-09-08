import 'package:feature_iptv/application/providers/cast_multiview_layouts_provider.dart';
import 'package:feature_iptv/application/providers/cast_multiview_sender_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/screens/cast_multiview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final channels = [
    const IPTVChannel(
      id: 'aajtak-hd',
      name: 'Aaj Tak HD',
      streamUrl: 'https://example.com/aajtak.m3u8',
      group: 'News',
    ),
    const IPTVChannel(
      id: 'yrf-music',
      name: 'YRF Music',
      streamUrl: 'https://example.com/yrf.m3u8',
      group: 'Music',
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required MultiviewCastSenderTransport transport,
    List<Override> extraOverrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          multiviewCastSenderTransportProvider.overrideWithValue(transport),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: CastMultiviewScreen()),
      ),
    );
  }

  testWidgets('shows not-connected with the unavailable transport', (
    tester,
  ) async {
    await pump(
      tester,
      transport: const UnavailableMultiviewCastSenderTransport(),
    );
    await tester.pump();

    expect(find.textContaining('Not connected'), findsOneWidget);
    expect(find.text('Nothing on screen yet.'), findsOneWidget);
  });

  testWidgets('shows the live grid once the receiver publishes state', (
    tester,
  ) async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);
    await pump(tester, transport: link.sender);
    await tester.pump();

    await link.receiver.publishState(
      const MultiviewCastState(
        capacity: 2,
        slots: [
          MultiviewCastSlot(
            slotId: 'aajtak-hd',
            channelId: 'aajtak-hd',
            channelName: 'Aaj Tak HD',
            featured: true,
          ),
          MultiviewCastSlot(
            slotId: 'yrf-music',
            channelId: 'yrf-music',
            channelName: 'YRF Music',
            featured: false,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('TV Connected'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cast-multiview-live-slot-aajtak-hd')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cast-multiview-live-slot-yrf-music')),
      findsOneWidget,
    );
  });

  testWidgets('tapping remove on a live slot sends a remove_slot command', (
    tester,
  ) async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);
    final receivedCommands = <MultiviewCastCommand>[];
    link.receiver.commands.listen(receivedCommands.add);

    await pump(tester, transport: link.sender);
    await tester.pump();
    await link.receiver.publishState(
      const MultiviewCastState(
        capacity: 2,
        slots: [
          MultiviewCastSlot(
            slotId: 'aajtak-hd',
            channelId: 'aajtak-hd',
            channelName: 'Aaj Tak HD',
            featured: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Remove from grid'));
    await tester.pump();

    expect(receivedCommands, [
      const MultiviewRemoveSlotCommand(slotId: 'aajtak-hd'),
    ]);
  });

  testWidgets('tapping focus on a muted live tile sends a promote command', (
    tester,
  ) async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);
    final receivedCommands = <MultiviewCastCommand>[];
    link.receiver.commands.listen(receivedCommands.add);

    await pump(tester, transport: link.sender);
    await tester.pump();
    await link.receiver.publishState(
      const MultiviewCastState(
        capacity: 2,
        slots: [
          MultiviewCastSlot(
            slotId: 'aajtak-hd',
            channelId: 'aajtak-hd',
            channelName: 'Aaj Tak HD',
            featured: true,
          ),
          MultiviewCastSlot(
            slotId: 'yrf-music',
            channelId: 'yrf-music',
            channelName: 'YRF Music',
            featured: false,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Focus audio here'));
    await tester.pump();

    expect(receivedCommands, [
      const MultiviewPromoteCommand(slotId: 'yrf-music'),
    ]);
  });

  testWidgets('creating a layout saves it and it shows up in the list', (
    tester,
  ) async {
    await pump(
      tester,
      transport: const UnavailableMultiviewCastSenderTransport(),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('cast-multiview-create-layout')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('cast-multiview-layout-name')),
      'News',
    );
    await tester.tap(
      find.byKey(const ValueKey('cast-multiview-channel-option-aajtak-hd')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('cast-multiview-save-layout')));
    await tester.pumpAndSettle();

    expect(find.text('News'), findsOneWidget);
    expect(find.text('Aaj Tak HD'), findsWidgets);
  });

  testWidgets(
    'the Save button stays disabled until a name and a channel are picked',
    (tester) async {
      await pump(
        tester,
        transport: const UnavailableMultiviewCastSenderTransport(),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cast-multiview-create-layout')),
      );
      await tester.pumpAndSettle();

      FilledButton saveButton() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('cast-multiview-save-layout')),
      );
      expect(saveButton().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('cast-multiview-layout-name')),
        'News',
      );
      await tester.pump();
      expect(saveButton().onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('cast-multiview-channel-option-aajtak-hd')),
      );
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
    },
  );

  testWidgets('launching a saved layout sends a set_slot command per channel', (
    tester,
  ) async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);
    final receivedCommands = <MultiviewCastCommand>[];
    link.receiver.commands.listen(receivedCommands.add);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = MultiviewCastLayoutStorage(prefs);
    await storage.saveLayout(
      const MultiviewCastLayout(
        id: 'layout-1',
        name: 'News',
        slots: [
          MultiviewCastLayoutSlot(
            channelId: 'aajtak-hd',
            channelName: 'Aaj Tak HD',
          ),
          MultiviewCastLayoutSlot(
            channelId: 'yrf-music',
            channelName: 'YRF Music',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          multiviewCastSenderTransportProvider.overrideWithValue(link.sender),
        ],
        child: const MaterialApp(home: CastMultiviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Launch on TV'));
    await tester.pumpAndSettle();

    expect(receivedCommands, [
      const MultiviewSetSlotCommand(
        slotId: 'aajtak-hd',
        channelId: 'aajtak-hd',
      ),
      const MultiviewSetSlotCommand(
        slotId: 'yrf-music',
        channelId: 'yrf-music',
      ),
    ]);
  });

  testWidgets(
    'the eight layout mosaics are on screen and tapping one sets layout',
    (tester) async {
      final link = FakeMultiviewCastLink();
      addTearDown(link.dispose);
      final receivedCommands = <MultiviewCastCommand>[];
      link.receiver.commands.listen(receivedCommands.add);

      await pump(tester, transport: link.sender);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('multiview-layout-picker')),
        findsOneWidget,
      );
      for (final kind in MultiviewLayoutKind.values) {
        expect(
          find.byKey(ValueKey('multiview-layout-pick-${kind.wireName}')),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.byKey(const ValueKey('multiview-layout-pick-spotlight')),
      );
      await tester.pump();

      expect(receivedCommands, [
        const MultiviewSetLayoutCommand(layout: MultiviewLayoutKind.spotlight),
      ]);
    },
  );
}
