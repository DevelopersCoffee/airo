import 'package:flutter_test/flutter_test.dart';
import 'package:platform_favorites/platform_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with no hidden groups', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = HiddenGroupsStorage(prefs);

    expect(await storage.getHiddenGroupIds(), isEmpty);
    expect(await storage.isHidden('Adult'), isFalse);
  });

  test('hides a group', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = HiddenGroupsStorage(prefs);

    await storage.hideGroup('Adult');

    expect(await storage.getHiddenGroupIds(), {'Adult'});
    expect(await storage.isHidden('Adult'), isTrue);
  });

  test('hiding the same group twice does not duplicate it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = HiddenGroupsStorage(prefs);

    await storage.hideGroup('Adult');
    await storage.hideGroup('Adult');

    expect(await storage.getHiddenGroupIds(), {'Adult'});
  });

  test('unhides a group', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = HiddenGroupsStorage(prefs);

    await storage.hideGroup('Adult');
    await storage.unhideGroup('Adult');

    expect(await storage.getHiddenGroupIds(), isEmpty);
    expect(await storage.isHidden('Adult'), isFalse);
  });

  test('toggling a group returns the new hidden state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = HiddenGroupsStorage(prefs);

    final nowHidden = await storage.toggleHidden('Radio');
    expect(nowHidden, isTrue);
    expect(await storage.isHidden('Radio'), isTrue);

    final nowShown = await storage.toggleHidden('Radio');
    expect(nowShown, isFalse);
    expect(await storage.isHidden('Radio'), isFalse);
  });

  test(
    'persists hidden groups across storage instances (same prefs)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await HiddenGroupsStorage(prefs).hideGroup('Sports 24/7');

      final reloaded = HiddenGroupsStorage(prefs);

      expect(await reloaded.getHiddenGroupIds(), {'Sports 24/7'});
    },
  );
}
