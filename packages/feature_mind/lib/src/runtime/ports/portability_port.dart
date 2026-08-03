import '../models/portability_models.dart';

/// Recovery Package export.
///
/// The package format is fixed by the architecture freeze and issue #1305.
/// This port is the export flow only.
abstract interface class PortabilityPort {
  /// What sealing would produce for [contextIds]. Recomputed per selection.
  Future<RecoveryPackagePlan> plan(List<String> contextIds);

  /// Seals and writes. Emits bytes written of total.
  ///
  /// [passphrase] is not stored anywhere. If it is lost the package cannot be
  /// opened, and there is no reset — the surface says so before this is
  /// called.
  Stream<({int written, int total})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  });
}
