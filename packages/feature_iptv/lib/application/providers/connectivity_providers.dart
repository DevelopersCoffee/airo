import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw connectivity change stream, overridable in tests so widgets don't
/// need a real platform channel to exercise offline UI.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

/// Whether the device currently has no network connectivity at all.
///
/// Defers to the raw connectivity stream rather than actual reachability --
/// this distinguishes "device says it's offline" (checklist's "offline
/// state") from playback-specific failures, which the player's own error
/// states already handle.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.maybeWhen(
    data: (results) =>
        results.every((result) => result == ConnectivityResult.none),
    orElse: () => false,
  );
});
