# Media Hub State Models

## Overview

State models for the unified Media Hub following existing patterns from `StreamingState`, `MusicPlayerState`, and Riverpod-based state management.

---

## Domain Models

### 1. MediaMode Enum
```dart
/// Media hub mode selection
enum MediaMode {
  music('Music', Icons.music_note),
  tv('TV', Icons.live_tv);

  const MediaMode(this.label, this.icon);
  final String label;
  final IconData icon;
}
```

### 2. MediaCategory Model
```dart
/// Category for content filtering
class MediaCategory extends Equatable {
  final String id;
  final String label;
  final IconData? icon;
  final MediaMode mode; // Which mode this category belongs to
  
  const MediaCategory({
    required this.id,
    required this.label,
    this.icon,
    required this.mode,
  });
  
  @override
  List<Object?> get props => [id, mode];
}

/// Predefined categories
class MediaCategories {
  // TV Categories
  static const tvLive = MediaCategory(id: 'tv_live', label: 'Live', mode: MediaMode.tv);
  static const tvMovies = MediaCategory(id: 'tv_movies', label: 'Movies', mode: MediaMode.tv);
  static const tvKids = MediaCategory(id: 'tv_kids', label: 'Kids', mode: MediaMode.tv);
  static const tvMusic = MediaCategory(id: 'tv_music', label: 'Music', mode: MediaMode.tv);
  static const tvRegional = MediaCategory(id: 'tv_regional', label: 'Regional', mode: MediaMode.tv);
  static const tvNews = MediaCategory(id: 'tv_news', label: 'News', mode: MediaMode.tv);
  
  // Music Categories
  static const musicTrending = MediaCategory(id: 'music_trending', label: 'Trending', mode: MediaMode.music);
  static const musicRegional = MediaCategory(id: 'music_regional', label: 'Regional', mode: MediaMode.music);
  static const musicIndie = MediaCategory(id: 'music_indie', label: 'Indie', mode: MediaMode.music);
  static const musicDevotional = MediaCategory(id: 'music_devotional', label: 'Devotional', mode: MediaMode.music);
  static const musicChill = MediaCategory(id: 'music_chill', label: 'Chill', mode: MediaMode.music);
  static const musicFocus = MediaCategory(id: 'music_focus', label: 'Focus', mode: MediaMode.music);
  
  static List<MediaCategory> forMode(MediaMode mode) => mode == MediaMode.tv
      ? [tvLive, tvMovies, tvKids, tvMusic, tvRegional, tvNews]
      : [musicTrending, musicRegional, musicIndie, musicDevotional, musicChill, musicFocus];
}
```

### 3. UnifiedMediaContent Model
```dart
/// Unified content model for both music and TV
class UnifiedMediaContent extends Equatable {
  final String id;
  final String title;
  final String? subtitle; // Artist for music, group for TV
  final String? thumbnailUrl;
  final String? streamUrl;
  final MediaMode type;
  final MediaCategory? category;
  final Duration? duration;
  final bool isLive;
  final int? viewerCount;
  final List<String> tags;
  final DateTime? lastPlayed;
  final Duration? lastPosition; // For resume functionality
  
  const UnifiedMediaContent({
    required this.id,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.streamUrl,
    required this.type,
    this.category,
    this.duration,
    this.isLive = false,
    this.viewerCount,
    this.tags = const [],
    this.lastPlayed,
    this.lastPosition,
  });
  
  /// Check if content can be resumed
  bool get canResume => lastPosition != null && lastPosition!.inSeconds > 10;
  
  /// Convert from IPTVChannel
  factory UnifiedMediaContent.fromChannel(IPTVChannel channel) {
    return UnifiedMediaContent(
      id: channel.id,
      title: channel.name,
      subtitle: channel.group,
      thumbnailUrl: channel.logoUrl,
      streamUrl: channel.streamUrl,
      type: MediaMode.tv,
      isLive: true,
      tags: [channel.category.label],
    );
  }
  
  /// Convert from MusicTrack
  factory UnifiedMediaContent.fromTrack(MusicTrack track) {
    return UnifiedMediaContent(
      id: track.id,
      title: track.title,
      subtitle: track.artist,
      thumbnailUrl: track.albumArt,
      streamUrl: track.streamUrl,
      type: MediaMode.music,
      duration: track.duration,
      isLive: false,
    );
  }
  
  @override
  List<Object?> get props => [id, type];
}
```

