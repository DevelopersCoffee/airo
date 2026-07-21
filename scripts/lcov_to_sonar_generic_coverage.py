#!/usr/bin/env python3
"""Convert an lcov.info report into SonarQube's Generic Test Coverage XML.

SonarCloud has no built-in Dart coverage sensor (`sonar.dart.coverage.
reportPath` is not a real property -- it is silently ignored, and the
"Zero Coverage Sensor" marks every coverable Dart line as uncovered).
The generic coverage XML format is the only documented, sensor-agnostic
way to import external coverage data:
https://docs.sonarsource.com/sonarqube/latest/analysis/generic-test/

`flutter test --coverage` writes lcov SF: paths relative to the Flutter
package root it was run from (e.g. "lib/main.dart" when run from
app/), but sonar.sources is the repository root, so paths need a
--prefix (e.g. "app/") to match what Sonar expects.
"""

import argparse
import sys
import xml.sax.saxutils as saxutils


def parse_lcov(lcov_path):
    """Yield (file_path, {line_number: hit_count}) per SF/end_of_record block."""
    current_file = None
    current_lines = {}
    with open(lcov_path, encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line.startswith("SF:"):
                current_file = line[len("SF:") :]
                current_lines = {}
            elif line.startswith("DA:"):
                line_number_str, hits_str = line[len("DA:") :].split(",", 1)
                current_lines[int(line_number_str)] = int(hits_str)
            elif line == "end_of_record":
                if current_file is not None:
                    yield current_file, current_lines
                current_file = None
                current_lines = {}


def write_generic_coverage_xml(entries, prefix, out_path):
    with open(out_path, "w", encoding="utf-8") as out:
        out.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        out.write('<coverage version="1">\n')
        for path, lines in entries:
            full_path = f"{prefix}{path}" if prefix else path
            out.write(f'  <file path="{saxutils.escape(full_path)}">\n')
            for line_number in sorted(lines):
                covered = "true" if lines[line_number] > 0 else "false"
                out.write(
                    f'    <lineToCover lineNumber="{line_number}" covered="{covered}"/>\n'
                )
            out.write("  </file>\n")
        out.write("</coverage>\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lcov_path", help="Path to the input lcov.info file")
    parser.add_argument(
        "--prefix",
        default="",
        help="Prefix prepended to each SF: path (e.g. 'app/')",
    )
    parser.add_argument(
        "--out", required=True, help="Path to write the generic coverage XML to"
    )
    args = parser.parse_args()

    entries = list(parse_lcov(args.lcov_path))
    if not entries:
        print(f"::warning::No coverage entries found in {args.lcov_path}", file=sys.stderr)

    write_generic_coverage_xml(entries, args.prefix, args.out)
    print(f"Wrote generic coverage XML for {len(entries)} files to {args.out}")


if __name__ == "__main__":
    main()
