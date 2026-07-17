import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Item {
  const _Item(this.id, this.name);
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory _Item.fromJson(Map<String, dynamic> json) =>
      _Item(json['id'] as String, json['name'] as String);
}

void main() {
  late KeyValueStore store;
  late BoundedRecentListStore<_Item> boundedStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PreferencesStore(prefs);
    boundedStore = BoundedRecentListStore<_Item>(
      store,
      storageKey: 'test_recent',
      maxSize: 3,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
      fromJson: _Item.fromJson,
    );
  });

  test('addToRecent then getRecent round-trips', () async {
    await boundedStore.addToRecent(const _Item('1', 'first'));

    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['1']);
  });

  test('re-adding an existing id moves it to the top, no duplicate', () async {
    await boundedStore.addToRecent(const _Item('1', 'first'));
    await boundedStore.addToRecent(const _Item('2', 'second'));
    await boundedStore.addToRecent(const _Item('1', 'first'));

    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['1', '2']);
  });

  test('trims to maxSize, dropping the oldest', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));
    await boundedStore.addToRecent(const _Item('3', 'c'));
    await boundedStore.addToRecent(const _Item('4', 'd'));

    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['4', '3', '2']);
  });

  test('getRecent respects limit', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    final result = await boundedStore.getRecent(limit: 1);

    expect(result.map((i) => i.id), ['2']);
  });

  test('removeFromRecent removes by id', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    await boundedStore.removeFromRecent('1');
    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['2']);
  });

  test('clearRecent empties the list', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));

    await boundedStore.clearRecent();
    final result = await boundedStore.getRecent();

    expect(result, isEmpty);
  });

  test('hasRecent is false before any add, true after', () async {
    expect(await boundedStore.hasRecent(), isFalse);

    await boundedStore.addToRecent(const _Item('1', 'a'));

    expect(await boundedStore.hasRecent(), isTrue);
  });

  test('getRecentCount reflects the current list size', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    expect(await boundedStore.getRecentCount(), 2);
  });

  test('two stores with different storageKeys do not collide', () async {
    final otherStore = BoundedRecentListStore<_Item>(
      store,
      storageKey: 'other_recent',
      maxSize: 3,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
      fromJson: _Item.fromJson,
    );

    await boundedStore.addToRecent(const _Item('1', 'a'));
    await otherStore.addToRecent(const _Item('2', 'b'));

    expect((await boundedStore.getRecent()).map((i) => i.id), ['1']);
    expect((await otherStore.getRecent()).map((i) => i.id), ['2']);
  });
}
