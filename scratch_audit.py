import os
import re
from pathlib import Path

repo_root = Path('/Users/udaychauhan/workspace/airo-upgrade')
packages_dir = repo_root / 'packages'
docs_dir = repo_root / 'docs'

packages_to_audit = [
    'platform_core',
    'platform_logging',
    'platform_events',
    'platform_settings',
    'platform_storage',
    'platform_filesystem',
    'design_system'
]

packages = [p for p in packages_dir.iterdir() if p.is_dir() and p.name in packages_to_audit]

def audit_exports():
    inventory = []
    for pkg in packages:
        main_dart = pkg / 'lib' / f"{pkg.name}.dart"
        if main_dart.exists():
            exports = []
            with open(main_dart, 'r') as f:
                for line in f:
                    if line.startswith('export'):
                        exports.append(line.strip())
            inventory.append((pkg.name, exports))
    return inventory

def check_forbidden_imports():
    forbidden = {
        'dart:io': ['platform_filesystem', 'platform_storage'],
        'package:sqlite3': ['platform_storage'],
        'package:drift': ['platform_storage'],
        'package:path_provider': ['platform_filesystem', 'platform_storage'],
        'package:shared_preferences': ['platform_settings']
    }
    violations = []
    for pkg in packages:
        for dart_file in pkg.rglob('*.dart'):
            if '.dart_tool' in dart_file.parts:
                continue
            with open(dart_file, 'r') as f:
                content = f.read()
                for f_import, allowed_pkgs in forbidden.items():
                    if pkg.name not in allowed_pkgs and f"import '{f_import}" in content:
                        violations.append(f"{pkg.name} improperly imports {f_import} in {dart_file.relative_to(repo_root)}")
    return violations

print("Public API Inventory:")
for pkg, exports in audit_exports():
    print(f"\n[{pkg}]")
    for exp in exports:
        print(f"  {exp}")

print("\nForbidden Imports Violations:")
v = check_forbidden_imports()
if v:
    for x in v: print(x)
else:
    print("None!")
