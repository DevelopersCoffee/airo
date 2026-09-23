import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/presentation/widgets/watch_remote_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WatchRemoteAction act(WatchFocusZone zone, TvInputKey key) =>
      watchRemoteAction(zone: zone, key: key);

  test('video keys open one zone or step the channel', () {
    expect(act(WatchFocusZone.video, TvInputKey.select), WatchRemoteAction.openControls);
    expect(act(WatchFocusZone.video, TvInputKey.up), WatchRemoteAction.openControls);
    expect(act(WatchFocusZone.video, TvInputKey.down), WatchRemoteAction.openMiniGuide);
    expect(act(WatchFocusZone.video, TvInputKey.left), WatchRemoteAction.previousChannel);
    expect(act(WatchFocusZone.video, TvInputKey.right), WatchRemoteAction.nextChannel);
    expect(act(WatchFocusZone.video, TvInputKey.back), WatchRemoteAction.exitPlayer);
    expect(act(WatchFocusZone.video, TvInputKey.menu), WatchRemoteAction.moreActions);
  });

  test('controls keys stay on the rail or dismiss', () {
    expect(act(WatchFocusZone.controls, TvInputKey.select), WatchRemoteAction.activateFocusedControl);
    expect(act(WatchFocusZone.controls, TvInputKey.left), WatchRemoteAction.moveControl);
    expect(act(WatchFocusZone.controls, TvInputKey.right), WatchRemoteAction.moveControl);
    expect(act(WatchFocusZone.controls, TvInputKey.up), WatchRemoteAction.ignored);
    expect(act(WatchFocusZone.controls, TvInputKey.down), WatchRemoteAction.closeControls);
    expect(act(WatchFocusZone.controls, TvInputKey.back), WatchRemoteAction.closeControls);
    expect(act(WatchFocusZone.controls, TvInputKey.menu), WatchRemoteAction.moreActions);
  });

  test('mini guide keys move cards or hand focus back', () {
    expect(act(WatchFocusZone.miniGuide, TvInputKey.select), WatchRemoteAction.switchFocusedChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.left), WatchRemoteAction.moveChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.right), WatchRemoteAction.moveChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.up), WatchRemoteAction.showControls);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.down), WatchRemoteAction.closeGuide);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.back), WatchRemoteAction.closeGuide);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.menu), WatchRemoteAction.moreActions);
  });
}
