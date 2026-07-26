import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = DartAiroNativeEngine();

  test('fallback ranking matches versioned integer rules', () async {
    final ranked = await engine.rankRecommendations(const [
      AiroNativeRecommendationInput(
        id: 'finished',
        title: 'Alpha',
        genreAffinity: 950,
        providerAffinity: 950,
        languageAffinity: 950,
        completionPermille: 950,
        preferredTime: false,
        deviceFit: false,
      ),
      AiroNativeRecommendationInput(
        id: 'unfinished',
        title: 'Zed',
        genreAffinity: 500,
        providerAffinity: 500,
        languageAffinity: 500,
        completionPermille: 500,
        lastWatchedAgeDays: 2,
        preferredTime: true,
        deviceFit: true,
      ),
    ]);

    expect(ranked.first.id, 'unfinished');
    expect(ranked.first.completionPoints, 150);
    expect(ranked.last.completionPoints, -5000);
  });

  test('fallback vector clocks distinguish all relations', () async {
    const a1 = AiroVectorClockCounter(nodeId: 'a', counter: 1);
    const a2 = AiroVectorClockCounter(nodeId: 'a', counter: 2);
    const b1 = AiroVectorClockCounter(nodeId: 'b', counter: 1);

    expect(
      await engine.compareVectorClocks(left: [a1], right: [a1]),
      AiroVectorClockRelation.equal,
    );
    expect(
      await engine.compareVectorClocks(left: [a2, b1], right: [a1]),
      AiroVectorClockRelation.leftDominates,
    );
    expect(
      await engine.compareVectorClocks(left: [a1], right: [a2, b1]),
      AiroVectorClockRelation.rightDominates,
    );
    expect(
      await engine.compareVectorClocks(left: [a2], right: [a1, b1]),
      AiroVectorClockRelation.concurrent,
    );
  });

  test('fallback parses SRT and WebVTT and counts malformed cues', () async {
    final srt = await engine.parseSubtitles(
      content: '1\n00:00:01,000 --> 00:00:02,500\nHello\nworld\n\nbad',
      format: AiroSubtitleFormat.srt,
    );
    final vtt = await engine.parseSubtitles(
      content: 'WEBVTT\n\n00:01.000 --> 00:02.000 align:start\nHello',
      format: AiroSubtitleFormat.webVtt,
    );

    expect(srt.cues.single.text, 'Hello\nworld');
    expect(srt.malformedCueCount, 1);
    expect(vtt.cues.single.startMillis, 1000);
  });

  test('native-preferred engine falls back on unavailable bridge', () async {
    final preferred = NativePreferredAiroEngine(
      native: _UnavailableNativeEngine(),
    );

    expect(
      await preferred.compareVectorClocks(
        left: const [AiroVectorClockCounter(nodeId: 'a', counter: 2)],
        right: const [AiroVectorClockCounter(nodeId: 'a', counter: 1)],
      ),
      AiroVectorClockRelation.leftDominates,
    );
  });
}

class _UnavailableNativeEngine implements AiroNativeEngine {
  @override
  Future<AiroVectorClockRelation> compareVectorClocks({
    required List<AiroVectorClockCounter> left,
    required List<AiroVectorClockCounter> right,
  }) {
    throw StateError('unavailable');
  }

  @override
  Future<AiroSubtitleParseResult> parseSubtitles({
    required String content,
    required AiroSubtitleFormat format,
  }) {
    throw StateError('unavailable');
  }

  @override
  Future<List<AiroNativeRecommendationScore>> rankRecommendations(
    List<AiroNativeRecommendationInput> candidates,
  ) {
    throw StateError('unavailable');
  }
}
