---
name: run-airo-tv
description: Launch and drive the Airo TV Flutter app (main_tv.dart entrypoint) on a target device — macOS desktop, Chrome, Android/Fire TV, or phone. Use whenever asked to run, start, or preview Airo TV.
---

# Run Airo TV

Airo TV is the TV-flavored Flutter entrypoint at `app/lib/main_tv.dart` (distinct from
`main.dart`, `main_airo_iptv.dart`, `main_mobile_streaming.dart`, `main_qualification.dart`).

## 1. Pick a device

```bash
cd app && flutter devices
```

Typical targets seen in this repo: `macos` (desktop), `chrome` (web), an Android device/emulator
(`android-arm64`), Fire TV/Android TV over adb.

## 2. Launch

Run from the `app/` directory, targeting `main_tv.dart` explicitly — the bare `flutter run`
defaults to `main.dart`, which is the wrong entrypoint for the TV experience.

```bash
cd /Users/udaychauhan/workspace/airo/app
flutter run -d macos -t lib/main_tv.dart
```

Swap `-d macos` for `-d chrome`, `-d <android-device-id>`, etc. as needed.

### Android target: swap in `pubspec_tv.yaml` first — `flutter run` needs it too

`--target=lib/main_tv.dart` only picks the Dart entrypoint — it does **not** make Flutter
read `app/pubspec_tv.yaml`. Skip the swap and you get more than a cosmetic version number:
`pubspec_tv.yaml` replaces several plugins with no-op stubs (`media_kit_libs_android_video`
among them) so their Android side never registers. Without the swap, the *real*
`media_kit_libs_android_video` plugin loads, and its native `System.loadLibrary("mpv")`
throws `UnsatisfiedLinkError` on every launch — the TV Gradle config always strips
`libmpv.so` from the APK regardless of which pubspec built it. Every later channel call that
plugin should have served then throws `MissingPluginException`, which the global error
handler surfaces as an auto-popping bug report dialog on nearly every cold start.

Always run this from `app/` before `flutter run` **or** `flutter build` against
`main_tv.dart`:

```bash
cp pubspec_tv.yaml pubspec.yaml && flutter pub get
```

(`scripts/build-tv.sh` does this automatically for release builds; a plain `flutter run`
debug session does not, so do it by hand first.) Restore `app/pubspec.yaml` via `git
checkout -- pubspec.yaml pubspec.lock` afterward if you also work on the phone app in the
same checkout.

Separately, Android's real `versionName`/`versionCode` always come from whichever pubspec
built the APK — `flutter run` has no `--build-name`/`--build-number` flags at all, so even
with the swap applied a debug session shows the version baked into `pubspec_tv.yaml` at
build time, not necessarily what you'd expect from a mid-session edit. Harmless to ignore
for a throwaway debug session.

For anything you actually keep installed or hand to someone (`flutter build apk --release`,
a local dogfood/sideload build), that same default is a real bug, not a display quirk — it
silently stamps the wrong `versionCode`, which can collide with what Play has already
consumed. Always pass explicit `--build-name`/`--build-number` sourced from
`app/pubspec_tv.yaml` via `scripts/aika_stream_version.sh`:

```bash
cd /Users/udaychauhan/workspace/airo
eval "$(scripts/aika_stream_version.sh)"
cd app
flutter build apk --release -t lib/main_tv.dart \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --build-name="$AIKA_STREAM_BUILD_NAME" \
  --build-number="$AIKA_STREAM_BUILD_NUMBER"
```

### Notes for macOS target

- First launch runs `pod install` for the macOS Runner — can take 30-90s before
  "Building macOS application..." appears.
- You'll see warnings that `flutter_image_compress_macos`, `flutter_tts`, and `pdfx` don't
  support Swift Package Manager on macOS yet — this is a non-fatal deprecation warning, not
  a build failure. Ignore it.
- Full cold build (pod install + Xcode build) commonly takes 2-5 minutes.

## 3. Run it in the background and watch for the real terminal state

`flutter run` is long-lived (hot-reload session) and never "completes," so launch it
detached and tail the log rather than blocking on it:

```bash
nohup flutter run -d macos -t lib/main_tv.dart > /tmp/airo_tv_macos_run.log 2>&1 &
```

Poll/monitor for one of the terminal signals:
- Success: log contains `Flutter run key commands` (the hot-reload prompt) or a line like
  `🔥  To hot reload changes` / `An Observatory debugger and profiler on macOS is available at`.
- Failure: log contains `Error`, `error:`, `Exception`, or `Failed`.

```bash
until grep -qE "Flutter run key commands|Error|error:|Exception|Failed" /tmp/airo_tv_macos_run.log; do sleep 3; done
tail -60 /tmp/airo_tv_macos_run.log
```

## 4. Drive it

Once the macOS window appears, it's a normal desktop app window — screenshot it to confirm
it rendered rather than just checking the process launched. The TV UI expects an authorized
M3U playlist to be added before channels appear (see
[`docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md`](../../../docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md)
for expected user flow / feature status if you need to sanity-check behavior against spec).

## Stopping

```bash
pkill -f "flutter run -d macos -t lib/main_tv.dart"
```
or kill the specific dart_tools PID from `ps aux | grep main_tv`.
