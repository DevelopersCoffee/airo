# Flutter IPTV Application - Comprehensive Requirements Specification

**Target Platforms:** iOS, Android, Web (PWA), Desktop (Windows/macOS/Linux)  
**Architecture Pattern:** Hexagonal (Ports & Adapters)  
**State Management:** Riverpod  
**Video Engine:** media_kit (libmpv backend)  
**Database:** Drift (SQLite with WAL mode)  
**Last Updated:** Sprint Planning Phase

---

## 1. ARCHITECTURAL LAYERS

### 1.1 Core Domain Layer (Business Logic)
- **Responsibility:** Playlist parsing, EPG management, stream metadata
- **Platform:** Dart (pure Dart, no platform-specific code)
- **Key Packages:** `xml_events`, `dio`, `drift`

### 1.2 Service Layer (Orchestration)
- **Responsibility:** Isolate-based background parsing, Xtream API coordination
- **Platform:** Dart with `workmanager` for background tasks
- **Key Packages:** `workmanager`, `flutter_background_service`

### 1.3 Data Layer (Persistence)
- **Responsibility:** SQLite database via Drift with repositories
- **Platform:** Cross-platform (handled by Drift + platform-specific native database drivers)
- **Key Packages:** `drift`, `sqlite3_flutter_libs`

### 1.4 Media Layer (Playback)
- **Responsibility:** Video/audio streaming, codec handling, casting
- **Platform:** Hybrid (media_kit wraps platform-specific libmpv)
- **Key Packages:** `media_kit`, `flutter_cast_framework`

### 1.5 UI/Presentation Layer (Widget Tree)
- **Responsibility:** Mobile-first, touch-optimized interfaces
- **Platform:** Flutter (cross-platform widgets with platform-specific polish)
- **Key Packages:** `riverpod`, `go_router`, `flutter_hooks`

---

## 2. DATA LAYER REQUIREMENTS

### 2.1 Database Schema (Drift)

#### Table: Playlists
```dart
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get serverUrl => text()();
  TextColumn get username => text().nullable()();
  TextColumn get password => text().nullable()();
  IntColumn get type => integer()(); // 0: M3U, 1: Xtream, 2: Stalker
  TextColumn get userAgent => text().nullable()();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  @override
  Set<Column> get primaryKey => {id};
}
```
**Acceptance Criteria:**
- [ ] Table creates successfully on first run
- [ ] Supports concurrent reads via WAL mode
- [ ] Migrations work without data loss

#### Table: Channels
```dart
class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text().references(Playlists, #id)();
  TextColumn get name => text()();
  TextColumn get groupTitle => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get tvgId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get type => integer().withDefault(const Constant(0))(); // 0: Live, 1: VOD, 2: Series
  
  @override
  Set<Column> get primaryKey => {id, playlistId};
  @override
  List<String> get customConstraints => ['UNIQUE(playlistId, streamUrl)'];
}
```
**Acceptance Criteria:**
- [ ] 50k+ channels load without UI blocking
- [ ] Fuzzy search executes in <50ms on 50k channels
- [ ] Favorites/Hidden state persists across app restarts

#### Table: EpgPrograms
```dart
class EpgPrograms extends Table {
  TextColumn get id => text()();
  TextColumn get channelTvgId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get playlistId => text().references(Playlists, #id)();
  
  @override
  Set<Column> get primaryKey => {id, channelTvgId};
}
```
**Acceptance Criteria:**
- [ ] Supports 100MB+ XMLTV files without OOM
- [ ] EPG grid displays 2-week view without lag
- [ ] Catch-up/Timeshift URLs generate correctly

#### Table: VodContent (Movies & Series)
```dart
class VodContent extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text().references(Playlists, #id)();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'movie' or 'series'
  TextColumn get description => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  IntColumn get rating => integer().nullable()();
  IntColumn get categoryId => integer()();
  DateTimeColumn get addedDate => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id, playlistId};
}
```

#### Table: UserPreferences
```dart
class UserPreferences extends Table {
  TextColumn get userId => text()(); // Device ID for multi-device support
  TextColumn get playlistId => text().nullable()();
  TextColumn get lastWatchedChannelId => text().nullable()();
  TextColumn get lastWatchedPosition => text().nullable()(); // JSON: {channel_id, timestamp}
  TextColumn get hiddenCategories => text()(); // JSON array
  DateTimeColumn get syncedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {userId};
}
```

