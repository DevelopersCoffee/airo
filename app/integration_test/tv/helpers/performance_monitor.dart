/// Performance monitoring utilities for Sony BRAVIA 2 qualification.
///
/// Tracks FPS (frame build + raster times), RSS memory consumption, and
/// image cache utilization against `DeviceClass.tvLow` budgets.
///
/// BRAVIA 2 constraints: 60 Hz panel = 16.67 ms frame budget, 2 GB RAM,
/// MediaTek SoC with limited processing headroom.
library;

import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame timing record for FPS analysis.
class FrameTimingRecord {
  const FrameTimingRecord({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
  });

  /// Time spent building the widget tree.
  final Duration buildDuration;

  /// Time spent rasterizing the frame.
  final Duration rasterDuration;

  /// Total frame time (build + raster).
  final Duration totalDuration;

  /// Whether this frame exceeded the 60 FPS budget (16.67ms).
  bool get isJank => totalDuration.inMicroseconds > 16667;

  /// Whether this frame is a severe jank (> 2× frame budget = 33.33ms).
  bool get isSevereJank => totalDuration.inMicroseconds > 33333;
}

/// RSS (Resident Set Size) memory snapshot.
class RssSnapshot {
  const RssSnapshot({
    required this.rssBytes,
    required this.timestamp,
  });

  final int rssBytes;
  final DateTime timestamp;

  int get rssMb => rssBytes ~/ (1024 * 1024);
}

/// Performance monitor for TV integration tests.
///
/// Usage:
/// ```dart
/// final monitor = PerformanceMonitor();
/// monitor.startFrameTracking();
/// // ... perform navigation/animation ...
/// monitor.stopFrameTracking();
/// monitor.expectSteady60Fps();
/// ```
class PerformanceMonitor {
  PerformanceMonitor({
    this.deviceClass = DeviceClass.tvLow,
  }) : _budget = MemoryBudget.forDevice(DeviceClass.tvLow);

  final DeviceClass deviceClass;
  final MemoryBudget _budget;

  final List<FrameTimingRecord> _frameTimings = [];
  bool _isTracking = false;

  // ── Frame Rate Tracking ──

  /// Start recording frame timings.
  void startFrameTracking() {
    _frameTimings.clear();
    _isTracking = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  /// Stop recording frame timings.
  void stopFrameTracking() {
    _isTracking = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isTracking) return;
    for (final timing in timings) {
      _frameTimings.add(FrameTimingRecord(
        buildDuration: Duration(
          microseconds:
              timing.buildDuration.inMicroseconds,
        ),
        rasterDuration: Duration(
          microseconds:
              timing.rasterDuration.inMicroseconds,
        ),
        totalDuration: Duration(
          microseconds: timing.totalSpan.inMicroseconds,
        ),
      ));
    }
  }

  /// Assert that the recorded frames maintained ≥ [minFps] FPS.
  ///
  /// Default [minFps] is 55 (allowing 5 FPS tolerance for emulator overhead
  /// on the 60 Hz target).
  void expectSteady60Fps({int minFps = 55}) {
    if (_frameTimings.isEmpty) {
      fail('No frame timings recorded — did you call startFrameTracking()?');
    }

    final totalDuration = _frameTimings
        .map((f) => f.totalDuration.inMicroseconds)
        .reduce((a, b) => a + b);
    final avgFrameTime = totalDuration / _frameTimings.length;
    final fps = 1000000.0 / avgFrameTime;

    expect(
      fps,
      greaterThanOrEqualTo(minFps),
      reason: 'Average FPS ${fps.toStringAsFixed(1)} is below '
          'minimum $minFps FPS. '
          '${_frameTimings.length} frames recorded, '
          'avg frame time: ${(avgFrameTime / 1000).toStringAsFixed(1)}ms',
    );
  }

  /// Assert that no frame exceeded [maxMs] milliseconds.
  ///
  /// Default is 32ms (2× the 16.67ms frame budget for 60 Hz).
  void expectNoJankFrames({int maxMs = 32}) {
    final jankFrames = _frameTimings
        .where((f) => f.totalDuration.inMilliseconds > maxMs)
        .toList();

    expect(
      jankFrames.isEmpty,
      isTrue,
      reason: '${jankFrames.length} jank frames detected exceeding '
          '${maxMs}ms. Worst frame: '
          '${jankFrames.isEmpty ? 0 : jankFrames.map((f) => f.totalDuration.inMilliseconds).reduce((a, b) => a > b ? a : b)}ms',
    );
  }

