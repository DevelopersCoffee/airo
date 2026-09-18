# Android setup

`airo_notifications` (via `flutter_local_notifications`) needs one piece of
host-app setup on Android that is easy to miss and, if missed, does not fail
at build time -- it crashes the app the first time a scheduled notification
actually fires.

## The small icon must be `@mipmap/ic_notification`, never `@mipmap/ic_launcher`

`LocalAiroNotificationEngine.initialize()` hard-codes the Android small icon
resource name:

```dart
const androidSettings = AndroidInitializationSettings('@mipmap/ic_notification');
```

This is deliberate, not a placeholder. Any host app consuming this package
**must** ship a `@mipmap/ic_notification` drawable (a plain white-on-transparent
glyph, per Android's status-bar icon guidelines) in its
`android/app/src/main/res/mipmap-*/` folders.

### Why not just reuse `ic_launcher`?

On API 26+ (Android 8.0+), an Adaptive Icon defined at
`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` **shadows** the
`ic_launcher` name for anything that asks Android's resource resolver for a
drawable/mipmap by that name at runtime -- which is exactly what
`flutter_local_notifications` does when you pass `'@mipmap/ic_launcher'` as
the small icon.

When `NotificationManager` resolves that shadowed reference and finds it is
not a valid status-bar-icon-shaped resource, it rejects the notification with
"no valid small icon" -- and on the versions of `flutter_local_notifications`
this package pins, that rejection surfaces as an uncaught platform exception
that **crashes the host app**, not a silently-dropped notification. This is a
process crash, not a cosmetic bug: it reproduces reliably the first time any
scheduled or immediate alert actually dispatches on a real API 26+ device,
which is why it can pass CI/emulator smoke tests and still take down
production.

### Checklist for a new host app

1. Add a dedicated notification glyph as `ic_notification` (not `ic_launcher`)
   under `android/app/src/main/res/mipmap-mdpi/`, `-hdpi/`, `-xhdpi/`,
   `-xxhdpi/`, `-xxxhdpi/` (or a single `mipmap-anydpi-v24/ic_notification.xml`
   vector, matching how the app already ships `ic_launcher`).
2. Never rename or remove it once a release has shipped with it -- the
   resource name is referenced by string literal in this package, not
   generated, so a rename silently reintroduces the crash on the next release
   that touches notifications.
3. If you fork/vendor this engine, grep for `ic_notification` before changing
   the Android initialization settings.

This mirrors the root cause and fix that was already validated against a
real device in `feature_mind`'s prior standalone notification scheduler --
see `docs/release/NOTIFICATION_VALIDATION.md` in the `airo` monorepo for the
original investigation.