**Database Configuration:**
```dart
@DriftDatabase(tables: [Playlists, Channels, EpgPrograms, VodContent, UserPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app.db'));
      final executor = NativeDatabase.createInBackground(
        file,
        logStatements: true,
        setup: (db) async {
          await db.execute('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=NORMAL');
        },
      );
      return executor;
    });
  }

  @override
  int get schemaVersion => 1;
}
```

---

### 2.2 Playlist Parsing Service (Core Domain)

#### M3U Parser Specification
**Location:** `lib/domain/services/m3u_parser.dart`

**Requirements:**
- Parse standard `#EXTINF` tags
- Extract proprietary fields: `tvg-id`, `tvg-logo`, `group-title`, `tvg-name`, `tvg-chno`
- Handle malformed entries gracefully
- Support custom user-agent headers
- Return normalized `Channel` objects

**Acceptance Criteria:**
- [ ] Parses 50k-line M3U in <2 seconds on mid-range device
- [ ] Preserves all metadata (logo URLs, group titles)
- [ ] Handles Windows/UNIX/Mac line endings
- [ ] Gracefully skips malformed lines with logging

**Example Dart Interface:**
```dart
abstract class M3uParserService {
  Stream<List<Channel>> parseM3u(
    String content, {
    required String playlistId,
    String? userAgent,
  });
  
  Future<String> downloadM3u(
    String url, {
    String? username,
    String? password,
    String? userAgent,
  });
}
```

---

#### Isolate-Based Parsing (Service Layer)
**Location:** `lib/domain/services/playlist_ingestion_service.dart`

**Requirements:**
- Run M3U parsing in background isolate to prevent UI blocking
- Batch insert channels (500 channels per transaction)
- Report progress via Stream for UI updates
- Handle cancellation mid-parse

**Acceptance Criteria:**
- [ ] 50MB M3U loads while UI maintains 60fps
- [ ] Progress bar updates every 0.5 seconds
- [ ] User can cancel without database corruption
- [ ] Duplicate channel detection by URL + name

**Pseudo-code:**
```dart
Stream<ParseProgress> ingestPlaylistIsolate(
  String url,
  String playlistId,
) async* {
  // Spawn isolate
  // Download M3U
  // Parse in batches of 500
  // Yield progress updates
  // Insert into drift DB
  // Cleanup isolate
}
```

---

#### Xtream Codes API Client
**Location:** `lib/domain/services/xtream_service.dart`

**Base Endpoint:** `http://portal-url.com/player_api.php`

**Endpoints to Implement:**

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `?action=get_live_categories` | Fetch live TV categories | JSON array of `{category_id, category_name}` |
| `?action=get_vod_categories` | Fetch VOD categories | JSON array |
| `?action=get_series_categories` | Fetch series categories | JSON array |
| `?action=get_live_streams&category_id=X` | Fetch streams for category | JSON array of streams |
| `?action=get_vod_streams&category_id=X` | Fetch VOD for category | JSON array of movies |
| `?action=get_series&category_id=X` | Fetch series for category | JSON array of series |
| `?action=get_series_info&series_id=X` | Get series seasons/episodes | JSON with seasons array |

**Acceptance Criteria:**
- [ ] Lazy-loads categories (no loading 100k streams at once)
- [ ] Caches category metadata for 24 hours
- [ ] Handles 401 (auth failure) gracefully
- [ ] Supports custom user-agent per portal
- [ ] Implements exponential backoff on rate limit (429)

**Pseudo-code:**
```dart
abstract class XtreamService {
  Future<List<Category>> getLiveCategories();
  Future<List<Channel>> getLiveStreams(int categoryId);
  Future<List<VodContent>> getVodStreams(int categoryId);
  Future<SeriesInfo> getSeriesInfo(int seriesId);
}
```

---

#### XMLTV EPG Parser (Streaming)
**Location:** `lib/domain/services/epg_parser.dart`

**Requirements:**
- Stream-parse XMLTV to prevent OOM on large files
- Use `xml_events` package (event-based, not DOM)
- Handle missing/malformed EPG gracefully
- Link EPG programs to channels via `tvg-id`

**Implementation Note:** Process XMLTV in background isolate via workmanager.

**Acceptance Criteria:**
- [ ] Parses 100MB+ XMLTV without OOM
- [ ] EPG grid displays immediately for 100+ channels
- [ ] Catch-up URLs append `?utc=START&lutc=END` correctly
- [ ] Handles missing channel matches gracefully

---

### 2.3 Repository Pattern (Data Access)

**Location:** `lib/domain/repositories/`

**Repositories Required:**

