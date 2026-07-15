import 'dart:convert';

import 'package:benchmarks/benchmarks.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkResult', () {
    final sampleTimestamp = DateTime.utc(2026, 7, 15, 12, 0, 0);

    final sample = BenchmarkResult(
      name: 'm3u_parse_50ch',
      metric: 'channels_per_sec',
      value: 125000.5,
      unit: 'channels/s',
      deviceClass: 'desktop',
      timestamp: sampleTimestamp,
    );

    test('toJson produces expected keys and values', () {
      final json = sample.toJson();

      expect(json['name'], 'm3u_parse_50ch');
      expect(json['metric'], 'channels_per_sec');
      expect(json['value'], 125000.5);
      expect(json['unit'], 'channels/s');
      expect(json['device_class'], 'desktop');
      expect(json['timestamp'], '2026-07-15T12:00:00.000Z');
    });

    test('fromJson round-trips correctly', () {
      final json = sample.toJson();
      final restored = BenchmarkResult.fromJson(json);

      expect(restored.name, sample.name);
      expect(restored.metric, sample.metric);
      expect(restored.value, sample.value);
      expect(restored.unit, sample.unit);
      expect(restored.deviceClass, sample.deviceClass);
      expect(restored.timestamp, sample.timestamp);
    });

    test('JSON encode/decode round-trip for a list of results', () {
      final results = [
        sample,
        BenchmarkResult(
          name: 'channel_dedup_200',
          metric: 'channels_per_sec',
          value: 500000.0,
          unit: 'channels/s',
          deviceClass: 'tvMid',
          timestamp: sampleTimestamp,
        ),
      ];

      final encoded = jsonEncode(results.map((r) => r.toJson()).toList());
      final decoded = (jsonDecode(encoded) as List<dynamic>)
          .map((e) => BenchmarkResult.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(decoded.length, 2);
      expect(decoded[0].name, 'm3u_parse_50ch');
      expect(decoded[1].name, 'channel_dedup_200');
      expect(decoded[1].deviceClass, 'tvMid');
    });

    test('toString contains name and value', () {
      expect(sample.toString(), contains('m3u_parse_50ch'));
      expect(sample.toString(), contains('125000.5'));
      expect(sample.toString(), contains('channels/s'));
    });
  });
}
