import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

const int kAiroXmltvFixtureDefaultTargetBytes = 50 * 1024 * 1024;
const String kAiroXmltvFixtureGeneratorVersion = '1.0.0';

class AiroXmltvFixtureConfig extends Equatable {
  AiroXmltvFixtureConfig({
    this.fixtureId = 'generated-xmltv-50mb-v1',
    this.outputPath = 'iptv-data/fixtures/xmltv/generated-50mb.xml',
    this.manifestPath = 'iptv-data/fixtures/xmltv/generated-50mb.manifest.json',
    this.targetByteCount = kAiroXmltvFixtureDefaultTargetBytes,
    this.channelCount = 512,
    this.programmeDurationMinutes = 30,
    DateTime? startUtc,
  }) : startUtc = startUtc ?? _defaultStartUtc;

  static final DateTime _defaultStartUtc = DateTime.utc(2026);

  final String fixtureId;
  final String outputPath;
  final String manifestPath;
  final int targetByteCount;
  final int channelCount;
  final int programmeDurationMinutes;
  final DateTime startUtc;

  AiroXmltvFixtureConfig normalized() {
    final normalizedFixtureId = fixtureId.trim();
    final normalizedOutputPath = outputPath.trim();
    final normalizedManifestPath = manifestPath.trim();
    return AiroXmltvFixtureConfig(
      fixtureId: normalizedFixtureId.isEmpty
          ? 'generated-xmltv-50mb-v1'
          : normalizedFixtureId,
      outputPath: normalizedOutputPath.isEmpty
          ? 'iptv-data/fixtures/xmltv/generated-50mb.xml'
          : normalizedOutputPath,
      manifestPath: normalizedManifestPath.isEmpty
          ? 'iptv-data/fixtures/xmltv/generated-50mb.manifest.json'
          : normalizedManifestPath,
      targetByteCount: math.max(targetByteCount, 1024),
      channelCount: math.max(channelCount, 1),
      programmeDurationMinutes: math.max(programmeDurationMinutes, 1),
      startUtc: startUtc.toUtc(),
    );
  }

  @override
  List<Object?> get props => [
    fixtureId,
    outputPath,
    manifestPath,
    targetByteCount,
    channelCount,
    programmeDurationMinutes,
    startUtc,
  ];
}

class AiroXmltvFixtureManifest extends Equatable {
  const AiroXmltvFixtureManifest({
    required this.schemaVersion,
    required this.fixtureId,
    required this.generatorVersion,
    required this.outputPath,
    required this.targetByteCount,
    required this.byteCount,
    required this.sha256,
    required this.channelCount,
    required this.programmeCount,
    required this.programmeDurationMinutes,
    required this.startUtc,
  });

  final String schemaVersion;
  final String fixtureId;
  final String generatorVersion;
  final String outputPath;
  final int targetByteCount;
  final int byteCount;
  final String sha256;
  final int channelCount;
  final int programmeCount;
  final int programmeDurationMinutes;
  final DateTime startUtc;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'fixtureId': fixtureId,
      'generatorVersion': generatorVersion,
      'outputPath': outputPath,
      'targetByteCount': targetByteCount,
      'byteCount': byteCount,
      'sha256': sha256,
      'channelCount': channelCount,
      'programmeCount': programmeCount,
      'programmeDurationMinutes': programmeDurationMinutes,
      'startUtc': startUtc.toUtc().toIso8601String(),
      'privacy': {
        'source': 'synthetic_xmltv',
        'containsProviderUrls': false,
        'containsUserData': false,
        'containsCredentials': false,
      },
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    fixtureId,
    generatorVersion,
    outputPath,
    targetByteCount,
    byteCount,
    sha256,
    channelCount,
    programmeCount,
    programmeDurationMinutes,
    startUtc,
  ];
}

class AiroXmltvFixtureGenerator {
  const AiroXmltvFixtureGenerator();

  Future<AiroXmltvFixtureManifest> writeFixture(
    AiroXmltvFixtureConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final output = File(config.outputPath);
    await output.parent.create(recursive: true);

    final digestSink = _DigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);
    final sink = output.openWrite();
    var byteCount = 0;
    var programmeCount = 0;

