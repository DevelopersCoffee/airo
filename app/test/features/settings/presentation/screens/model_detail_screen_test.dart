import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/settings/presentation/screens/model_detail_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    testWidgets('set active action updates shared model selections', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const model = OfflineModelInfo(
        id: 'gemma-downloaded',
        name: 'Gemma Downloaded',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        filePath: '/models/gemma-downloaded.gguf',
        provider: AIProvider.gemma,
      );

      await tester.pumpWidget(
        buildScreen(
          model,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            modelRegistryProvider.overrideWithValue(ModelRegistry()),
          ],
        ),
      );

      await tester.scrollUntilVisible(find.text('Set as Active Model'), 300);
      await tester.tap(find.text('Set as Active Model'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(selectedModelIdProvider), model.id);
      expect(
        container.read(selectedAssistantModelIdProvider),
        assistantModelIdForOfflineModel(model.id),
      );
    });

    testWidgets('delete action clears shared selections through providers', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'selected_offline_model_id': 'gemma-downloaded',
        selectedAssistantModelKey: assistantModelIdForOfflineModel(
          'gemma-downloaded',
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final registry = ModelRegistry()
        ..registerModel(
          const OfflineModelInfo(
            id: 'gemma-downloaded',
            name: 'Gemma Downloaded',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-downloaded.gguf',
            provider: AIProvider.gemma,
          ),
        );
      const model = OfflineModelInfo(
        id: 'gemma-downloaded',
        name: 'Gemma Downloaded',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        filePath: '/models/gemma-downloaded.gguf',
        provider: AIProvider.gemma,
      );

      await tester.pumpWidget(
        buildScreen(
          model,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            modelRegistryProvider.overrideWithValue(registry),
            modelDownloadServiceProvider.overrideWithValue(
              _FakeModelDownloadService(deleteResult: true),
            ),
          ],
        ),
      );

      await tester.scrollUntilVisible(find.byIcon(Icons.delete_outline), 300);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(selectedModelIdProvider), isNull);
      expect(container.read(selectedAssistantModelIdProvider), isNull);
      expect(registry.getModel(model.id)?.isDownloaded, isFalse);
    });
  });
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService({required this.deleteResult});

  final bool deleteResult;

  @override
  Future<bool> deleteModel(String modelId) async => deleteResult;
}
