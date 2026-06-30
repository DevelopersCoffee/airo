#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as p;

/// The architectural gatekeeper script.
/// Validates package boundaries and forbidden imports across the workspace.
/// Run this via CI to ensure the foundation remains intact.

final repoRoot = Directory.current.path;

// Map of forbidden import string -> list of allowed package names
final forbiddenImports = {
  'dart:io': ['platform_filesystem', 'platform_storage', 'scripts'],
  'package:sqlite3': ['platform_storage'],
  'package:drift': ['platform_storage'],
  'package:path_provider': ['platform_filesystem', 'platform_storage'],
  // Legacy exceptions until they are fully migrated
  'package:shared_preferences': ['platform_settings', 'core_data'],
};

// Only strictly enforce newly engineered Program 0 platform packages right now.
// Once legacy feature packages are migrated, they will be subject to the same gates.
final enforcedPackages = [
  'platform_core',
  'platform_logging',
  'platform_events',
  'platform_settings',
  'platform_storage',
  'platform_filesystem',
];

void main() async {
  print('Starting Architecture Validation Gate...');
  
  final packagesDir = Directory(p.join(repoRoot, 'packages'));
  if (!packagesDir.existsSync()) {
    print('Error: Could not find packages/ directory.');
    exit(1);
  }

  var hasViolations = false;

  for (final pkg in packagesDir.listSync().whereType<Directory>()) {
    final pkgName = p.basename(pkg.path);
    if (!enforcedPackages.contains(pkgName)) {
      continue;
    }

    final libDir = Directory(p.join(pkg.path, 'lib'));
    if (!libDir.existsSync()) continue;

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart') && !file.path.contains('.dart_tool'));

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      
      for (final entry in forbiddenImports.entries) {
        final forbiddenImport = entry.key;
        final allowedPackages = entry.value;
        
        if (!allowedPackages.contains(pkgName)) {
          // Naive check for import statement
          if (content.contains("import '$forbiddenImport") || content.contains('import "$forbiddenImport')) {
            print('❌ ARCHITECTURE VIOLATION:');
            print('   Package: $pkgName');
            print('   File:    ${p.relative(file.path, from: repoRoot)}');
            print('   Error:   Improperly imports forbidden dependency "$forbiddenImport"');
            hasViolations = true;
          }
        }
      }
    }
  }

  if (hasViolations) {
    print('\n❌ Architecture validation failed. Please correct the forbidden dependencies.');
    exit(1);
  } else {
    print('\n✅ Architecture validation passed. All boundaries are respected.');
    exit(0);
  }
}
