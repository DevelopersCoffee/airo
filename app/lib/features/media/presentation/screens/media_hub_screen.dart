import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/presentation/screens/iptv_screen.dart';
import '../../../iptv/presentation/widgets/video_player_widget.dart';
import '../../../media_hub/application/providers/media_hub_providers.dart';
import '../../../media_hub/domain/models/media_mode.dart';
import '../../../media_hub/domain/models/player_display_mode.dart';
import '../../../media_hub/presentation/widgets/collapsible_player_container.dart';
import '../../../media_hub/presentation/widgets/personalization_carousel.dart';
import '../../../music/application/providers/music_provider.dart';
import '../../../music/application/providers/music_tracks_provider.dart';
import '../../../music/domain/services/music_service.dart';

/// Media type for the hub
enum MediaType { music, stream, podcasts }

/// Provider to track selected media tab (for state persistence)
final selectedMediaTabProvider = StateProvider<int>((ref) => 0);

/// Unified Media Hub with sub-navigation for Music, Stream, and Podcasts
///
/// Implements collapsible player container with scroll-based collapse behavior.
/// Core principle: "Player never blocks discovery"
class MediaHubScreen extends ConsumerStatefulWidget {
  const MediaHubScreen({super.key});

  @override
  ConsumerState<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends ConsumerState<MediaHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  static const _tabs = [
    Tab(icon: Icon(Icons.music_note), text: 'Music'),
    Tab(icon: Icon(Icons.live_tv), text: 'Stream'),
    // Tab(icon: Icon(Icons.podcasts), text: 'Podcasts'), // Future
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final initialIndex = ref.read(selectedMediaTabProvider);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref.read(selectedMediaTabProvider.notifier).state = _tabController.index;
      // Sync with MediaMode provider
      final mode = _tabController.index == 0 ? MediaMode.music : MediaMode.tv;
      ref.read(selectedMediaModeProvider.notifier).state = mode;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFullscreenToggle() {
    // Handle fullscreen toggle - could update system UI, etc.
    debugPrint('Fullscreen toggled');
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(playerDisplayModeProvider);
    final isFullscreen = displayMode == PlayerDisplayMode.fullscreen;

    // In fullscreen mode, only show the player
    if (isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: CollapsiblePlayerContainer(
          scrollController: _scrollController,
          onFullscreenToggle: _onFullscreenToggle,
          child: const VideoPlayerWidget(showControls: true),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          indicatorWeight: 3,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement unified media search
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible player at the top
          CollapsiblePlayerContainer(
            scrollController: _scrollController,
            onFullscreenToggle: _onFullscreenToggle,
            child: const VideoPlayerWidget(showControls: true),
          ),
          // Discovery content below
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Music Tab - scrollable discovery content
                _MusicTabContent(scrollController: _scrollController),
                // Stream Tab - scrollable discovery content
                _StreamTabContent(scrollController: _scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Music tab content (MusicScreen without AppBar)
///
/// Accepts an optional scroll controller for shared scroll behavior
/// with the collapsible player container. Includes personalization sections
/// (Continue Watching, Recently Played, Favorites) at the top.
///
/// Uses CustomScrollView with slivers to avoid nested scroll view issues.
class _MusicTabContent extends ConsumerWidget {
  final ScrollController? scrollController;

  const _MusicTabContent({this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      controller: scrollController,
      slivers: const [
        // Personalization sections at the top of discovery
        SliverToBoxAdapter(child: ContinueWatchingSection()),
        SliverToBoxAdapter(child: RecentlyPlayedSection()),
        SliverToBoxAdapter(child: FavoritesSection()),
        // Original music screen body content (uses SliverFillRemaining to handle its own scroll)
        SliverToBoxAdapter(child: _MusicContentBody()),
      ],
    );
  }
}

/// Extracted music content that renders without its own scroll view
/// This widget extracts the content from MusicScreenBody but renders it
/// in a way that works within a parent scroll view.
class _MusicContentBody extends ConsumerWidget {
  const _MusicContentBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerStateProvider);
    final musicTracks = ref.watch(musicTracksProvider);
    final musicController = ref.watch(musicControllerProvider);

    return musicTracks.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tracks available'),
                  const SizedBox(height: 8),
                  const Text(
                    'No tracks loaded',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(musicTracksProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return playerState.when(
          data: (state) => _MusicPlayerContent(
            state: state,
            tracks: tracks,
            musicController: musicController,
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Error: $err'),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading tracks: $err'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(musicTracksProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Music player content without scroll view wrapper
/// Renders the same content as _MusicPlayerUI but without SingleChildScrollView
class _MusicPlayerContent extends StatelessWidget {
  const _MusicPlayerContent({
    required this.state,
    required this.tracks,
    required this.musicController,
  });

  final MusicPlayerState state;
  final List<MusicTrack> tracks;
  final MusicController musicController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now playing card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Album art
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: state.currentTrack?.albumArt != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              state.currentTrack!.albumArt!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            size: 64,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Track info
                  Text(
                    state.currentTrack?.title ?? 'No track playing',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.currentTrack?.artist ?? '—',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  if (state.currentTrack != null)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: state.duration.inMilliseconds > 0
                              ? state.position.inMilliseconds /
                                    state.duration.inMilliseconds
                              : 0,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(state.position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              _formatDuration(state.duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Player controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: state.currentIndex > 0
                            ? () => musicController.previous()
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 48,
                        ),
                        onPressed: () {
                          if (state.isPlaying) {
                            musicController.pause();
                          } else if (state.currentTrack != null) {
                            musicController.resume();
                          } else if (tracks.isNotEmpty) {
                            musicController.playTrack(tracks[0]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: state.currentIndex < tracks.length - 1
                            ? () => musicController.next()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Playlist section
          Text('Top 20 India', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Use Column instead of ListView to avoid nested scroll
          ...tracks.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            final isCurrentTrack = state.currentTrack?.id == track.id;

            return Column(
              children: [
                ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: track.albumArt != null
                        ? Image.network(track.albumArt!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note, size: 24),
                          ),
                  ),
                  title: Text(
                    track.title,
                    style: TextStyle(
                      fontWeight: isCurrentTrack
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrentTrack
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  subtitle: Text(track.artist),
                  trailing: isCurrentTrack
                      ? Icon(
                          state.isPlaying ? Icons.volume_up : Icons.pause,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () => musicController.playTrack(track),
                ),
                if (index < tracks.length - 1) const Divider(height: 0.5),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Stream/IPTV tab content (IPTVScreen without AppBar)
///
/// Accepts an optional scroll controller for shared scroll behavior
/// with the collapsible player container. Includes personalization sections
/// (Continue Watching, Recently Played, Favorites) above the channel list.
///
/// The IPTV screen has a fixed video player at top, so personalization
/// sections are shown in a collapsible area between player and channel list.
class _StreamTabContent extends ConsumerWidget {
  final ScrollController? scrollController;

  const _StreamTabContent({this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The IPTVScreenBody already has its own layout with video player and channel list.
    // We wrap it in a Column and add personalization sections that can be scrolled
    // horizontally (each carousel scrolls independently).
    return const _StreamContentWithPersonalization();
  }
}

/// Stream content with personalization sections integrated
class _StreamContentWithPersonalization extends ConsumerStatefulWidget {
  const _StreamContentWithPersonalization();

  @override
  ConsumerState<_StreamContentWithPersonalization> createState() =>
      _StreamContentWithPersonalizationState();
}

class _StreamContentWithPersonalizationState
    extends ConsumerState<_StreamContentWithPersonalization> {
  bool _showPersonalization = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Collapsible personalization sections
        if (_showPersonalization)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with collapse button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'For You',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                        onPressed: () =>
                            setState(() => _showPersonalization = false),
                        tooltip: 'Hide personalization',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Personalization carousels (each scrolls horizontally)
                const ContinueWatchingSection(),
                const RecentlyPlayedSection(),
                const FavoritesSection(),
              ],
            ),
          )
        else
          // Show expand button when collapsed
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextButton.icon(
              onPressed: () => setState(() => _showPersonalization = true),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              label: const Text('Show For You'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        // Original IPTV screen body content (takes remaining space)
        const Expanded(child: IPTVScreenBody()),
      ],
    );
  }
}
