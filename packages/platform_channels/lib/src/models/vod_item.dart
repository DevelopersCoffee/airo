import 'package:equatable/equatable.dart';

/// Whether a [VodItem] is a standalone movie or one episode of a series.
enum VodContentKind {
  movie('movie'),
  episode('episode');

  const VodContentKind(this.stableId);

  final String stableId;

  static VodContentKind fromStableId(String value) {
    return VodContentKind.values.firstWhere(
      (kind) => kind.stableId == value,
      orElse: () => VodContentKind.movie,
    );
  }
}

/// Groups a [VodItem] of kind [VodContentKind.episode] under its parent
/// series. [seriesId] is a stable grouping key (not necessarily a
/// source-provided id) — see `feature_iptv`'s series/episode grouping
/// heuristic for how this gets derived from source titles.
class VodSeriesRef extends Equatable {
  const VodSeriesRef({
    required this.seriesId,
    required this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
  });

  final String seriesId;
  final String seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;

  factory VodSeriesRef.fromJson(Map<String, dynamic> json) {
    return VodSeriesRef(
      seriesId: json['seriesId'] as String,
      seriesTitle: json['seriesTitle'] as String,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    if (seasonNumber != null) 'seasonNumber': seasonNumber,
    if (episodeNumber != null) 'episodeNumber': episodeNumber,
  };

  @override
  List<Object?> get props => [
    seriesId,
    seriesTitle,
    seasonNumber,
    episodeNumber,
  ];
}

/// A single on-demand content entry (movie or episode) surfaced from a
/// BYOC source (M3U or Xtream). Provider-agnostic — mirrors [IPTVChannel]'s
/// role for live channels, deliberately with no third-party metadata
/// fields (no synopsis, no rating, no cast — see CV-019 non-goals).
class VodItem extends Equatable {
  const VodItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.group,
    required this.kind,
    this.posterUrl,
    this.containerExtension,
    this.seriesRef,
  });

  final String id;
  final String title;
  final String streamUrl;
  final String? posterUrl;
  final String group;
  final VodContentKind kind;
  final String? containerExtension;
  final VodSeriesRef? seriesRef;

  factory VodItem.fromJson(Map<String, dynamic> json) {
    return VodItem(
      id: json['id'] as String,
      title: json['title'] as String,
      streamUrl: json['streamUrl'] as String,
      posterUrl: json['posterUrl'] as String?,
      group: json['group'] as String,
      kind: VodContentKind.fromStableId(json['kind'] as String),
      containerExtension: json['containerExtension'] as String?,
      seriesRef: json['seriesRef'] != null
          ? VodSeriesRef.fromJson(json['seriesRef'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'streamUrl': streamUrl,
    if (posterUrl != null) 'posterUrl': posterUrl,
    'group': group,
    'kind': kind.stableId,
    if (containerExtension != null) 'containerExtension': containerExtension,
    if (seriesRef != null) 'seriesRef': seriesRef!.toJson(),
  };

  @override
  List<Object?> get props => [
    id,
    title,
    streamUrl,
    posterUrl,
    group,
    kind,
    containerExtension,
    seriesRef,
  ];
}
