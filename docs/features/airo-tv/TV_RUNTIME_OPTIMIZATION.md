# Airo TV runtime optimization

The Android release host enables R8 and resource shrinking and is distributed
as an App Bundle for Play device-specific delivery. Flutter ABI selection is
left to `flutter build appbundle` / `--split-per-abi`; the Gradle file does not
override Flutter's 32-bit and 64-bit filters.

`app/android/app/src/main/baseline-prof.txt` packages startup rules for the
Airo activity and Flutter engine. `androidx.profileinstaller` installs the
profile on supported non-Play paths as well.

At startup, Airo TV configures its constrained image-cache budget and registers
one framework-owned `AiroMemoryPressureObserver`. Android `onTrimMemory` /
`onLowMemory` reaches Flutter's `didHaveMemoryPressure`; the observer clears
pending and live decoded images. Feature widgets do not register separate
pressure listeners.

Channel and Explorer tiles retain their existing `RepaintBoundary` isolation,
and `WakelockPlaybackCoordinator` holds the OS wakelock only during active
non-audio-only playback. EPG warmup and source refresh remain scheduled after
`runApp`, so parsing does not block the first frame.

## Required physical evidence

Before closing #884, capture on the same 1 GB-class TV:

1. release APK/AAB download and installed sizes before and after R8/App Bundle;
2. cold-start time before and after profile installation;
3. DevTools repaint-rainbow recording showing D-pad focus repaints one tile;
4. ABI inspection proving the intended 32-bit and 64-bit Play artifacts.

These measurements are device evidence and must not be inferred from unit
tests or build configuration alone.
