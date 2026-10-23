import 'package:core_ai/src/format/storage_byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatBinaryStorageBytes uses 1024-based steps', () {
    expect(formatBinaryStorageBytes(512), '512 B');
    expect(formatBinaryStorageBytes(1536), '1.5 KB');
    expect(formatBinaryStorageBytes(1024 * 1024), '1.0 MB');
    expect(formatBinaryStorageBytes(1024 * 1024 * 1024), '1.0 GB');
  });
}
