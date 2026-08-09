import 'package:feature_mind/src/models/byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats bytes at the right unit', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(1500000000), '1.4 GB');
    expect(formatBytes(12000000000), '11.2 GB');
  });

  test('formats a negative shortfall with its sign kept', () {
    expect(formatBytes(-2048), '-2.0 KB');
  });

  test('formats a used-of-total pair, matching the design doc example', () {
    // docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md
    // gives "6.8 / 12 GB" as the storage-budget example.
    expect(formatBytesOf(6800000000, 12000000000), '6.3 GB of 11.2 GB');
  });
}
