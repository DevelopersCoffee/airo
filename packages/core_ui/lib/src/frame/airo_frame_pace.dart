import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One OS display mode. [refreshRate] is in hertz.
@immutable
class AiroDisplayMode {
  const AiroDisplayMode({
    required this.id,
    required this.width,
    required this.height,
    required this.refreshRate,
  });

  final int id;
  final int width;
  final int height;
  final double refreshRate;

  @override
  bool operator ==(Object other) {
    return other is AiroDisplayMode &&
        other.id == id &&
        other.width == width &&
        other.height == height &&
        other.refreshRate == refreshRate;
  }

  @override
  int get hashCode => Object.hash(id, width, height, refreshRate);
}

/// Modes the platform can see right now.
@immutable
class AiroDisplayInventory {
  const AiroDisplayInventory({
    required this.supported,
    this.active,
    this.transientFailure = false,
  });

  final List<AiroDisplayMode> supported;
  final AiroDisplayMode? active;

  /// The activity window was not ready. The caller should retry once.
  final bool transientFailure;
}

/// Time budget for a single frame at [refreshRateHz].
///
/// 120 Hz is 8333 microseconds (8.33 ms). A frame that takes longer than
/// this is dropped by the display. Build work stays inside the budget by
/// keeping JSON, image decode, and other large parses off the UI isolate
/// (`runOffMain` in `core_workers`) and by painting only what changed.
@immutable
class AiroFrameBudget {
  const AiroFrameBudget(this.refreshRateHz);

  final double refreshRateHz;

  /// 120 Hz, the rate [AiroFramePace] asks Android to prefer when the panel
  /// offers it.
  static const double highRefreshHz = 120;

  Duration get duration {
    final hz = refreshRateHz.isFinite && refreshRateHz > 1 ? refreshRateHz : 60;
    return Duration(microseconds: (1000000 / hz).round());
  }

  /// True when the panel is meaningfully above a 60 Hz cadence.
  bool get isHighRefresh => refreshRateHz >= 90;

  /// Budget exposed by the nearest [AiroFramePace], or the Flutter view's
  /// current refresh rate when no host is mounted.
  static AiroFrameBudget of(BuildContext context) {
    final scope = AiroFramePaceScope.maybeOf(context);
    if (scope != null) return scope.budget;
    final rate = View.maybeOf(context)?.display.refreshRate ?? 60;
    return AiroFrameBudget(rate > 1 ? rate : 60);
  }

  @override
  bool operator ==(Object other) {
    return other is AiroFrameBudget && other.refreshRateHz == refreshRateHz;
  }

  @override
  int get hashCode => refreshRateHz.hashCode;
}

/// Where the current [AiroFrameBudget] came from.
enum AiroFramePaceSource {
  /// The first platform reply has not landed.
  pending,

  /// Android accepted a preferred display mode.
  operatingSystem,

  /// iOS, web, desktop, or an Android build without the channel. The budget
  /// follows [View.display.refreshRate]. iPhone ProMotion stays unlocked by
  /// `CADisableMinimumFrameDurationOnPhone` in `app/ios/Runner/Info.plist`.
  display,
}

/// Chooses the display mode a shell should ask the OS for.
///
/// Prefers a mode within [bandHz] of [targetHz] at the active resolution so
/// a 120 Hz panel is unlocked and a 144 Hz panel is not forced off its
/// native high rate when 120 is missing. Falls back to the fastest mode at
/// that resolution.
abstract final class AiroFramePacePolicy {
  static const double targetHz = AiroFrameBudget.highRefreshHz;
  static const double bandHz = 1.5;

  static AiroDisplayMode? select({
    required List<AiroDisplayMode> supported,
    AiroDisplayMode? active,
    double targetHz = AiroFramePacePolicy.targetHz,
    double bandHz = AiroFramePacePolicy.bandHz,
  }) {
    if (supported.isEmpty) return null;
    final sameResolution = active == null
        ? supported
        : supported
              .where(
                (mode) =>
                    mode.width == active.width && mode.height == active.height,
              )
              .toList(growable: false);
    final pool = sameResolution.isEmpty ? supported : sameResolution;
    final nearTarget = pool
        .where((mode) => (mode.refreshRate - targetHz).abs() <= bandHz)
        .toList(growable: false);
    if (nearTarget.isNotEmpty) {
      return nearTarget.reduce(
        (best, mode) => _prefer(best, mode, targetHz: targetHz),
      );
    }
    return pool.reduce((best, mode) => _preferHighest(best, mode));
  }

