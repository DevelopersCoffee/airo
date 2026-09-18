import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/presentation/tv_ux/tv_local_media_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FocusNode focusTvControl(WidgetTester tester, Finder root) {
    final focusWidgets = tester.widgetList<Focus>(
      find.descendant(of: root.first, matching: find.byType(Focus)),
    );
    for (final focus in focusWidgets) {
      final node = focus.focusNode;
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
        return node;
      }
    }
    throw StateError('No requestable Focus node under $root');
  }

  Future<void> pumpBrowser(
    WidgetTester tester, {
    required Future<List<LocalMediaEntry>> Function() loadEntries,
    bool isNetworkBrowse = true,
    String title = 'Choose network media',
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TvLocalMediaBrowserDialog(
          title: title,
          loadEntries: loadEntries,
          isNetworkBrowse: isNetworkBrowse,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Browse Network empty shows find-media copy, Scan again, and How it works',
    (tester) async {
      var scans = 0;
      await pumpBrowser(
        tester,
        loadEntries: () async {
          scans++;
          return const [];
        },
      );

      expect(find.text('Find media shared on your network'), findsOneWidget);
      expect(find.textContaining('Windows'), findsOneWidget);
      expect(find.textContaining('Mac'), findsOneWidget);
      expect(find.textContaining('NAS'), findsOneWidget);
      expect(find.textContaining('same network'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('No supported media was found here.'), findsNothing);

      await tester.tap(find.text('Scan again'));
      await tester.pumpAndSettle();
      expect(scans, 2);

      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();
      expect(find.text('How it works'), findsWidgets);
      expect(find.textContaining('same'), findsWidgets);
    },
  );

  testWidgets('USB empty keeps the generic no-media copy', (tester) async {
    await pumpBrowser(
      tester,
      title: 'Choose USB media',
      isNetworkBrowse: false,
      loadEntries: () async => const [],
    );

    expect(find.text('No supported media was found here.'), findsOneWidget);
    expect(find.text('Scan again'), findsNothing);
    expect(find.text('How it works'), findsNothing);
  });

  testWidgets('Browse Network empty Scan again is D-pad reachable', (
    tester,
  ) async {
    await pumpBrowser(tester, loadEntries: () async => const []);

    final scan = find.ancestor(
      of: find.text('Scan again'),
      matching: find.byType(TvFocusable),
    );
    final how = find.ancestor(
      of: find.text('How it works'),
      matching: find.byType(TvFocusable),
    );
    expect(focusTvControl(tester, scan).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final howNodes = tester.widgetList<Focus>(
      find.descendant(of: how, matching: find.byType(Focus)),
    );
    expect(
      howNodes.any((focus) => focus.focusNode?.hasPrimaryFocus == true),
      isTrue,
    );
  });
}
