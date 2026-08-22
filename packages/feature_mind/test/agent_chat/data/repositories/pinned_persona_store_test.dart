import 'package:feature_mind/src/agent_chat/data/repositories/pinned_persona_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves, loads, and clears the pinned persona id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PinnedPersonaStore();

    expect(await store.load(), isNull);

    await store.save('contract-review-assistant');
    expect(await store.load(), 'contract-review-assistant');

    await store.save('  ');
    expect(await store.load(), isNull);
  });
}
