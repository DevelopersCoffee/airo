---
name: run-airo-tv
description: Launch and drive the Airo TV Flutter app (main_tv.dart entrypoint) on a target device — macOS desktop, Chrome, Android/Fire TV, or phone. Use whenever asked to run, start, or preview Airo TV.
---

# Run Airo TV

Airo TV is the TV-flavored Flutter entrypoint at `app/lib/main_tv.dart` (distinct from
`main.dart`, `main_tv.dart`, `main_qualification.dart`).

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
