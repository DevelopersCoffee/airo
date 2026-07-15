import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:platform_channels/channel_search.dart';
import 'package:platform_epg/platform_epg.dart';

const String kAiroTvEpgWarmupBenchmarkSchemaVersion = '1.0.0';
const Duration kAiroTvEpgWarmupDefaultMaxNowNextLatency = Duration(seconds: 1);
const Duration kAiroTvEpgWarmupDefaultMaxHeartbeatDelay = Duration(
  milliseconds: 50,
);
const Duration kAiroTvEpgWarmupDefaultHeartbeatInterval = Duration(
  milliseconds: 16,
);
const int kAiroTvEpgWarmupDefaultMaxRssDeltaBytes = 50 * 1024 * 1024;

class AiroTvEpgWarmupBenchmarkConfig extends Equatable {
  const AiroTvEpgWarmupBenchmarkConfig({
    required this.fixturePath,
    this.outputPath = 'artifacts/performance/airo-tv-epg-warmup.json',
    this.channelCount = 512,
    this.visibleChannelCount = 64,
    this.now,
    this.maxNowNextLatency = kAiroTvEpgWarmupDefaultMaxNowNextLatency,
    this.maxHeartbeatDelay = kAiroTvEpgWarmupDefaultMaxHeartbeatDelay,
    this.heartbeatInterval = kAiroTvEpgWarmupDefaultHeartbeatInterval,
    this.maxRssDeltaBytes = kAiroTvEpgWarmupDefaultMaxRssDeltaBytes,
  });

  final String fixturePath;
  final String outputPath;
  final int channelCount;
  final int visibleChannelCount;
  final DateTime? now;
  final Duration maxNowNextLatency;
  final Duration maxHeartbeatDelay;
  final Duration heartbeatInterval;
  final int maxRssDeltaBytes;

  AiroTvEpgWarmupBenchmarkConfig normalized() {
    final normalizedFixturePath = fixturePath.trim();
    if (normalizedFixturePath.isEmpty) {
      throw const FormatException('fixturePath is required.');
    }
    return AiroTvEpgWarmupBenchmarkConfig(
      fixturePath: normalizedFixturePath,
      outputPath: outputPath.trim().isEmpty
          ? 'artifacts/performance/airo-tv-epg-warmup.json'
          : outputPath.trim(),
      channelCount: channelCount < 1 ? 1 : channelCount,
      visibleChannelCount: visibleChannelCount < 1 ? 1 : visibleChannelCount,
      now: (now ?? DateTime.utc(2026, 1, 1, 0, 15)).toUtc(),
      maxNowNextLatency: maxNowNextLatency,
      maxHeartbeatDelay: maxHeartbeatDelay,
      heartbeatInterval: heartbeatInterval,
      maxRssDeltaBytes: maxRssDeltaBytes < 0
          ? kAiroTvEpgWarmupDefaultMaxRssDeltaBytes
          : maxRssDeltaBytes,
    );
  }

  @override
  List<Object?> get props => [
    fixturePath,
    outputPath,
    channelCount,
    visibleChannelCount,
    now,
    maxNowNextLatency,
    maxHeartbeatDelay,
    heartbeatInterval,
    maxRssDeltaBytes,
  ];
}

class AiroTvEpgWarmupBenchmarkArtifact extends Equatable {
  const AiroTvEpgWarmupBenchmarkArtifact({
    required this.schemaVersion,
    required this.capturedAt,
    required this.fixtureBytes,
    required this.fixtureSha256,
    required this.channelCount,
    required this.visibleChannelCount,
    required this.now,
    required this.programmeCount,
    required this.snapshotEntryCount,
    required this.visibleEntryCount,
    required this.snapshotBytes,
    required this.warmupWallTime,
    required this.mainHeartbeatTicks,
    required this.maxMainHeartbeatDelay,
    required this.baselineRssBytes,
    required this.peakRssBytes,
    required this.maxNowNextLatency,
    required this.maxHeartbeatDelay,
    required this.maxRssDeltaBytes,
  });

  final String schemaVersion;
  final DateTime capturedAt;
  final int fixtureBytes;
  final String fixtureSha256;
  final int channelCount;
  final int visibleChannelCount;
  final DateTime now;
  final int programmeCount;
  final int snapshotEntryCount;
  final int visibleEntryCount;
  final int snapshotBytes;
  final Duration warmupWallTime;
  final int mainHeartbeatTicks;
  final Duration maxMainHeartbeatDelay;
  final int baselineRssBytes;
  final int peakRssBytes;
  final Duration maxNowNextLatency;
  final Duration maxHeartbeatDelay;
  final int maxRssDeltaBytes;

