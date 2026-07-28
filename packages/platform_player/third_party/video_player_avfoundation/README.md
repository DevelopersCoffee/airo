# video\_player\_avfoundation

The iOS and macOS implementation of [`video_player`][1].

## Airo fork

This directory pins upstream `video_player_avfoundation 2.11.0` as
`2.11.0+airo.1`. The example application is intentionally omitted.

The only runtime delta publishes the existing `AVPlayerLayer` through
`AiroPlayerLayerAvailable` / `AiroPlayerLayerUnavailable`
`NotificationCenter` events from texture and platform-view players. Airo's
Apple Picture-in-Picture host consumes those events so PiP reuses the exact
player and stream already owned by this plugin. It must never create a second
handoff `AVPlayer`.

When rebasing this fork, retain:

- the layer-available post immediately after each native layer is attached;
- the matching layer-unavailable post before texture disposal or native-view
  deallocation;
- the Airo lifecycle test in `darwin/RunnerTests/VideoPlayerTests.swift`;
- the upstream BSD license and authorship files.

## Usage

This package is [endorsed][2], which means you can simply use `video_player`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

[1]: https://pub.dev/packages/video_player
[2]: https://flutter.dev/to/endorsed-federated-plugin
