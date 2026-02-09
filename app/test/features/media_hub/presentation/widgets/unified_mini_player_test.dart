import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/iptv/domain/models/streaming_state.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_player_state.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/unified_mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Provider to override unified player state for testing
final testUnifiedPlayerStateProvider = StateProvider<UnifiedPlayerState>(
  (ref) => const UnifiedPlayerState(),
);

void main() {
  final testMusicContent = UnifiedMediaContent(
    id: 'music-1',
    title: 'Test Song',
    subtitle: 'Test Artist',
    thumbnailUrl: null,
    type: MediaMode.music,
  );

  group('UnifiedMiniPlayer', () {
    testWidgets('does not show when no content is playing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentNavigationTabProvider.overrideWith((ref) => 0)],
          child: const MaterialApp(home: Scaffold(body: UnifiedMiniPlayer())),
        ),
      );

      expect(find.byType(UnifiedMiniPlayer), findsOneWidget);
      // Should render SizedBox.shrink (no Container in widget tree)
      expect(find.text('Test Song'), findsNothing);
    });

    testWidgets('constants are defined correctly', (tester) async {
      expect(UnifiedMiniPlayer.mobileHeight, 64.0);
      expect(UnifiedMiniPlayer.tabletHeight, 72.0);
      expect(UnifiedMiniPlayer.minTouchTarget, 44.0);
    });

    testWidgets('renders basic structure', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: UnifiedMiniPlayer())),
        ),
      );

      expect(find.byType(UnifiedMiniPlayer), findsOneWidget);
    });
  });

  group('UnifiedMiniPlayer constants', () {
    test('mobileHeight is 64.0', () {
      expect(UnifiedMiniPlayer.mobileHeight, 64.0);
    });

    test('tabletHeight is 72.0', () {
      expect(UnifiedMiniPlayer.tabletHeight, 72.0);
    });

    test('minTouchTarget meets accessibility requirements', () {
      expect(UnifiedMiniPlayer.minTouchTarget, greaterThanOrEqualTo(44.0));
    });
  });

  group('UnifiedPlayerState integration', () {
    test('empty state has no content', () {
      const state = UnifiedPlayerState();
      expect(state.hasContent, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.currentContent, isNull);
    });

    test('state with content returns correct properties', () {
      final state = UnifiedPlayerState(
        currentContent: testMusicContent,
        playbackState: PlaybackState.playing,
      );
      expect(state.hasContent, isTrue);
      expect(state.isPlaying, isTrue);
      expect(state.isMusic, isTrue);
      expect(state.isTV, isFalse);
    });

    test('state with paused playback', () {
      final state = UnifiedPlayerState(
        currentContent: testMusicContent,
        playbackState: PlaybackState.paused,
      );
      expect(state.hasContent, isTrue);
      expect(state.isPlaying, isFalse);
    });
  });
}
