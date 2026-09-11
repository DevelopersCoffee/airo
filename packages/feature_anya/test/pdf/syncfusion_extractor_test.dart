import 'package:feature_anya/feature_anya.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty PDF bytes do not throw and yield no pages', () {
    expect(SyncfusionAnyaPdfExtractor.extractSync(const []), isEmpty);
  });
}
