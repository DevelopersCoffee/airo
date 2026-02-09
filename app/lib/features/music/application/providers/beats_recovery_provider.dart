import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/beats_recovery_service.dart';

/// Provider for BeatsRecoveryService
final beatsRecoveryServiceProvider = Provider<BeatsRecoveryService>((ref) {
  final service = BeatsRecoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for recovery stream
final beatsRecoveryStreamProvider = StreamProvider<RecoveryEvent>((ref) {
  final service = ref.watch(beatsRecoveryServiceProvider);
  return service.recoveryStream;
});

/// Provider for whether recovery is in progress
final beatsIsRecoveringProvider = Provider<bool>((ref) {
  final service = ref.watch(beatsRecoveryServiceProvider);
  return service.isRecovering;
});

/// Provider for current recovery status
final beatsRecoveryStatusProvider = Provider<RecoveryStatus>((ref) {
  final recovery = ref.watch(beatsRecoveryStreamProvider);
  return recovery.when(
    data: (event) => event.status,
    loading: () => RecoveryStatus.idle,
    error: (_, __) => RecoveryStatus.idle,
  );
});

/// Provider for recovery message (for UI display)
final beatsRecoveryMessageProvider = Provider<String?>((ref) {
  final recovery = ref.watch(beatsRecoveryStreamProvider);
  return recovery.when(
    data: (event) {
      // Only show messages during active recovery
      if (event.status == RecoveryStatus.idle ||
          event.status == RecoveryStatus.recovered) {
        return null;
      }
      return event.message;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
