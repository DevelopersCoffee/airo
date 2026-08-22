import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const commercial = ['google', 'bing', 'tavily', 'duckduckgo'];

  test('private is local plus searxng and never commercial search', () {
    final ids = SearchRouter.engineIdsFor(PrivacyProfile.private);
    expect(ids, containsAll(['wikipedia', 'searxng']));
    expect(ids, isNot(contains('semantic_scholar')));
    for (final id in commercial) {
      expect(ids, isNot(contains(id)));
    }
    expect(PrivacyProfile.private.searchPolicy, SearchPolicy.privacyFirst);
  });

  test('balanced and cloud never imply google', () {
    for (final profile in [PrivacyProfile.balanced, PrivacyProfile.cloud]) {
      final ids = SearchRouter.engineIdsFor(profile);
      expect(ids, containsAll(['wikipedia', 'arxiv', 'semantic_scholar']));
      for (final id in commercial) {
        expect(ids, isNot(contains(id)));
      }
    }
    expect(PrivacyProfile.cloud.searchPolicy, SearchPolicy.maximumQuality);
  });
}