  static AiroDisplayMode _prefer(
    AiroDisplayMode best,
    AiroDisplayMode mode, {
    required double targetHz,
  }) {
    final bestDistance = (best.refreshRate - targetHz).abs();
    final modeDistance = (mode.refreshRate - targetHz).abs();
    if (modeDistance < bestDistance) return mode;
    if (modeDistance > bestDistance) return best;
    return mode.id < best.id ? mode : best;
  }

  static AiroDisplayMode _preferHighest(
    AiroDisplayMode best,
    AiroDisplayMode mode,
  ) {
    if (mode.refreshRate > best.refreshRate) return mode;
    if (mode.refreshRate < best.refreshRate) return best;
    return mode.id < best.id ? mode : best;
  }
}

/// Reads and applies OS display modes. Tests substitute a fake.
abstract interface class AiroFramePacePlatform {
  Future<AiroDisplayInventory> readInventory();

  Future<bool> applyMode(int modeId);
}

/// Android implementation. Other platforms have no plugin and follow the
/// Flutter view's refresh rate.
class MethodChannelAiroFramePacePlatform implements AiroFramePacePlatform {
  MethodChannelAiroFramePacePlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'dev.developerscoffee.airo/frame_pace';

  final MethodChannel _channel;

  @override
  Future<AiroDisplayInventory> readInventory() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getModes');
      if (raw is! Map) {
        return const AiroDisplayInventory(supported: []);
      }
      return AiroDisplayInventory(
        active: _mode(raw['active']),
        supported: _modes(raw['supported']),
      );
    } on MissingPluginException {
      return const AiroDisplayInventory(supported: []);
    } on PlatformException catch (error) {
      return AiroDisplayInventory(
        supported: const [],
        transientFailure: error.code == 'no_activity',
      );
    }
  }

  @override
  Future<bool> applyMode(int modeId) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('applyMode', {
        'id': modeId,
      });
      return raw == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static AiroDisplayMode? _mode(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final width = raw['width'];
    final height = raw['height'];
    final refreshRate = raw['refreshRate'];
    if (id is! int || width is! int || height is! int || refreshRate is! num) {
      return null;
    }
    return AiroDisplayMode(
      id: id,
      width: width,
      height: height,
      refreshRate: refreshRate.toDouble(),
    );
  }

  static List<AiroDisplayMode> _modes(Object? raw) {
    if (raw is! List) return const [];
    return [for (final entry in raw) ?_mode(entry)];
  }
}

/// Publishes the active [AiroFrameBudget] to the subtree.
class AiroFramePaceScope extends InheritedWidget {
  const AiroFramePaceScope({
    required this.budget,
    required this.source,
    required super.child,
    super.key,
  });

  final AiroFrameBudget budget;
  final AiroFramePaceSource source;

  static AiroFramePaceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AiroFramePaceScope>();
  }

  @override
  bool updateShouldNotify(AiroFramePaceScope oldWidget) {
    return budget != oldWidget.budget || source != oldWidget.source;
  }
}

/// Root host that asks Android for a high refresh rate and publishes the
/// frame budget.
///
/// [AiroBootstrap] mounts this around every product shell, so phone, TV,
/// Coins, Mind, and Anya share one request. The request runs after the first
/// frame and again whenever the app resumes, because several OEM power
/// policies put third-party apps back on 60 Hz.
///
/// Impeller is already the engine default on iOS and on Android API 29 and
/// above. This host does not force `EnableImpeller` in the manifest: devices
/// below that API stay on Skia, which is the engine's own fallback. Passing
/// `--enable-impeller` is unnecessary on the supported default path.
///
/// The host does not move work off the UI isolate. Callers still have to
/// keep a frame inside [AiroFrameBudget.duration]. Use [AiroLazyList] for
/// long collections and [AiroRepaintIsland] around widgets that repaint
/// every frame.
class AiroFramePace extends StatefulWidget {
  const AiroFramePace({
    required this.child,
    super.key,
    this.platform,
    this.targetHz = AiroFramePacePolicy.targetHz,
    this.reportOverBudget,
  });

