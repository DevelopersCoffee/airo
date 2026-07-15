import 'dart:convert';
import 'dart:io';

/// A single benchmark measurement.
class BenchmarkResult {
  /// Human-readable name of the benchmark (e.g. "m3u_parse_50ch").
  final String name;

  /// What is being measured (e.g. "channels_per_sec", "ops_per_sec").
  final String metric;

  /// The numeric measurement value.
  final double value;

  /// Unit label (e.g. "channels/s", "bytes/s", "us").
  final String unit;

  /// Device class that produced this result (e.g. "desktop", "tvLow").
  final String deviceClass;

  /// When the benchmark was run (UTC).
  final DateTime timestamp;

  const BenchmarkResult({
    required this.name,
    required this.metric,
    required this.value,
    required this.unit,
    required this.deviceClass,
    required this.timestamp,
  });

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'name': name,
    'metric': metric,
    'value': value,
    'unit': unit,
    'device_class': deviceClass,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  /// Deserialize from a JSON map.
  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      name: json['name'] as String,
      metric: json['metric'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      deviceClass: json['device_class'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() => '$name: $value $unit ($metric)';
}

/// Write a list of [BenchmarkResult]s to [path] as a JSON array.
Future<void> writeBenchmarkResults(
  List<BenchmarkResult> results,
  String path,
) async {
  final json = jsonEncode(results.map((r) => r.toJson()).toList());
  await File(path).writeAsString(json);
}
