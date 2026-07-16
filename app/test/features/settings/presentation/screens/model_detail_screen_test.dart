import 'package:airo_app/features/settings/presentation/screens/model_detail_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  Widget buildScreen(
    OfflineModelInfo model, {
    Future<bool> Function(Uri uri, {LaunchMode mode})? launchUrlCallback,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: ModelDetailScreen(
          model: model,
          launchUrlCallback: launchUrlCallback,
        ),
      ),
    );
  }

  group('ModelDetailScreen', () {
    testWidgets('shows learn more action when source URL exists', (
      tester,
    ) async {
      const model = OfflineModelInfo(
        id: 'gemma',
        name: 'Gemma',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        huggingFaceId: 'litert-community/gemma-4-E2B-it-litert-lm',
      );

      await tester.pumpWidget(buildScreen(model));

      expect(find.byTooltip('Learn more'), findsOneWidget);
    });

    testWidgets('hides learn more action when source URL is unavailable', (
      tester,
    ) async {
      const model = OfflineModelInfo(
        id: 'local-only',
        name: 'Local Only',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
      );

      await tester.pumpWidget(buildScreen(model));

      expect(find.byTooltip('Learn more'), findsNothing);
    });

    testWidgets('shows snackbar when external launch fails', (tester) async {
      const model = OfflineModelInfo(
        id: 'gemma',
        name: 'Gemma',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        huggingFaceId: 'litert-community/gemma-4-E2B-it-litert-lm',
      );

      await tester.pumpWidget(
        buildScreen(
          model,
          launchUrlCallback: (uri, {mode = LaunchMode.platformDefault}) async {
            return false;
          },
        ),
      );

      await tester.tap(find.byTooltip('Learn more'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the model page for Gemma.'), findsOne);
    });
  });
}
