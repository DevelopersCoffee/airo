import 'package:feature_iptv/presentation/tv_ux/airo_tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'one',
      name: 'One',
      streamUrl: 'https://one',
      group: 'News',
    ),
  ];

  Future<void> pumpAt(WidgetTester tester, double width) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 720,
              child: AiroTvShell(
                channels: channels,
                videoStage: const SizedBox(key: ValueKey('video-stage')),
                onChannelSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('compact layout preserves the stacked browsing structure', (
    tester,
  ) async {
    await pumpAt(tester, 390);
    expect(find.byKey(const ValueKey('video-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('airo-tv-channel-table')), findsOneWidget);
  });

  testWidgets('wide layout retains the full channel table', (tester) async {
    await pumpAt(tester, 900);
    expect(find.text('Country'), findsWidgets);
  });

  testWidgets('wide layout uses the Explorer stage and panel composition', (
    tester,
  ) async {
    await pumpAt(tester, 1280);

    expect(
      find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-video-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-panel')),
      findsOneWidget,
    );
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('HOTBAR'), findsOneWidget);
    expect(find.text('FILTER'), findsOneWidget);

    final stageWidth = tester
        .getSize(find.byKey(const ValueKey('airo-tv-explorer-video-stage')))
        .width;
    final panelWidth = tester
        .getSize(find.byKey(const ValueKey('airo-tv-explorer-panel')))
        .width;
    expect(stageWidth, lessThan(panelWidth));
  });

  testWidgets('TV-sized layout keeps channel rows focusable', (tester) async {
    await pumpAt(tester, 1280);
    expect(find.byType(Focus), findsWidgets);
  });
}
