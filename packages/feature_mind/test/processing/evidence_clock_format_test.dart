import 'package:feature_mind/src/processing/evidence_clock_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatEvidenceClock renders zero-padded mm:ss from milliseconds', () {
    expect(formatEvidenceClock(0), '00:00');
    expect(formatEvidenceClock(65000), '01:05');
    expect(formatEvidenceClock(754000), '12:34');
  });
}
