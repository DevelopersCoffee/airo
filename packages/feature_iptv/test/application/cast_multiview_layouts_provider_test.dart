import 'package:feature_iptv/application/providers/cast_multiview_layouts_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  MultiviewCastLayout layout(String id, String name, List<String> channelIds) {
    return MultiviewCastLayout(
      id: id,
      name: name,
      slots: [
        for (final channelId in channelIds)
          MultiviewCastLayoutSlot(
            channelId: channelId,
            channelName: 'Channel $channelId',
          ),
      ],
    );
  }

  test('starts with no saved layouts', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MultiviewCastLayoutStorage(
      await SharedPreferences.getInstance(),
    );

    expect(await storage.getLayouts(), isEmpty);
  });

  test('saves a layout and reads it back with every field intact', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MultiviewCastLayoutStorage(
      await SharedPreferences.getInstance(),
    );
    final news = layout('layout-1', 'News', ['aajtak-hd', 'yrf-music']);

    await storage.saveLayout(news);

    expect(await storage.getLayouts(), [news]);
  });

  test('saving a layout with an existing id replaces it in place', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MultiviewCastLayoutStorage(
      await SharedPreferences.getInstance(),
    );
    await storage.saveLayout(layout('layout-1', 'News', ['aajtak-hd']));
    await storage.saveLayout(layout('layout-2', 'Sports', ['espn']));

    final renamed = layout('layout-1', 'Breaking News', [
      'aajtak-hd',
      'yrf-music',
    ]);
    await storage.saveLayout(renamed);

    final layouts = await storage.getLayouts();
    expect(layouts, hasLength(2));
    // Replaced in place, not moved to the end.
    expect(layouts.first, renamed);
  });

  test('deletes a layout by id', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MultiviewCastLayoutStorage(
      await SharedPreferences.getInstance(),
    );
    await storage.saveLayout(layout('layout-1', 'News', ['aajtak-hd']));
    await storage.saveLayout(layout('layout-2', 'Sports', ['espn']));

    await storage.deleteLayout('layout-1');

    final layouts = await storage.getLayouts();
    expect(layouts, hasLength(1));
    expect(layouts.single.id, 'layout-2');
  });

  test('deleting an id that does not exist is a no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MultiviewCastLayoutStorage(
      await SharedPreferences.getInstance(),
    );
    await storage.saveLayout(layout('layout-1', 'News', ['aajtak-hd']));

    await storage.deleteLayout('ghost');

    expect(await storage.getLayouts(), hasLength(1));
  });

  test('generated layout ids are unique', () {
    final first = newMultiviewCastLayoutId();
    final second = newMultiviewCastLayoutId();
    expect(first, isNot(second));
  });

  test(
    'layout kind round-trips and older records without one still load',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = MultiviewCastLayoutStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.saveLayout(
        layout('layout-1', 'News', [
          'aajtak-hd',
        ]).copyWith(layout: MultiviewLayoutKind.spotlight),
      );

      final loaded = await storage.getLayouts();
      expect(loaded.single.layout, MultiviewLayoutKind.spotlight);

      expect(
        MultiviewCastLayout.fromJson({
          'id': 'legacy',
          'name': 'Old',
          'slots': [
            {'channelId': 'a', 'channelName': 'A'},
          ],
        }).layout,
        isNull,
      );
    },
  );
}
