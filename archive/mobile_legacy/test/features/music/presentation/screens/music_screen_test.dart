import 'package:airo_app/features/music/application/providers/music_provider.dart';
import 'package:airo_app/features/music/application/providers/music_tracks_provider.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';
import 'package:airo_app/features/music/presentation/screens/music_screen.dart';
import 'package:airo_app/features/music/presentation/widgets/beats_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestMusicService implements MusicService {
  _TestMusicService(this._state);

  final MusicPlayerState _state;

  @override
  Future<void> dispose() async {}

  @override
  Stream<MusicPlayerState> getStateStream() async* {
    yield _state;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {}

  @override
  Future<void> playTrack(MusicTrack track) async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  const tracks = [
    MusicTrack(
      id: '1',
      title: 'Calm Start',
      artist: 'Asha',
      duration: Duration(minutes: 3, seconds: 12),
      streamUrl: 'https://example.com/stream1.m3u8',
    ),
    MusicTrack(
      id: '2',
      title: 'Focus Lane',
      artist: 'Ravi',
      duration: Duration(minutes: 2, seconds: 58),
      streamUrl: 'https://example.com/stream2.mp3',
    ),
    MusicTrack(
      id: '3',
      title: 'Night Echo',
      artist: 'Asha',
      duration: Duration(minutes: 4, seconds: 4),
      streamUrl: 'https://example.com/stream3.m3u8',
    ),
  ];

  Widget createWidget() {
    final playerState = MusicPlayerState(
      currentTrack: tracks[0],
      isPlaying: true,
      position: const Duration(minutes: 1),
      duration: const Duration(minutes: 3, seconds: 12),
      queue: tracks,
      currentIndex: 0,
    );

    return ProviderScope(
      overrides: [
        musicTracksProvider.overrideWith((ref) async => tracks),
        musicServiceProvider.overrideWithValue(_TestMusicService(playerState)),
      ],
      child: const MaterialApp(home: MusicScreen()),
    );
  }

  testWidgets('renders new beats browse sections and actions', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Beats'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsWidgets);
    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Streaming Quality: Adaptive HQ'), findsOneWidget);
  });

  testWidgets('opens search and queue sheets', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search music'));
    await tester.pumpAndSettle();
    expect(find.text('Search or paste YouTube URL...'), findsOneWidget);

    Navigator.of(tester.element(find.byType(BeatsSearchBar))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open queue'));
    await tester.pumpAndSettle();
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Calm Start'), findsWidgets);
    expect(find.text('Focus Lane'), findsWidgets);
    expect(find.text('Night Echo'), findsWidgets);
  });
}