    FutureOr<void> add(String chunk) {
      final bytes = utf8.encode(chunk);
      hashInput.add(bytes);
      sink.add(bytes);
      byteCount += bytes.length;
    }

    add(_header(config));
    for (
      var channelIndex = 0;
      channelIndex < config.channelCount;
      channelIndex++
    ) {
      add(_channel(channelIndex));
    }

    while (byteCount < config.targetByteCount) {
      add(_programme(config, programmeCount));
      programmeCount++;
    }

    add('</tv>\n');
    await sink.flush();
    await sink.close();
    hashInput.close();

    final manifest = AiroXmltvFixtureManifest(
      schemaVersion: '1.0.0',
      fixtureId: config.fixtureId,
      generatorVersion: kAiroXmltvFixtureGeneratorVersion,
      outputPath: _portableOutputPath(config.outputPath),
      targetByteCount: config.targetByteCount,
      byteCount: byteCount,
      sha256: digestSink.value.toString(),
      channelCount: config.channelCount,
      programmeCount: programmeCount,
      programmeDurationMinutes: config.programmeDurationMinutes,
      startUtc: config.startUtc,
    );

    final manifestFile = File(config.manifestPath);
    await manifestFile.parent.create(recursive: true);
    await manifestFile.writeAsString('${manifest.toPrettyJson()}\n');
    return manifest;
  }

  String _header(AiroXmltvFixtureConfig config) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="Airo XMLTV fixture generator" generator-info-url="urn:airo:xmltv-fixture:${config.fixtureId}">
''';
  }

  String _channel(int index) {
    final id = _channelId(index);
    final category = _categoryFor(index);
    final number = index.toString().padLeft(4, '0');
    return '''
  <channel id="$id">
    <display-name lang="en">Airo Fixture $category $number</display-name>
    <display-name lang="en">$number</display-name>
  </channel>
''';
  }

  String _programme(AiroXmltvFixtureConfig config, int index) {
    final channelIndex = index % config.channelCount;
    final slot = index ~/ config.channelCount;
    final start = config.startUtc.add(
      Duration(minutes: slot * config.programmeDurationMinutes),
    );
    final stop = start.add(Duration(minutes: config.programmeDurationMinutes));
    final category = _categoryFor(channelIndex);
    final channelId = _channelId(channelIndex);
    final programmeNumber = index.toString().padLeft(7, '0');
    final episode = slot.toString().padLeft(5, '0');
    return '''
  <programme start="${_xmltvTime(start)}" stop="${_xmltvTime(stop)}" channel="$channelId">
    <title lang="en">Airo $category Fixture Programme $programmeNumber</title>
    <sub-title lang="en">Deterministic slot $episode for channel $channelId</sub-title>
    <desc lang="en">Synthetic XMLTV guide data for Airo TV parser and storage benchmarks. This row intentionally uses repeatable text, stable identifiers, and no provider URLs or customer data so framework agents can measure large-guide ingestion safely.</desc>
    <category lang="en">$category</category>
    <episode-num system="xmltv_ns">$slot.$channelIndex.0/1</episode-num>
  </programme>
''';
  }

  String _channelId(int index) {
    return 'channel-${index.toString().padLeft(5, '0')}';
  }

  String _categoryFor(int index) {
    return switch (index % 6) {
      0 => 'News',
      1 => 'Sports',
      2 => 'Movies',
      3 => 'Kids',
      4 => 'Documentary',
      _ => 'Music',
    };
  }

  String _xmltvTime(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}'
        '${two(utc.month)}'
        '${two(utc.day)}'
        '${two(utc.hour)}'
        '${two(utc.minute)}'
        '${two(utc.second)} +0000';
  }

  String _portableOutputPath(String outputPath) {
    final normalized = outputPath.replaceAll('\\', '/');
    const fixtureRoot = 'iptv-data/';
    final fixtureRootIndex = normalized.indexOf(fixtureRoot);
    if (fixtureRootIndex >= 0) {
      return normalized.substring(fixtureRootIndex);
    }
    if (!File(outputPath).isAbsolute) {
      return normalized;
    }
    return normalized.split('/').where((segment) => segment.isNotEmpty).last;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
