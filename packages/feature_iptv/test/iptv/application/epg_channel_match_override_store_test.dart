import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_channel_match_override_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late KeyValueStore store;
  late EpgChannelMatchOverrideStore overrideStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PreferencesStore(prefs);
    overrideStore = EpgChannelMatchOverrideStore(store);
  });

  test('resolveEpgChannelId returns null when no override is set', () async {
    final result = await overrideStore.resolveEpgChannelId('channel-1');
    expect(result, isNull);
  });

  test('setOverride then resolveEpgChannelId returns the mapped id', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg.example.tv');

    final result = await overrideStore.resolveEpgChannelId('channel-1');

    expect(result, 'epg.example.tv');
  });

  test('setOverride for one channel does not affect another', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), 'epg-a');
    expect(await overrideStore.resolveEpgChannelId('channel-2'), 'epg-b');
  });

  test('clearOverride removes only the targeted channel', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    await overrideStore.clearOverride('channel-1');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), isNull);
    expect(await overrideStore.resolveEpgChannelId('channel-2'), 'epg-b');
  });

  test('getOverrides returns the full map', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    final overrides = await overrideStore.getOverrides();

    expect(overrides, {'channel-1': 'epg-a', 'channel-2': 'epg-b'});
  });

  test('re-setting an override for the same channel replaces the old value', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a-corrected');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), 'epg-a-corrected');
  });
}