  /// Get a summary of recorded frame timings.
  FrameTimingSummary get summary {
    if (_frameTimings.isEmpty) {
      return const FrameTimingSummary(
        frameCount: 0,
        avgFrameTimeUs: 0,
        maxFrameTimeUs: 0,
        jankFrameCount: 0,
        severeJankCount: 0,
        fps: 0,
      );
    }

    final times = _frameTimings.map((f) => f.totalDuration.inMicroseconds);
    final total = times.reduce((a, b) => a + b);
    final maxTime = times.reduce((a, b) => a > b ? a : b);
    final avg = total / _frameTimings.length;

    return FrameTimingSummary(
      frameCount: _frameTimings.length,
      avgFrameTimeUs: avg.round(),
      maxFrameTimeUs: maxTime,
      jankFrameCount: _frameTimings.where((f) => f.isJank).length,
      severeJankCount: _frameTimings.where((f) => f.isSevereJank).length,
      fps: 1000000.0 / avg,
    );
  }

  // ── Memory Monitoring ──

  /// Read the current RSS (Resident Set Size) from /proc/self/status.
  ///
  /// Returns null on platforms where /proc is unavailable (macOS, web).
  RssSnapshot? captureRss() {
    try {
      final status = File('/proc/self/status').readAsStringSync();
      final match = RegExp(r'VmRSS:\s+(\d+)\s+kB').firstMatch(status);
      if (match == null) return null;
      final rssKb = int.parse(match.group(1)!);
      return RssSnapshot(
        rssBytes: rssKb * 1024,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      // /proc not available (macOS dev, web)
      debugPrint('⚠️ RSS monitoring unavailable on this platform');
      return null;
    }
  }

  /// Assert RSS is below the tvLow target (200 MB).
  void expectRssBelowTarget() {
    final rss = captureRss();
    if (rss == null) {
      debugPrint('⚠️ Skipping RSS assertion — /proc unavailable');
      return;
    }
    expect(
      rss.rssBytes,
      lessThanOrEqualTo(_budget.rssTargetBytes),
      reason: 'RSS ${rss.rssMb} MB exceeds tvLow target of '
          '${_budget.rssTargetBytes ~/ (1024 * 1024)} MB',
    );
  }

  /// Assert RSS never exceeds the tvLow absolute peak (300 MB).
  void expectRssBelowPeak() {
    final rss = captureRss();
    if (rss == null) return;
    expect(
      rss.rssBytes,
      lessThanOrEqualTo(_budget.rssPeakBytes),
      reason: 'RSS ${rss.rssMb} MB exceeds tvLow peak of '
          '${_budget.rssPeakBytes ~/ (1024 * 1024)} MB',
    );
  }

  // ── Image Cache Monitoring ──

  /// Assert image cache is within tvLow budget (30 MB / 100 items).
  void expectImageCacheWithinBudget() {
    final cache = PaintingBinding.instance.imageCache;
    expect(
      cache.currentSizeBytes,
      lessThanOrEqualTo(_budget.imageCacheBytes),
      reason: 'Image cache ${cache.currentSizeBytes ~/ (1024 * 1024)} MB '
          'exceeds tvLow budget of '
          '${_budget.imageCacheBytes ~/ (1024 * 1024)} MB',
    );
    expect(
      cache.currentSize,
      lessThanOrEqualTo(_budget.imageCacheCount),
      reason: 'Image cache ${cache.currentSize} entries '
          'exceeds tvLow limit of ${_budget.imageCacheCount}',
    );
  }

  // ── Stopwatch Helpers ──

  /// Measure the duration of an async operation.
  static Future<Duration> measure(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Reset all recorded data.
  void reset() {
    _frameTimings.clear();
    _isTracking = false;
  }
}

/// Summary of frame timing analysis.
class FrameTimingSummary {
  const FrameTimingSummary({
    required this.frameCount,
    required this.avgFrameTimeUs,
    required this.maxFrameTimeUs,
    required this.jankFrameCount,
    required this.severeJankCount,
    required this.fps,
  });

  final int frameCount;
  final int avgFrameTimeUs;
  final int maxFrameTimeUs;
  final int jankFrameCount;
  final int severeJankCount;
  final double fps;

  @override
  String toString() =>
      'FrameTimingSummary(fps: ${fps.toStringAsFixed(1)}, '
      'frames: $frameCount, '
      'avg: ${(avgFrameTimeUs / 1000).toStringAsFixed(1)}ms, '
      'max: ${(maxFrameTimeUs / 1000).toStringAsFixed(1)}ms, '
      'jank: $jankFrameCount, severe: $severeJankCount)';
}
