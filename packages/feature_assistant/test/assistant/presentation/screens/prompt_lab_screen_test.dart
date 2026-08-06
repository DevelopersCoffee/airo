import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:feature_assistant/src/assistant/presentation/screens/prompt_lab_screen.dart';

void main() {
  testWidgets('Prompt Lab exposes negative prompt and runtime controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PromptLabScreen()));
    expect(find.text('Prompt Lab'), findsOneWidget);
    expect(find.text('Negative prompt (optional)'), findsOneWidget);
    expect(find.textContaining('Temperature:'), findsOneWidget);
    expect(find.textContaining('Top-k:'), findsOneWidget);
    expect(find.textContaining('Maximum output:'), findsOneWidget);
  });

  testWidgets('image mode validates the local server before sending', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PromptLabScreen()));
    await tester.tap(find.text('Image'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), 'a quiet garden');
    await tester.scrollUntilVisible(
      find.text('Generate image'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate image'));
    await tester.pump();

    expect(
      find.text('Enter a valid local/private image server URL.'),
      findsOneWidget,
    );
  });

  testWidgets('text mode sends composed prompt to chat route', (tester) async {
    String? prefill;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PromptLabScreen()),
        GoRoute(
          path: '/assistant/chat',
          builder: (_, state) {
            prefill = state.uri.queryParameters['prefill'];
            return const Scaffold(body: Text('Chat route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField).at(0), 'Plan release');
    await tester.enterText(find.byType(TextField).at(1), 'remote fallback');
    await tester.scrollUntilVisible(
      find.text('Run with selected runtime'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Run with selected runtime'));
    await tester.pumpAndSettle();

    expect(find.text('Chat route'), findsOneWidget);
    expect(prefill, contains('Plan release'));
    expect(prefill, contains('Negative prompt: remote fallback'));
    expect(prefill, contains('Runtime controls:'));
  });

  testWidgets('image mode renders a generated image response', (tester) async {
    ImageGenerationRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: PromptLabScreen(
          initialImageMode: true,
          generateImage: (value) async {
            request = value;
            return const Success(
              GeneratedImage(
                base64Data:
                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
                    'DUlEQVR42mP8z8BQDwAFgwJ/lwI1MgAAAABJRU5ErkJggg==',
                revisedPrompt: 'quiet garden revised',
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField).at(0),
      'http://127.0.0.1:8188/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'quiet garden');
    await tester.scrollUntilVisible(
      find.text('Generate image'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate image'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(request?.prompt, 'quiet garden');
    expect(find.text('Revised prompt: quiet garden revised'), findsOneWidget);
    expect(find.textContaining('Image generation failed'), findsNothing);
  });

  testWidgets('image mode handles empty generated image payloads safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PromptLabScreen(
          initialImageMode: true,
          generateImage: (_) async => const Success(
            GeneratedImage(revisedPrompt: 'server accepted the prompt'),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      'http://127.0.0.1:8188/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'quiet garden');
    await tester.scrollUntilVisible(
      find.text('Generate image'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate image'));
    await tester.pumpAndSettle();

    expect(
      find.text('The image server returned no renderable image.'),
      findsOneWidget,
    );
    expect(
      find.text('Revised prompt: server accepted the prompt'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
