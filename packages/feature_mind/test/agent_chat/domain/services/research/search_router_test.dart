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
    expect(SearchRouter.engineIds(SearchPolicy.academic), ['arxiv']);
  });

  test('privacy-first does not include commercial web search', () {
    final ids = SearchRouter.engineIds(SearchPolicy.privacyFirst);
    expect(ids, ['wikipedia']);
    expect(ids, isNot(contains('google')));
    expect(ids, isNot(contains('bing')));
  });

  test('local-only uses no remote engines', () {
    expect(SearchRouter.engineIds(SearchPolicy.localOnly), isEmpty);
  });
}
