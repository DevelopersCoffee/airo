import 'package:core_ui/core_ui.dart';

enum WatchFocusZone { video, controls, miniGuide }

enum WatchRemoteAction {
  openControls,
  activateFocusedControl,
  switchFocusedChannel,
  previousChannel,
  nextChannel,
  moveControl,
  moveChannel,
  openMiniGuide,
  closeControls,
  closeGuide,
  showControls,
  exitPlayer,
  moreActions,
  ignored,
}

WatchRemoteAction watchRemoteAction({
  required WatchFocusZone zone,
  required TvInputKey key,
}) {
  return switch (zone) {
    WatchFocusZone.video => switch (key) {
      TvInputKey.select || TvInputKey.up => WatchRemoteAction.openControls,
      TvInputKey.down => WatchRemoteAction.openMiniGuide,
      TvInputKey.left => WatchRemoteAction.previousChannel,
      TvInputKey.right => WatchRemoteAction.nextChannel,
      TvInputKey.back => WatchRemoteAction.exitPlayer,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
    WatchFocusZone.controls => switch (key) {
      TvInputKey.select => WatchRemoteAction.activateFocusedControl,
      TvInputKey.left || TvInputKey.right => WatchRemoteAction.moveControl,
      TvInputKey.down || TvInputKey.back => WatchRemoteAction.closeControls,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
    WatchFocusZone.miniGuide => switch (key) {
      TvInputKey.select => WatchRemoteAction.switchFocusedChannel,
      TvInputKey.left || TvInputKey.right => WatchRemoteAction.moveChannel,
      TvInputKey.up => WatchRemoteAction.showControls,
      TvInputKey.down || TvInputKey.back => WatchRemoteAction.closeGuide,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
  };
}
