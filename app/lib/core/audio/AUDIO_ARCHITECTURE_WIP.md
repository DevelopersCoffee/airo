# Global Audio Architecture - WIP

## Status: Work In Progress

This document outlines the global audio service architecture. Core structure is implemented; platform-specific features are marked WIP.

## Overview

Single global audio service for entire app. Manages music playback, audio focus, ducking, and background playback across all tabs.

## Architecture

### GlobalAudioService (Singleton)

```dart
class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();

  late AudioPlayer _musicPlayer;
  late AudioPlayer _sfxPlayer;

  bool _isPlaying = false;
  bool _isDucked = false;
  double _normalVolume = 1.0;
  double _duckedVolume = 0.3;

  // Audio focus management
  bool _hasAudioFocus = true;
  bool _allowBackgroundAudio = true;
}
```

### Key Features

1. **Single Instance**: One audio service for entire app
2. **Music Player**: Dedicated player for background music
3. **SFX Player**: Dedicated player for game sound effects
4. **Audio Ducking**: Lower music volume during SFX
5. **Audio Focus**: Handle interruptions (calls, alarms)
6. **Background Playback**: Continue music when app backgrounded
7. **Lifecycle Management**: Pause on background, resume on foreground

## API

### Music Control

```dart
// Play music
await audioService.playMusic(url, title: 'Lofi Beats');

// Pause/Resume
await audioService.pauseMusic();
await audioService.resumeMusic();

// Stop
await audioService.stopMusic();

// Next track
await audioService.nextTrack();

// Volume control
await audioService.setMusicVolume(0.8);
```

### SFX Control

```dart
// Play SFX with optional ducking
await audioService.playSfx(
  'assets/audio/pieces/knight/capture.mp3',
  duckDuration: Duration(milliseconds: 500),
);

// Volume control
await audioService.setSfxVolume(0.7);
```

### State Streams

```dart
// Listen to music state
audioService.getMusicStateStream().listen((state) {
  print('Music state: $state');
});

// Listen to music position
audioService.getMusicPositionStream().listen((position) {
  print('Position: $position');
});
```

### Audio Focus

```dart
// Handle focus loss (e.g., phone call)
await audioService.onAudioFocusLoss();

// Handle focus gain (e.g., call ended)
await audioService.onAudioFocusGain();

// Set background audio permission
audioService.setAllowBackgroundAudio(true);
```

## Platform-Specific Implementation (WIP)

### Android

**WIP Tasks:**
- [ ] Request media style notification
- [ ] Foreground service for background playback
- [ ] Handle Doze mode
- [ ] Audio focus callbacks
- [ ] Lockscreen controls
- [ ] Notification controls (play/pause/next)

**Implementation:**
```kotlin
// WIP: Android audio session configuration
// - Set audio attributes for music
// - Request audio focus
// - Handle focus loss callbacks
// - Setup notification with media controls
```

### iOS

**WIP Tasks:**
- [ ] Enable audio background mode in Info.plist
- [ ] Set AVAudioSession category
- [ ] Handle audio interruptions
- [ ] Lockscreen controls
- [ ] Respect hardware mute switch for SFX

**Implementation:**
```swift
// WIP: iOS audio session configuration
// - Set AVAudioSession category to allowMixing
// - Enable background mode
// - Handle interruptions
// - Setup remote commands for lockscreen
```

### Web

**WIP Tasks:**
- [ ] MediaSession API for lockscreen controls
- [ ] Background playback (service worker)
- [ ] Audio focus simulation
- [ ] Notification API integration

## Contracts Between Tabs

### Music Tab API

```dart
interface MusicService {
  Future<void> play(String query);
  Future<void> pause();
  Future<void> resume();
  Future<void> next();
  Future<void> setQueue(List<String> tracks);
  Stream<MusicState> getState();
}
```

### Games Tab API