  final Widget child;
  final AiroFramePacePlatform? platform;
  final double targetHz;

  /// Logs frames that miss [AiroFrameBudget.duration]. Defaults to profile
  /// mode, where frame timings reflect release-like scheduling.
  final bool? reportOverBudget;

  @override
  State<AiroFramePace> createState() => _AiroFramePaceState();
}

class _AiroFramePaceState extends State<AiroFramePace>
    with WidgetsBindingObserver {
  AiroFrameBudget _budget = const AiroFrameBudget(60);
  AiroFramePaceSource _source = AiroFramePaceSource.pending;
  var _requestGeneration = 0;
  var _retriedEmptyWindow = false;
  DateTime? _lastOverBudgetReport;

  AiroFramePacePlatform get _platform =>
      widget.platform ?? MethodChannelAiroFramePacePlatform();

  bool get _reportOverBudget => widget.reportOverBudget ?? kProfileMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_reportOverBudget) {
      WidgetsBinding.instance.addTimingsCallback(_onTimings);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestHighRefresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_reportOverBudget) {
      WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retriedEmptyWindow = false;
      unawaited(_requestHighRefresh());
    }
  }

  Future<void> _requestHighRefresh() async {
    final generation = ++_requestGeneration;
    final inventory = await _platform.readInventory();
    if (!mounted || generation != _requestGeneration) return;

    if (inventory.transientFailure && !_retriedEmptyWindow) {
      _retriedEmptyWindow = true;
      // A post-frame callback alone does not schedule a frame, so the retry
      // would never run if the tree is otherwise idle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_requestHighRefresh());
      });
      WidgetsBinding.instance.scheduleFrame();
      return;
    }

    final selected = AiroFramePacePolicy.select(
      supported: inventory.supported,
      active: inventory.active,
      targetHz: widget.targetHz,
    );
    var effective = inventory.active;
    if (selected != null && selected.id != inventory.active?.id) {
      final applied = await _platform.applyMode(selected.id);
      if (!mounted || generation != _requestGeneration) return;
      if (applied) effective = selected;
    } else if (selected != null) {
      effective = selected;
    }

    final fromOs = effective != null && inventory.supported.isNotEmpty;
    final appliedMode = fromOs ? effective : null;
    final hz = appliedMode?.refreshRate ?? _viewRefreshRate();
    final previous = inventory.active;
    if (kDebugMode &&
        appliedMode != null &&
        previous != null &&
        (appliedMode.refreshRate - previous.refreshRate).abs() > 1) {
      debugPrint(
        'AiroFramePace: ${previous.refreshRate} Hz -> '
        '${appliedMode.refreshRate} Hz',
      );
    }
    setState(() {
      _budget = AiroFrameBudget(hz);
      _source = appliedMode != null
          ? AiroFramePaceSource.operatingSystem
          : AiroFramePaceSource.display;
    });
  }

  double _viewRefreshRate() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 60;
    final rate = views.first.display.refreshRate;
    return rate > 1 ? rate : 60;
  }

  void _onTimings(List<FrameTiming> timings) {
    final budget = _budget.duration;
    FrameTiming? missed;
    for (final timing in timings) {
      if (timing.totalSpan > budget) {
        missed = timing;
        break;
      }
    }
    if (missed == null) return;
    final now = DateTime.now();
    final previous = _lastOverBudgetReport;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      return;
    }
    _lastOverBudgetReport = now;
    debugPrint(
      'AiroFramePace: frame ${missed.totalSpan.inMicroseconds}µs exceeded '
      '${budget.inMicroseconds}µs '
      '(${_budget.refreshRateHz.toStringAsFixed(0)} Hz)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AiroFramePaceScope(
      budget: _budget,
      source: _source,
      child: widget.child,
    );
  }
}
