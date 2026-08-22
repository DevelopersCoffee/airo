import 'package:core_ai/core_ai.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:feature_mind/src/agent_chat/data/services/preferences_reliability_checkpoint_store.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/services/gguf_load_outcome.dart';
import 'package:feature_mind/src/services/llama_gguf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantRuntimeService', () {
    test('diagnostic envelopes render optional repair context as markdown', () {
      const envelope = AssistantRuntimeDiagnosticEnvelope(
        runtimeId: 'runtime-a',
        runtimeName: 'Runtime A',
        summary: 'Runtime cannot start.',
        detail: 'The model exceeded a temporary budget.',
        deviceLabel: 'Google Pixel 9',
        platformLabel: 'ANDROID',
        reasonCode: 'compatibility_blocked',
        availableMemoryMB: 1536,
        requiredMemoryMB: 3072,
        repairActions: ['Reduce context.', 'Retry warmup.'],
      );
      final error = AssistantRuntimeUnavailableException(
        envelope.runtimeId,
        envelope.summary,
      );

      expect(envelope.toMarkdown(), contains('Runtime: Runtime A (runtime-a)'));
      expect(
        envelope.toMarkdown(),
        contains('Reason code: compatibility_blocked'),
      );
      expect(
        envelope.toMarkdown(),
        contains('Memory MB: available=1536, required=3072'),
      );
      expect(envelope.toMarkdown(), contains('- Reduce context.'));
      expect(error.toString(), envelope.summary);
    });

    test('marks cloud candidates ready without local initialization', () async {
      final progress = <AssistantRuntimePreparationProgress>[];
      final service = AssistantRuntimeService(
        loadDeviceInfo: () async => const {
          'manufacturer': '',
          'model': '',
          'platform': 'web',
        },
      );

      final result = await service.prepareRuntime(
        candidate: const AssistantModelCandidate(
          id: geminiCloudAssistantModelId,
          name: 'Gemini Cloud',
          runtime: 'Cloud',
          description: 'Cloud runtime',
          bestFor: [AssistantTask.chat],
          tags: ['Cloud'],
          privacyLabel: 'Remote',
          sizeLabel: 'No download',
          available: true,
          actionLabel: 'Start',
          local: false,
        ),
        onProgress: progress.add,
      );

      expect(result.status, AssistantRuntimePreparationStatus.ready);
      expect(progress.last.phase, AssistantRuntimePreparationPhase.ready);
      expect(progress.last.detail, contains('does not require local'));
    });

    test(
      'blocks generic GGUF packages instead of routing them through LiteRT',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          provider: AIProvider.gguf,
        );
        final candidate = AssistantModelCandidate(
          id: assistantModelIdForOfflineModel(package.id),
          name: package.name,
          runtime: 'Qwen GGUF',
          description: 'Downloaded GGUF package',
          bestFor: const [AssistantTask.chat],
          tags: const ['Local', 'GGUF'],
          privacyLabel: 'Prompt stays on device after install',
          sizeLabel: package.fileSizeDisplay,
          available: false,
          actionLabel: 'Native backend unavailable',
          local: true,
          package: package,
        );
        final service = AssistantRuntimeService(
          loadDeviceInfo: () async => {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
            'platform': 'android',
          },
        );

        final result = await service.prepareRuntime(candidate: candidate);

        expect(result.status, AssistantRuntimePreparationStatus.blocked);
        expect(result.diagnostic?.reasonCode, 'native_backend_unavailable');
        expect(result.diagnostic?.detail, contains('llama.cpp'));
      },
    );

    test(
      'blocks the LiteRT runtime when its package is not a LiteRT artifact',
      () async {
        // Selecting the LiteRT runtime with a GGUF artifact attached is the
        // dangerous combination: the earlier GGUF guard is keyed on the
        // offline model id, so a plain `litert-gemma-mobile` candidate walks
        // straight past it and would otherwise hand a .gguf file to LiteRT-LM.
        final service = AssistantRuntimeService(
          loadDeviceInfo: () async => const {'platform': 'android'},
        );

        final result = await service.prepareRuntime(
          candidate: AssistantModelCandidate(
            id: litertGemmaAssistantModelId,
            name: 'Gemma Mobile',
            runtime: 'LiteRT-LM',
            description: 'LiteRT runtime pointed at a GGUF file',
            bestFor: const [AssistantTask.chat],
            tags: const ['Local'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: '1.1 GB',
            available: true,
            actionLabel: 'Start chat',
            local: true,
            package: OfflineModelInfo(
              id: 'qwen2-1.5b-q4',
              name: 'Qwen2 1.5B',
              family: ModelFamily.qwen,
              fileSizeBytes: 1_100_000_000,
              filePath: '/models/qwen2-1.5b-q4.gguf',
              provider: AIProvider.gguf,
            ),
          ),
        );

        expect(result.status, AssistantRuntimePreparationStatus.blocked);
        expect(result.diagnostic?.reasonCode, 'native_backend_unavailable');
      },
    );

    test(
      'blocks default LiteRT when only a download URL is configured',
      () async {
        final service = AssistantRuntimeService(
          liteRtLm: LiteRtLmService(
            client: _UrlOnlyLiteRtClient(),
            config: const LiteRtLmConfig(
              modelUrl: 'https://example.com/gemma.task',
            ),
          ),
          loadDeviceInfo: () async => const {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
            'platform': 'android',
          },
        );

        final result = await service.prepareRuntime(
          candidate: const AssistantModelCandidate(
            id: litertGemmaAssistantModelId,
            name: 'Gemma mobile package',
            runtime: 'LiteRT-LM local model',
            description: 'Local package',
            bestFor: [AssistantTask.chat],
            tags: ['Local'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: '2 GB',
            available: true,
            actionLabel: 'Start',
            local: true,
          ),
        );

        expect(result.status, AssistantRuntimePreparationStatus.blocked);
        expect(result.diagnostic?.reasonCode, 'runtime_unavailable');
        expect(
          result.diagnostic?.repairActions,
          contains(
            'Set LITERT_LM_MODEL_PATH to a verified local artifact when launching locally.',
          ),
        );
      },
    );

    test('blocks the LiteRT runtime when no model backs it', () async {
      // A native channel can answer "available" on a device that has no model
      // installed. Reporting ready there is what produced a setup dialog that
      // reached 100% and then never opened a chat.
      final service = AssistantRuntimeService(
        loadDeviceInfo: () async => const {'platform': 'android'},
        isLiteRtAvailable: () async => false,
      );

      final result = await service.prepareRuntime(
        candidate: const AssistantModelCandidate(
          id: litertGemmaAssistantModelId,
          name: 'Gemma Mobile',
          runtime: 'LiteRT-LM',
          description: 'No installed package',
          bestFor: [AssistantTask.chat],
          tags: ['Local'],
          privacyLabel: 'Prompt stays on device',
          sizeLabel: 'Not installed',
          available: false,
          actionLabel: 'Install',
          local: true,
        ),
      );

      expect(result.status, AssistantRuntimePreparationStatus.blocked);
      expect(result.diagnostic?.reasonCode, 'runtime_unavailable');
    });

    test('blocks missing generic GGUF packages before native setup', () async {
      final service = AssistantRuntimeService(
        loadDeviceInfo: () async => const {'platform': 'android'},
        loadAssistantModelLibrary: () async => const AssistantModelLibraryState(
          task: AssistantTask.chat,
          deviceLabel: 'Pixel 9',
          platformLabel: 'ANDROID',
          candidates: [],
          recommended: AssistantModelCandidate(
            id: geminiCloudAssistantModelId,
            name: 'Gemini Cloud',
            runtime: 'Cloud',
            description: 'Cloud',
            bestFor: [AssistantTask.chat],
            tags: ['Cloud'],
            privacyLabel: 'Remote',
            sizeLabel: 'None',
            available: true,
            actionLabel: 'Start',
            local: false,
          ),
          defaultPackages: {},
        ),
      );

      final result = await service.prepareRuntime(
        candidate: AssistantModelCandidate(
          id: assistantModelIdForOfflineModel('missing-gguf'),
          name: 'Missing GGUF',
          runtime: 'GGUF',
          description: 'Missing local package',
          bestFor: const [AssistantTask.chat],
          tags: const ['Local'],
          privacyLabel: 'Private',
          sizeLabel: '1 GB',
          available: false,
          actionLabel: 'Install',
          local: true,
        ),
      );

      expect(result.status, AssistantRuntimePreparationStatus.blocked);
      expect(result.diagnostic?.reasonCode, 'model_missing');
    });

    test(
      'blocks and succeeds through the native GGUF preparation path',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          provider: AIProvider.gguf,
          contextLength: 16384,
        );
        final candidate = AssistantModelCandidate(
          id: assistantModelIdForOfflineModel(package.id),
          name: package.name,
          runtime: 'Qwen GGUF',
          description: 'Downloaded GGUF package',
          bestFor: const [AssistantTask.chat],
          tags: const ['Local', 'GGUF'],
          privacyLabel: 'Prompt stays on device',
          sizeLabel: package.fileSizeDisplay,
          available: true,
          actionLabel: 'Start',
          local: true,
          package: package,
        );

        final blockedService = AssistantRuntimeService(
          llamaGguf: _FakeLlamaGgufService(isAvailableResult: true),
          loadDeviceInfo: () async => const {'platform': 'android'},
        );
        final blocked = await blockedService.prepareRuntime(
          candidate: candidate,
        );
        expect(blocked.status, AssistantRuntimePreparationStatus.blocked);
        expect(blocked.diagnostic?.reasonCode, 'init_failed');

        final progress = <AssistantRuntimePreparationProgress>[];
        final loadedService = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
        );
        final readyService = AssistantRuntimeService(
          llamaGguf: loadedService,
          loadDeviceInfo: () async => const {'platform': 'android'},
        );
        final ready = await readyService.prepareRuntime(
          candidate: candidate,
          onProgress: progress.add,
        );

        expect(ready.status, AssistantRuntimePreparationStatus.ready);
        expect(loadedService.loadedContextSize, 8192);
        expect(
          progress.map((event) => event.phase),
          containsAllInOrder([
            AssistantRuntimePreparationPhase.allocate,
            AssistantRuntimePreparationPhase.ready,
          ]),
        );
      },
    );

    test(
      'honors reduced context override when preparing GGUF models',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          contextLength: 16384,
          provider: AIProvider.gguf,
        );
        final loadedService = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
        );
        final service = AssistantRuntimeService(
          llamaGguf: loadedService,
          loadDeviceInfo: () async => const {'platform': 'android'},
        );

        final result = await service.prepareRuntime(
          candidate: AssistantModelCandidate(
            id: assistantModelIdForOfflineModel(package.id),
            name: package.name,
            runtime: 'Qwen GGUF',
            description: 'Downloaded GGUF package',
            bestFor: const [AssistantTask.chat],
            tags: const ['Local', 'GGUF'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: package.fileSizeDisplay,
            available: true,
            actionLabel: 'Start',
            local: true,
            package: package,
          ),
          contextLengthOverride: 1024,
        );

        expect(result.status, AssistantRuntimePreparationStatus.ready);
        expect(loadedService.loadedContextSize, 1024);
      },
    );

    test(
      'streams installed GGUF responses through the native backend',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          provider: AIProvider.gguf,
        );
        final runtimeId = assistantModelIdForOfflineModel(package.id);
        final traces = <AssistantRuntimeDebugTrace>[];
        final llama = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
          generatedChunks: ['hello', ' ', 'gguf'],
        );
        final service = AssistantRuntimeService(
          llamaGguf: llama,
          debugTraceEmitter: traces.add,
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Pixel 9',
            platformLabel: 'ANDROID',
            candidates: [
              AssistantModelCandidate(
                id: runtimeId,
                name: package.name,
                runtime: 'GGUF',
                description: 'Installed package',
                bestFor: const [AssistantTask.chat],
                tags: const ['Local'],
                privacyLabel: 'Private',
                sizeLabel: package.fileSizeDisplay,
                available: true,
                actionLabel: 'Start',
                local: true,
                package: package,
              ),
            ],
            recommended: AssistantModelCandidate(
              id: runtimeId,
              name: package.name,
              runtime: 'GGUF',
              description: 'Installed package',
              bestFor: const [AssistantTask.chat],
              tags: const ['Local'],
              privacyLabel: 'Private',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
            defaultPackages: const {},
          ),
        );

        final text = await service.generateText(
          selectedModelId: runtimeId,
          systemPrompt: 'brief',
          prompt: 'say hello',
        );

        expect(text, 'hello gguf');
        expect(traces.last.detail, package.id);
        expect(llama.lastPrompt, contains('<|im_start|>user'));
        expect(llama.lastPrompt, contains('say hello'));
        expect(llama.lastMaxTokens, 2048);
      },
    );

    test(
      'streams GGUF tokens incrementally and captures engine stats',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          provider: AIProvider.gguf,
        );
        final runtimeId = assistantModelIdForOfflineModel(package.id);
        final llama = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
          generatedChunks: ['hello', ' ', 'gguf'],
          stats: const GgufRuntimeStats(
            prefillMs: 120,
            prefillTokens: 80,
            generationMs: 400,
            generatedTokens: 12,
            tokensPerSecond: 30,
          ),
        );
        final service = AssistantRuntimeService(
          llamaGguf: llama,
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Mac',
            platformLabel: 'MACOS',
            candidates: [
              AssistantModelCandidate(
                id: runtimeId,
                name: package.name,
                runtime: 'GGUF',
                description: 'Installed package',
                bestFor: const [AssistantTask.chat],
                tags: const ['Local'],
                privacyLabel: 'Private',
                sizeLabel: package.fileSizeDisplay,
                available: true,
                actionLabel: 'Start',
                local: true,
                package: package,
              ),
            ],
            recommended: AssistantModelCandidate(
              id: runtimeId,
              name: package.name,
              runtime: 'GGUF',
              description: 'Installed package',
              bestFor: const [AssistantTask.chat],
              tags: const ['Local'],
              privacyLabel: 'Private',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
            defaultPackages: const {},
          ),
        );

        final chunks = await service
            .generateTextStream(
              selectedModelId: runtimeId,
              prompt: 'say hello',
              systemPrompt: 'brief',
            )
            .toList();

        expect(chunks, ['hello', 'hello gguf']);
        expect(service.lastGenerationStats?.prefillTokens, 80);
        expect(service.lastGenerationStats?.tokensPerSecond, 30);
      },
    );

    test(
      'prefills the assistant turn instead of relying on prefix GBNF',
      () async {
        final package = OfflineModelInfo(
          id: 'qwen2-1.5b-q4',
          name: 'Qwen2 1.5B',
          family: ModelFamily.qwen,
          fileSizeBytes: 1_100_000_000,
          filePath: '/models/qwen2-1.5b-q4.gguf',
          provider: AIProvider.gguf,
        );
        final runtimeId = assistantModelIdForOfflineModel(package.id);
        final llama = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
          generatedChunks: ['Day 1: oats'],
        );
        final service = AssistantRuntimeService(
          llamaGguf: llama,
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Mac',
            platformLabel: 'MACOS',
            candidates: [
              AssistantModelCandidate(
                id: runtimeId,
                name: package.name,
                runtime: 'GGUF',
                description: 'Installed package',
                bestFor: const [AssistantTask.chat],
                tags: const ['Local'],
                privacyLabel: 'Private',
                sizeLabel: package.fileSizeDisplay,
                available: true,
                actionLabel: 'Start',
                local: true,
                package: package,
              ),
            ],
            recommended: AssistantModelCandidate(
              id: runtimeId,
              name: package.name,
              runtime: 'GGUF',
              description: 'Installed package',
              bestFor: const [AssistantTask.chat],
              tags: const ['Local'],
              privacyLabel: 'Private',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
            defaultPackages: const {},
          ),
        );
        const prefix = "Here's a 3-day diet plan:\n\n";
        final constraint = GenerationConstraint.forcedPrefix(prefix);

        final chunks = await service
            .generateTextStream(
              selectedModelId: runtimeId,
              prompt: 'write the plan',
              constraint: constraint,
            )
            .toList();

        expect(llama.lastGrammar, isNull);
        expect(llama.lastPrompt, contains('<|im_start|>assistant\n$prefix'));
        expect(
          llama.lastPrompt,
          isNot(contains('Start your reply with exactly:')),
        );
        expect(chunks.last, startsWith(prefix.trim()));
        expect(chunks.last, contains('Day 1: oats'));
      },
    );

    test('keeps the prefill when Gemma stops after Here', () async {
      final package = OfflineModelInfo(
        id: 'gemma-2b-it-q4',
        name: 'Gemma 2 2B Instruct',
        family: ModelFamily.gemma,
        fileSizeBytes: 1_600_000_000,
        filePath: '/models/gemma-2-2b-it.gguf',
        provider: AIProvider.gguf,
      );
      final runtimeId = assistantModelIdForOfflineModel(package.id);
      final llama = _FakeLlamaGgufService(
        isAvailableResult: true,
        loadModelResult: true,
        generatedChunks: ['Here'],
      );
      final service = AssistantRuntimeService(
        llamaGguf: llama,
        loadAssistantModelLibrary: () async => AssistantModelLibraryState(
          task: AssistantTask.chat,
          deviceLabel: 'Mac',
          platformLabel: 'MACOS',
          candidates: [
            AssistantModelCandidate(
              id: runtimeId,
              name: package.name,
              runtime: 'GGUF',
              description: 'Installed package',
              bestFor: const [AssistantTask.chat],
              tags: const ['Local'],
              privacyLabel: 'Private',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
          ],
          recommended: AssistantModelCandidate(
            id: runtimeId,
            name: package.name,
            runtime: 'GGUF',
            description: 'Installed package',
            bestFor: const [AssistantTask.chat],
            tags: const ['Local'],
            privacyLabel: 'Private',
            sizeLabel: package.fileSizeDisplay,
            available: true,
            actionLabel: 'Start',
            local: true,
            package: package,
          ),
          defaultPackages: const {},
        ),
      );

      final chunks = await service
          .generateTextStream(
            selectedModelId: runtimeId,
            prompt: 'write the plan',
            constraint: GenerationConstraint.forcedPrefix(
              "Here's a 3-day diet plan:\n\n",
            ),
          )
          .toList();

      expect(llama.lastPrompt, contains('<start_of_turn>model\n'));
      expect(llama.lastPrompt, contains("Here's a 3-day diet plan:"));
      expect(chunks.last, contains("Here's a 3-day diet plan:"));
    });

    test(
      'wraps Gemma GGUF with turn markers and stops on role bleed',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-2b-it-q4',
          name: 'Gemma 2 2B Instruct',
          family: ModelFamily.gemma,
          fileSizeBytes: 1_600_000_000,
          filePath: '/models/gemma-2-2b-it.gguf',
          provider: AIProvider.gguf,
          parameterCount: 2000000000,
        );
        final runtimeId = assistantModelIdForOfflineModel(package.id);
        final llama = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
          generatedChunks: [
            'Hello!',
            ' Airo: Hello again [Type your information here]',
          ],
        );
        final service = AssistantRuntimeService(
          llamaGguf: llama,
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Mac',
            platformLabel: 'MACOS',
            candidates: [
              AssistantModelCandidate(
                id: runtimeId,
                name: package.name,
                runtime: 'GGUF',
                description: 'Installed package',
                bestFor: const [AssistantTask.chat],
                tags: const ['Local'],
                privacyLabel: 'Private',
                sizeLabel: package.fileSizeDisplay,
                available: true,
                actionLabel: 'Start',
                local: true,
                package: package,
              ),
            ],
            recommended: AssistantModelCandidate(
              id: runtimeId,
              name: package.name,
              runtime: 'GGUF',
              description: 'Installed package',
              bestFor: const [AssistantTask.chat],
              tags: const ['Local'],
              privacyLabel: 'Private',
              sizeLabel: package.fileSizeDisplay,
              available: true,
              actionLabel: 'Start',
              local: true,
              package: package,
            ),
            defaultPackages: const {},
          ),
        );

        final text = await service.generateText(
          selectedModelId: runtimeId,
          systemPrompt: 'You are Airo.',
          prompt: 'hi',
        );

        expect(text, 'Hello!');
        expect(llama.lastPrompt, contains('<start_of_turn>user'));
        expect(llama.lastPrompt, contains('<start_of_turn>model'));
        expect(llama.stopCount, 1);
      },
    );

    test(
      'does not treat a host GGUF as missing when generate reloads the library',
      () async {
        final package = OfflineModelInfo(
          id: 'mind-scribe-qwen2.5-0.5b-instruct',
          name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
          family: ModelFamily.qwen,
          fileSizeBytes: 1024,
          filePath: '/models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          provider: AIProvider.gguf,
          parameterCount: 500000000,
          capabilities: const [ModelCapability.chat],
        );
        final runtimeId = assistantModelIdForOfflineModel(package.id);
        final candidate = AssistantModelCandidate(
          id: runtimeId,
          name: package.name,
          runtime: 'GGUF · llama.cpp',
          description: 'Scribe chat package',
          bestFor: const [AssistantTask.chat],
          tags: const ['Local'],
          privacyLabel: 'Private',
          sizeLabel: package.fileSizeDisplay,
          available: true,
          actionLabel: 'Start',
          local: true,
          package: package,
        );

        final missing = AssistantRuntimeService(
          llamaGguf: _FakeLlamaGgufService(
            isAvailableResult: true,
            generatedChunks: ['should not run'],
          ),
        );
        expect(
          () => missing.generateText(selectedModelId: runtimeId, prompt: 'hi'),
          throwsA(
            isA<AssistantRuntimeUnavailableException>().having(
              (error) => error.message,
              'message',
              offlinePackageCatalogMissingMessage,
            ),
          ),
        );

        final loadedGguf = _FakeLlamaGgufService(
          isAvailableResult: true,
          loadModelResult: true,
          generatedChunks: [
            '+2=4\nAiro: Sure, I can help you with that. Ready to proceed?',
          ],
        );
        final service = AssistantRuntimeService(
          llamaGguf: loadedGguf,
          loadAssistantModelLibrary: () async => AssistantModelLibraryState(
            task: AssistantTask.chat,
            deviceLabel: 'Mac',
            platformLabel: 'MACOS',
            candidates: [candidate],
            recommended: candidate,
            defaultPackages: const {},
          ),
        );
        expect(
          await service.generateText(selectedModelId: runtimeId, prompt: '2+2'),
          '+2=4',
        );
        expect(loadedGguf.lastMaxTokens, 512);
      },
    );

    test(
      'emits bounded debug traces for Gemini Nano requests and responses',
      () async {
        final traces = <AssistantRuntimeDebugTrace>[];
        final service = AssistantRuntimeService(
          isGeminiNanoSupported: () async => true,
          initializeGeminiNano: () async => true,
          generateGeminiNanoText: (_) async => 'Airo helps with planning.',
          debugTraceEmitter: traces.add,
        );

        final text = await service.generateText(
          selectedModelId: geminiNanoAssistantModelId,
          prompt: 'what does airo do?',
          systemPrompt: 'You are Airo.',
        );

        expect(text, 'Airo helps with planning.');
        expect(traces.map((trace) => trace.stage), ['request', 'response']);
        expect(traces.first.runtimeId, geminiNanoAssistantModelId);
        expect(traces.first.systemPromptPreview, contains('You are Airo.'));
        expect(traces.first.promptPreview, contains('what does airo do?'));
        expect(
          traces.last.responsePreview,
          contains('Airo helps with planning.'),
        );
      },
    );

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
      'resolves a cloud fallback for an unavailable local runtime',
      () async {
        const nano = AssistantModelCandidate(
          id: geminiNanoAssistantModelId,
          name: 'Gemini Nano',
          runtime: 'AICore on-device',
          description: 'Local runtime',
          bestFor: [AssistantTask.chat],
          tags: ['Local'],
          privacyLabel: 'Prompt stays on device',
          sizeLabel: 'System managed',
          available: false,
          actionLabel: 'Needs setup',
          local: true,
        );
        const cloud = AssistantModelCandidate(
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
        );
        final service = AssistantRuntimeService(
          loadAssistantModelLibrary: () async =>
              const AssistantModelLibraryState(
                task: AssistantTask.chat,
                deviceLabel: 'Pixel 9',
                platformLabel: 'ANDROID',
                candidates: [nano, cloud],
                recommended: nano,
                defaultPackages: {},
              ),
        );

        final fallback = await service.resolveFallback(
          failedRuntimeId: geminiNanoAssistantModelId,
          reason: 'Gemini Nano is not available on this device.',
        );

        expect(fallback, isNotNull);
        expect(fallback?.fallbackRuntimeId, geminiCloudAssistantModelId);
        expect(fallback?.failedRuntimeName, 'Gemini Nano');
      },
    );

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

    test(
      'returns ready after Gemini Nano warmup without touching LiteRT setup',
      () async {
        var liteRtAvailabilityChecks = 0;
        var liteRtWarmups = 0;
        var compatibilityChecks = 0;
        final service = AssistantRuntimeService(
          isGeminiNanoSupported: () async => true,
          initializeGeminiNano: () async => true,
          warmupGeminiNano: () async => true,
          isLiteRtAvailable: () async {
            liteRtAvailabilityChecks++;
            return false;
          },
          warmupLiteRtInstalledModel: () async {
            liteRtWarmups++;
            return false;
          },
          warmupLiteRtModel: (_) async {
            liteRtWarmups++;
            return false;
          },
          checkModelCompatibility: (_) async {
            compatibilityChecks++;
            return ModelCompatibilityResult.compatible(MemorySeverity.safe);
          },
          loadDeviceInfo: () async => {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
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

        expect(result.status, AssistantRuntimePreparationStatus.ready);
        expect(liteRtAvailabilityChecks, 0);
        expect(liteRtWarmups, 0);
        expect(compatibilityChecks, 0);
      },
    );

    test('blocks Gemini Nano when initialization fails', () async {
      final progress = <AssistantRuntimePreparationProgress>[];
      final service = AssistantRuntimeService(
        isGeminiNanoSupported: () async => true,
        initializeGeminiNano: () async => false,
        loadDeviceInfo: () async => {
          'manufacturer': 'Google',
          'model': 'Pixel 9',
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
        onProgress: progress.add,
      );

      expect(result.status, AssistantRuntimePreparationStatus.blocked);
      expect(result.diagnostic?.reasonCode, 'init_failed');
      expect(
        progress.map((event) => event.phase),
        containsAllInOrder([
          AssistantRuntimePreparationPhase.validate,
          AssistantRuntimePreparationPhase.allocate,
        ]),
      );
    });

    test('cancels Gemini Nano preparation after warmup', () async {
      var cancelChecks = 0;
      final service = AssistantRuntimeService(
        isGeminiNanoSupported: () async => true,
        initializeGeminiNano: () async => true,
        warmupGeminiNano: () async => true,
        loadDeviceInfo: () async => const {'platform': 'android'},
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
        isCancelled: () => ++cancelChecks >= 4,
      );

      expect(result.status, AssistantRuntimePreparationStatus.cancelled);
    });

    test('streams Gemini Nano chunks and ignores empty tokens', () async {
      final traces = <AssistantRuntimeDebugTrace>[];
      final service = AssistantRuntimeService(
        isGeminiNanoSupported: () async => true,
        initializeGeminiNano: () async => true,
        generateGeminiNanoStream: (_) =>
            Stream<String>.fromIterable(['', 'hello', ' ', ' world']),
        debugTraceEmitter: traces.add,
      );

      final chunks = await service
          .generateTextStream(
            selectedModelId: geminiNanoAssistantModelId,
            prompt: 'say hello',
            systemPrompt: 'brief',
          )
          .toList();

      expect(chunks, ['hello', ' world']);
      expect(
        traces.where((trace) => trace.detail == 'stream-chunk'),
        hasLength(2),
      );
    });

    test('reports empty Gemini Nano streams as unavailable', () async {
      final service = AssistantRuntimeService(
        isGeminiNanoSupported: () async => true,
        initializeGeminiNano: () async => true,
        generateGeminiNanoStream: (_) =>
            Stream<String>.fromIterable(['', '   ']),
      );

      await expectLater(
        () => service
            .generateTextStream(
              selectedModelId: geminiNanoAssistantModelId,
              prompt: 'hello',
            )
            .drain<void>(),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            ChatOutputVerifier.userMessageFor(OutputVerification.incomplete),
          ),
        ),
      );
      expect(
        service.lastReliabilityDiagnostic?.failureMode,
        FailureMode.pm06LogicCollapse,
      );
    });

    test('routes non-stream runtimes through single response stream', () async {
      final service = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => true,
        generateCloudText: (_) async => 'cloud response',
      );

      final chunks = await service
          .generateTextStream(
            selectedModelId: geminiCloudAssistantModelId,
            prompt: 'hello',
          )
          .toList();

      expect(chunks, ['cloud response']);
    });

    test('throws structured errors for missing and unknown runtimes', () async {
      final service = AssistantRuntimeService();

      await expectLater(
        () => service.generateText(selectedModelId: '  ', prompt: 'hello'),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            noAssistantModelSelectedMessage,
          ),
        ),
      );
      await expectLater(
        () => service.generateText(
          selectedModelId: 'runtime-does-not-exist',
          prompt: 'hello',
        ),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            unsupportedAssistantRuntimeMessage,
          ),
        ),
      );
    });

    test('trims cloud responses and rejects empty cloud output', () async {
      final service = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => true,
        generateCloudText: (_) async => '  trimmed cloud  ',
      );

      final text = await service.generateText(
        selectedModelId: geminiCloudAssistantModelId,
        prompt: 'hello',
      );
      expect(text, 'trimmed cloud');
      expect(service.lastReliabilityDiagnostic, isNull);

      final emptyService = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => true,
        generateCloudText: (_) async => '   ',
      );
      await expectLater(
        () => emptyService.generateText(
          selectedModelId: geminiCloudAssistantModelId,
          prompt: 'hello',
        ),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            ChatOutputVerifier.userMessageFor(OutputVerification.incomplete),
          ),
        ),
      );
      expect(
        emptyService.lastReliabilityDiagnostic?.failureMode,
        FailureMode.pm06LogicCollapse,
      );
      expect(emptyService.reliabilityLog.checkpoints, hasLength(1));
      expect(
        emptyService.reliabilityLog.lastFailure?.runtimeError,
        RuntimeFailure.r06VerificationFailure,
      );
      expect(
        emptyService.reliabilityLog.checkpoints.toString(),
        isNot(contains('hello')),
      );
    });

    test('empty cloud failure survives a second service hydrate', () async {
      final store = MemoryReliabilityCheckpointStore();
      final emptyService = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => true,
        generateCloudText: (_) async => '   ',
        checkpointStore: store,
      );
      await expectLater(
        () => emptyService.generateText(
          selectedModelId: geminiCloudAssistantModelId,
          prompt: 'hello',
        ),
        throwsA(isA<AssistantRuntimeUnavailableException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.encoded, isNotNull);
      expect(store.encoded, isNot(contains('hello')));
      expect(store.encoded, contains('PM-06'));
      expect(store.encoded, contains('AIRO-R06'));

      final second = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => true,
        generateCloudText: (_) async => 'ok',
        checkpointStore: MemoryReliabilityCheckpointStore(store.encoded),
      );
      final text = await second.generateText(
        selectedModelId: geminiCloudAssistantModelId,
        prompt: 'hello',
      );
      expect(text, 'ok');
      expect(second.reliabilityLog.checkpoints, hasLength(1));
      expect(
        second.reliabilityLog.lastFailure?.runtimeError,
        RuntimeFailure.r06VerificationFailure,
      );
      expect(second.reliabilityLog.encode(), isNot(contains('hello')));
    });

    test(
      'prefs checkpoint store round-trips metadata without prompt text',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await PreferencesStore.create();
        final store = PreferencesReliabilityCheckpointStore(prefs);
        const secret = 'SECRET_PROMPT_BODY ignore previous instructions';
        final log = ExecutionLog();
        log.record(
          FailureClassifier.recordChatCompletion(
            executionId: 'chat-1',
            text: secret,
            engineOk: false,
          ),
        );
        await store.save(log.encode());
        final raw = await store.load();
        expect(raw, isNotNull);
        expect(raw, isNot(contains(secret)));
        expect(raw, contains('PM-08'));
        expect(raw, contains('AIRO-R07'));
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
      'does not block LiteRT packages when only transient free RAM is low',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat],
        );
        var warmed = false;
        final service = AssistantRuntimeService(
          isLiteRtAvailable: () async => true,
          warmupLiteRtModel: (_) async {
            warmed = true;
            return true;
          },
          loadDeviceInfo: () async => {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
            'platform': 'android',
          },
          checkModelCompatibility: (_) async => const ModelCompatibilityResult(
            isCompatible: true,
            memorySeverity: MemorySeverity.critical,
            reason:
                'This package fits the device budget, but only 885 MB is currently free. It needs 2.4 GB available to warm up cleanly.',
            availableMemoryMB: 885,
            requiredMemoryMB: 2458,
          ),
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

        expect(result.status, AssistantRuntimePreparationStatus.ready);
        expect(warmed, isTrue);
      },
    );

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

    test(
      'honors reduced context override for LiteRT checks and warmup',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          filePath: '/models/gemma-4-e2b-it-litertlm.task',
          contextLength: 32768,
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat, ModelCapability.reasoning],
        );
        var compatibilityContext = 0;
        var warmedContext = 0;
        final service = AssistantRuntimeService(
          isLiteRtAvailable: () async => true,
          warmupLiteRtModel: (model) async {
            warmedContext = model.contextLength;
            return true;
          },
          loadDeviceInfo: () async => const {
            'manufacturer': 'Google',
            'model': 'Pixel 9',
            'platform': 'android',
          },
          checkModelCompatibility: (model) async {
            compatibilityContext = model.contextLength;
            return ModelCompatibilityResult.compatible(MemorySeverity.safe);
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
          contextLengthOverride: 1024,
        );

        expect(result.status, AssistantRuntimePreparationStatus.ready);
        expect(compatibilityContext, 1024);
        expect(warmedContext, 1024);
      },
    );

    test(
      'blocks LiteRT setup when warmup fails or package is only a download card',
      () async {
        final package = OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 2 * 1024 * 1024 * 1024,
          filePath: '/models/gemma-4-e2b-it-litertlm.task',
          backendPreference: ModelBackendPreference.gpu,
          provider: AIProvider.gemma,
          capabilities: const [ModelCapability.chat],
        );
        final service = AssistantRuntimeService(
          isLiteRtAvailable: () async => true,
          warmupLiteRtModel: (_) async => false,
          loadDeviceInfo: () async => const {'platform': 'android'},
          checkModelCompatibility: (_) async =>
              ModelCompatibilityResult.compatible(MemorySeverity.safe),
        );

        final failedWarmup = await service.prepareRuntime(
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
        expect(failedWarmup.status, AssistantRuntimePreparationStatus.blocked);
        expect(failedWarmup.diagnostic?.reasonCode, 'warmup_failed');

        final downloadOnlyService = AssistantRuntimeService(
          isLiteRtAvailable: () async => true,
          warmupLiteRtModel: (_) async => true,
          loadDeviceInfo: () async => const {'platform': 'android'},
        );
        final downloadOnly = await downloadOnlyService.prepareRuntime(
          candidate: AssistantModelCandidate(
            id: litertGemmaAssistantModelId,
            name: 'Gemma mobile package',
            runtime: 'LiteRT-LM local model',
            description: 'Local package',
            bestFor: const [AssistantTask.chat],
            tags: const ['Local'],
            privacyLabel: 'Prompt stays on device',
            sizeLabel: package.fileSizeDisplay,
            available: false,
            actionLabel: 'Download',
            local: true,
            opensModelManager: true,
            package: package,
          ),
        );
        expect(downloadOnly.status, AssistantRuntimePreparationStatus.blocked);
        expect(downloadOnly.diagnostic?.reasonCode, 'package_missing');
      },
    );

    test(
      'returns no fallback when every alternate runtime is unavailable',
      () async {
        const nano = AssistantModelCandidate(
          id: geminiNanoAssistantModelId,
          name: 'Gemini Nano',
          runtime: 'AICore',
          description: 'Local',
          bestFor: [AssistantTask.chat],
          tags: ['Local'],
          privacyLabel: 'Private',
          sizeLabel: 'System',
          available: false,
          actionLabel: 'Blocked',
          local: true,
        );
        const cloud = AssistantModelCandidate(
          id: geminiCloudAssistantModelId,
          name: 'Gemini Cloud',
          runtime: 'Cloud',
          description: 'Cloud',
          bestFor: [AssistantTask.chat],
          tags: ['Cloud'],
          privacyLabel: 'Remote',
          sizeLabel: 'No download',
          available: false,
          actionLabel: 'Configure',
          local: false,
        );
        final service = AssistantRuntimeService(
          loadAssistantModelLibrary: () async =>
              const AssistantModelLibraryState(
                task: AssistantTask.chat,
                deviceLabel: 'Pixel 9',
                platformLabel: 'ANDROID',
                candidates: [nano, cloud],
                recommended: nano,
                defaultPackages: {},
              ),
        );

        final fallback = await service.resolveFallback(
          failedRuntimeId: geminiNanoAssistantModelId,
          excludedRuntimeIds: {geminiCloudAssistantModelId},
        );

        expect(fallback, isNull);
      },
    );
  });
}

