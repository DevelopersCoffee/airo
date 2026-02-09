import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../music/presentation/screens/music_screen.dart';
import '../../../iptv/presentation/screens/iptv_screen.dart';
import '../../../iptv/presentation/widgets/video_player_widget.dart';
import '../../../media_hub/application/providers/media_hub_providers.dart';
import '../../../media_hub/domain/models/media_mode.dart';
import '../../../media_hub/domain/models/player_display_mode.dart';
import '../../../media_hub/presentation/widgets/collapsible_player_container.dart';

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
/// with the collapsible player container.
class _MusicTabContent extends ConsumerWidget {
  final ScrollController? scrollController;

  const _MusicTabContent({this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse music screen body content
    // TODO: Pass scrollController to MusicScreenBody when it supports it
    return const MusicScreenBody();
  }
}

/// Stream/IPTV tab content (IPTVScreen without AppBar)
///
/// Accepts an optional scroll controller for shared scroll behavior
/// with the collapsible player container.
class _StreamTabContent extends ConsumerWidget {
  final ScrollController? scrollController;

  const _StreamTabContent({this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse IPTV screen body content
    // TODO: Pass scrollController to IPTVScreenBody when it supports it
    return const IPTVScreenBody();
  }
}
