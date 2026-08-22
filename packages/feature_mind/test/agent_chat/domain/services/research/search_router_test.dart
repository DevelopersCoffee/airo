import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('balanced policy is not google-only', () {
    final ids = SearchRouter.engineIds(SearchPolicy.balanced);
    expect(ids, containsAll(['wikipedia', 'arxiv']));
    expect(ids, isNot(contains('google')));
  });

  test('academic policy prefers papers', () {
    final ids = SearchRouter.engineIds(SearchPolicy.academic);
    expect(ids, containsAll(['arxiv', 'semantic_scholar', 'pubmed', 'crossref']));
    expect(ids, isNot(contains('google')));
  });

  test('balanced policy can use scholar without implying google', () {
    final ids = SearchRouter.engineIds(SearchPolicy.balanced);
    expect(ids, contains('semantic_scholar'));
    expect(ids, contains('github'));
    expect(ids, isNot(contains('google')));
    expect(ids, isNot(contains('bing')));
  });

  test('privacy-first does not include commercial web search', () {
    final ids = SearchRouter.engineIds(SearchPolicy.privacyFirst);
    expect(ids, containsAll(['wikipedia', 'searxng']));
    expect(ids, isNot(contains('google')));
    expect(ids, isNot(contains('bing')));
    expect(ids, isNot(contains('semantic_scholar')));
  });

  test('local-only uses no remote engines', () {
    expect(SearchRouter.engineIds(SearchPolicy.localOnly), isEmpty);
  });
}
