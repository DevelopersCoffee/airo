import 'package:feature_iptv/presentation/tv_ux/sections/shell_help_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses only the latest changelog release', () {
    final notes = AiroTvReleaseNotes.parseLatest('''
# Changelog

## 0.0.2
- Current feature
- Current fix

## 0.0.1
- Old feature
''');

    expect(notes.version, '0.0.2');
    expect(notes.items, ['Current feature', 'Current fix']);
  });

  testWidgets("help reaches What's New backed by changelog content", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiroTvShellHelpDialog(
            changelogLoader: () async => '''
## 0.0.1
- Real playback stats.
''',
          ),
        ),
      ),
    );

    expect(find.text('Playback Stats'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('airo-tv-whats-new-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('airo-tv-whats-new-dialog')),
      findsOneWidget,
    );
    expect(find.text('0.0.1'), findsOneWidget);
    expect(find.text('• Real playback stats.'), findsOneWidget);
  });
}
