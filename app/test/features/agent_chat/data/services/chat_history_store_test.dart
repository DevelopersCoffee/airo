import 'package:airo_app/features/agent_chat/data/services/chat_history_store.dart';
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
  });

  test('chat history ignores corrupt or incompatible payloads', () async {
    SharedPreferences.setMockInitialValues({
      ChatHistoryStore.storageKey: '{"schemaVersion":99,"entries":[]}',
    });
    final store = ChatHistoryStore(
      preferences: await SharedPreferences.getInstance(),
    );
    expect(await store.load(), isEmpty);
  });
}
