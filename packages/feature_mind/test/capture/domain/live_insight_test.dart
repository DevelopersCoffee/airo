import 'package:feature_mind/src/capture/domain/live_insight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses native ConversationIrEvent JSON and skips segments', () {
    expect(
      liveInsightFromJson(
        '{"type":"decision","text":"We decided Friday","evidence":"s0","confidence":0.86}',
      ),
      isA<LiveInsight>()
          .having((i) => i.kind, 'kind', LiveInsightKind.decision)
          .having((i) => i.text, 'text', 'We decided Friday')
          .having((i) => i.evidence, 'evidence', 's0'),
    );
    expect(
      liveInsightFromJson('{"type":"topic","title":"Migration","evidence":"s1"}'),
      isA<LiveInsight>().having((i) => i.kind, 'kind', LiveInsightKind.topic),
    );
    expect(
      liveInsightFromJson(
        '{"type":"segment","segment_id":"s0","text":"hello","start_ms":0,"end_ms":1}',
      ),
      isNull,
    );
  });
}
