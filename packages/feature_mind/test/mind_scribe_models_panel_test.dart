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
}) => OfflineModelInfo(
  id: id,
  name: name,
  family: ModelFamily.other,
  fileSizeBytes: 1000,
  filePath: downloaded ? '/tmp/$id' : null,
);

Map<String, OfflineModelInfo> _catalog() => {
  MindScribeModelIds.whisperMultilingual: _model(
    id: MindScribeModelIds.whisperMultilingual,
    name: 'Whisper Tiny (Multilingual)',
    downloaded: true,
  ),
  MindScribeModelIds.qwenGeneration: _model(
    id: MindScribeModelIds.qwenGeneration,
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    downloaded: true,
  ),
  MindScribeModelIds.sarvamGeneration: _model(
    id: MindScribeModelIds.sarvamGeneration,
    name: 'Sarvam-1 (Q4_K_M)',
  ),
};

void main() {
  testWidgets('shows featured best-overall recommendation', (tester) async {
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

    expect(find.textContaining('Best overall'), findsOneWidget);
    expect(find.text('Meeting scribe picks'), findsOneWidget);
    expect(find.text('Sarvam Edge ASR'), findsOneWidget);
  });
}
