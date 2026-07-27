import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/wifi_settings_launcher.dart';

/// Shared connectivity monitor for the "OFFLINE" banner (AiroTV D-pad
/// design): the playlist is cached, so channels stay listed, but streams
/// need a real connection.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  return service;
});

/// issues/04-recovery-states.md AC4: the offline banner's "Open Wi-Fi
/// Settings" action, backed by a real platform adapter.
final wifiSettingsLauncherProvider = Provider<WifiSettingsLauncher>((ref) {
  return const WifiSettingsLauncher();
});

/// Whether the device currently has network connectivity. Seeded with a
/// one-shot check so the UI doesn't have to assume "online" before the
/// first stream event arrives.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isConnected;
  yield* service.onConnectivityChanged;
});
