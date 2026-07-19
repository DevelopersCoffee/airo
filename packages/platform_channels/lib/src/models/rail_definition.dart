import 'package:equatable/equatable.dart';

import 'iptv_channel.dart';

/// When a rail is shown in the browse screen.
enum RailVisibility { always, whenNonEmpty, hidden }

/// Card presentation for a rail's channels.
enum RailLayout { standard, hero, compact }

/// Declarative filter for selecting a rail's channels.
///
/// All non-null fields must match (AND semantics). An empty query
/// matches every channel.
class RailQuery extends Equatable {
  const RailQuery({
    this.category,
    this.language,
    this.liveOnly = false,
    this.favoritesOnly = false,
    this.recentOnly = false,
  });

  final ChannelCategory? category;
  final String? language;
  final bool liveOnly;
  final bool favoritesOnly;

  /// Restrict to recently watched channels, ordered by recency.
  final bool recentOnly;

  bool matches(IPTVChannel channel) {
    if (category != null && channel.category != category) return false;
    if (language != null && !channel.languages.contains(language)) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [
    category,
    language,
    liveOnly,
    favoritesOnly,
    recentOnly,
  ];
}

/// A generated rail: what it's called, what it contains, where it sits.
///
/// The intelligence layer can add, remove, and reorder definitions without
/// any Flutter change — the UI renders whatever list it receives.
class RailDefinition extends Equatable {
  const RailDefinition({
    required this.id,
    required this.title,
    required this.query,
    required this.priority,
    this.subtitle,
    this.visibility = RailVisibility.whenNonEmpty,
    this.layout = RailLayout.standard,
    this.maxItems = 20,
  });

  final String id;
  final String title;
  final String? subtitle;
  final RailQuery query;

  /// Lower renders first.
  final int priority;
  final RailVisibility visibility;
  final RailLayout layout;
  final int maxItems;

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    query,
    priority,
    visibility,
    layout,
    maxItems,
  ];
}

/// A built rail ready for rendering.
class RailResult extends Equatable {
  const RailResult({required this.definition, required this.channels});

  final RailDefinition definition;
  final List<IPTVChannel> channels;

  @override
  List<Object?> get props => [definition, channels];
}

/// Builds the channel list for a rail definition.
///
/// Media Engine implements this from playlist metadata, EPG, watch history,
/// and provider data; the Edge Intelligence SDK later personalizes and
/// reorders. The UI never implements this.
abstract class RailProvider {
  Future<List<IPTVChannel>> buildRail(RailDefinition rail);
}
