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

  test(
    'file extraction reports missing and unsupported files clearly',
    () async {
      final service = GeminiQuestService();
      final missing = QuestFile(
        id: 'missing',
        name: 'missing.txt',
        path: '/tmp/airo-missing-quest-file.txt',
        mimeType: 'text/plain',
        sizeBytes: 0,
        uploadedAt: DateTime(2026),
      );

      expect(
        () => service.extractTextFromFile(missing),
        throwsA(
          isA<QuestProcessingUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('no longer available'),
          ),
        ),
      );

      final directory = await Directory.systemTemp.createTemp('airo-quest-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/notes.pdf');
      await source.writeAsBytes(<int>[1, 2, 3]);
      final sourceLength = await source.length();

      expect(
        () => service.extractTextFromFile(
          QuestFile(
            id: 'pdf',
            name: 'notes.pdf',
            path: source.path,
            mimeType: 'application/pdf',
            sizeBytes: sourceLength,
            uploadedAt: DateTime(2026),
          ),
        ),
        throwsA(
          isA<QuestProcessingUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('Text extraction is not available'),
          ),
        ),
      );
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

  test(
    'text quest context is sent to Nano and empty answers fail closed',
    () async {
      final directory = await Directory.systemTemp.createTemp('airo-quest-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/notes.txt');
      await source.writeAsString('Use this exact quest context.');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'initialize':
                return true;
              case 'generateContent':
                final arguments = call.arguments as Map<dynamic, dynamic>;
                expect(
                  arguments['prompt'],
                  contains('Use this exact quest context.'),
                );
                return '   ';
              default:
                return null;
            }
          });
      final service = GeminiQuestService();
      final quest = await service.createQuest('Text quest');
      await service.uploadFile(quest.id, source);

      expect(
        () => service.processQuery(quest.id, 'Summarize it'),
        throwsA(
          isA<QuestProcessingUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('returned no answer'),
          ),
        ),
      );
    },
  );

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

  test('quest reminders, listing, and deletion stay local', () async {
    final service = GeminiQuestService();
    final quest = await service.createQuest('Reminder quest');

    final reminder = await service.createReminder(
      quest.id,
      'Follow up',
      'Check the local plan',
      DateTime(2026, 7, 30, 10),
      isRecurring: true,
      recurringPattern: 'daily',
    );

    expect(reminder.questId, quest.id);
    expect(reminder.isRecurring, isTrue);
    expect(
      (await service.getQuest(quest.id))?.reminders.single.id,
      reminder.id,
    );
    expect(await service.listQuests(limit: 1), hasLength(1));

    await service.deleteQuest(quest.id);

    expect(await service.getQuest(quest.id), isNull);
  });

  test(
    'missing quest operations throw instead of creating orphan state',
    () async {
      final service = GeminiQuestService();
      final directory = await Directory.systemTemp.createTemp('airo-quest-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/notes.docx');
      await source.writeAsBytes(<int>[1, 2, 3]);

      expect(() => service.uploadFile('missing', source), throwsException);
      expect(
        () => service.createReminder(
          'missing',
          'No quest',
          'No quest',
          DateTime(2026),
        ),
        throwsException,
      );
    },
  );
}
