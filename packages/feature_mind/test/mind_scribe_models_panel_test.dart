import 'package:core_ai/core_ai.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/mind_model_advisor.dart';
import 'package:feature_mind/src/mind_scribe_models_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OfflineModelInfo _model({
  required String id,
  required String name,
  bool downloaded = false,
  List<ModelCapability> capabilities = const [ModelCapability.chat],
  List<ModelModality> modalities = const [ModelModality.text],
  InferenceRuntime? runtime,
  ModelTask? task,
}) => OfflineModelInfo(
  id: id,
  name: name,
  family: ModelFamily.other,
  fileSizeBytes: 1000,
  filePath: downloaded ? '/tmp/$id' : null,
  downloadUrl: 'https://example.test/$id',
  capabilities: capabilities,
  modalities: modalities,
  runtime: runtime,
  task: task,
);

Map<String, OfflineModelInfo> _catalog() => {
  MindScribeModelIds.whisperMultilingual: _model(
    id: MindScribeModelIds.whisperMultilingual,
    name: 'Whisper Tiny (Multilingual)',
    downloaded: true,
    capabilities: const [ModelCapability.audioUnderstanding],
    modalities: const [ModelModality.audio],
    runtime: InferenceRuntime.whisper,
    task: ModelTask.speechToText,
  ),
  MindScribeModelIds.qwenGeneration: _model(
    id: MindScribeModelIds.qwenGeneration,
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    downloaded: true,
    capabilities: const [ModelCapability.meetingSummarization],
  ),
  MindScribeModelIds.sarvamGeneration: _model(
    id: MindScribeModelIds.sarvamGeneration,
    name: 'Sarvam-1 (Q4_K_M)',
    capabilities: const [ModelCapability.meetingSummarization],
  ),
};

void main() {
  testWidgets('shows Meeting Assistant with Automatic and named strategies', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MindScribeModelsPanel(
                scribeModelsById: _catalog(),
                entitlements: const LaunchPromoEntitlements(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meeting Assistant'), findsOneWidget);
    expect(find.text('Automatic'), findsWidgets);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Best overall'), findsNothing);
    expect(find.text('Meeting scribe picks'), findsNothing);
    expect(find.text('Sarvam Edge ASR'), findsNothing);
    expect(find.text('Standard (Qwen)'), findsNothing);
  });
}