  int get maxRssDeltaBytesObserved => peakRssBytes - baselineRssBytes;

  bool get nowNextAccepted =>
      warmupWallTime <= maxNowNextLatency &&
      visibleEntryCount == visibleChannelCount;

  bool get mainHeartbeatAccepted => maxMainHeartbeatDelay <= maxHeartbeatDelay;

  bool get rssAccepted => maxRssDeltaBytesObserved <= maxRssDeltaBytes;

  bool get accepted => nowNextAccepted && mainHeartbeatAccepted && rssAccepted;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'fixture': {'byteCount': fixtureBytes, 'sha256': fixtureSha256},
      'config': {
        'channelCount': channelCount,
        'visibleChannelCount': visibleChannelCount,
        'now': now.toUtc().toIso8601String(),
        'maxNowNextLatencyMs': maxNowNextLatency.inMilliseconds,
        'maxMainHeartbeatDelayMs': maxHeartbeatDelay.inMilliseconds,
        'maxRssDeltaBytes': maxRssDeltaBytes,
      },
      'result': {
        'programmeCount': programmeCount,
        'snapshotEntryCount': snapshotEntryCount,
        'visibleEntryCount': visibleEntryCount,
        'snapshotBytes': snapshotBytes,
        'warmupWallTimeMs': warmupWallTime.inMilliseconds,
        'mainHeartbeatTicks': mainHeartbeatTicks,
        'maxMainHeartbeatDelayMs': maxMainHeartbeatDelay.inMilliseconds,
        'baselineRssBytes': baselineRssBytes,
        'peakRssBytes': peakRssBytes,
        'maxRssDeltaBytes': maxRssDeltaBytesObserved,
      },
      'evaluation': {
        'accepted': accepted,
        'nowNextAccepted': nowNextAccepted,
        'mainHeartbeatAccepted': mainHeartbeatAccepted,
        'rssAccepted': rssAccepted,
      },
      'host': {
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'dartVersion': Platform.version,
      },
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    capturedAt,
    fixtureBytes,
    fixtureSha256,
    channelCount,
    visibleChannelCount,
    now,
    programmeCount,
    snapshotEntryCount,
    visibleEntryCount,
    snapshotBytes,
    warmupWallTime,
    mainHeartbeatTicks,
    maxMainHeartbeatDelay,
    baselineRssBytes,
    peakRssBytes,
    maxNowNextLatency,
    maxHeartbeatDelay,
    maxRssDeltaBytes,
  ];
}

class AiroTvEpgWarmupBenchmarkRunner {
  const AiroTvEpgWarmupBenchmarkRunner();

  Future<AiroTvEpgWarmupBenchmarkArtifact> run(
    AiroTvEpgWarmupBenchmarkConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final fixture = File(config.fixturePath);
    final fixtureBytes = await fixture.length();
    final fixtureSha256 = await sha256.bind(fixture.openRead()).first;
    final channels = _generatedChannels(config.channelCount);
    final visibleChannelIds = channels
        .take(config.visibleChannelCount)
        .map((channel) => channel.id)
        .toList(growable: false);

    final heartbeat = _MainIsolateHeartbeat(interval: config.heartbeatInterval)
      ..start();
    await Future<void>.delayed(config.heartbeatInterval);

    final stopwatch = Stopwatch()..start();
    final snapshot = await Isolate.run<CompactEpgSlice>(
      () async => _buildSnapshot(
        xmltvPath: fixture.path,
        now: config.now!,
        channels: channels,
      ),
      debugName: 'airo_tv_epg_warmup_benchmark',
    );
    final snapshotPayload = encodeCompactEpgSlice(snapshot);
    final visibleSlice = snapshot.filterForChannels(visibleChannelIds);
    stopwatch.stop();
    heartbeat.stop();

    return AiroTvEpgWarmupBenchmarkArtifact(
      schemaVersion: kAiroTvEpgWarmupBenchmarkSchemaVersion,
      capturedAt: DateTime.now().toUtc(),
      fixtureBytes: fixtureBytes,
      fixtureSha256: fixtureSha256.toString(),
      channelCount: config.channelCount,
      visibleChannelCount: visibleChannelIds.length,
      now: config.now!,
      programmeCount: snapshot.entries
          .map(
            (entry) => [entry.current, entry.next].whereType<Object>().length,
          )
          .fold<int>(0, (sum, count) => sum + count),
      snapshotEntryCount: snapshot.entries.length,
      visibleEntryCount: visibleSlice.entries.length,
      snapshotBytes: utf8.encode(snapshotPayload).length,
      warmupWallTime: stopwatch.elapsed,
      mainHeartbeatTicks: heartbeat.tickCount,
      maxMainHeartbeatDelay: heartbeat.maxDelay,
      baselineRssBytes: heartbeat.baselineRssBytes,
      peakRssBytes: heartbeat.maxRssBytes,
      maxNowNextLatency: config.maxNowNextLatency,
      maxHeartbeatDelay: config.maxHeartbeatDelay,
      maxRssDeltaBytes: config.maxRssDeltaBytes,
    );
  }

