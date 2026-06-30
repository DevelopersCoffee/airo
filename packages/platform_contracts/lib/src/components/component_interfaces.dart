// ignore_for_file: one_member_abstracts

abstract interface class HealthCheck {
  Future<bool> isHealthy();
}

abstract interface class DiagnosticProvider {
  Map<String, dynamic> getDiagnostics();
}

abstract interface class CapabilityProvider {
  List<String> get capabilities;
}

abstract interface class VersionedComponent {
  String get version;
}

abstract interface class ExtensionComponent implements CapabilityProvider, VersionedComponent {
  String get identifier;
}
