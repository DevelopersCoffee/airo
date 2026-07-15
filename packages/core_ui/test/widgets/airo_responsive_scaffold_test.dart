import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  Widget buildTestScaffold({
    required Widget body,
    double? width,
    double? height,
    bool isLoading = false,
    bool isEmpty = false,
    String? errorMessage,
    bool useResponsiveCenter = true,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          final size = Size(width ?? 400.0, height ?? 800.0);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: AiroResponsiveScaffold(
              isLoading: isLoading,
              isEmpty: isEmpty,
              errorMessage: errorMessage,
              useResponsiveCenter: useResponsiveCenter,
              body: body,
            ),
          );
        },
      ),
    );
  }

  group('AiroResponsiveScaffold State Tests', () {
    testWidgets('renders normal body by default', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(body: const Text('Normal Content')),
      );

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No items found.'), findsNothing);
      expect(find.text('Test Error'), findsNothing);
    });

    testWidgets('renders loading widget when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(body: const Text('Normal Content'), isLoading: true),
      );

      expect(find.text('Normal Content'), findsNothing);
      expect(find.byType(LoadingIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when isEmpty is true', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(body: const Text('Normal Content'), isEmpty: true),
      );

      expect(find.text('Normal Content'), findsNothing);
      expect(find.text('No items found.'), findsOneWidget);
    });

    testWidgets('renders error message state when errorMessage is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          body: const Text('Normal Content'),
          errorMessage: 'Failed to sync database',
        ),
      );

      expect(find.text('Normal Content'), findsNothing);
      expect(find.text('Failed to sync database'), findsOneWidget);
    });
  });

  group('AiroResponsiveScaffold Responsiveness & Constraints', () {
    testWidgets('applies maxWidth constraint on wide viewports (Desktop)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          body: const Text('Desktop Content'),
          width: 1200.0, // Desktop width
        ),
      );

      final Finder bodyFinder = find.text('Desktop Content');
      expect(bodyFinder, findsOneWidget);

      // Verify that the body is wrapped inside a ConstrainedBox with max width 1000
      final constrainedBox = tester.widget<ConstrainedBox>(
        find
            .ancestor(of: bodyFinder, matching: find.byType(ConstrainedBox))
            .first,
      );
      expect(constrainedBox.constraints.maxWidth, equals(1000.0));
    });

    testWidgets(
      'does not apply maxWidth constraint when useResponsiveCenter is false',
      (tester) async {
        await tester.pumpWidget(
          buildTestScaffold(
            body: const Text('No Constraint Content'),
            width: 1200.0,
            useResponsiveCenter: false,
          ),
        );

        // Verify that the child is not inside any ConstrainedBox restricting width to 1000
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        for (final box in constrainedBoxes) {
          expect(box.constraints.maxWidth == 1000.0, isFalse);
        }
      },
    );
  });
}
