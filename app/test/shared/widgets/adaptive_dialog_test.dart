import 'package:airo_app/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adaptive dialog stays visible on mobile with keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(420, 900),
            viewInsets: EdgeInsets.only(bottom: 240),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AdaptiveDialog.show<void>(
                      context: context,
                      builder: (_) => const Text('Dialog body'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Dialog body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive dialog shows a centered dialog on wide layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 900)),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AdaptiveDialog.show<void>(
                      context: context,
                      builder: (_) => const Text('Desktop dialog body'),
                    );
                  },
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Desktop dialog body'), findsOneWidget);
  });
}
