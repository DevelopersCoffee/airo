enum CertificationLevel {
  none,
  experimental,
  stable,
  production,
  missionCritical
}

class ComplianceReport {
  const ComplianceReport({
    required this.passed,
    required this.failures,
    required this.level,
  });
  
  final bool passed;
  final List<String> failures;
  final CertificationLevel level;
}

abstract class TestSuite {
  Future<ComplianceReport> run();
}

// Replaced Architecture gates with Implementation Certification gates
abstract class AbiCompatibilitySuite extends TestSuite {}
abstract class PluginHotSwapSuite extends TestSuite {}
abstract class MemoryLeakSuite extends TestSuite {}
abstract class IdleMemorySuite extends TestSuite {}
abstract class ThreadSafetySuite extends TestSuite {}
abstract class CancellationSuite extends TestSuite {}
abstract class DeterministicReplaySuite extends TestSuite {}
abstract class PerformanceSuite extends TestSuite {}
abstract class HardwareSuite extends TestSuite {}
abstract class ResilienceSuite extends TestSuite {}
abstract class CrossPlatformParitySuite extends TestSuite {}
