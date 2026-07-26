import 'package:equatable/equatable.dart';

class SimilarMediaFeatures extends Equatable {
  SimilarMediaFeatures({
    required this.id,
    required this.title,
    required Iterable<String> genres,
    required this.provider,
    required this.language,
  }) : genres = Set.unmodifiable(genres.map(_normalize));

  final String id;
  final String title;
  final Set<String> genres;
  final String provider;
  final String language;

  @override
  List<Object?> get props => [id, title, genres, provider, language];
}

class SimilarMediaContribution extends Equatable {
  const SimilarMediaContribution({required this.ruleId, required this.points});

  final String ruleId;
  final int points;

  @override
  List<Object?> get props => [ruleId, points];
}

class SimilarMediaResult extends Equatable {
  SimilarMediaResult({
    required this.item,
    required Iterable<SimilarMediaContribution> contributions,
  }) : contributions = List.unmodifiable(contributions),
       score = contributions.fold(0, (sum, value) => sum + value.points);

  final SimilarMediaFeatures item;
  final List<SimilarMediaContribution> contributions;
  final int score;

  @override
  List<Object?> get props => [item, contributions, score];
}

class SimilarMediaResolver {
  const SimilarMediaResolver();

  List<SimilarMediaResult> resolve({
    required SimilarMediaFeatures seed,
    required Iterable<SimilarMediaFeatures> candidates,
    int? limit,
  }) {
    if (limit != null && limit < 0) {
      throw ArgumentError.value(limit, 'limit');
    }
    final result = candidates.where((item) => item.id != seed.id).map((item) {
      final sharedGenres = item.genres.intersection(seed.genres).length;
      return SimilarMediaResult(
        item: item,
        contributions: [
          SimilarMediaContribution(
            ruleId: 'shared_genre_v1',
            points: sharedGenres * 100,
          ),
          SimilarMediaContribution(
            ruleId: 'same_provider_v1',
            points:
                _normalize(item.provider) == _normalize(seed.provider) &&
                    _normalize(seed.provider).isNotEmpty
                ? 30
                : 0,
          ),
          SimilarMediaContribution(
            ruleId: 'same_language_v1',
            points:
                _normalize(item.language) == _normalize(seed.language) &&
                    _normalize(seed.language).isNotEmpty
                ? 20
                : 0,
          ),
        ],
      );
    }).toList();
    result.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final title = left.item.title.toLowerCase().compareTo(
        right.item.title.toLowerCase(),
      );
      if (title != 0) return title;
      return left.item.id.compareTo(right.item.id);
    });
    final selected = limit == null ? result : result.take(limit);
    return List.unmodifiable(selected);
  }
}

String _normalize(String value) => value.trim().toLowerCase();
