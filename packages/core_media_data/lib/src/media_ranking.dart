import 'package:equatable/equatable.dart';

const String kMediaRankingSchemaVersion = '1.0.0';

enum MediaTimeBucket { morning, afternoon, evening, night }

class MediaViewingEvent extends Equatable {
  MediaViewingEvent({
    required this.titleId,
    required Iterable<String> genres,
    required this.provider,
    required this.language,
    required this.completionPermille,
    required this.watchedAt,
  }) : genres = Set.unmodifiable(genres);

  final String titleId;
  final Set<String> genres;
  final String provider;
  final String language;
  final int completionPermille;
  final DateTime watchedAt;

  @override
  List<Object?> get props => [
    titleId,
    genres,
    provider,
    language,
    completionPermille,
    watchedAt,
  ];
}

class MediaRankingProfile extends Equatable {
  MediaRankingProfile({
    required Map<String, int> genreAffinity,
    required Map<String, int> providerAffinity,
    required Map<String, int> languageAffinity,
    required Map<String, int> completionByTitle,
    required Map<String, DateTime> lastWatchedByTitle,
  }) : genreAffinity = Map.unmodifiable(genreAffinity),
       providerAffinity = Map.unmodifiable(providerAffinity),
       languageAffinity = Map.unmodifiable(languageAffinity),
       completionByTitle = Map.unmodifiable(completionByTitle),
       lastWatchedByTitle = Map.unmodifiable(lastWatchedByTitle);

  factory MediaRankingProfile.fromEvents(Iterable<MediaViewingEvent> events) {
    final genres = <String, int>{};
    final providers = <String, int>{};
    final languages = <String, int>{};
    final completion = <String, int>{};
    final recency = <String, DateTime>{};
    for (final event in events) {
      final strength = event.completionPermille.clamp(100, 1000);
      for (final genre in event.genres) {
        genres.update(
          _normalize(genre),
          (value) => value + strength,
          ifAbsent: () => strength,
        );
      }
      providers.update(
        _normalize(event.provider),
        (value) => value + strength,
        ifAbsent: () => strength,
      );
      languages.update(
        _normalize(event.language),
        (value) => value + strength,
        ifAbsent: () => strength,
      );
      final priorCompletion = completion[event.titleId] ?? 0;
      if (event.completionPermille > priorCompletion) {
        completion[event.titleId] = event.completionPermille;
      }
      final priorWatch = recency[event.titleId];
      if (priorWatch == null || event.watchedAt.isAfter(priorWatch)) {
        recency[event.titleId] = event.watchedAt.toUtc();
      }
    }
    return MediaRankingProfile(
      genreAffinity: genres,
      providerAffinity: providers,
      languageAffinity: languages,
      completionByTitle: completion,
      lastWatchedByTitle: recency,
    );
  }

  final Map<String, int> genreAffinity;
  final Map<String, int> providerAffinity;
  final Map<String, int> languageAffinity;
  final Map<String, int> completionByTitle;
  final Map<String, DateTime> lastWatchedByTitle;

  @override
  List<Object?> get props => [
    genreAffinity,
    providerAffinity,
    languageAffinity,
    completionByTitle,
    lastWatchedByTitle,
  ];
}

class MediaRankingCandidate extends Equatable {
  MediaRankingCandidate({
    required this.id,
    required this.title,
    required Iterable<String> genres,
    required this.provider,
    required this.language,
    Iterable<MediaTimeBucket> preferredTimeBuckets = const [],
    Iterable<String> supportedDeviceClasses = const [],
  }) : genres = Set.unmodifiable(genres.map(_normalize)),
       preferredTimeBuckets = Set.unmodifiable(preferredTimeBuckets),
       supportedDeviceClasses = Set.unmodifiable(
         supportedDeviceClasses.map(_normalize),
       );

  final String id;
  final String title;
  final Set<String> genres;
  final String provider;
  final String language;
  final Set<MediaTimeBucket> preferredTimeBuckets;
  final Set<String> supportedDeviceClasses;

  @override
  List<Object?> get props => [
    id,
    title,
    genres,
    provider,
    language,
    preferredTimeBuckets,
    supportedDeviceClasses,
  ];
}

class MediaScoreContribution extends Equatable {
  const MediaScoreContribution({required this.ruleId, required this.points});

