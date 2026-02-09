import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/media_category.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/player_display_mode.dart';

/// Current media mode (Music/TV)
final selectedMediaModeProvider = StateProvider<MediaMode>(
  (ref) => MediaMode.music,
);

/// Selected category for filtering (null = all)
final selectedCategoryProvider = StateProvider<MediaCategory?>((ref) => null);

/// Player display mode
final playerDisplayModeProvider = StateProvider<PlayerDisplayMode>(
  (ref) => PlayerDisplayMode.collapsed,
);

/// Search query for media content
final mediaSearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether overlay controls are visible
final controlsVisibleProvider = StateProvider<bool>((ref) => false);

/// Current scroll offset for collapse calculations
final mediaHubScrollOffsetProvider = StateProvider<double>((ref) => 0.0);

/// Derived provider: available categories based on current mode
final availableCategoriesProvider = Provider<List<MediaCategory>>((ref) {
  final mode = ref.watch(selectedMediaModeProvider);
  return MediaCategories.forMode(mode);
});

/// Derived provider: check if in search mode
final isSearchingProvider = Provider<bool>((ref) {
  final query = ref.watch(mediaSearchQueryProvider);
  return query.isNotEmpty;
});