```dart
interface GamesAudioService {
  Future<void> requestDucking(Duration duration);
  Future<void> playSfx(String id);
  Future<void> stopSfxAll();
  Future<void> onFocusLost();
  Future<void> onFocusGain();
}
```

### Agent Tab API

```dart
// Agent can call both:
// "play lofi" → Music.play('lofi')
// "launch chess" → Games.launch('chess')
// Music continues playing while chess is open
```

## UI Components

### Mini Player (Persistent)

- Appears at bottom across all tabs
- Shows: title, play/pause, next, progress
- Tap to open full Music tab
- Back returns to previous tab

### Game HUD

- Show temporary "ducked" icon while SFX plays
- Visual feedback for audio ducking

### Settings

**Global Settings:**
- [ ] Allow background audio (toggle)
- [ ] Audio ducking (toggle)
- [ ] Normalize volume (toggle)
- [ ] Crossfade (toggle)

**Per-Game Settings:**
- [ ] SFX volume (slider)
- [ ] Mute on focus loss (toggle)
- [ ] Respect bedtime mode (toggle)

**Bedtime Mode:**
- [ ] Auto lower volume after 22:30
- [ ] Optional fade out timer

## Lifecycle Management

### App Lifecycle

```dart
// On app background
- Pause game timers/loops
- Keep music playing (if allowed)
- Save game state

// On app foreground
- Resume game timers/loops
- Music continues unchanged

// On app kill
- Stop music (unless background allowed)
- Save game state
```

### Tab Switching

```dart
// Switch from Music to Games
- Music continues playing
- Games request transient audio focus
- Music ducks on SFX

// Switch from Games to Music
- Game SFX stops
- Music volume restored
- Full Music tab opens
```

## Error Handling

**WIP Tasks:**
- [ ] Audio engine failure → show non-blocking toast
- [ ] Stream drops → retry with backoff
- [ ] Model not supported → fallback gracefully
- [ ] Thermal throttling → reduce quality

## Telemetry (WIP)

**Track:**
- [ ] Play/pause events
- [ ] Duck events
- [ ] Audio focus changes
- [ ] SFX count per minute
- [ ] Dropouts
- [ ] Crash logs on audio thread underruns

## Performance Optimization (WIP)

**Tasks:**
- [ ] Keep audio decoding off UI thread (use isolates)
- [ ] Cap SFX concurrency
- [ ] Pool audio players
- [ ] Preload most-used SFX
- [ ] Limit sample rates to device preferred

## QA Matrix (WIP)

- [ ] Switch tabs while music plays: no gap
- [ ] Start game SFX: music ducks then restores
- [ ] Phone call arrives: music pauses, game pauses
- [ ] Both resume per setting
- [ ] Lockscreen control works
- [ ] Unlocking returns to game with music unchanged
- [ ] Battery check: 30-minute session under thermal limits
- [ ] Background playback works on Android/iOS
- [ ] Audio focus callbacks work
- [ ] Notification controls work

## Rollout Plan

### Phase 1 (Current)
- [x] Global audio service structure
- [ ] Music + mini player
- [ ] Games SFX with manual ducking

### Phase 2 (WIP)
- [ ] Lockscreen controls
- [ ] Background playback
- [ ] Audio focus management

### Phase 3 (WIP)
- [ ] Per-game audio settings
- [ ] Bedtime integration
- [ ] Thermal management

## Dev Tasks (WIP)

- [ ] Platform-specific audio session setup
- [ ] Notification integration
- [ ] Lockscreen controls
- [ ] Audio focus callbacks
- [ ] Background playback
- [ ] Thermal guards
- [ ] Battery optimization
- [ ] QA testing
- [ ] Telemetry

## Notes

- GlobalAudioService is singleton for app lifetime
- Music player is always active (even when paused)
- SFX player is transient (created per sound)
- Audio focus is simulated on Web
- Ducking is automatic on SFX playback
- Background playback requires OS permission

