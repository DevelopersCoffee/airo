import 'dart:convert';

import 'package:feature_mind/src/agent_chat/data/services/chat_history_store.dart';
import 'package:feature_mind/src/reasoning/chat_reasoning_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('chat history round-trips a versioned bounded payload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ChatHistoryStore(preferences: preferences);
    final timestamp = DateTime.utc(2026, 7, 30, 2, 30);

    await store.save([
      ChatHistoryEntry(text: 'hello', isUser: true, timestamp: timestamp),
      ChatHistoryEntry(text: 'hi there', isUser: false, timestamp: timestamp),
    ]);

    final loaded = await store.load();
    expect(loaded, hasLength(2));
    expect(loaded.first.text, 'hello');
    expect(loaded.first.isUser, isTrue);
    expect(loaded.last.timestamp, timestamp.toLocal());
    expect(loaded.last.runId, isNull);
  });

  test(
    'chat history v2 round-trips assistant runId and loads v1 payloads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(preferences: preferences);
      final timestamp = DateTime.utc(2026, 8, 21, 15, 0);

      await store.save([
        ChatHistoryEntry(
          text: 'Make me a 7 day diet plan',
          isUser: true,
          timestamp: timestamp,
        ),
        ChatHistoryEntry(
          text: 'Here',
          isUser: false,
          timestamp: timestamp,
          runId: 'run-diet-1',
        ),
      ]);

      final loaded = await store.load();
      expect(loaded.last.runId, 'run-diet-1');
      expect(loaded.last.text, 'Here');

      SharedPreferences.setMockInitialValues({
        ChatHistoryStore.storageKey:
            '{"schemaVersion":1,"entries":[{"text":"old","isUser":false,"timestamp":"2026-07-30T02:30:00.000Z"}]}',
      });
      final v1Store = ChatHistoryStore(
        preferences: await SharedPreferences.getInstance(),
      );
      final v1 = await v1Store.load();
      expect(v1.single.text, 'old');
      expect(v1.single.runId, isNull);
    },
  );

  test('chat history ignores corrupt or incompatible payloads', () async {
    SharedPreferences.setMockInitialValues({
      ChatHistoryStore.storageKey: '{"schemaVersion":99,"entries":[]}',
    });
    final store = ChatHistoryStore(
      preferences: await SharedPreferences.getInstance(),
    );
    expect(await store.load(), isEmpty);
  });

  test('chat history does not persist empty streaming placeholders', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ChatHistoryStore(preferences: preferences);
    final timestamp = DateTime.utc(2026, 7, 30, 2, 30);

    await store.save([
      ChatHistoryEntry(text: 'question', isUser: true, timestamp: timestamp),
      ChatHistoryEntry(text: '', isUser: false, timestamp: timestamp),
      ChatHistoryEntry(text: '   ', isUser: false, timestamp: timestamp),
      ChatHistoryEntry(text: 'answer', isUser: false, timestamp: timestamp),
    ]);

    final loaded = await store.load();
    expect(loaded.map((entry) => entry.text), ['question', 'answer']);
  });

  test(
    'chat history serializes rapid saves so the newest snapshot wins',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(preferences: preferences);
      final timestamp = DateTime.utc(2026, 7, 30, 2, 30);

      final first = store.save([
        ChatHistoryEntry(text: 'older', isUser: true, timestamp: timestamp),
      ]);
      final second = store.save([
        ChatHistoryEntry(text: 'newer', isUser: true, timestamp: timestamp),
      ]);
      await Future.wait([first, second]);

      final loaded = await store.load();
      expect(loaded.single.text, 'newer');
    },
  );

  test(
    'chat history persists summary and level and never thought traces',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(preferences: preferences);
      final timestamp = DateTime.utc(2026, 8, 21, 18);

      await store.save([
        ChatHistoryEntry(
          text: 'Ice is less dense than water.',
          isUser: false,
          timestamp: timestamp,
          reasoningSummary: 'Used density, not a scratchpad.',
          reasoningLevel: 'light',
          toolCalls: const [
            ChatHistoryToolCall(name: 'calendar', argumentsJson: '{}'),
          ],
        ),
      ]);

      final loaded = await store.load();
      expect(loaded.single.reasoningSummary, 'Used density, not a scratchpad.');
      expect(loaded.single.reasoningLevel, 'light');
      expect(loaded.single.toolCalls.single.name, 'calendar');

      final raw = jsonDecode(
        preferences.getString(ChatHistoryStore.storageKey)!,
      );
      expect(jsonContainsBannedReasoningTraceKeys(raw), isFalse);
    },
  );

  test(
    'loading a payload that smuggled thoughts drops them on the next save',
    () async {
      final timestamp = DateTime.utc(2026, 8, 21, 18).toIso8601String();
      SharedPreferences.setMockInitialValues({
        ChatHistoryStore.storageKey: jsonEncode({
          'schemaVersion': 1,
          'entries': [
            {
              'text': 'Ice floats.',
              'isUser': false,
              'timestamp': timestamp,
              'reasoningSummary': 'Density.',
              'reasoningLevel': 'light',
              'thoughts': 'SECRET TRACE',
              'scratchpad': 'step by step...',
            },
          ],
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(preferences: preferences);
      final loaded = await store.load();
      expect(loaded.single.reasoningSummary, 'Density.');
      await store.save(loaded);
      final raw = jsonDecode(
        preferences.getString(ChatHistoryStore.storageKey)!,
      );
      expect(jsonContainsBannedReasoningTraceKeys(raw), isFalse);
    },
  );
}
