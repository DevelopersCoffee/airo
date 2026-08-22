import 'package:feature_mind/src/agent_chat/domain/services/research/arxiv_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arxiv parser maps atom entries to abs urls', () {
    const body = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>http://arxiv.org/abs/2401.00001v1</id>
    <title>Qwen on device</title>
    <summary>A paper about on-device Qwen inference.</summary>
  </entry>
</feed>
''';
    final hits = ArxivSearchEngine.parseAtom(body);
    expect(hits, hasLength(1));
    expect(hits.single.url, 'https://arxiv.org/abs/2401.00001');
    expect(hits.single.title, 'Qwen on device');
    expect(hits.single.engineId, 'arxiv');
  });
}