1. **PlaylistRepository**
   - `addPlaylist(Playlist)` → Future<String> (returns playlist ID)
   - `getPlaylist(id)` → Future<Playlist?>
   - `updatePlaylist(Playlist)` → Future<void>
   - `deletePlaylist(id)` → Future<void>
   - `watchAllPlaylists()` → Stream<List<Playlist>>

2. **ChannelRepository**
   - `getChannelsByPlaylist(playlistId)` → Future<List<Channel>>
   - `watchChannelsByPlaylist(playlistId)` → Stream<List<Channel>>
   - `searchChannels(query, playlistId)` → Future<List<Channel>>
   - `toggleFavorite(channelId)` → Future<void>
   - `toggleHidden(channelId)` → Future<void>
   - `getChannelsByGroup(groupTitle)` → Future<List<Channel>>

3. **EpgRepository**
   - `getProgramsForChannel(tvgId, date)` → Future<List<EpgProgram>>
   - `watchProgramsForChannel(tvgId, date)` → Stream<List<EpgProgram>>
   - `upsertPrograms(programs)` → Future<void>
   - `getLastEpgSync()` → Future<DateTime?>

4. **VodRepository**
   - `getVodByCategory(categoryId)` → Future<List<VodContent>>
   - `watchVodByCategory(categoryId)` → Stream<List<VodContent>>
   - `searchVod(query)` → Future<List<VodContent>>
   - `getPaginatedVod(categoryId, page)` → Future<List<VodContent>>

5. **UserPreferencesRepository**
   - `saveLastWatched(channelId, position)` → Future<void>
   - `getLastWatched()` → Future<UserPreferences?>
   - `saveHiddenCategories(List<String>)` → Future<void>
   - `getHiddenCategories()` → Future<List<String>>

---

## 3. MEDIA PLAYER LAYER REQUIREMENTS

### 3.1 Media Engine (media_kit Integration)

**Location:** `lib/domain/services/media_service.dart`

**Initialization (main.dart):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaKit.ensureInitialized();
  // ... rest of initialization
  runApp(const MyApp());
}
```

**Core Requirements:**
- Initialize media_kit on app start
- Support HLS (.m3u8), Transport Stream (.ts), MP4, and audio-only streams
- Pass custom User-Agent headers per provider
- Handle stream redirects transparently
- Implement play/pause/seek controls

**Acceptance Criteria:**
- [ ] Plays HLS (m3u8) streams on all platforms
- [ ] Plays .ts streams without buffering issues
- [ ] Audio-only streams show placeholder UI
- [ ] User-Agent header passed to streaming server
- [ ] Seek accuracy ±500ms
- [ ] No black screen on app backgrounding/foregrounding

**Pseudo-code:**
```dart
abstract class MediaService {
  Future<void> initialize();
  Future<void> openStream(Channel channel);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
  
  // Getters for state
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get isPlaying;
}
```

---

### 3.2 Catch-Up & Timeshift (VOD Playback)

**Location:** `lib/domain/services/catchup_service.dart`

**Requirements:**
- When user taps an EPG program from the past, construct a catch-up URL
- Append UTC timestamps: `?utc=START_TIMESTAMP&lutc=END_TIMESTAMP`
- Support different provider URL formats (some use `?start=` and `?end=`)
- Handle no-catchup-available gracefully

**Acceptance Criteria:**
- [ ] Constructs catch-up URL with correct timestamps
- [ ] Plays past EPG programs on demand
- [ ] Shows "Catchup not available" for expired programs
- [ ] Handles timezone conversions correctly

**Example:**
```dart
String generateCatchupUrl(
  Channel channel,
  EpgProgram program,
) {
  final startUtc = program.startTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  final endUtc = program.endTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  return '${channel.streamUrl}?utc=$startUtc&lutc=$endUtc';
}
```

---

### 3.3 Casting Integration (Chromecast & AirPlay)

**Location:** `lib/domain/services/casting_service.dart`

**Requirements:**
- Discover Chromecast devices via mDNS
- Discover AirPlay devices on iOS/macOS
- Cast current stream to selected device
- Show casting status in player overlay
- Handle disconnection gracefully

**Packages:**
- `flutter_cast_framework` (Android/iOS)
- `mdns_sd` (mDNS discovery)

**V1 Scope:** Single-device casting of public IPTV streams only (defer multi-device orchestration to V2)

**Acceptance Criteria:**
- [ ] Discovers local Chromecast devices (Sony Bravia, Chromecast)
- [ ] Successfully initiates cast
- [ ] Displays "Casting to Device X" indicator
- [ ] Handles device disconnection
- [ ] Works on WiFi-only networks

**Pseudo-code:**
```dart
abstract class CastingService {
  Stream<List<CastDevice>> discoverDevices();
  Future<void> castStream(CastDevice device, Channel channel);
  Future<void> stopCasting();
  Stream<CastingState> get castingState;
}
```

---

## 4. STATE MANAGEMENT LAYER (Riverpod)

**Location:** `lib/presentation/providers/`

### 4.1 Core State Providers

#### PlaylistProviders
```dart
// Current active playlist
final activePlaylistProvider = StateProvider<String?>((ref) => null);

