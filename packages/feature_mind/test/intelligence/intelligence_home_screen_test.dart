import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/intelligence/intelligence_home_screen.dart';
import 'package:feature_mind/src/intelligence/intelligence_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OfflineModelInfo _chat({required bool downloaded}) => OfflineModelInfo(
  id: 'chat-model',
  name: 'Chat model',
  family: ModelFamily.other,
  fileSizeBytes: 1000,
  filePath: downloaded ? '/tmp/chat' : null,
  downloadUrl: 'https://example.test/chat',
  capabilities: const [ModelCapability.chat],
);

void main() {
  testWidgets('Overview asks for a job and hides empty capabilities', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          intelligenceCatalogProvider.overrideWithValue([
            _chat(downloaded: true),
          ]),
          intelligenceMemoryLoaderProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: IntelligenceHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What do you want Airo to do?'), findsOneWidget);
    expect(find.text('CHAT'), findsWidgets);
    expect(find.text('General conversation'), findsOneWidget);
    expect(find.text('Vision'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('phone Overview pushes Advanced instead of inner chips', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          intelligenceCatalogProvider.overrideWithValue([
            _chat(downloaded: true),
          ]),
          intelligenceMemoryLoaderProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: IntelligenceHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ADVANCED'), findsOneWidget);
    expect(find.text('Capabilities'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });
}
