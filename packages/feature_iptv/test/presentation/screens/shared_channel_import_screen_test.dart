import 'package:feature_iptv/presentation/screens/shared_channel_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires an explicit save, play once, or cancel action', (
    tester,
  ) async {
    var saved = 0;
    var playedOnce = 0;
    var cancelled = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SharedChannelImportScreen(
          channelName: '9XM',
          sourceHost: '9xjio.wiseplayout.com',
          onSaveAndPlay: () async => saved++,
          onPlayOnce: () => playedOnce++,
          onCancel: () => cancelled++,
        ),
      ),
    );

    expect(find.text('A friend shared 9XM'), findsOneWidget);
    expect(
      find.text('Adaptive HLS stream from 9xjio.wiseplayout.com'),
      findsOneWidget,
    );
    expect(
      find.text('Only add streams you have permission to watch.'),
      findsOneWidget,
    );
    expect(saved, 0);
    expect(playedOnce, 0);

    await tester.tap(find.byKey(const ValueKey('shared-channel-play-once')));
    await tester.pump();
    expect(playedOnce, 1);

    await tester.tap(find.byKey(const ValueKey('shared-channel-cancel')));
    await tester.pump();
    expect(cancelled, 1);

    await tester.tap(
      find.byKey(const ValueKey('shared-channel-save-and-play')),
    );
    await tester.pump();
    await tester.pump();
    expect(saved, 1);
  });

  testWidgets('shows a recoverable message when persistence fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedChannelImportScreen(
          channelName: 'Channel',
          sourceHost: 'media.example.com',
          onSaveAndPlay: () => Future<void>.error(StateError('disk full')),
          onPlayOnce: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('shared-channel-save-and-play')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shared-channel-error')), findsOneWidget);
    expect(find.textContaining('Try again or play it once'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('shared-channel-save-and-play')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
