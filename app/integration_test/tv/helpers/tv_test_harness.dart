/// TV test harness for bootstrapping the Airo TV app in BRAVIA 2 simulation.
///
/// Forces `DeviceClass.tvLow` memory budgets (30 MB image cache, 200 MB RSS
/// target) and configures the app for headless integration testing on a
/// 4K Android TV emulator with 2 GB RAM.
///
/// Usage:
/// ```dart
/// late TvTestHarness harness;
///
/// setUp(() async {
///   harness = TvTestHarness();
///   await harness.setUp(tester);
/// });
///
/// tearDown(() async {
///   await harness.tearDown();
/// });
/// ```
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/core/app/airo_tv_app.dart';
import 'package:airo_app/core/app/tv_router.dart';

/// Bootstrap harness that initializes the TV app in BRAVIA 2 simulation mode.
///
/// Key behaviors:
/// - Forces `DeviceClass.tvLow` memory budget
/// - Configures landscape orientation (TV mode)
/// - Starts with empty database for UI-driven import testing
/// - Provides `pumpAndSettleTv()` with TV animation duration tolerance
class TvTestHarness {
  TvTestHarness({
    this.initialRoute = TvRouteNames.live,
    this.deviceClass = DeviceClass.tvLow,
  });

  final String initialRoute;
  final DeviceClass deviceClass;

  late WidgetTester _tester;
  late ProviderContainer _container;
  late SharedPreferences _prefs;

  /// The Riverpod container, for overriding or reading providers in tests.
  ProviderContainer get container => _container;

  /// SharedPreferences instance for playlist URL setup.
  SharedPreferences get prefs => _prefs;

  /// Initialize the test binding and launch the TV app.
  Future<void> setUp(WidgetTester tester) async {
    _tester = tester;
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    // Force tvLow memory budget — matching BRAVIA 2's 2 GB RAM constraint
    final budget = MemoryBudget.forDevice(deviceClass);
    debugPrint('📺 Test harness: using ${deviceClass.name} budget — '
        'imageCache: ${budget.imageCacheBytes ~/ (1024 * 1024)} MB / '
        '${budget.imageCacheCount} items, '
        'RSS target: ${budget.rssTargetBytes ~/ (1024 * 1024)} MB');

    // Configure image cache to tvLow limits
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = budget.imageCacheCount;
    imageCache.maximumSizeBytes = budget.imageCacheBytes;

    // Initialize SharedPreferences with empty state (UI-driven import)
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();

    // Set landscape orientation (TV mode)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Create the TV router with the specified initial route
    final router = TvRouter.createRouter(initialLocation: initialRoute);

    // Build the app
    _container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container,
        child: MaterialApp.router(
          title: 'Airo TV Test',
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(),
            scrollbars: false,
          ),
        ),
      ),
    );

    await pumpAndSettleTv();
  }

  /// Pump and settle with a longer timeout suitable for TV animations.
  ///
  /// TV animations use `TvFocusConstants.focusAnimationDuration` (200ms)
  /// and the 60 Hz refresh cycle means we need slightly more tolerance.
  Future<void> pumpAndSettleTv({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Pump a single frame with a specified duration.
  Future<void> pump([Duration? duration]) async {
    await _tester.pump(duration);
  }

  /// Clean up all test resources.
  Future<void> tearDown() async {
    // Flush image cache
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    // Dispose provider container
    _container.dispose();

    // Reset orientation
    await SystemChrome.setPreferredOrientations([]);

    debugPrint('📺 Test harness: tearDown complete');
  }

  /// Verify the current memory budget is within tvLow limits.
  ///
  /// Returns a [MemoryBudgetStatus] with current measurements.
  MemoryBudgetStatus checkMemoryBudget() {
    final imageCache = PaintingBinding.instance.imageCache;
    final budget = MemoryBudget.forDevice(deviceClass);

    return MemoryBudgetStatus(
      currentImageCacheBytes: imageCache.currentSizeBytes,
      currentImageCacheCount: imageCache.currentSize,
      maxImageCacheBytes: budget.imageCacheBytes,
      maxImageCacheCount: budget.imageCacheCount,
      rssTargetBytes: budget.rssTargetBytes,
      rssPeakBytes: budget.rssPeakBytes,
    );
  }
}

/// Snapshot of current memory usage vs. budget limits.
class MemoryBudgetStatus {
  const MemoryBudgetStatus({
    required this.currentImageCacheBytes,
    required this.currentImageCacheCount,
    required this.maxImageCacheBytes,
    required this.maxImageCacheCount,
    required this.rssTargetBytes,
    required this.rssPeakBytes,
  });

  final int currentImageCacheBytes;
  final int currentImageCacheCount;
  final int maxImageCacheBytes;
  final int maxImageCacheCount;
  final int rssTargetBytes;
  final int rssPeakBytes;

  bool get isImageCacheWithinBudget =>
      currentImageCacheBytes <= maxImageCacheBytes &&
      currentImageCacheCount <= maxImageCacheCount;

  @override
  String toString() =>
      'MemoryBudget(imageCache: '
      '${currentImageCacheBytes ~/ (1024 * 1024)}/'
      '${maxImageCacheBytes ~/ (1024 * 1024)} MB, '
      '$currentImageCacheCount/$maxImageCacheCount items, '
      'rssTarget: ${rssTargetBytes ~/ (1024 * 1024)} MB)';
}
