import 'package:feature_mind/src/widgets/progress_byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatProgressByteSize renders whole KB or one-decimal MB', () {
    expect(formatProgressByteSize(2048), '2 KB');
    expect(formatProgressByteSize(1024 * 1024), '1.0 MB');
    expect(formatProgressByteSize(1536 * 1024), '1.5 MB');
  });
}
