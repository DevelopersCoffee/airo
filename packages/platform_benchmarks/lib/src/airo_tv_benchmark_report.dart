import 'dart:convert';
import 'dart:io';

class AiroTvBenchmarkReportRenderer {
  const AiroTvBenchmarkReportRenderer();

  Future<String> renderJsonFile(String inputPath) async {
    final raw = await File(inputPath).readAsString();
    return renderJsonString(raw);
  }

  String renderJsonString(String rawJson) {
    final payload = jsonDecode(rawJson) as Map<String, dynamic>;
    return render(payload);
  }

  String render(Map<String, dynamic> artifact) {
    final evaluation = _map(artifact['evaluation']);
    final fixture = _map(artifact['fixture']);
    final plan = _map(artifact['plan']);
    final dataset = _map(plan['dataset']);
    final budget = _map(plan['budget']);
    final run = _map(artifact['run']);
    final samples = _list(run['samples']).map(_map).toList(growable: false);
    final accepted = evaluation['accepted'] == true ? 'accepted' : 'rejected';
    final blockers = _displayBlockers(_list(evaluation['blockers']));

    final buffer = StringBuffer()
      ..writeln('# Airo TV Host Benchmark Report')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Schema | `${_text(artifact['schemaVersion'])}` |')
      ..writeln('| Captured at | `${_text(artifact['capturedAt'])}` |')
      ..writeln('| Device class | `${_text(artifact['deviceClass'])}` |')
      ..writeln('| Status | `$accepted` |')
      ..writeln('| Blockers | `$blockers` |')
      ..writeln('| Iterations | `${_text(artifact['iterations'])}` |')
      ..writeln('| Channel count | `${_text(artifact['channelCount'])}` |')
      ..writeln('| Fixture | `${_text(fixture['fixtureId'])}` |')
      ..writeln('| Fixture source | `${_text(fixture['sourceKind'])}` |')
      ..writeln('| Fixture bytes | `${_text(fixture['byteCount'])}` |')
      ..writeln('| Fixture SHA-256 | `${_text(fixture['sha256'])}` |')
      ..writeln()
      ..writeln('## Dataset')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Profile | `${_text(dataset['profileId'])}` |')
      ..writeln('| Kind | `${_text(dataset['kind'])}` |')
      ..writeln('| Live channels | `${_text(dataset['liveChannelCount'])}` |')
      ..writeln('| VOD items | `${_text(dataset['vodItemCount'])}` |')
      ..writeln('| EPG programs | `${_text(dataset['epgProgramCount'])}` |')
      ..writeln(
        '| Playlist sources | `${_text(dataset['playlistSourceCount'])}` |',
      )
      ..writeln()
      ..writeln('## Budget')
      ..writeln()
      ..writeln('| Metric | Budget | Observed |')
      ..writeln('| --- | ---: | ---: |')
      ..writeln(
        '| Total elapsed ms | `${_text(budget['maxElapsedMillis'])}` | `${_text(run['totalElapsedMillis'])}` |',
      )
      ..writeln(
        '| Peak memory MB | `${_text(budget['maxPeakMemoryMb'])}` | `${_text(run['peakMemoryMb'])}` |',
      )
      ..writeln(
        '| Storage MB | `${_text(budget['maxStorageMb'])}` | `${_maxSampleValue(samples, 'storageMb')}` |',
      )
      ..writeln(
        '| Rows/sec floor | `${_text(budget['minRowsPerSecond'])}` | `${_formatNumber(run['minRowsPerSecond'])}` |',
      )
      ..writeln()
      ..writeln('## Samples')
      ..writeln()
      ..writeln(
        '| Step | Operation | Records | Elapsed ms | Rows/sec | Memory MB | Storage MB |',
      )
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: |');

    for (final sample in samples) {
      buffer.writeln(
        '| `${_text(sample['stepId'])}` '
        '| `${_text(sample['operation'])}` '
        '| `${_text(sample['completedRecordCount'])}` '
        '| `${_text(sample['elapsedMillis'])}` '
        '| `${_formatNumber(sample['rowsPerSecond'])}` '
        '| `${_text(sample['peakMemoryMb'])}` '
        '| `${_text(sample['storageMb'])}` |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Notes')
      ..writeln()
      ..writeln(
        '- Host benchmark artifacts record fixture metadata, counts, and timings only.',
      )
      ..writeln(
        '- Public fixture runs must not copy raw stream URLs, logo URLs, or local paths into reports.',
      )
      ..writeln(
        '- Use this report for local regression review; device RSS/frame evidence is tracked separately.',
      );

    return buffer.toString();
  }

  Future<void> renderFile({
    required String inputPath,
    required String outputPath,
  }) async {
    final report = await renderJsonFile(inputPath);
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(report);
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  List<dynamic> _list(Object? value) {
    return value is List<dynamic> ? value : const <dynamic>[];
  }

  String _displayBlockers(List<dynamic> values) {
    final blockers = values
        .map((value) => '$value')
        .where((value) => value.isNotEmpty && value != 'accepted')
        .toList(growable: false);
    return blockers.isEmpty ? 'none' : blockers.join(', ');
  }

  String _maxSampleValue(List<Map<String, dynamic>> samples, String key) {
    num? maxValue;
    for (final sample in samples) {
      final value = sample[key];
      if (value is num && (maxValue == null || value > maxValue)) {
        maxValue = value;
      }
    }
    return maxValue == null ? 'not_recorded' : _formatNumber(maxValue);
  }

  String _text(Object? value) {
    return value == null ? 'not_recorded' : '$value';
  }

  String _formatNumber(Object? value) {
    if (value is int) return '$value';
    if (value is double) return value.toStringAsFixed(2);
    if (value is num) return value.toStringAsFixed(2);
    return _text(value);
  }
}
