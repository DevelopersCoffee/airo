import os
import glob
import re

packages = [
    'platform_core', 'platform_events', 'platform_logging',
    'platform_settings', 'platform_storage', 'platform_filesystem',
    'platform_jobs', 'design_system'
]

output = "# API Baseline (PFR-1)\n\n"
output += "> This document is a snapshot of the public API surface for Program 0 platform packages.\n\n"

for pkg in packages:
    output += f"## {pkg}\n\n"
    lib_path = f"packages/{pkg}/lib"
    if not os.path.exists(lib_path):
        continue
    
    files = glob.glob(f"{lib_path}/**/*.dart", recursive=True)
    
    classes = []
    enums = []
    extensions = []
    typedefs = []
    
    for file in files:
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
            # Find classes/mixins
            for match in re.finditer(r'^(?:abstract\s+)?(?:interface\s+)?(?:base\s+)?(?:final\s+)?(?:sealed\s+)?(?:class|mixin)\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
                classes.append(match.group(1))
            # Find enums
            for match in re.finditer(r'^enum\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
                enums.append(match.group(1))
            # Find extensions
            for match in re.finditer(r'^extension\s+([A-Z][a-zA-Z0-9_]*)\s+on', content, re.MULTILINE):
                extensions.append(match.group(1))
            # Find typedefs
            for match in re.finditer(r'^typedef\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
                typedefs.append(match.group(1))

    # sort and deduplicate, filtering out private ones starting with _
    classes = sorted([c for c in set(classes) if not c.startswith('_')])
    enums = sorted([e for e in set(enums) if not e.startswith('_')])
    extensions = sorted([e for e in set(extensions) if not e.startswith('_')])
    typedefs = sorted([t for t in set(typedefs) if not t.startswith('_')])

    if classes:
        output += "### Classes & Interfaces\n"
        for c in classes:
            output += f"- `{c}`\n"
        output += "\n"
    if enums:
        output += "### Enums\n"
        for e in enums:
            output += f"- `{e}`\n"
        output += "\n"
    if extensions:
        output += "### Extensions\n"
        for e in extensions:
            output += f"- `{e}`\n"
        output += "\n"
    if typedefs:
        output += "### Typedefs\n"
        for t in typedefs:
            output += f"- `{t}`\n"
        output += "\n"

with open('docs/foundation/api_baseline.md', 'w') as f:
    f.write(output)

print("api_baseline.md generated.")
