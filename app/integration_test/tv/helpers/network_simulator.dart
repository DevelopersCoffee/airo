// Network simulation helper for TV integration tests.
// Allows toggling connectivity, bandwidth throttling, and packet loss to
// emulate real‑world TV network conditions (e.g., 5 Mbps, 2 % loss).
// Uses the `connectivity_plus` package to listen for changes and the
// `flutter_test` `HttpOverrides` mechanism to intercept HTTP requests.

library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuration for a simulated network profile.
class NetworkProfile {
  const NetworkProfile({
    required this.downloadMbps,
    required this.uploadMbps,
    this.latencyMs = 0,
    this.packetLossPercent = 0,
  });

  /// Approximate download speed in megabits per second.
  final double downloadMbps;

  /// Approximate upload speed in megabits per second.
  final double uploadMbps;

  /// Added artificial round‑trip latency (ms).
  final int latencyMs;

  /// Packet loss percentage (0‑100).
  final double packetLossPercent;

  /// Human readable name for debugging.
  String get name =>
      '${downloadMbps}Mbps↓/${uploadMbps}Mbps↑ ${latencyMs}ms latency '
      '${packetLossPercent}% loss';
}

/// Global override that injects latency and loss into HTTP requests.
class _ThrottlingHttpOverrides extends HttpOverrides {
  _ThrottlingHttpOverrides(this.profile);

  final NetworkProfile profile;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return _ThrottlingHttpClient(client, profile);
  }
}

class _ThrottlingHttpClient implements HttpClient {
  _ThrottlingHttpClient(this._inner, this._profile);

  final HttpClient _inner;
  final NetworkProfile _profile;

  // Helper to randomly drop packets based on loss percent.
  bool _shouldDrop() => _profile.packetLossPercent > 0 &&
      (Random().nextDouble() * 100) < _profile.packetLossPercent;

  // Wraps the request future with added latency.
  Future<HttpClientRequest> _maybeThrottle(HttpClientRequest request) async {
    if (_shouldDrop()) {
      // Simulate a dropped request by never completing.
      final completer = Completer<HttpClientRequest>();
      // Complete after a long timeout so the test eventually fails.
      Future.delayed(Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.completeError(
              SocketException('Simulated packet loss'),
              StackTrace.current);
        }
      });
      return completer.future;
    }
    // Add latency before returning the request.
    if (_profile.latencyMs > 0) {
      await Future.delayed(Duration(milliseconds: _profile.latencyMs));
    }
    return request;
  }

  // Implement the subset of HttpClient methods used by the app.
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _maybeThrottle(await _inner.getUrl(url));

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _maybeThrottle(await _inner.postUrl(url));

  // Forward remaining members directly – most are not needed for test.
  @override
  // ignore: unnecessary_overrides
  void close({bool force = false}) => _inner.close(force: force);

  @override
  // ignore: unnecessary_overrides
  set autoCompress(bool? value) => _inner.autoCompress = value;

  @override
  // ignore: unnecessary_overrides
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  // The rest of the HttpClient API is delegated via `noSuchMethod`.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Function.apply(_inner.noSuchMethod, [invocation]);
}

/// Manages the simulated network during a test.
///
/// Typical usage:
/// ```dart
/// final simulator = NetworkSimulator(tester);
/// await simulator.applyProfile(NetworkProfile(
///   downloadMbps: 5,
///   uploadMbps: 2,
///   latencyMs: 150,
///   packetLossPercent: 1,
/// ));
/// // run test steps…
/// await simulator.restore();
/// ```
class NetworkSimulator {
  NetworkSimulator(this.tester);

  final WidgetTester tester;
  NetworkProfile? _current;

  /// Apply a profile – sets connectivity state and installs HTTP overrides.
  Future<void> applyProfile(NetworkProfile profile) async {
    _current = profile;
    // Simulate Wi‑Fi connectivity for the profile.
    await Connectivity().setResult(ConnectivityResult.wifi);
    // Install HttpOverrides globally for the duration of the test.
    HttpOverrides.global = _ThrottlingHttpOverrides(profile);
    // Force a rebuild so widgets that react to connectivity recompute.
    await tester.pumpAndSettle();
  }

  /// Restore normal network – removes overrides and resets connectivity.
  Future<void> restore() async {
    if (_current != null) {
      await Connectivity().setResult(ConnectivityResult.mobile);
      HttpOverrides.global = null;
      _current = null;
      await tester.pumpAndSettle();
    }
  }
}
