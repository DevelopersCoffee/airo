import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airo_app/features/quest/domain/models/quest_models.dart';
import 'package:airo_app/features/quest/domain/services/gemini_quest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.airo.gemini_nano');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('upload records the real file size and path', () async {
    final directory = await Directory.systemTemp.createTemp('airo-quest-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/notes.txt');
    await source.writeAsString('actual quest content');
    final service = GeminiQuestService();
    final quest = await service.createQuest('Test quest');

    final uploaded = await service.uploadFile(quest.id, source);

    expect(uploaded.path, source.path);
    expect(uploaded.sizeBytes, await source.length());
    expect(uploaded.sizeBytes, greaterThan(0));
  });

  test(
    'text extraction reads the selected file instead of sample content',
    () async {
      final directory = await Directory.systemTemp.createTemp('airo-quest-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/notes.txt');
      await source.writeAsString('actual quest content');
      final service = GeminiQuestService();

      final extracted = await service.extractTextFromFile(
        QuestFile(
          id: 'file',
          name: 'notes.txt',
          path: source.path,
          mimeType: 'text/plain',
          sizeBytes: await source.length(),
          uploadedAt: DateTime(2026),
        ),
      );

      expect(extracted, 'actual quest content');
      expect(extracted, isNot(contains('sample extracted content')));
    },
  );

  test('missing Nano never returns a canned answer', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return false;
          return null;
        });
    final service = GeminiQuestService();
    final quest = await service.createQuest('Test quest');

    expect(
      () => service.processQuery(quest.id, 'Create a diet plan'),
      throwsA(
        isA<QuestProcessingUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('No on-device inference runtime is available'),
        ),
      ),
    );
  });

  test('image requests report unsupported local vision on desktop', () async {
    final directory = await Directory.systemTemp.createTemp('airo-quest-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/photo.jpg');
    await source.writeAsBytes(<int>[1, 2, 3]);
    final service = GeminiQuestService();
    final quest = await service.createQuest('Image quest');
    await service.uploadFile(quest.id, source);

    expect(
      () => service.processQuery(quest.id, 'Describe this image'),
      throwsA(
        isA<QuestProcessingUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('available on Android and iOS only'),
        ),
      ),
    );
  });

  test('image OCR stays local and is passed to the on-device model', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'isAvailable':
              return true;
            case 'initialize':
              return true;
            case 'generateContent':
              final arguments = call.arguments as Map<dynamic, dynamic>;
              expect(arguments['prompt'], contains('TOTAL 42.00'));
              return 'I found the total locally.';
            default:
              return null;
          }
        });
    final service = GeminiQuestService(
      imageTextExtractor: (_) async => 'TOTAL 42.00',
    );
    final directory = await Directory.systemTemp.createTemp('airo-quest-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/receipt.jpg');
    await source.writeAsBytes(<int>[1, 2, 3]);
    final quest = await service.createQuest('Local image quest');
    await service.uploadFile(quest.id, source);

    final response = await service.processQuery(quest.id, 'What is the total?');

    expect(response, 'I found the total locally.');
  });
}