### 4. PlayerDisplayMode Enum
```dart
/// Player display states
enum PlayerDisplayMode {
  collapsed,   // Default ~65% height
  expanded,    // Full viewport (not fullscreen)
  fullscreen,  // System fullscreen
  mini,        // Mini player bar only
  hidden,      // No player visible
}
```

### 5. QualitySettings Model
```dart
/// User quality preferences
class QualitySettings extends Equatable {
  final VideoQuality videoQuality;
  final String? audioLanguage;
  final double playbackSpeed;
  
  const QualitySettings({
    this.videoQuality = VideoQuality.auto,
    this.audioLanguage,
    this.playbackSpeed = 1.0,
  });
  
  QualitySettings copyWith({
    VideoQuality? videoQuality,
    String? audioLanguage,
    double? playbackSpeed,
  }) => QualitySettings(
    videoQuality: videoQuality ?? this.videoQuality,
    audioLanguage: audioLanguage ?? this.audioLanguage,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
  );
  
  @override
  List<Object?> get props => [videoQuality, audioLanguage, playbackSpeed];
}
```

---

## Application State Models

### 6. UnifiedPlayerState
```dart
/// Unified player state combining music and TV player states
class UnifiedPlayerState extends Equatable {
  final UnifiedMediaContent? currentContent;
  final PlaybackState playbackState;
  final PlayerDisplayMode displayMode;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final QualitySettings qualitySettings;
  final BufferStatus bufferStatus;
  final List<UnifiedMediaContent> queue;
  final int currentIndex;
  final String? errorMessage;

  const UnifiedPlayerState({
    this.currentContent,
    this.playbackState = PlaybackState.idle,
    this.displayMode = PlayerDisplayMode.collapsed,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.qualitySettings = const QualitySettings(),
    this.bufferStatus = const BufferStatus(),
    this.queue = const [],
    this.currentIndex = -1,
    this.errorMessage,
  });

  bool get isPlaying => playbackState == PlaybackState.playing;
  bool get isLoading => playbackState == PlaybackState.loading;
  bool get hasError => playbackState == PlaybackState.error;
  bool get hasContent => currentContent != null;
  bool get isMusic => currentContent?.type == MediaMode.music;
  bool get isTV => currentContent?.type == MediaMode.tv;

  /// Progress as percentage (0.0 - 1.0)
  double get progress => duration.inMilliseconds > 0
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  UnifiedPlayerState copyWith({
    UnifiedMediaContent? currentContent,
    PlaybackState? playbackState,
    PlayerDisplayMode? displayMode,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    QualitySettings? qualitySettings,
    BufferStatus? bufferStatus,
    List<UnifiedMediaContent>? queue,
    int? currentIndex,
    String? errorMessage,
  }) => UnifiedPlayerState(
    currentContent: currentContent ?? this.currentContent,
    playbackState: playbackState ?? this.playbackState,
    displayMode: displayMode ?? this.displayMode,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    isMuted: isMuted ?? this.isMuted,
    qualitySettings: qualitySettings ?? this.qualitySettings,
    bufferStatus: bufferStatus ?? this.bufferStatus,
    queue: queue ?? this.queue,
    currentIndex: currentIndex ?? this.currentIndex,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    currentContent, playbackState, displayMode, position,
    volume, isMuted, qualitySettings, queue, currentIndex,
  ];
}
```