class _FakeLlamaGgufService extends LlamaGgufService {
  _FakeLlamaGgufService({
    required this.isAvailableResult,
    this.loadModelResult = false,
    this.generatedChunks = const [],
    this.stats,
  });

  final bool isAvailableResult;
  final bool loadModelResult;
  final List<String> generatedChunks;
  final GgufRuntimeStats? stats;
  int? loadedContextSize;
  int stopCount = 0;

  @override
  GgufRuntimeStats? get lastStats => stats;

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Future<bool> loadModel(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async {
    loadedContextSize = contextSize;
    return loadModelResult;
  }

  @override
  Future<GgufLoadOutcome> loadModelOutcome(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async {
    loadedContextSize = contextSize;
    return loadModelResult
        ? const GgufLoadOutcome.success()
        : GgufLoadOutcome.engineError('test_load_failed');
  }

  @override
  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    String? grammar,
  }) {
    lastPrompt = prompt;
    lastMaxTokens = maxTokens;
    lastGrammar = grammar;
    return Stream<String>.fromIterable(generatedChunks);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  String? lastPrompt;
  int? lastMaxTokens;
  String? lastGrammar;
}

class _UrlOnlyLiteRtClient implements LiteRtLmClient {
  @override
  Future<bool> activeModelExists({String? modelPath}) async => true;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async => 'should-not-run';

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {}

  @override
  Future<String?> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async => null;
}
