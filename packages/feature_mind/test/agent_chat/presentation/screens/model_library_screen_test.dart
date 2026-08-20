import 'dart:io';

import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/fake_assistant_host_adapter.dart';

void main() {
  test('does not advertise a downloaded GGUF file as locally runnable', () {
    final model = OfflineModelInfo(
      id: 'qwen2-1.5b-q4',
      name: 'Qwen2 1.5B',
      family: ModelFamily.qwen,
      fileSizeBytes: 1_100_000_000,
      filePath: '/models/qwen2-1.5b-q4.gguf',
      downloadUrl: 'https://example.test/qwen2.gguf',
      provider: AIProvider.gguf,
    );

    final candidate = AssistantModelCandidate.fromOfflineModel(
      model,
      nativeGgufAvailable: false,
    );

    expect(candidate.available, isFalse);
    expect(candidate.actionLabel, 'Runtime unavailable');
    expect(candidate.unavailableReason, contains('llama.cpp'));
  });

  test('downloaded LiteRT is runnable on Android when backend is ready', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final model = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2_000_000_000,
      filePath: '/models/gemma-4-e2b-it.litertlm',
      provider: AIProvider.gemma,
      runtime: InferenceRuntime.litertLm,
      platformSupport: PlatformSupport.androidOnly(),
    );

    final candidate = AssistantModelCandidate.fromOfflineModel(
      model,
      liteRtNativeAvailable: true,
    );

    expect(candidate.available, isTrue);
    expect(candidate.actionLabel, 'Start');
  });

  test('downloaded LiteRT is not runnable on macOS even when downloaded', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final model = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2_000_000_000,
      filePath: '/models/gemma-4-e2b-it.litertlm',
      provider: AIProvider.gemma,
      runtime: InferenceRuntime.litertLm,
      platformSupport: PlatformSupport.androidOnly(),
    );

    final candidate = AssistantModelCandidate.fromOfflineModel(
      model,
      liteRtNativeAvailable: true,
    );

    expect(candidate.available, isFalse);
    expect(candidate.actionLabel, contains('macOS'));
    expect(candidate.unavailableReason, contains('GGUF'));
  });

  test('LiteRT is not ready from native availability alone', () {
    expect(
      AssistantModelLibraryState.isLiteRtReady(
        runtimeAvailable: true,
        hasDownloadedPackage: false,
        hasConfiguredModelPath: false,
      ),
      isFalse,
    );
    // A path setting alone is not enough for the picker to advertise a
    // runnable Gemma card; the artifact must be verified as installed.
    expect(
      AssistantModelLibraryState.isLiteRtReady(
        runtimeAvailable: true,
        hasDownloadedPackage: false,
        hasConfiguredModelPath: true,
      ),
      isFalse,
    );
    expect(
      AssistantModelLibraryState.isLiteRtReady(
        runtimeAvailable: false,
        hasDownloadedPackage: true,
        hasConfiguredModelPath: false,
      ),
      isFalse,
    );
    expect(
      AssistantModelLibraryState.isLiteRtReady(
        runtimeAvailable: true,
        hasDownloadedPackage: false,
        hasConfiguredModelPath: false,
      ),
      isFalse,
    );
  });

  test(
    'chat prefers an installed Gemma package over Gemini Nano on Android',
    () {
      const nano = AssistantModelCandidate(
        id: geminiNanoAssistantModelId,
        name: 'Gemini Nano',
        runtime: 'AICore on-device',
        description: 'System runtime',
        bestFor: [AssistantTask.chat],
        tags: ['Local'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: 'System managed',
        available: true,
        actionLabel: 'Start chat',
        local: true,
      );
      const gemma = AssistantModelCandidate(
        id: litertGemmaAssistantModelId,
        name: 'Gemma mobile package',
        runtime: 'LiteRT-LM local model',
        description: 'Downloaded package',
        bestFor: [AssistantTask.chat],
        tags: ['Local', 'Gemma'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: '2.4 GB',
        available: true,
        actionLabel: 'Start chat',
        local: true,
      );

      expect(
        AssistantModelLibraryState.recommend(
          [nano, gemma],
          AssistantTask.chat,
          const {},
          isAndroidHost: true,
        ).id,
        litertGemmaAssistantModelId,
      );
    },
  );

  test('recommend does not prefer LiteRT on desktop hosts', () {
    const nano = AssistantModelCandidate(
      id: geminiNanoAssistantModelId,
      name: 'Gemini Nano',
      runtime: 'AICore on-device',
      description: 'System runtime',
      bestFor: [AssistantTask.chat],
      tags: ['Local'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: 'System managed',
      available: true,
      actionLabel: 'Start chat',
      local: true,
    );
    final gguf = AssistantModelCandidate(
      id: 'offline-qwen2-1.5b-q4',
      name: 'Qwen2 1.5B',
      runtime: 'GGUF · llama.cpp',
      description: 'Downloaded GGUF',
      bestFor: [AssistantTask.chat],
      tags: ['Local'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: '1.1 GB',
      available: true,
      actionLabel: 'Start chat',
      local: true,
    );
    const gemma = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Downloaded package',
      bestFor: [AssistantTask.chat],
      tags: ['Local', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: '2.4 GB',
      available: true,
      actionLabel: 'Start chat',
      local: true,
    );

    expect(
      AssistantModelLibraryState.recommend(
        [nano, gemma, gguf],
        AssistantTask.chat,
        {
          AssistantTask.chat: OfflineModelInfo(
            id: 'qwen2-1.5b-q4',
            name: 'Qwen2 1.5B',
            family: ModelFamily.qwen,
            fileSizeBytes: 1_100_000_000,
            filePath: '/models/qwen2-1.5b-q4.gguf',
            provider: AIProvider.gguf,
          ),
        },
        isAndroidHost: false,
      ).id,
      assistantModelIdForOfflineModel('qwen2-1.5b-q4'),
    );
  });

  test('loads deterministic local, cloud, and downloaded candidates', () async {
    final gemmaPackage = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      filePath: '/models/gemma-4-e2b-it.litertlm',
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
      backendPreference: ModelBackendPreference.gpu,
    );
    final actionPackage = OfflineModelInfo(
      id: 'mobile-actions-270m-litertlm',
      name: 'MobileActions-270M',
      family: ModelFamily.gemma,
      fileSizeBytes: 276 * 1024 * 1024,
      filePath: '/models/mobile-actions-270m.litertlm',
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.mobileActions],
      backendPreference: ModelBackendPreference.npu,
    );
    final tempDir = await Directory.systemTemp.createTemp('airo_gguf_test');
    final ggufPath = '${tempDir.path}/qwen2-1.5b-q4.gguf';
    final ggufFile = File(ggufPath);
    await ggufFile.writeAsBytes(List<int>.filled(1024, 0));
    final downloadedGguf = OfflineModelInfo(
      id: 'qwen2-1.5b-q4',
      name: 'Qwen2 1.5B Q4',
      family: ModelFamily.qwen,
      fileSizeBytes: 1024,
      filePath: ggufPath,
      provider: AIProvider.gguf,
      capabilities: const [ModelCapability.chat],
    );

    final state = await AssistantModelLibraryState.load(
      task: AssistantTask.reasoning,
      isAndroidHost: true,
      isNanoSupported: () async => true,
      loadDeviceInfo: () async => {
        'manufacturer': 'Google',
        'model': 'Pixel 9',
      },
      isLiteRtAvailable: () async => true,
      hasConfiguredModelPath: false,
      isGgufAvailable: () async => true,
      initializeCloud: () async {},
      isCloudAvailable: () => true,
      loadDefaultPackages: () async => {
        AssistantTask.chat: gemmaPackage,
        AssistantTask.reasoning: gemmaPackage,
        AssistantTask.documents: gemmaPackage,
        AssistantTask.skills: gemmaPackage,
        AssistantTask.actions: actionPackage,
      },
      loadCompatibilityByModelId: (packages) async => {
        gemmaPackage.id: ModelCompatibilityResult.compatible(
          MemorySeverity.safe,
        ),
        actionPackage.id: ModelCompatibilityResult.compatible(
          MemorySeverity.warning,
        ),
        downloadedGguf.id: ModelCompatibilityResult.compatible(
          MemorySeverity.safe,
        ),
      },
      hydrateDownloadedModel: (model) async => downloadedGguf,
      mobileRecommended: [downloadedGguf],
      platformLabelOverride: 'ANDROID',
    );

    expect(state.deviceLabel, 'Google Pixel 9');
    expect(state.platformLabel, 'ANDROID');
    expect(state.recommended.id, litertGemmaAssistantModelId);
    expect(state.candidateById(geminiNanoAssistantModelId)?.available, isTrue);
    expect(state.candidateById(geminiCloudAssistantModelId)?.available, isTrue);
    expect(state.candidateById(litertGemmaAssistantModelId)?.available, isTrue);
    expect(
      state
          .candidateById(assistantModelIdForOfflineModel(actionPackage.id))
          ?.available,
      isTrue,
    );
    expect(
      state
          .candidateById(assistantModelIdForOfflineModel(downloadedGguf.id))
          ?.available,
      isTrue,
    );
    expect(
      state.candidateById(litertGemmaAssistantModelId)?.compatibility,
      isNotNull,
    );
  });

  test(
    'load hides LiteRT card when no verified package is downloaded',
    () async {
      final catalogOnlyPackage = OfflineModelInfo(
        id: 'gemma-4-e2b-it-litertlm',
        name: 'Gemma 4 E2B',
        family: ModelFamily.gemma,
        fileSizeBytes: 2 * 1024 * 1024 * 1024,
        provider: AIProvider.gemma,
        capabilities: const [ModelCapability.chat],
        downloadUrl: 'https://example.test/gemma-4-e2b-it.litertlm',
      );

      final state = await AssistantModelLibraryState.load(
        task: AssistantTask.chat,
        isAndroidHost: true,
        isNanoSupported: () async => false,
        loadDeviceInfo: () async => {
          'manufacturer': 'Google',
          'model': 'Pixel 9',
        },
        isLiteRtAvailable: () async => true,
        hasConfiguredModelPath: true,
        isGgufAvailable: () async => false,
        initializeCloud: () async {},
        isCloudAvailable: () => false,
        loadDefaultPackages: () async => {
          AssistantTask.chat: catalogOnlyPackage,
          AssistantTask.reasoning: catalogOnlyPackage,
        },
        loadCompatibilityByModelId: (packages) async => {
          catalogOnlyPackage.id: ModelCompatibilityResult.compatible(
            MemorySeverity.safe,
          ),
        },
        hydrateDownloadedModel: (model) async => model,
        mobileRecommended: const [],
        platformLabelOverride: 'ANDROID',
      );

      expect(state.candidateById(litertGemmaAssistantModelId), isNull);
      expect(
        state.candidates.map((candidate) => candidate.id),
        contains(geminiNanoAssistantModelId),
      );
      expect(
        state.candidateById(geminiNanoAssistantModelId)?.available,
        isFalse,
      );
      expect(
        state.candidateById(geminiCloudAssistantModelId)?.available,
        isFalse,
      );
      expect(state.recommended.id, geminiNanoAssistantModelId);
    },
  );

  testWidgets(
    'shows diagnostics instead of launching unsupported local runtime',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final candidate = const AssistantModelCandidate(
        id: geminiNanoAssistantModelId,
        name: 'Gemini Nano',
        runtime: 'AICore on-device',
        description: 'Local runtime',
        bestFor: [AssistantTask.chat],
        tags: ['Local'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: 'System managed',
        available: true,
        actionLabel: 'Start chat',
        local: true,
      );

      final state = AssistantModelLibraryState(
        task: AssistantTask.chat,
        deviceLabel: 'Pixel 8',
        platformLabel: 'ANDROID',
        candidates: [candidate],
        recommended: candidate,
        defaultPackages: const {},
      );

      var selected = false;
      final runtimeService = AssistantRuntimeService(
        isGeminiNanoSupported: () async => false,
        loadDeviceInfo: () async => {
          'manufacturer': 'Google',
          'model': 'Pixel 8',
          'platform': 'android',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantHostAdapterProvider.overrideWithValue(
              FakeAssistantHostAdapter(),
            ),
            assistantModelLibraryProvider.overrideWith((ref) async => state),
            selectedAssistantModelIdProvider.overrideWith(
              (ref) => _SelectedAssistantModelNotifier(),
            ),
          ],
          child: MaterialApp(
            home: ModelLibraryScreen(
              runtimeService: runtimeService,
              onModelSelected: (_) => selected = true,
              onOpenModelManager: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Start chat'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start chat'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Gemini Nano is not supported on this device.'),
        findsOneWidget,
      );
      expect(find.text('Copy diagnostics'), findsOneWidget);
      expect(selected, isFalse);
    },
  );

  testWidgets('project cards do not overflow on narrow mobile widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    SharedPreferences.setMockInitialValues({});

    final package = OfflineModelInfo(
      id: 'mobile-actions-270m-litertlm',
      name: 'MobileActions-270M',
      family: ModelFamily.gemma,
      fileSizeBytes: 276 * 1024 * 1024,
      backendPreference: ModelBackendPreference.npu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.mobileActions],
      learnMoreUrl: 'https://example.com/models/mobile-actions',
    );

    final candidate = AssistantModelCandidate(
      id: 'litert-gemma',
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description:
          'Default local package for planning, documents, and medium reasoning.',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local', 'Downloadable', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: '2 GB to 4 GB typical',
      available: false,
      actionLabel: 'Download package',
      unavailableReason:
          'Set LITERT_LM_MODEL_PATH or LITERT_LM_MODEL_URL, or install a compatible local model.',
      local: true,
      opensModelManager: true,
      package: package,
    );

    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('General Chat'), findsOneWidget);
    expect(find.text('Download package'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows safe device-fit details for local packages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final package = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      backendPreference: ModelBackendPreference.gpu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
      filePath: '/models/gemma-4-e2b-it.litertlm',
    );
    final candidate = AssistantModelCandidate(
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
      compatibility: const ModelCompatibilityResult(
        isCompatible: true,
        memorySeverity: MemorySeverity.safe,
        availableMemoryMB: 6144,
        requiredMemoryMB: 2048,
      ),
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Device fit: Safe to load'), findsWidgets);
    expect(find.text('Plenty of memory available'), findsWidgets);
    expect(find.text('Needs 2048 MB, device has 6144 MB free.'), findsWidgets);
  });

  testWidgets('shows blocked device-fit details for incompatible packages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final package = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      backendPreference: ModelBackendPreference.gpu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
    );
    final candidate = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Local package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: package.fileSizeDisplay,
      available: false,
      actionLabel: 'Download package',
      local: true,
      opensModelManager: true,
      package: package,
      compatibility: const ModelCompatibilityResult(
        isCompatible: false,
        memorySeverity: MemorySeverity.blocked,
        reason: 'Insufficient memory.',
        availableMemoryMB: 1024,
        requiredMemoryMB: 4096,
      ),
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Small Phone',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Device fit: Cannot load'), findsWidgets);
    expect(find.text('Insufficient memory.'), findsWidgets);
    expect(find.text('Needs 4096 MB, device has 1024 MB free.'), findsWidgets);
  });
  testWidgets('selects Gemma and closes setup after a successful warmup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final package = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      backendPreference: ModelBackendPreference.gpu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
      filePath: '/models/gemma-4-e2b-it.litertlm',
    );
    final candidate = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Local package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: package.fileSizeDisplay,
      available: true,
      actionLabel: 'Start',
      local: true,
      package: package,
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );
    AssistantModelCandidate? selected;
    final runtimeService = AssistantRuntimeService(
      loadDeviceInfo: () async => {
        'manufacturer': 'Google',
        'model': 'Pixel 9',
        'platform': 'android',
      },
      isLiteRtAvailable: () async => true,
      checkModelCompatibility: (_) async => const ModelCompatibilityResult(
        isCompatible: true,
        memorySeverity: MemorySeverity.safe,
      ),
      warmupLiteRtModel: (_) async => true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            runtimeService: runtimeService,
            onModelSelected: (value) => selected = value,
            onOpenModelManager: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start chat'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start chat'));
    await tester.pumpAndSettle();
    expect(selected?.id, litertGemmaAssistantModelId);
    expect(find.text('General Chat setup'), findsNothing);
  });

  testWidgets('setup failure dialog shows memory diagnostics', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final package = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      backendPreference: ModelBackendPreference.gpu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
      filePath: '/models/gemma-4-e2b-it.litertlm',
    );
    final candidate = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Local package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: package.fileSizeDisplay,
      available: true,
      actionLabel: 'Start',
      local: true,
      package: package,
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );
    final runtimeService = AssistantRuntimeService(
      loadDeviceInfo: () async => {
        'manufacturer': 'Google',
        'model': 'Pixel 9',
        'platform': 'android',
      },
      isLiteRtAvailable: () async => true,
      checkModelCompatibility: (_) async => const ModelCompatibilityResult(
        isCompatible: false,
        memorySeverity: MemorySeverity.blocked,
        reason: 'Not enough transient memory for warmup.',
        availableMemoryMB: 1536,
        requiredMemoryMB: 3072,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            runtimeService: runtimeService,
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start chat'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start chat'));
    await tester.pumpAndSettle();

    expect(
      find.text('This local package exceeds the current device budget.'),
      findsOneWidget,
    );
    expect(find.text('Runtime: Gemma mobile package'), findsOneWidget);
    expect(find.text('Reason code: compatibility_blocked'), findsOneWidget);
    expect(
      find.text('Memory: 1536 MB available · 3072 MB estimated peak'),
      findsOneWidget,
    );
    expect(
      find.text('Not enough transient memory for warmup.'),
      findsOneWidget,
    );
  });

  testWidgets('download setup dialog opens model management when confirmed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final package = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma 4 E2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      backendPreference: ModelBackendPreference.gpu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
      learnMoreUrl: 'https://example.test/gemma',
    );
    final candidate = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Local package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: package.fileSizeDisplay,
      available: false,
      actionLabel: 'Download package',
      unavailableReason: 'Install the local package first.',
      local: true,
      opensModelManager: true,
      package: package,
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
    );
    var openedManager = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            onModelSelected: (_) {},
            onOpenModelManager: () => openedManager = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download package').first);
    await tester.pumpAndSettle();

    expect(find.text('Download General Chat package?'), findsOneWidget);
    expect(find.text('Package'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Download package').last,
    );
    await tester.pumpAndSettle();

    expect(openedManager, isTrue);
  });

  testWidgets('unavailable package dialog can route to profile settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const candidate = AssistantModelCandidate(
      id: 'cloud-fallback',
      name: 'Cloud fallback',
      runtime: 'Remote opt-in',
      description: 'Remote runtime',
      bestFor: [AssistantTask.chat],
      tags: ['Remote'],
      privacyLabel: 'Requires opt-in',
      sizeLabel: 'No local package',
      available: false,
      actionLabel: 'Configure',
      unavailableReason: 'No local runtime can satisfy this request yet.',
      local: false,
      opensModelManager: false,
    );
    const state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Desktop',
      platformLabel: 'MACOS',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {},
    );
    var openedManager = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            onModelSelected: (_) {},
            onOpenModelManager: () => openedManager = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start chat').first);
    await tester.pumpAndSettle();

    expect(find.text('General Chat setup needed'), findsOneWidget);
    expect(
      find.text('No local runtime can satisfy this request yet.'),
      findsWidgets,
    );

    await tester.tap(find.text('Open Profile settings'));
    await tester.pumpAndSettle();

    expect(openedManager, isTrue);
  });

  test('desktop profile recommends installed GGUF and hides LiteRT', () async {
    final gemma = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma-4-E2B-it',
      family: ModelFamily.gemma,
      fileSizeBytes: 2 * 1024 * 1024 * 1024,
      filePath: '/models/gemma-4-e2b-it.litertlm',
      provider: AIProvider.gemma,
      runtime: InferenceRuntime.litertLm,
      platformSupport: PlatformSupport.androidOnly(),
      capabilities: const [ModelCapability.chat],
    );
    final tempDir = await Directory.systemTemp.createTemp('airo_desktop_gguf');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final ggufPath = '${tempDir.path}/qwen.gguf';
    await File(ggufPath).writeAsBytes(List<int>.filled(1024, 0));
    final gguf = OfflineModelInfo(
      id: 'mind-scribe-qwen2.5-0.5b-instruct',
      name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
      family: ModelFamily.qwen,
      fileSizeBytes: 1024,
      filePath: ggufPath,
      provider: AIProvider.gguf,
      capabilities: const [ModelCapability.chat],
    );

    final state = await AssistantModelLibraryState.load(
      task: AssistantTask.chat,
      isAndroidHost: false,
      runtimeProfile: ModelRuntimeProfile.desktopGguf,
      isNanoSupported: () async => false,
      loadDeviceInfo: () async => {},
      isLiteRtAvailable: () async => true,
      isGgufAvailable: () async => true,
      initializeCloud: () async {},
      isCloudAvailable: () => false,
      loadCompatibilityByModelId: (_) async => {},
      hydrateDownloadedModel: (model) async => model,
      mobileRecommended: [gemma],
      loadAssistantDownloadedModels: () async => [gguf],
      platformLabelOverride: 'MACOS',
    );

    expect(
      state.candidateById(assistantModelIdForOfflineModel(gemma.id)),
      isNull,
    );
    expect(state.recommended.id, assistantModelIdForOfflineModel(gguf.id));
    expect(state.recommended.available, isTrue);
    expect(state.recommended.opensModelManager, isFalse);
  });

  test('desktop model library steers users toward GGUF setup copy', () async {
    final state = await AssistantModelLibraryState.load(
      task: AssistantTask.chat,
      isAndroidHost: false,
      isNanoSupported: () async => false,
      loadDeviceInfo: () async => {},
      isLiteRtAvailable: () async => false,
      isGgufAvailable: () async => false,
      initializeCloud: () async {},
      isCloudAvailable: () => false,
      loadDefaultPackages: () async => {},
      loadCompatibilityByModelId: (_) async => {},
      hydrateDownloadedModel: (model) async => model,
      mobileRecommended: const [],
      platformLabelOverride: 'MACOS',
    );

    final setup = state.candidateById('assistant-setup-required');
    expect(setup, isNotNull);
    expect(setup!.description, contains('GGUF'));
  });

  testWidgets('change-model picker lists installed GGUF packages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final qwen = AssistantModelCandidate(
      id: assistantModelIdForOfflineModel('mind-scribe-qwen2.5-0.5b-instruct'),
      name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
      runtime: 'GGUF · llama.cpp',
      description: 'Scribe chat package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local'],
      privacyLabel: 'Private',
      sizeLabel: '469 MB',
      available: true,
      actionLabel: 'Start',
      local: true,
      package: const OfflineModelInfo(
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
        family: ModelFamily.qwen,
        fileSizeBytes: 491000000,
        filePath: '/models/qwen.gguf',
        provider: AIProvider.gguf,
        capabilities: [ModelCapability.chat],
      ),
    );
    final phi = AssistantModelCandidate(
      id: assistantModelIdForOfflineModel('phi-3-mini-4k-q4'),
      name: 'Phi-3 Mini 4K',
      runtime: 'GGUF · llama.cpp',
      description: 'Downloaded chat package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local'],
      privacyLabel: 'Private',
      sizeLabel: '2.1 GB',
      available: true,
      actionLabel: 'Start',
      local: true,
      package: const OfflineModelInfo(
        id: 'phi-3-mini-4k-q4',
        name: 'Phi-3 Mini 4K',
        family: ModelFamily.phi,
        fileSizeBytes: 2300000000,
        filePath: '/models/phi.gguf',
        provider: AIProvider.phi,
        capabilities: [ModelCapability.chat],
      ),
    );
    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Mac',
      platformLabel: 'MACOS',
      candidates: [qwen, phi],
      recommended: qwen,
      defaultPackages: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith((ref) async => state),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ModelLibraryScreen(
            runtimeService: AssistantRuntimeService(
              loadDeviceInfo: () async => const {},
            ),
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Qwen2.5 0.5B Instruct (Q4_K_M)'), findsWidgets);
    expect(find.text('Phi-3 Mini 4K'), findsOneWidget);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = null;
  }
}