  Future<void> write(AiroTvEpgWarmupBenchmarkConfig config) async {
    final artifact = await run(config);
    final output = File(config.normalized().outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString('${artifact.toPrettyJson()}\n');
  }
}

class _MainIsolateHeartbeat {
  _MainIsolateHeartbeat({required this.interval})
    : baselineRssBytes = ProcessInfo.currentRss,
      maxRssBytes = ProcessInfo.currentRss;

  final Duration interval;
  final int baselineRssBytes;
  int maxRssBytes;
  Timer? _timer;
  Stopwatch? _stopwatch;
  int _lastElapsedUs = 0;
  int tickCount = 0;
  Duration maxDelay = Duration.zero;

  void start() {
    _stopwatch = Stopwatch()..start();
    _lastElapsedUs = 0;
    _timer = Timer.periodic(interval, (_) {
      final elapsedUs = _stopwatch!.elapsedMicroseconds;
      final deltaUs = elapsedUs - _lastElapsedUs;
      _lastElapsedUs = elapsedUs;
      tickCount++;
      final delayUs = deltaUs - interval.inMicroseconds;
      if (delayUs > maxDelay.inMicroseconds) {
        maxDelay = Duration(microseconds: delayUs);
      }
      final rssBytes = ProcessInfo.currentRss;
      if (rssBytes > maxRssBytes) {
        maxRssBytes = rssBytes;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
  }
}

Future<CompactEpgSlice> _buildSnapshot({
  required String xmltvPath,
  required DateTime now,
  required List<IPTVChannel> channels,
}) async {
  final aliasesByChannel = {
    for (final channel in channels) channel.id: _guideAliasesFor(channel),
  };
  final guideChannelIds = aliasesByChannel.values
      .expand((aliases) => aliases)
      .toSet()
      .toList(growable: false);
  final channelNamesByGuideId = {
    for (final channel in channels)
      for (final alias in aliasesByChannel[channel.id]!) alias: channel.name,
  };
  final guideRepository =
      await XmltvCompactEpgRepository.fromXmltvCurrentNextFileNative(
        path: xmltvPath,
        ingestedAt: now,
        channelIds: guideChannelIds,
        now: now,
        sourceRef: CompactEpgSourceRef.redacted('benchmark-xmltv-fixture'),
        channelNamesById: channelNamesByGuideId,
      );
  final guideSlice = await guideRepository.loadCurrentNext(
    channelIds: guideChannelIds,
    now: now,
  );
  final entries = <CompactEpgEntry>[];

  for (final channel in channels) {
    for (final alias in aliasesByChannel[channel.id]!) {
      final guideEntry = guideSlice.entryForChannel(alias);
      if (guideEntry == null || !guideEntry.hasPrograms) {
        continue;
      }
      entries.add(
        CompactEpgEntry(
          channelId: channel.id,
          channelName: channel.name,
          channelNumber: channel.tvgId?.toString(),
          current: guideEntry.current,
          next: guideEntry.next,
          sourceRef: guideEntry.sourceRef,
        ),
      );
      break;
    }
  }

  return CompactEpgSlice(
    entries: entries,
    generatedAt: guideSlice.generatedAt,
    expiresAt: guideSlice.expiresAt,
    source: entries.isEmpty
        ? CompactEpgSliceSource.unavailable
        : CompactEpgSliceSource.localCache,
  );
}

List<IPTVChannel> _generatedChannels(int channelCount) {
  return [
    for (var index = 0; index < channelCount; index++)
      IPTVChannel(
        id: 'stream-${index.toString().padLeft(5, '0')}',
        name: 'Airo Fixture ${index.toString().padLeft(5, '0')}',
        streamUrl: 'https://cdn.example.com/live/$index.m3u8',
        tvgName: _fixtureGuideChannelId(index),
      ),
  ];
}

List<String> _guideAliasesFor(IPTVChannel channel) {
  final aliases = <String>{
    channel.id,
    if (channel.tvgId != null) channel.tvgId.toString(),
    if (channel.tvgName != null) channel.tvgName!,
    channel.name,
    ...channel.altNames,
  };
  return aliases
      .map((alias) => alias.trim())
      .where((alias) => alias.isNotEmpty)
      .toList(growable: false);
}

String _fixtureGuideChannelId(int index) {
  return 'channel-${index.toString().padLeft(5, '0')}';
}
