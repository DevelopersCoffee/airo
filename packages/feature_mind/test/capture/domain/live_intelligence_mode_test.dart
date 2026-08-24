import 'package:feature_mind/src/capture/domain/live_intelligence_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('storage values round-trip and insights-off skips IR', () {
    expect(LiveIntelligenceMode.fallback, LiveIntelligenceMode.automatic);
    expect(
      LiveIntelligenceMode.fromStorageValue('prefer_full'),
      LiveIntelligenceMode.preferFull,
    );
    expect(
      LiveIntelligenceMode.fromStorageValue('unknown'),
      LiveIntelligenceMode.automatic,
    );
    expect(LiveIntelligenceMode.automatic.collectInsights, isTrue);
    expect(LiveIntelligenceMode.insightsOff.collectInsights, isFalse);
  });
}
