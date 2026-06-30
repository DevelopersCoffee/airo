abstract interface class ArchitectureValidator {
  bool validate();
}

abstract interface class DependencyValidator implements ArchitectureValidator {
  bool checkAcyclicDependencies();
}

abstract interface class ManifestValidator implements ArchitectureValidator {
  bool validateManifests();
}

abstract interface class ApiBaselineValidator implements ArchitectureValidator {
  bool validateBaseline();
}
