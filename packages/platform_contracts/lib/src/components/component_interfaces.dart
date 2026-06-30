// ignore_for_file: one_member_abstracts

abstract interface class HealthCheck {
  Future<bool> isHealthy();
}

abstract interface class DiagnosticProvider {
  Map<String, dynamic> getDiagnostics();
}

import 'package:platform_identity/platform_identity.dart';

import '../capabilities/capability.dart';

abstract interface class ExtensionComponent implements CapabilityProvider, VersionedComponent {
  String get identifier;
}