### 7. DiscoveryState
```dart
/// Discovery/browse state for content exploration
class DiscoveryState extends Equatable {
  final MediaMode currentMode;
  final MediaCategory? selectedCategory;
  final List<UnifiedMediaContent> contentItems;
  final bool isLoading;
  final String? errorMessage;
  final String? searchQuery;
  final bool hasMore; // Pagination

  const DiscoveryState({
    this.currentMode = MediaMode.music,
    this.selectedCategory,
    this.contentItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery,
    this.hasMore = true,
  });

  /// Get available categories for current mode
  List<MediaCategory> get availableCategories =>
      MediaCategories.forMode(currentMode);

  /// Filtered content based on selected category
  List<UnifiedMediaContent> get filteredContent {
    if (selectedCategory == null) return contentItems;
    return contentItems.where((c) => c.category == selectedCategory).toList();
  }

  DiscoveryState copyWith({
    MediaMode? currentMode,
    MediaCategory? selectedCategory,
    List<UnifiedMediaContent>? contentItems,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    bool? hasMore,
  }) => DiscoveryState(
    currentMode: currentMode ?? this.currentMode,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    contentItems: contentItems ?? this.contentItems,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
    searchQuery: searchQuery ?? this.searchQuery,
    hasMore: hasMore ?? this.hasMore,
  );

  @override
  List<Object?> get props => [
    currentMode, selectedCategory, contentItems,
    isLoading, searchQuery, hasMore,
  ];
}
```

### 8. PersonalizationState
```dart
/// User personalization state for resume/favorites
class PersonalizationState extends Equatable {
  final List<UnifiedMediaContent> continueWatching;
  final List<UnifiedMediaContent> recentlyPlayed;
  final Set<String> favoriteIds;
  final Map<String, Duration> playbackPositions; // id -> last position

  const PersonalizationState({
    this.continueWatching = const [],
    this.recentlyPlayed = const [],
    this.favoriteIds = const {},
    this.playbackPositions = const {},
  });

  /// Check if content is favorited
  bool isFavorite(String contentId) => favoriteIds.contains(contentId);

  /// Get last position for content
  Duration? getLastPosition(String contentId) => playbackPositions[contentId];

  PersonalizationState copyWith({
    List<UnifiedMediaContent>? continueWatching,
    List<UnifiedMediaContent>? recentlyPlayed,
    Set<String>? favoriteIds,
    Map<String, Duration>? playbackPositions,
  }) => PersonalizationState(
    continueWatching: continueWatching ?? this.continueWatching,
    recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    playbackPositions: playbackPositions ?? this.playbackPositions,
  );

  @override
  List<Object?> get props => [
    continueWatching, recentlyPlayed, favoriteIds, playbackPositions,
  ];
}
```

---

## Riverpod Providers

### UI State Providers
```dart
/// Current media mode (Music/TV)
final selectedMediaModeProvider = StateProvider<MediaMode>((ref) => MediaMode.music);

/// Selected category for filtering
final selectedCategoryProvider = StateProvider<MediaCategory?>((ref) => null);

/// Player display mode
final playerDisplayModeProvider = StateProvider<PlayerDisplayMode>(
  (ref) => PlayerDisplayMode.collapsed,
);

/// Search query
final mediaSearchQueryProvider = StateProvider<String>((ref) => '');
```

### State Notifier Providers
```dart
/// Unified player state notifier
final unifiedPlayerProvider = StateNotifierProvider<UnifiedPlayerNotifier, UnifiedPlayerState>(
  (ref) => UnifiedPlayerNotifier(ref),
);

/// Discovery state notifier
final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
  (ref) => DiscoveryNotifier(ref),
);

/// Personalization state notifier
final personalizationProvider = StateNotifierProvider<PersonalizationNotifier, PersonalizationState>(
  (ref) => PersonalizationNotifier(ref),
);

/// Quality settings (persisted)
final qualitySettingsProvider = StateNotifierProvider<QualitySettingsNotifier, QualitySettings>(
  (ref) => QualitySettingsNotifier(ref),
);
```

