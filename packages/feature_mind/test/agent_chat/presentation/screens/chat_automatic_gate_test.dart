import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_automatic_gate.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_mind/src/intelligence/intelligence_providers.dart';

void main() {
  testWidgets('first-run chat shows Install recommended, not a model catalog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    const library = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'test',
      platformLabel: 'test',
      candidates: [],
      recommended: AssistantModelCandidate(
        id: 'missing',
        name: 'Missing',
        runtime: 'none',
        description: '',
        bestFor: [],
        tags: [],
        privacyLabel: '',
        sizeLabel: '',
        available: false,
        actionLabel: 'Download',
        local: true,
      ),
      defaultPackages: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          intelligenceCatalogProvider.overrideWithValue(const []),
          intelligenceMemoryLoaderProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: ChatAutomaticGate(
            library: library,
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Install recommended'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Gemma-4-E2B-it'), findsNothing);
    expect(find.text('Start a Project'), findsNothing);
  });

  test('automaticChatCandidate prefers an installed chat package', () {
    final model = OfflineModelInfo(
      id: 'chat-model',
      name: 'Chat model',
      family: ModelFamily.other,
      fileSizeBytes: 1000,
      filePath: '/tmp/chat',
      downloadUrl: 'https://example.test/chat',
      capabilities: const [ModelCapability.chat],
    );
    final candidate = AssistantModelCandidate(
      id: assistantModelIdForOfflineModel(model.id),
      name: model.name,
      runtime: 'llama.cpp',
      description: '',
      bestFor: const [],
      tags: const ['Local'],
      privacyLabel: '',
      sizeLabel: '1 KB',
      available: true,
      actionLabel: 'Start',
      local: true,
      package: model,
    );
    final library = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'test',
      platformLabel: 'test',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: const {},
    );

    expect(
      automaticChatCandidate(
        library: library,
        catalog: [model],
        overrides: const {},
      )?.id,
      candidate.id,
    );
  });
}
