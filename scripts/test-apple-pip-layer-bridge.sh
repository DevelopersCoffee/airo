#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORK_ROOT="$REPO_ROOT/packages/platform_player/third_party/video_player_avfoundation"
TEXTURE_PLAYER="$FORK_ROOT/darwin/video_player_avfoundation/Sources/video_player_avfoundation_objc/FVPTextureBasedVideoPlayer.m"
IOS_VIEW="$FORK_ROOT/darwin/video_player_avfoundation/Sources/video_player_avfoundation_ios/FVPNativeVideoView.m"
MACOS_VIEW="$FORK_ROOT/darwin/video_player_avfoundation/Sources/video_player_avfoundation_macos/FVPNativeVideoView.m"
IOS_PLUGIN="$REPO_ROOT/app/ios/Runner/AiroPictureInPicturePlugin.swift"
MACOS_PLUGIN="$REPO_ROOT/app/macos/Runner/AiroPictureInPicturePlugin.swift"

for source_file in "$TEXTURE_PLAYER" "$IOS_VIEW" "$MACOS_VIEW"; do
  rg -q 'AiroPlayerLayerAvailable' "$source_file"
  rg -q 'AiroPlayerLayerUnavailable' "$source_file"
done

for plugin_file in "$IOS_PLUGIN" "$MACOS_PLUGIN"; do
  rg -q 'AiroPlayerLayerAvailable' "$plugin_file"
  rg -q 'AiroPlayerLayerUnavailable' "$plugin_file"
  rg -q 'case "isActive"' "$plugin_file"
  rg -q 'case "setAutoEnterEnabled"' "$plugin_file"
  rg -q 'guard pipController === controller else' "$plugin_file"
  rg -q 'private func detachController()' "$plugin_file"
  if rg -Fq 'AVPlayer(' "$plugin_file"; then
    echo "FAIL: PiP host must reuse the existing layer, not create AVPlayer" >&2
    exit 1
  fi
done

for app_pubspec in \
  "$REPO_ROOT/app/pubspec.yaml" \
  "$REPO_ROOT/app/pubspec_tv.yaml" \
  "$REPO_ROOT/app/pubspec_ios_spm.yaml"; do
  rg -q 'video_player_avfoundation:' "$app_pubspec"
  rg -q 'path: ../packages/platform_player/third_party/video_player_avfoundation' \
    "$app_pubspec"
done

echo "Apple PiP layer bridge source contract passed"
