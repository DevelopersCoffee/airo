import 'package:airo_app/core/assistant/mind_assistant_host_adapter.dart';
import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final mindAssistantAdapterProvider = Provider<MindAssistantHostAdapter>(
  (ref) => MindAssistantHostAdapter(ref),
);

void main() {
  testWidgets('openModelManager navigates to the models route', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              final adapter = ref.read(mindAssistantAdapterProvider);
              return ElevatedButton(
                onPressed: () => adapter.openModelManager(context),
                child: const Text('open models'),
              );
            },
          ),
        ),
        GoRoute(
          path: '/models',
          builder: (context, state) =>
              const Scaffold(body: Text('models surface')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.tap(find.text('open models'));
    await tester.pumpAndSettle();

    expect(find.text('models surface'), findsOneWidget);
  });

  testWidgets('openHostSettings navigates to the settings route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              final adapter = ref.read(mindAssistantAdapterProvider);
              return ElevatedButton(
                onPressed: () => adapter.openHostSettings(context),
                child: const Text('open settings'),
              );
            },
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('settings surface')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    expect(find.text('settings surface'), findsOneWidget);
  });

  test(
    'loadAssistantDownloadedModels returns only downloaded gguf chat models',
    () async {
      final registry = ModelRegistry();
      addTearDown(registry.dispose);
      registry.registerModel(
        const OfflineModelInfo(
          id: 'chat-gguf',
          name: 'Chat GGUF',
          family: ModelFamily.qwen,
          fileSizeBytes: 1024,
          provider: AIProvider.custom,
          capabilities: [ModelCapability.chat],
          filePath: '/tmp/chat.gguf',
        ),
      );
      registry.registerModel(
        const OfflineModelInfo(
          id: 'speech-whisper',
          name: 'Whisper',
          family: ModelFamily.other,
          fileSizeBytes: 2048,
          provider: AIProvider.custom,
          capabilities: [ModelCapability.audioUnderstanding],
          filePath: '/tmp/whisper.bin',
        ),
      );
      registry.registerModel(
        const OfflineModelInfo(
          id: 'chat-no-path',
          name: 'Chat no path',
          family: ModelFamily.qwen,
          fileSizeBytes: 512,
          provider: AIProvider.custom,
          capabilities: [ModelCapability.chat],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          mindAssistantAdapterProvider.overrideWith(
            (ref) => MindAssistantHostAdapter(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      final models = await container
          .read(mindAssistantAdapterProvider)
          .loadAssistantDownloadedModels();

      expect(models.map((model) => model.id), ['chat-gguf']);
    },
  );
}
