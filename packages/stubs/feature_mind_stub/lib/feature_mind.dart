/// Airo Mind, absent.
///
/// Swapped in on shared surfaces -- web and TV -- where a personal vault must
/// not render. Rule R05.
///
/// Nothing the real package exports is re-exported here. That is the point: a
/// shared-surface build should fail to compile if it reaches for a Mind
/// surface, rather than compiling and showing an empty screen.
library;

/// Marks this build as one where Mind does not exist.
///
/// The product shell reads this to decide whether to offer a Mind destination.
/// It is absent from the real package, so a shell that reads it gets a compile
/// error rather than a silently wrong answer if the two ever drift.
abstract final class AiroMindAbsent {
  static const bool value = true;
}
