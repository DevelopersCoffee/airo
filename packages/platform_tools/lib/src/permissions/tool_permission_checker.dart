import 'package:platform_manifest/platform_manifest.dart';

class ToolPermissionChecker {
  bool checkPermissions(ToolManifest manifest, List<String> grantedPermissions) {
    for (final req in manifest.permissions) {
      if (!grantedPermissions.contains(req)) {
        return false;
      }
    }
    return true;
  }
}