  final String ruleId;
  final int points;

  @override
  List<Object?> get props => [ruleId, points];
}

class RankedMediaCandidate extends Equatable {
  RankedMediaCandidate({
    required this.candidate,
    required Iterable<MediaScoreContribution> contributions,
  }) : contributions = List.unmodifiable(contributions),
       score = contributions.fold(0, (sum, item) => sum + item.points);

  final MediaRankingCandidate candidate;
  final List<MediaScoreContribution> contributions;
  final int score;

  @override
  List<Object?> get props => [candidate, contributions, score];
}

class MediaRankingRequest extends Equatable {
  MediaRankingRequest({
    required Iterable<MediaRankingCandidate> candidates,
    required this.profile,
    required this.now,
    required this.timeBucket,
    required this.deviceClass,
    this.schemaVersion = kMediaRankingSchemaVersion,
  }) : candidates = List.unmodifiable(candidates);

  final String schemaVersion;
  final List<MediaRankingCandidate> candidates;
  final MediaRankingProfile profile;
  final DateTime now;
  final MediaTimeBucket timeBucket;
  final String deviceClass;

  @override
  List<Object?> get props => [
    schemaVersion,
    candidates,
    profile,
    now,
    timeBucket,
    deviceClass,
  ];
}

abstract interface class MediaRankingExecutor {
  Future<List<RankedMediaCandidate>> rank(MediaRankingRequest request);
}

class DeterministicMediaRankingExecutor implements MediaRankingExecutor {
  const DeterministicMediaRankingExecutor();

  @override
  Future<List<RankedMediaCandidate>> rank(MediaRankingRequest request) async {
    if (request.schemaVersion != kMediaRankingSchemaVersion) {
      throw ArgumentError('Unsupported media ranking schema');
    }
    final ranked = request.candidates.map((candidate) {
      final contributions = <MediaScoreContribution>[
        MediaScoreContribution(
          ruleId: 'genre_affinity_v1',
          points:
              candidate.genres
                  .map((genre) => request.profile.genreAffinity[genre] ?? 0)
                  .fold(0, (best, value) => value > best ? value : best) *
              3,
        ),
        MediaScoreContribution(
          ruleId: 'provider_affinity_v1',
          points:
              (request.profile.providerAffinity[_normalize(
                    candidate.provider,
                  )] ??
                  0) *
              2,
        ),
        MediaScoreContribution(
          ruleId: 'language_affinity_v1',
          points:
              (request.profile.languageAffinity[_normalize(
                    candidate.language,
                  )] ??
                  0) *
              2,
        ),
        MediaScoreContribution(
          ruleId: 'completion_v1',
          points: _completionPoints(
            request.profile.completionByTitle[candidate.id],
          ),
        ),
        MediaScoreContribution(
          ruleId: 'recency_v1',
          points: _recencyPoints(
            request.profile.lastWatchedByTitle[candidate.id],
            request.now,
          ),
        ),
        MediaScoreContribution(
          ruleId: 'time_bucket_v1',
          points: candidate.preferredTimeBuckets.contains(request.timeBucket)
              ? 50
              : 0,
        ),
        MediaScoreContribution(
          ruleId: 'device_fit_v1',
          points:
              candidate.supportedDeviceClasses.contains(
                _normalize(request.deviceClass),
              )
              ? 25
              : 0,
        ),
      ];
      return RankedMediaCandidate(
        candidate: candidate,
        contributions: contributions,
      );
    }).toList();
    ranked.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final title = left.candidate.title.toLowerCase().compareTo(
        right.candidate.title.toLowerCase(),
      );
      if (title != 0) return title;
      return left.candidate.id.compareTo(right.candidate.id);
    });
    return List.unmodifiable(ranked);
  }

  static int _completionPoints(int? completion) {
    if (completion == null) return 0;
    if (completion >= 900) return -5000;
    if (completion >= 50) return 150;
    return 0;
  }

  static int _recencyPoints(DateTime? watchedAt, DateTime now) {
    if (watchedAt == null) return 0;
    final age = now.toUtc().difference(watchedAt.toUtc());
    if (age.isNegative) return 0;
    if (age <= const Duration(days: 7)) return 40;
    if (age <= const Duration(days: 30)) return 15;
    return 0;
  }
}

String _normalize(String value) => value.trim().toLowerCase();
