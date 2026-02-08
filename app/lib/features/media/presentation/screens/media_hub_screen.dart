import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../music/presentation/screens/music_screen.dart';
import '../../../iptv/presentation/screens/iptv_screen.dart';

/// Media type for the hub
enum MediaType { music, stream, podcasts }

/// Provider to track selected media tab (for state persistence)
final selectedMediaTabProvider = StateProvider<int>((ref) => 0);

/// Unified Media Hub with sub-navigation for Music, Stream, and Podcasts
class MediaHubScreen extends ConsumerStatefulWidget {
  const MediaHubScreen({super.key});

  @override
  ConsumerState<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends ConsumerState<MediaHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(icon: Icon(Icons.music_note), text: 'Music'),
    Tab(icon: Icon(Icons.live_tv), text: 'Stream'),
    // Tab(icon: Icon(Icons.podcasts), text: 'Podcasts'), // Future
  ];

  @override
  void initState() {
    super.initState();
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
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Music Tab - embed MusicScreen content without its own AppBar
          _MusicTabContent(),
          // Stream Tab - embed IPTVScreen content without its own AppBar
          _StreamTabContent(),
          // Podcasts Tab - placeholder for future
          // _PodcastsTabContent(),
        ],
      ),
    );
  }
}

/// Music tab content (MusicScreen without AppBar)
class _MusicTabContent extends ConsumerWidget {
  const _MusicTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse music screen body content
    return const MusicScreenBody();
  }
}

/// Stream/IPTV tab content (IPTVScreen without AppBar)
class _StreamTabContent extends ConsumerWidget {
  const _StreamTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse IPTV screen body content
    return const IPTVScreenBody();
  }
}

/// Placeholder for future Podcasts tab
class _PodcastsTabContent extends StatelessWidget {
  const _PodcastsTabContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.podcasts, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Podcasts Coming Soon',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Stay tuned for podcast support!',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
