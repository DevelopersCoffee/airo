import 'package:airo_app/features/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantRuntimeService', () {
    test(
      'reports Gemini Nano unavailable instead of using canned fallback',
      () async {
        final service = AssistantRuntimeService(
          isGeminiNanoSupported: () async => false,
          initializeGeminiNano: () async => throw StateError('should not init'),
          generateGeminiNanoText: (_) async => 'fake fallback',
        );

        expect(
          () => service.generateText(
            selectedModelId: geminiNanoAssistantModelId,
            prompt: 'hello',
          ),
          throwsA(
            isA<AssistantRuntimeUnavailableException>().having(
              (error) => error.message,
              'message',
              geminiNanoUnavailableMessage,
            ),
          ),
        );
      },
    );

    test('routes LiteRT-LM text through the selected runtime', () async {
      final service = AssistantRuntimeService(
        generateLiteRtText: (prompt, {systemPrompt}) async {
          return '${systemPrompt ?? 'no-system'} :: $prompt';
        },
        loadAssistantModelLibrary: () async => const AssistantModelLibraryState(
          task: AssistantTask.chat,
          deviceLabel: 'Pixel 9',
          platformLabel: 'ANDROID',
          candidates: [],
          recommended: AssistantModelCandidate(
            id: geminiCloudAssistantModelId,
            name: 'Gemini Cloud',
            runtime: 'Cloud',
            description: 'Cloud runtime',
            bestFor: [AssistantTask.chat],
            tags: ['Cloud'],
            privacyLabel: 'Sends prompt to API',
            sizeLabel: 'No local download',
            available: true,
            actionLabel: 'Start',
            local: false,
          ),
          defaultPackages: {},
        ),
      );

      final text = await service.generateText(
        selectedModelId: litertGemmaAssistantModelId,
        systemPrompt: 'skill planner',
        prompt: 'pick a tool',
      );

      expect(text, 'skill planner :: pick a tool');
    });

    test(
      'routes generic LiteRT runtime through a downloaded package when available',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          filePath: '/models/gemma-4-e2b-it-litertlm.task',
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat, ModelCapability.reasoning],
        );
        final service = AssistantRuntimeService(
          generateLiteRtText: (_, {systemPrompt}) async =>
              'generic ${systemPrompt ?? ''}'.trim(),
          generateLiteRtModelText: (model, prompt, {systemPrompt}) async {
            return '${model.id} :: ${systemPrompt ?? 'no-system'} :: $prompt';
          },
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Pixel 9',
            platformLabel: 'ANDROID',
            candidates: [
              AssistantModelCandidate(
                id: litertGemmaAssistantModelId,
                name: 'Gemma mobile package',
                runtime: 'LiteRT-LM local model',
                description: 'Local package',
                bestFor: const [AssistantTask.chat, AssistantTask.reasoning],
                tags: const ['Local'],
                privacyLabel: 'Prompt stays on device',
                sizeLabel: package.fileSizeDisplay,
                available: true,
                actionLabel: 'Start',
                local: true,
                package: package,
              ),
            ],
            recommended: AssistantModelCandidate(
              id: litertGemmaAssistantModelId,
              name: 'Gemma mobile package',
              runtime: 'LiteRT-LM local model',
              description: 'Local package',
              bestFor: const [AssistantTask.chat, AssistantTask.reasoning],
              tags: const ['Local'],
              privacyLabel: 'Prompt stays on device',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
            defaultPackages: {AssistantTask.chat: package},
          ),
        );

        final text = await service.generateText(
          selectedModelId: litertGemmaAssistantModelId,
          systemPrompt: 'planner',
          prompt: 'pick a tool',
        );

        expect(text, 'gemma-4-e2b-it-litertlm :: planner :: pick a tool');
      },
    );

    test(
      'falls back to another downloaded LiteRT package when generic runtime yields no response',
      () async {
        final fallbackPackage = OfflineModelInfo(
          id: 'gemma-3n-e2b-it-litertlm',
          name: 'Gemma 3n',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024 * 1024 * 1024,
          filePath: '/models/gemma-3n-e2b-it-litertlm.task',
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat],
        );
        final service = AssistantRuntimeService(
          generateLiteRtText: (_, {systemPrompt}) async => null,
          generateLiteRtModelText: (model, prompt, {systemPrompt}) async {
            return '${model.id} :: ${systemPrompt ?? 'no-system'} :: $prompt';
          },
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Pixel 9',
            platformLabel: 'ANDROID',
            candidates: [
              AssistantModelCandidate(
                id: litertGemmaAssistantModelId,
                name: 'Gemma mobile package',
                runtime: 'LiteRT-LM local model',
                description: 'Default runtime',
                bestFor: const [AssistantTask.chat],
                tags: const ['Local'],
                privacyLabel: 'Prompt stays on device',
                sizeLabel: '2 GB',
                available: false,
                actionLabel: 'Download package',
                local: true,
              ),
              AssistantModelCandidate.fromOfflineModel(fallbackPackage),
            ],
            recommended: const AssistantModelCandidate(
              id: litertGemmaAssistantModelId,
              name: 'Gemma mobile package',
              runtime: 'LiteRT-LM local model',
              description: 'Default runtime',
              bestFor: [AssistantTask.chat],
              tags: ['Local'],
              privacyLabel: 'Prompt stays on device',
              sizeLabel: '2 GB',
              available: false,
              actionLabel: 'Download package',
              local: true,
            ),
            defaultPackages: {AssistantTask.chat: fallbackPackage},
          ),
        );

        final text = await service.generateText(
          selectedModelId: litertGemmaAssistantModelId,
          systemPrompt: 'planner',
          prompt: 'pick a tool',
        );

        expect(text, 'gemma-3n-e2b-it-litertlm :: planner :: pick a tool');
      },
    );

    test(
      'falls back to another downloaded LiteRT package when selected offline package is missing',
      () async {
        final fallbackPackage = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          filePath: '/models/gemma-4-e2b-it-litertlm.task',
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat, ModelCapability.reasoning],
        );
        final missingPackage = OfflineModelInfo(
          id: 'phi-3-mini-4k-litertlm',
          name: 'Phi 3 Mini',
          family: ModelFamily.phi,
          fileSizeBytes: 1024 * 1024 * 1024,
          provider: AIProvider.phi,
          capabilities: const [ModelCapability.chat],
        );
        final service = AssistantRuntimeService(
          generateLiteRtModelText: (model, prompt, {systemPrompt}) async {
            return '${model.id} :: ${systemPrompt ?? 'no-system'} :: $prompt';
          },
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Pixel 9',
            platformLabel: 'ANDROID',
            candidates: [
              AssistantModelCandidate.fromOfflineModel(missingPackage),
              AssistantModelCandidate.fromOfflineModel(fallbackPackage),
            ],
            recommended: AssistantModelCandidate.fromOfflineModel(
              fallbackPackage,
            ),
            defaultPackages: {AssistantTask.chat: fallbackPackage},
          ),
        );

        final text = await service.generateText(
          selectedModelId: assistantModelIdForOfflineModel(missingPackage.id),
          systemPrompt: 'planner',
          prompt: 'pick a tool',
        );

        expect(text, 'gemma-4-e2b-it-litertlm :: planner :: pick a tool');
      },
    );

    test('reports Gemini Cloud configuration errors explicitly', () async {
      final service = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => false,
        generateCloudText: (_) async => 'should not run',
      );

      expect(
        () => service.generateText(
          selectedModelId: geminiCloudAssistantModelId,
          prompt: 'hello',
        ),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            geminiCloudUnavailableMessage,
          ),
        ),
      );
    });

    test(
      'builds a blocked preparation result for unsupported Gemini Nano',
      () async {
        final service = AssistantRuntimeService(
          isGeminiNanoSupported: () async => false,
          loadDeviceInfo: () async => {
            'manufacturer': 'Google',
            'model': 'Pixel 8',
            'platform': 'android',
          },
        );

        final result = await service.prepareRuntime(
          candidate: const AssistantModelCandidate(
            id: geminiNanoAssistantModelId,
            name: 'Gemini Nano',
            runtime: 'AICore on-device',
            description: 'Local runtime',
            bestFor: [AssistantTask.chat],
            tags: ['Local'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: 'System managed',
            available: true,
            actionLabel: 'Start',
            local: true,
          ),
        );

        expect(result.status, AssistantRuntimePreparationStatus.blocked);
        expect(
          result.diagnostic?.summary,
          'Gemini Nano is not supported on this device.',
        );
        expect(result.diagnostic?.deviceLabel, 'Google Pixel 8');
      },
    );

    test('cancels preparation before runtime work starts', () async {
      final service = AssistantRuntimeService(
        loadDeviceInfo: () async => {'manufacturer': 'Web', 'model': 'Browser'},
      );

      final result = await service.prepareRuntime(
        candidate: const AssistantModelCandidate(
          id: geminiCloudAssistantModelId,
          name: 'Gemini Cloud',
          runtime: 'Cloud',
          description: 'Cloud runtime',
          bestFor: [AssistantTask.chat],
          tags: ['Cloud'],
          privacyLabel: 'Sends prompt to API',
          sizeLabel: 'No local download',
          available: true,
          actionLabel: 'Start',
          local: false,
        ),
        isCancelled: () => true,
      );

      expect(result.status, AssistantRuntimePreparationStatus.cancelled);
    });

    test('blocks LiteRT packages when compatibility fails', () async {
      final package = OfflineModelInfo(
        id: 'gemma-4-e2b-it-litertlm',
        name: 'Gemma 4 E2B',
        family: ModelFamily.gemma,
        fileSizeBytes: 2 * 1024 * 1024 * 1024,
        backendPreference: ModelBackendPreference.gpu,
        provider: AIProvider.gemma,
        capabilities: const [ModelCapability.chat],
      );
      final service = AssistantRuntimeService(
        isLiteRtAvailable: () async => true,
        loadDeviceInfo: () async => {
          'manufacturer': 'Nothing',
          'model': 'Phone',
          'platform': 'android',
        },
        checkModelCompatibility: (_) async =>
            ModelCompatibilityResult.incompatible('Insufficient memory.'),
      );

      final result = await service.prepareRuntime(
        candidate: AssistantModelCandidate(
          id: litertGemmaAssistantModelId,
          name: 'Gemma mobile package',
          runtime: 'LiteRT-LM local model',
          description: 'Local package',
          bestFor: const [AssistantTask.chat],
          tags: const ['Local'],
          privacyLabel: 'Prompt stays on device',
          sizeLabel: package.fileSizeDisplay,
          available: true,
          actionLabel: 'Start',
          local: true,
          package: package,
        ),
      );

      expect(result.status, AssistantRuntimePreparationStatus.blocked);
      expect(
        result.diagnostic?.summary,
        'This local package exceeds the current device budget.',
      );
    });

    test(
      'prepares generic LiteRT runtime from a downloaded package when default runtime is unavailable',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          filePath: '/models/gemma-4-e2b-it-litertlm.task',
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat, ModelCapability.reasoning],
        );
        var warmedPackageId = '';
        var warmedInstalled = false;
        final service = AssistantRuntimeService(
          isLiteRtAvailable: () async => false,
          warmupLiteRtInstalledModel: () async {
            warmedInstalled = true;
            return true;
          },
          warmupLiteRtModel: (model) async {
            warmedPackageId = model.id;
            return true;
          },
          loadDeviceInfo: () async => {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
            'platform': 'android',
          },
        );

        final result = await service.prepareRuntime(
          candidate: AssistantModelCandidate(
            id: litertGemmaAssistantModelId,
            name: 'Gemma mobile package',
            runtime: 'LiteRT-LM local model',
            description: 'Local package',
            bestFor: const [AssistantTask.chat, AssistantTask.reasoning],
            tags: const ['Local'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: package.fileSizeDisplay,
            available: true,
            actionLabel: 'Start',
            local: true,
            package: package,
          ),
        );

        expect(result.status, AssistantRuntimePreparationStatus.ready);
        expect(warmedPackageId, 'gemma-4-e2b-it-litertlm');
        expect(warmedInstalled, isFalse);
      },
    );
  });
}
