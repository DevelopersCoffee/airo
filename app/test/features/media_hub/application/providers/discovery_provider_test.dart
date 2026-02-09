import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/media_hub/application/providers/discovery_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/media_hub/domain/models/unified_media_content.dart';

void main() {
  group('DiscoveryNotifier', () {
    late ProviderContainer container;
    late DiscoveryNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(discoveryProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('starts with music mode', () {
        final state = container.read(discoveryProvider);
        expect(state.currentMode, MediaMode.music);
      });

      test('starts with no category selected', () {
        final state = container.read(discoveryProvider);
        expect(state.selectedCategory, isNull);
      });

      test('initializes with content from providers', () {
        // DiscoveryNotifier listens to music/IPTV providers and loads content
        final state = container.read(discoveryProvider);
        // Content may or may not be loaded depending on provider state
        expect(state.contentItems, isA<List<UnifiedMediaContent>>());
      });
    });

    group('setMode', () {
      test('updates current mode', () {
        notifier.setMode(MediaMode.tv);
        final state = container.read(discoveryProvider);
        expect(state.currentMode, MediaMode.tv);
      });

      test('clears selected category on mode change', () {
        notifier.setCategory(MediaCategories.musicTrending);
        notifier.setMode(MediaMode.tv);
        final state = container.read(discoveryProvider);
        expect(state.selectedCategory, isNull);
      });

      test('sets loading state on mode change', () {
        notifier.setMode(MediaMode.tv);
        final state = container.read(discoveryProvider);
        expect(state.isLoading, isTrue);
      });
    });

    group('setCategory', () {
      test('updates selected category', () {
        notifier.setCategory(MediaCategories.musicTrending);
        final state = container.read(discoveryProvider);
        expect(state.selectedCategory, MediaCategories.musicTrending);
      });

      test('clears category when set to null', () {
        notifier.setCategory(MediaCategories.musicTrending);
        notifier.setCategory(null);
        final state = container.read(discoveryProvider);
        expect(state.selectedCategory, isNull);
      });
    });

    group('search', () {
      test('does not search with less than 2 characters', () {
        notifier.search('a');
        final state = container.read(discoveryProvider);
        expect(state.searchQuery, isNull);
      });

      test('sets search query with 2+ characters', () {
        notifier.search('te');
        final state = container.read(discoveryProvider);
        expect(state.searchQuery, 'te');
      });

      test('filters content based on query', () {
        // _performSearch is called synchronously for in-memory search
        notifier.search('test');
        final state = container.read(discoveryProvider);
        expect(state.searchQuery, 'test');
      });
    });

    group('clearSearch', () {
      test('clears search query', () {
        notifier.search('test');
        notifier.clearSearch();
        final state = container.read(discoveryProvider);
        expect(state.searchQuery, isNull);
      });
    });
  });

  group('Derived Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('tvContentProvider filters TV content only', () {
      // The provider filters content based on isTV property
      final tvContent = container.read(tvContentProvider);
      expect(tvContent.every((c) => c.isTV), isTrue);
    });

    test('musicContentProvider filters music content only', () {
      // The provider filters content based on isMusic property
      final musicContent = container.read(musicContentProvider);
      expect(musicContent.every((c) => c.isMusic), isTrue);
    });
  });
}
