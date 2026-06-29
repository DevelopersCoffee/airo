import 'package:airo_app/shared/widgets/adaptive_dialog.dart';
import 'package:airo_app/shared/widgets/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAdaptiveNavigation(
    WidgetTester tester, {
    required double width,
    double textScaleFactor = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: AdaptiveNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              AdaptiveNavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              AdaptiveNavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            child: const Center(child: Text('Adaptive body')),
          ),
        ),
      ),
    );
  }

  testWidgets('adaptive navigation uses a bottom bar on compact widths', (
    tester,
  ) async {
    await pumpAdaptiveNavigation(tester, width: 420);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Adaptive body'), findsOneWidget);
  });

  testWidgets('adaptive navigation uses a rail on tablet and desktop widths', (
    tester,
  ) async {
    await pumpAdaptiveNavigation(tester, width: 1200);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Adaptive body'), findsOneWidget);
  });

  testWidgets('adaptive navigation stays pumpable under large font scaling', (
    tester,
  ) async {
    await pumpAdaptiveNavigation(tester, width: 420, textScaleFactor: 2.0);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