// List of all playlists
final playlistsProvider = StreamProvider<List<Playlist>>((ref) async* {
  final repo = ref.watch(playlistRepositoryProvider);
  yield* repo.watchAllPlaylists();
});

// Playlist details by ID
final playlistDetailProvider = FutureProvider.family<Playlist?, String>((ref, id) async {
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.getPlaylist(id);
});
```

#### ChannelProviders
```dart
// Channels for active playlist
final activePlaylistChannelsProvider = StreamProvider<List<Channel>>((ref) async* {
  final playlistId = ref.watch(activePlaylistProvider);
  if (playlistId == null) return;
  
  final repo = ref.watch(channelRepositoryProvider);
  yield* repo.watchChannelsByPlaylist(playlistId);
});

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered channels based on search
final filteredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final channels = ref.watch(activePlaylistChannelsProvider);
  final query = ref.watch(searchQueryProvider);
  
  return channels.maybeWhen(
    data: (data) async {
      if (query.isEmpty) return data;
      final repo = ref.watch(channelRepositoryProvider);
      return repo.searchChannels(query, data.first.playlistId);
    },
    orElse: () => [],
  );
});

// Hidden categories
final hiddenCategoriesProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(userPreferencesRepositoryProvider);
  final hidden = await repo.getHiddenCategories();
  return hidden.toSet();
});

// Filtered channels excluding hidden categories
final visibleChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final channels = ref.watch(filteredChannelsProvider);
  final hidden = ref.watch(hiddenCategoriesProvider);
  
  return channels.maybeWhen(
    data: (data) => hidden.maybeWhen(
      data: (hiddenSet) => data.where(
        (ch) => !hiddenSet.contains(ch.groupTitle ?? 'Unknown'),
      ).toList(),
      orElse: () => data,
    ),
    orElse: () => [],
  );
});
```

#### PlaybackProviders
```dart
// Currently playing channel
final currentChannelProvider = StateProvider<Channel?>((ref) => null);

// Player UI visibility (immersive mode toggle)
final playerUiVisibleProvider = StateProvider<bool>((ref) => true);

// Player playback state
final playerStateProvider = StreamProvider<PlayerState>((ref) {
  final mediaService = ref.watch(mediaServiceProvider);
  return mediaService.playerState;
});

// Current playback position
final playbackPositionProvider = StreamProvider<Duration>((ref) {
  final mediaService = ref.watch(mediaServiceProvider);
  return mediaService.position;
});
```

#### EPGProviders
```dart
// EPG programs for current channel on given date
final epgForChannelProvider = FutureProvider.family<List<EpgProgram>, DateTime>(
  (ref, date) async {
    final channel = ref.watch(currentChannelProvider);
    if (channel == null) return [];
    
    final repo = ref.watch(epgRepositoryProvider);
    return repo.getProgramsForChannel(channel.tvgId ?? '', date);
  },
);

// Current EPG program for channel
final currentEpgProgramProvider = FutureProvider<EpgProgram?>((ref) async {
  final channel = ref.watch(currentChannelProvider);
  if (channel == null) return null;
  
  final repo = ref.watch(epgRepositoryProvider);
  final programs = await repo.getProgramsForChannel(
    channel.tvgId ?? '',
    DateTime.now(),
  );
  
  final now = DateTime.now();
  return programs.firstWhereOrNull(
    (p) => p.startTime.isBefore(now) && p.endTime.isAfter(now),
  );
});
```

#### CastingProviders
```dart
// Available casting devices
final availableCastDevicesProvider = StreamProvider<List<CastDevice>>((ref) {
  final castService = ref.watch(castingServiceProvider);
  return castService.discoverDevices();
});

// Current casting state
final castingStateProvider = StreamProvider<CastingState>((ref) {
  final castService = ref.watch(castingServiceProvider);
  return castService.castingState;
});
```

---

### 4.2 Repository Providers (Dependency Injection)

```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PlaylistRepositoryImpl(db);
});

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChannelRepositoryImpl(db);
});

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EpgRepositoryImpl(db);
});

