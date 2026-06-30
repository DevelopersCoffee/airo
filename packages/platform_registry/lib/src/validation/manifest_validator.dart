import 'package:platform_registry/platform_registry.dart';

class ManifestValidator {
  void validate(ExtensionManifest manifest) {
    if (manifest.identifier.isEmpty) throw ArgumentError('Manifest identifier cannot be empty');
    if (manifest.version.isEmpty) throw ArgumentError('Manifest version cannot be empty');
  }
}
