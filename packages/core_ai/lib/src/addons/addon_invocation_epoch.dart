import 'package:meta/meta.dart';

/// Monotonic epoch bumped when add-on invocation eligibility is revoked mid-flight.
class AddonInvocationEpoch {
  AddonInvocationEpoch._();

  static const cancelledCode = 'addon_invocation_cancelled';

  static final AddonInvocationEpoch instance = AddonInvocationEpoch._();

  int _epoch = 0;

  int get current => _epoch;

  void bump() => _epoch++;

  @visibleForTesting
  void resetForTesting() => _epoch = 0;
}
