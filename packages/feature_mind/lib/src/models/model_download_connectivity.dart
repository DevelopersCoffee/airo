import 'package:connectivity_plus/connectivity_plus.dart';

/// What the download coordinator needs to know about the network: is it
/// metered right now, and when does that change.
///
/// An interface rather than `connectivity_plus` used directly at the call
/// site, so [ModelDownloadCoordinator] can be driven by a fake in tests
/// without a platform channel — connectivity checks are the one part of this
/// feature `flutter_test` cannot exercise for real.
abstract interface class ModelDownloadConnectivity {
  Future<bool> isMetered();

  Stream<bool> get onMeteredChanged;
}

/// [ModelDownloadConnectivity] backed by `connectivity_plus`, the same
/// package `core_data`'s `ConnectivityService`, `platform_player`'s cast
/// handoff, and `feature_iptv` already use.
///
/// [ConnectivityResult.mobile] is the proxy for "metered": true per-network
/// billing status (Android's `NetworkCapabilities.NET_CAPABILITY_NOT_METERED`,
/// which would also catch a metered Wi-Fi hotspot) needs a platform channel
/// this package does not have. Treating mobile data as metered and
/// everything else as not is the conservative default the rest of Airo
/// already ships with — it does not invent a new connectivity model for one
/// feature.
class ConnectivityPlusModelDownloadConnectivity
    implements ModelDownloadConnectivity {
  ConnectivityPlusModelDownloadConnectivity({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isMetered() async {
    final results = await _connectivity.checkConnectivity();
    return _isMetered(results);
  }

  @override
  Stream<bool> get onMeteredChanged =>
      _connectivity.onConnectivityChanged.map(_isMetered);

  bool _isMetered(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.mobile);
}
