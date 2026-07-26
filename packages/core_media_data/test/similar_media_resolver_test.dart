import 'package:core_media_data/core_media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SimilarMediaFeatures item(
    String id,
    String title, {
    Set<String> genres = const {},
    String provider = '',
    String language = '',
  }) {
    return SimilarMediaFeatures(
      id: id,
      title: title,
      genres: genres,
      provider: provider,
      language: language,
    );
  }

  test('scores explicit metadata overlap and excludes seed', () {
    final seed = item(
      'seed',
      'Seed',
      genres: {'Comedy', 'Family'},
      provider: 'Provider A',
      language: 'English',
    );
    final result = const SimilarMediaResolver().resolve(
      seed: seed,
      candidates: [
        seed,
        item(
          'best',
          'Best',
          genres: {'comedy', 'family'},
          provider: 'provider a',
          language: 'english',
        ),
        item('other', 'Other', genres: {'Drama'}),
      ],
    );

    expect(result.map((value) => value.item.id), ['best', 'other']);
    expect(result.first.score, 250);
    expect(result.first.contributions.map((value) => value.ruleId), [
      'shared_genre_v1',
      'same_provider_v1',
      'same_language_v1',
    ]);
  });

  test('neutral scores tie-break by title then ID and respect limit', () {
    final result = const SimilarMediaResolver().resolve(
      seed: item('seed', 'Seed'),
      candidates: [item('z', 'Same'), item('a', 'Same'), item('b', 'Alpha')],
      limit: 2,
    );

    expect(result.map((value) => value.item.id), ['b', 'a']);
    expect(result.every((value) => value.score == 0), isTrue);
  });
}
