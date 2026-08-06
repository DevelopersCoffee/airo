import 'package:feature_assistant/src/services/model_preload_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists sorted frequent-model selections', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final adapter = SharedPreferencesModelPreloadPreferences(preferences);

    await adapter.setEnabled('model-b', true);
    await adapter.setEnabled('model-a', true);

    expect(await adapter.loadModelIds(), {'model-a', 'model-b'});
    expect(
      preferences.getStringList(
        SharedPreferencesModelPreloadPreferences.storageKey,
      ),
      ['model-a', 'model-b'],
    );

    await adapter.setEnabled('model-a', false);
    expect(await adapter.loadModelIds(), {'model-b'});
  });
}