final vodRepositoryProvider = Provider<VodRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return VodRepositoryImpl(db);
});

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserPreferencesRepositoryImpl(db);
});
```

---

### 4.3 Service Providers

```dart
final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaServiceImpl();
});

final castingServiceProvider = Provider<CastingService>((ref) {
  return CastingServiceImpl();
});

final xtreamServiceProvider = Provider.family<XtreamService, Playlist>(
  (ref, playlist) {
    return XtreamServiceImpl(playlist);
  },
);

final m3uParserProvider = Provider<M3uParserService>((ref) {
  return M3uParserServiceImpl();
});

final playlistIngestionServiceProvider = Provider<PlaylistIngestionService>((ref) {
  final m3uParser = ref.watch(m3uParserProvider);
  final channelRepo = ref.watch(channelRepositoryProvider);
  return PlaylistIngestionServiceImpl(m3uParser, channelRepo);
});
```

---

## 5. BACKGROUND SYNC LAYER (Workmanager)

**Location:** `lib/infrastructure/background_tasks/`

### 5.1 EPG Sync Task

**File:** `lib/infrastructure/background_tasks/epg_sync_task.dart`

**Requirements:**
- Run every 12 hours on Android
- iOS: Use BGAppRefreshTask (OS-controlled timing)
- Download XMLTV from playlist URL
- Stream-parse into EpgPrograms table
- Show completion notification
- Handle failures gracefully with retry logic

**Pseudo-code:**
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == 'syncEpg') {
        // 1. Get all active playlists from DB
        // 2. For each, fetch XMLTV URL
        // 3. Stream-parse into EpgPrograms
        // 4. Update lastEpgSync timestamp
        // 5. Show notification
        return Future.value(true);
      }
    } catch (e) {
      // Log error, retry next scheduled time
      return Future.value(false);
    }
  });
}
```

