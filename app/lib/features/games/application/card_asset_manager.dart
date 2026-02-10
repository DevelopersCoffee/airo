import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/services/deck_of_cards_service.dart';

/// Provider for card asset manager
final cardAssetManagerProvider = Provider<CardAssetManager>((ref) {
  return CardAssetManager();
});

/// Manages card image assets with caching and preloading
class CardAssetManager {
  // Cache for preloaded images
  final Map<String, ImageProvider> _imageCache = {};
  bool _isPreloaded = false;

  /// All card codes for a standard 52-card deck
  static const List<String> allCardCodes = [
    // Spades
    'AS',
    '2S',
    '3S',
    '4S',
    '5S',
    '6S',
    '7S',
    '8S',
    '9S',
    '0S',
    'JS',
    'QS',
    'KS',
    // Hearts
    'AH',
    '2H',
    '3H',
    '4H',
    '5H',
    '6H',
    '7H',
    '8H',
    '9H',
    '0H',
    'JH',
    'QH',
    'KH',
    // Diamonds
    'AD',
    '2D',
    '3D',
    '4D',
    '5D',
    '6D',
    '7D',
    '8D',
    '9D',
    '0D',
    'JD',
    'QD',
    'KD',
    // Clubs
    'AC',
    '2C',
    '3C',
    '4C',
    '5C',
    '6C',
    '7C',
    '8C',
    '9C',
    '0C',
    'JC',
    'QC',
    'KC',
  ];

  /// Get image URL for a card code
  static String getCardImageUrl(String cardCode) {
    return 'https://deckofcardsapi.com/static/img/$cardCode.png';
  }

  /// Get SVG image URL for a card code
  static String getCardSvgUrl(String cardCode) {
    return 'https://deckofcardsapi.com/static/img/$cardCode.svg';
  }

  /// Preload all card images for smooth gameplay
  /// Uses compute isolate to avoid blocking main thread
  Future<void> preloadAllCards(BuildContext context) async {
    if (_isPreloaded) return;

    // Preload in batches to avoid blocking main thread
    const batchSize = 10;
    final batches = <List<String>>[];

    for (var i = 0; i < allCardCodes.length; i += batchSize) {
      final end = (i + batchSize < allCardCodes.length)
          ? i + batchSize
          : allCardCodes.length;
      batches.add(allCardCodes.sublist(i, end));
    }

    // Preload each batch with delay to avoid frame drops
    for (final batch in batches) {
      final List<Future<void>> batchFutures = [];

      for (final cardCode in batch) {
        final imageUrl = getCardImageUrl(cardCode);
        final imageProvider = CachedNetworkImageProvider(imageUrl);

        _imageCache[cardCode] = imageProvider;

        batchFutures.add(
          // ignore: use_build_context_synchronously
          precacheImage(imageProvider, context).catchError((_) {
            // Ignore errors during preload
          }),
        );
      }

      await Future.wait(batchFutures);
      // Small delay between batches to keep UI responsive
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Preload card back
    final cardBackProvider = NetworkImage(DeckOfCardsService.cardBackImage);
    _imageCache['BACK'] = cardBackProvider;
    // ignore: use_build_context_synchronously
    await precacheImage(cardBackProvider, context).catchError((_) {});

    _isPreloaded = true;
  }

  /// Preload only essential cards for faster initial load
  /// (Aces, face cards, and a few number cards)
  Future<void> preloadEssentialCards(BuildContext context) async {
    final essentialCards = [
      'AS', 'AH', 'AD', 'AC', // Aces
      'KS', 'KH', 'KD', 'KC', // Kings
      'QS', 'QH', 'QD', 'QC', // Queens
      'JS', 'JH', 'JD', 'JC', // Jacks
      '0S', '0H', '0D', '0C', // Tens
      '2S', '5H', '7D', '9C', // Sample number cards
    ];

    final List<Future<void>> preloadFutures = [];

    for (final cardCode in essentialCards) {
      final imageUrl = getCardImageUrl(cardCode);
      final imageProvider = CachedNetworkImageProvider(imageUrl);

      _imageCache[cardCode] = imageProvider;

      preloadFutures.add(
        precacheImage(imageProvider, context).catchError((_) {}),
      );
    }

    // Preload card back
    final cardBackProvider = NetworkImage(DeckOfCardsService.cardBackImage);
    _imageCache['BACK'] = cardBackProvider;
    preloadFutures.add(
      precacheImage(cardBackProvider, context).catchError((_) {}),
    );

    await Future.wait(
      preloadFutures,
    ).timeout(const Duration(seconds: 10), onTimeout: () => []);
  }

  /// Get cached image provider for a card code
  ImageProvider? getCachedImage(String cardCode) {
    return _imageCache[cardCode];
  }

  /// Build a card image widget with caching
  Widget buildCardImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error_outline, color: Colors.white),
      ),
    );
  }

  /// Build card back image widget
  Widget buildCardBack({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return buildCardImage(
      imageUrl: DeckOfCardsService.cardBackImage,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Clear the image cache
  void clearCache() {
    _imageCache.clear();
    _isPreloaded = false;
  }

  /// Check if images are preloaded
  bool get isPreloaded => _isPreloaded;
}

/// Widget to preload card images on app start
class CardImagePreloader extends ConsumerStatefulWidget {
  final Widget child;
  final bool preloadAll;

  const CardImagePreloader({
    super.key,
    required this.child,
    this.preloadAll = false,
  });

  @override
  ConsumerState<CardImagePreloader> createState() => _CardImagePreloaderState();
}

class _CardImagePreloaderState extends ConsumerState<CardImagePreloader> {
  bool _isLoading = true;
  bool _hasPreloaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPreloaded) {
      _hasPreloaded = true;
      _preloadImages();
    }
  }

  Future<void> _preloadImages() async {
    final assetManager = ref.read(cardAssetManagerProvider);

    if (widget.preloadAll) {
      await assetManager.preloadAllCards(context);
    } else {
      await assetManager.preloadEssentialCards(context);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Loading cards...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
