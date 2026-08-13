# Vendoring convention

This is the workspace's single vendoring location. When a pub.dev package
needs a local fork — a missing platform implementation, an unmerged fix, a
pinned pre-release API — the fork lives here as a full package directory
(its own `pubspec.yaml`, native sources, docs) and consumers pull it in with
a `path:` dependency override, the same way `packages/stubs/` swaps in a
no-op for one platform.

Nothing here is playback-specific. It lives under `platform_player/`
because that is where the largest, best-documented vendoring precedent
(`flutter_chrome_cast`) already existed when this convention was decided —
not because ownership is scoped to playback. Any package in the workspace
may depend on a fork here via a relative `path:` override in its own
`pubspec.yaml` or in `.github/airo-build-profiles.json`'s
`requiredDependencyOverrides`.

Current forks:

- `flutter_chrome_cast` — local patches to the upstream Cast plugin, used by
  `platform_player` itself for TV casting.
- `video_player_avfoundation` — vendored AVFoundation implementation.
- `screen_protector` — the published `screen_protector` 1.5.3 declares an
  Android plugin class but does not ship the Android source; this fork
  keeps the upstream Dart/iOS API and adds the missing Android
  `FLAG_SECURE` bridge locally. Consumed by `app/pubspec.yaml`,
  `app/pubspec_coins.yaml`, and `app/pubspec_mind.yaml`. Unrelated to
  playback — it lives here only because this is the workspace's one
  vendoring location, not because it belongs to `platform_player`.

There used to be a second, less-documented vendoring root at
`packages/third_party/` (a bare directory with no `pubspec.yaml` of its
own, holding only `screen_protector`). It was folded into this directory —
see #1676 — so there is exactly one place to look for a local fork.