**Initialization (main.dart):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Schedule EPG sync
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  
  Workmanager().registerPeriodicTask(
    'epgSync',
    'syncEpg',
    frequency: const Duration(hours: 12),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
    ),
  );
  
  runApp(const MyApp());
}
```

**Acceptance Criteria:**
- [ ] Android: Syncs every 12 hours
- [ ] iOS: Syncs on app launch if sync is >12 hours old
- [ ] EPG UI shows "Syncing..." indicator during background task
- [ ] No data loss on sync failure
- [ ] Battery impact is minimal

---

### 5.2 Playlist Update Task

**Requirements:**
- Periodically re-fetch Xtream category lists
- Update channel metadata (logos, names, groups)
- Detect new channels and add to DB
- Mark stale channels as unavailable

**Frequency:** Every 24 hours for Xtream, every 7 days for M3U

---

## 6. UI/UX LAYER SPECIFICATIONS

**Location:** `lib/presentation/screens/`, `lib/presentation/widgets/`

### 6.1 Core Screens

#### 6.1.1 Dashboard Screen
**File:** `lib/presentation/screens/dashboard_screen.dart`

**Layout (Mobile-first vertical):**
```
┌─────────────────┐
│   Search Bar    │
├─────────────────┤
│ Continue Watch  │
│  [Thumbnail]    │
├─────────────────┤
│    Favorites    │
│ [Grid of logos] │
├─────────────────┤
│   Categories    │
│  [Scroll List]  │
└─────────────────┘
```

**Widgets:**
- `SearchBar`: Persistent top bar, filters channels real-time
- `ContinueWatchingSection`: Shows last 5 watched channels
- `FavoritesGrid`: 4-column grid of favorited channel logos
- `CategoryCarousel`: Horizontal scroll of categories
- `ChannelTile`: Tap to play, long-press for actions (add favorite, hide category)

**Acceptance Criteria:**
- [ ] Search state persists when navigating away
- [ ] Favorites load instantly from local DB
- [ ] Continuous Watching updates on every channel switch
- [ ] Category carousel horizontal scrolls smoothly
- [ ] Tap/long-press gestures responsive

---

#### 6.1.2 Channel List Screen
**File:** `lib/presentation/screens/channel_list_screen.dart`

**Layout:**
```
┌─────────────────┐
│ [Active Category]
│ Search bar      │
├─────────────────┤
│ Channel List    │
│ [Stream-built]  │
│ [Icon][Name]    │
│                 │
│ (Pull to refresh)
└─────────────────┘
```

**Widgets:**
- `CategoryFilterChip`: Tap to filter by group
- `ChannelListTile`: Logo, name, play button
- `FavoriteIcon`: Toggle favorite
- `HideIcon`: Toggle category visibility
- `PullToRefresh`: Refresh channel list from server

**Acceptance Criteria:**
- [ ] Channels load via StreamBuilder without blocking
- [ ] Fuzzy search <50ms for 50k channels
- [ ] Pull-to-refresh updates category metadata (Xtream only)
- [ ] Favorite toggle instant, persisted
- [ ] Hide category removes all channels in group

---

#### 6.1.3 Player Screen
**File:** `lib/presentation/screens/player_screen.dart`

**Layout (Immersive Mode):**
```
Full screen video with overlay controls:
- Tap video to toggle UI
- Left swipe: Brightness (left side)
- Right swipe: Volume (right side)
- Horizontal swipe: Seek VOD content
- Pinch: Zoom (if supported by media_kit)
- Double-tap: Play/Pause
```

**Widgets:**
- `VideoPlayerOverlay`: Shows play/pause, seek bar, title
- `BrightnessVolumeGestures`: Left/right swipe handlers
- `PlayerControlsBar`: Play, pause, next/prev channel, cast button
- `CastIndicator`: Shows "Casting to Device X"
- `EPGOverlay`: Optional overlay showing current + next program

**Gesture Map:**
- Single tap: Toggle UI visibility
- Double tap: Play/Pause
- Swipe left (left 1/3): Brightness -/+
- Swipe right (right 1/3): Volume -/+
- Horizontal swipe (center): Seek VOD
- Long press: Show EPG programs for channel

**Acceptance Criteria:**
- [ ] 60fps playback with gesture overlays
- [ ] Single-tap toggle immersive mode instantly
- [ ] Brightness/volume swipes responsive
- [ ] Seek works for VOD, disabled for live
- [ ] Casting button shows available devices

---

#### 6.1.4 EPG Grid Screen
**File:** `lib/presentation/screens/epg_screen.dart`

**Layout:**
```
┌──────────────────┐
│ Time ←→ Scroll   │
├──────────────────┤
│ Channel1 │[Program A][Program B]
│ Channel2 │[Program C][Program D]
│ Channel3 │[Program E][Program F]
│          │ (Pinch to zoom time)
└──────────────────┘
```

**Widgets:**
- `EpgTimeHeader`: Horizontal time slots (30-min intervals)
- `EpgChannelColumn`: Vertical list of channels
- `EpgProgramCell`: Program title, tap to play catch-up
- `DateNavigator`: Switch between today, tomorrow, +7 days

**Acceptance Criteria:**
- [ ] 2-week EPG view loads <500ms
- [ ] Horizontal scroll for time slots smooth
- [ ] Vertical scroll for channels smooth
- [ ] Tap past program to play catch-up
- [ ] Pinch-to-zoom time scaling (optional V2)

---

#### 6.1.5 VOD/Series Screen
**File:** `lib/presentation/screens/vod_screen.dart`

**Layout (Netflix-style):**
```
┌──────────────────┐
│ [Category Tabs]  │
│ Movies | Series  │
├──────────────────┤
│ [Poster] [Poster]│
│ [Poster] [Poster]│
│ [Poster] [Poster]│
│   (Pagination)   │
└──────────────────┘
```

**Widgets:**
- `CategoryTabs`: Switch Movies/Series
- `VodGridView`: Lazy-loaded grid via PagingController
- `VodPosterTile`: Image (cached), title, rating
- `VodDetailSheet`: Bottom sheet with synopsis, cast, play button
- `SeasonSelector`: Dropdown for series seasons
- `EpisodeList`: List of episodes for selected season

**Packages:**
- `infinite_scroll_pagination`: For pagination
- `cached_network_image`: For poster caching with strict memory limits

**Acceptance Criteria:**
- [ ] Posters load via pagination (50 at a time)
- [ ] Image cache limited to 100MB
- [ ] Tap poster → Detail sheet (not full screen)
- [ ] Series detail sheet shows season dropdown + episode list
- [ ] Play button navigates to player with correct stream URL
- [ ] No OOM crashes on low-end devices

---

### 6.2 Dialogs & Sheets

#### Playlist Import Dialog
**File:** `lib/presentation/widgets/playlist_import_dialog.dart`

**Flow:**
1. User taps "Add Playlist"
2. Show dialog with:
   - URL input field
   - Type selector (M3U / Xtream / Stalker)
   - Username/password fields (Xtream/Stalker only)
   - User-Agent override (optional)
3. Submit → Trigger isolate-based parsing
4. Show progress dialog "Importing X% (Y/Z channels)"
5. On complete → Add to DB, dismiss dialog

**Acceptance Criteria:**
- [ ] URL validation (must be valid URL)
- [ ] Credentials required for Xtream/Stalker
- [ ] Progress updates every 0.5s
- [ ] Cancel button stops mid-parse
- [ ] Error handling: network, invalid format, auth

---

#### Category Management Sheet
**File:** `lib/presentation/widgets/category_management_sheet.dart`

**Flow:**
1. User taps "Manage Categories" in dashboard
2. Show bottom sheet with:
   - List of all categories with checkboxes
   - "Select All" / "Deselect All" buttons
   - Save button
3. Unchecked categories apply `isHidden = true` to all channels
4. State persists in `UserPreferences` table

**Acceptance Criteria:**
- [ ] Multi-select with checkboxes
- [ ] Apply instantly on save
- [ ] Hidden categories don't appear in channel lists
- [ ] State persists across app restarts

---

#### Casting Device Selector
**File:** `lib/presentation/widgets/cast_device_selector.dart`

**Flow:**
1. User taps casting icon in player
2. Show bottom sheet with discovered Chromecast devices
3. Tap device → Cast current stream
4. Show "Casting to Device X" indicator

**Acceptance Criteria:**
- [ ] Discovers devices within 2 seconds
- [ ] Tap device initiates cast
- [ ] Show loading indicator during cast handshake
- [ ] Handle disconnection gracefully

---

### 6.3 Navigation Structure

**Router Config (go_router):**
```dart
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
      routes: [
        GoRoute(
          path: 'channels/:playlistId',
          builder: (context, state) => ChannelListScreen(
            playlistId: state.pathParameters['playlistId']!,
          ),
        ),
        GoRoute(
          path: 'player/:channelId',
          builder: (context, state) => PlayerScreen(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: 'epg',
          builder: (context, state) => const EpgScreen(),
        ),
        GoRoute(
          path: 'vod/:playlistId',
          builder: (context, state) => VodScreen(
            playlistId: state.pathParameters['playlistId']!,
          ),
        ),
      ],
    ),
  ],
);
```

---

## 7. CROSS-PLATFORM CONSIDERATIONS

### 7.1 Platform-Specific Code

#### iOS Requirements
- **AirPlay Support:** Implement via platform channel
- **Background Tasks:** Use BGAppRefreshTask (not Workmanager)
- **App Group:** Share data with AirPlay/CarPlay if applicable
- **Vibration:** Haptic feedback on channel switch (optional)

#### Android Requirements
- **Notification Permissions:** Request at runtime (API 33+)
- **Foreground Service:** For background EPG sync (if backgrounding)
- **Device Admin:** Optional (for advanced casting scenarios V2)
- **Battery Optimization:** Whitelist app from doze mode for casting

#### Web (PWA) Requirements
- **IndexedDB:** Use for offline playlist caching
- **Service Worker:** Cache M3U/XMLTV for offline access
- **Casting:** No native casting (V2 consideration)
- **Geolocation:** Optional geo-blocking bypass (V2)

#### Desktop (Windows/macOS/Linux)
- **Native Window:** Use `bitsdojo_window` + `flutter_window_close`
- **Keyboard Shortcuts:** Cmd+K for search, arrow keys for channel nav
- **System Tray:** Minimize to tray on close
- **Desktop Notifications:** Show EPG alerts via desktop notifications

---

### 7.2 Responsive Design

**Breakpoints:**
```dart
// Mobile: < 600dp
// Tablet: 600-1200dp
// Desktop: > 1200dp

class MediaQueryHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;
  
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;
}
```

**Layout Adaption:**
- Mobile: Single-column, bottom navigation
- Tablet: Split-view (channels + player)
- Desktop: Full three-pane (categories + channels + player)

---

## 8. IMPLEMENTATION ROADMAP

### Sprint 0: Technical Spikes (Research/Prototype)

**Week 1:**
- [ ] Media Engine Spike: Bare `media_kit` app playing .m3u8, .ts, audio streams
- [ ] Data Pipeline Spike: Isolate parsing 100MB XMLTV without blocking UI
- [ ] Mobile Wireframing: Figma prototype for bottom-sheet search

**Success Criteria:**
- [ ] Video plays smoothly on iOS simulator + Android device
- [ ] UI remains at 60fps during background parsing
- [ ] Figma prototype approved by PM

---

### Sprint 1: Core Foundation (Weeks 2-5)

**Epics:**
1. Database schema + Drift setup with WAL mode
2. M3U parser (Dart port) + Isolate integration
3. media_kit player initialization + HLS/TS playback
4. Riverpod state management foundation
5. Dashboard + Channel List screens (static layouts)

**Deliverable:** Internal build ingesting M3U URL and playing live streams

---

### Sprint 2: Feature Expansion (Weeks 6-9)

**Epics:**
1. Xtream Codes API client (lazy-load categories)
2. XMLTV EPG parser + background sync via workmanager
3. EPG Grid screen
4. Casting integration (mDNS discovery)
5. VOD/Series screens with pagination

**Deliverable:** Beta build with multi-source support + EPG + casting

---

### Sprint 3: Polish & Testing (Weeks 10-12)

**Epics:**
1. Gesture tuning (brightness/volume swipes)
2. Testing on 50k+ channel playlists + 100MB+ XMLTV
3. In-app purchases (premium paywall)
4. App Store / Google Play asset prep
5. Bug fixes from beta testing

**Deliverable:** TestFlight / Google Play Console Internal Track

---

### Sprint 4: Public Launch (Week 13)

**Deliverable:** V1.0 on App Store + Google Play

---

## 9. TESTING REQUIREMENTS

### 9.1 Unit Tests
- M3U parser correctness
- Xtream API client error handling
- EPG time calculations
- Catch-up URL generation
- State providers edge cases

### 9.2 Widget Tests
- Dashboard layout on various screen sizes
- Gesture recognition (swipes, taps, long-press)
- Navigation state preservation
- Immersive mode toggle

### 9.3 Integration Tests
- E2E flow: Add playlist → Search channel → Play stream
- Background sync with workmanager
- Database transactions under concurrent load
- Casting discovery → cast → disconnect

### 9.4 Performance Tests
- M3U parsing: 50k channels in <2 seconds
- XMLTV parsing: 100MB file without OOM
- Search: Fuzzy query <50ms for 50k channels
- UI: 60fps during background isolate work
- Casting: Device discovery <2 seconds

---

## 10. RISK MITIGATION

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| OOM on large XMLTV | High | Critical | Stream-parse XMLTV, paginate VOD, image cache limits |
| Xtream auth failures | High | High | Implement retry logic, show auth error UX |
| Codec support gaps | Medium | High | Use media_kit (libmpv), test on multiple devices |
| Background task failures (iOS) | Medium | Medium | Fallback: Manual sync on app open |
| Search state loss (navigation) | Medium | Medium | Use Riverpod StateProvider, preserve across routes |
| Casting device discovery slow | Medium | Low | Implement timeout + "No devices" message |

---

## 11. DEPENDENCIES SUMMARY

### Core
- `flutter`
- `dart`
- `riverpod` (state management)
- `go_router` (navigation)

### Data
- `drift` (database)
- `sqlite3_flutter_libs` (native SQLite)
- `dio` (HTTP client)
- `xml_events` (streaming XML parse)

### Media
- `media_kit` (video playback)
- `media_kit_video` (video widget)
- `flutter_cast_framework` (casting)
- `mdns_sd` (mDNS discovery)

### UI
- `flutter_hooks` (widget composition)
- `cached_network_image` (image caching)
- `infinite_scroll_pagination` (VOD pagination)
- `pull_to_refresh` (refresh gesture)

### Background
- `workmanager` (background tasks)
- `flutter_background_service` (foreground service)

### Platform
- `bitsdojo_window` (desktop window)
- `flutter_window_close` (desktop close button)

### Notifications
- `flutter_local_notifications` (local notifications)

---

## 12. DOCUMENTATION ARTIFACTS

**To be maintained:**
1. Architecture Decision Records (ADRs) for each major decision
2. API contracts for Xtream endpoints (OpenAPI spec)
3. Database schema ER diagram
4. State management flow diagrams (Mermaid)
5. UI component library (Storybook-style)
6. Deployment & release checklist
7. Troubleshooting guide for common issues

---

## Appendix A: Example M3U Format

```m3u
#EXTM3U
#EXTINF:-1 tvg-id="bbc-hd" tvg-name="BBC HD" tvg-logo="http://example.com/logo.png" group-title="UK",BBC HD
http://streaming.example.com/bbc-hd.ts
#EXTINF:-1 tvg-id="itv-hd" tvg-name="ITV HD" group-title="UK",ITV HD
http://streaming.example.com/itv-hd.m3u8
```

---

## Appendix B: Example XMLTV Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv>
  <channel id="bbc-hd">
    <display-name>BBC HD</display-name>
  </channel>
  <programme start="20260701120000 +0000" stop="20260701130000 +0000" channel="bbc-hd">
    <title>Example Program</title>
    <desc>Program description</desc>
  </programme>
</tv>
```

---

**End of Requirements Specification**

Version: 1.0  
Last Updated: Sprint Planning  
Authored by: Architecture Team  
Status: Ready for Implementation