### Derived Providers
```dart
/// Current content filtered by mode and category
final filteredContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  final discovery = ref.watch(discoveryProvider);
  return discovery.filteredContent;
});

/// Continue watching/listening content
final continueContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  final personalization = ref.watch(personalizationProvider);
  final mode = ref.watch(selectedMediaModeProvider);

  return personalization.continueWatching
      .where((c) => c.type == mode)
      .take(10)
      .toList();
});

/// Recent content for current mode
final recentContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  final personalization = ref.watch(personalizationProvider);
  final mode = ref.watch(selectedMediaModeProvider);

  return personalization.recentlyPlayed
      .where((c) => c.type == mode)
      .take(20)
      .toList();
});

/// Favorites for current mode
final favoritesProvider = Provider<List<UnifiedMediaContent>>((ref) {
  final personalization = ref.watch(personalizationProvider);
  final discovery = ref.watch(discoveryProvider);
  final mode = ref.watch(selectedMediaModeProvider);

  return discovery.contentItems
      .where((c) => c.type == mode && personalization.isFavorite(c.id))
      .toList();
});
```

---

## State Notifier Implementations

### UnifiedPlayerNotifier
```dart
class UnifiedPlayerNotifier extends StateNotifier<UnifiedPlayerState> {
  final Ref _ref;
  StreamSubscription? _positionSubscription;

  UnifiedPlayerNotifier(this._ref) : super(const UnifiedPlayerState());

  Future<void> play(UnifiedMediaContent content) async {
    state = state.copyWith(
      currentContent: content,
      playbackState: PlaybackState.loading,
    );

    // Delegate to appropriate player service
    if (content.type == MediaMode.music) {
      await _ref.read(musicServiceProvider).playTrack(_toMusicTrack(content));
    } else {
      await _ref.read(iptvStreamingServiceProvider).playChannel(_toChannel(content));
    }

    // Update personalization
    _ref.read(personalizationProvider.notifier).addToRecent(content);
  }

  void pause() { /* ... */ }
  void resume() { /* ... */ }
  void seek(Duration position) { /* ... */ }
  void setDisplayMode(PlayerDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }
  void toggleFavorite() {
    final id = state.currentContent?.id;
    if (id != null) {
      _ref.read(personalizationProvider.notifier).toggleFavorite(id);
    }
  }
}
```

### PersonalizationNotifier
```dart
class PersonalizationNotifier extends StateNotifier<PersonalizationState> {
  final Ref _ref;

  PersonalizationNotifier(this._ref) : super(const PersonalizationState()) {
    _loadFromStorage();
  }

  void addToRecent(UnifiedMediaContent content) {
    final updated = [content, ...state.recentlyPlayed.where((c) => c.id != content.id)]
        .take(50)
        .toList();
    state = state.copyWith(recentlyPlayed: updated);
    _saveToStorage();
  }

  void savePosition(String contentId, Duration position) {
    final positions = Map<String, Duration>.from(state.playbackPositions);
    positions[contentId] = position;
    state = state.copyWith(playbackPositions: positions);
    _saveToStorage();
  }

  void toggleFavorite(String contentId) {
    final favorites = Set<String>.from(state.favoriteIds);
    if (favorites.contains(contentId)) {
      favorites.remove(contentId);
    } else {
      favorites.add(contentId);
    }
    state = state.copyWith(favoriteIds: favorites);
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async { /* Load from Hive/SharedPrefs */ }
  Future<void> _saveToStorage() async { /* Save to Hive/SharedPrefs */ }
}
```

---

## State Flow Diagram

```
User Action → Provider Update → Widget Rebuild → UI Update
     ↓
[Mode Switch] → selectedMediaModeProvider → CategoryChipsBar rebuilds
     ↓
[Category Tap] → selectedCategoryProvider → filteredContentProvider → ContentGrid rebuilds
     ↓
[Content Tap] → unifiedPlayerProvider.play() → HeroPlayer rebuilds
     ↓
[Favorite Tap] → personalizationProvider.toggleFavorite() → FavoriteButton rebuilds
```


