# Airo Open-Source Library Standard & Extraction Template

This document defines the mandatory structure and quality checklist for any new Flutter/Dart package or Rust crate extracted from the Airo codebase into the `DevelopersCoffee` organization.

---

## 1. Repository File Standard

Every public package repository under `DevelopersCoffee` MUST include:

```text
<repository_name>/
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Automated format, lint, test, dry-run
│       └── publish.yml            # Automated pub.dev / crates.io release via OIDC
├── example/                       # Runnable standalone example app (Mandatory for pub points)
│   ├── lib/
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── README.md
├── lib/                           # Clean public API entrypoints (Dart)
│   └── <package_name>.dart
├── src/                           # Rust crate source (Rust)
│   └── lib.rs
├── test/                          # Unit & integration tests
├── .gitignore
├── CHANGELOG.md                   # Version history
├── LICENSE                        # Open-source license (MIT / Apache-2.0)
├── README.md                      # Badges, problem statement, quickstart, API guide
├── analysis_options.yaml          # Strict static analysis rules
└── pubspec.yaml / Cargo.toml     # Package metadata, topics, issue tracker
```

---

## 2. README Standard

Every `README.md` must follow this structure:

1. **Title & Badges**: Package name, pub.dev version badge, CI status badge, license badge.
2. **Problem Statement & Solution**: 2–3 sentences explaining what problem the package solves and why developers need it.
3. **Features Matrix**: Key capabilities bulleted with platform compatibility table (Android, iOS, macOS, Windows, Linux, Web).
4. **Quickstart Code Snippets**: Minimal copy-pasteable example showing initialization and basic usage.
5. **Detailed API Overview**: Explanation of core classes/traits.
6. **License & Contributing**: Contribution guidelines link and license statement.

---

## 3. Pre-Release Quality Gate Checklist

- [ ] Zero local dependencies on Airo monorepo code.
- [ ] `flutter analyze` / `cargo clippy` passes with **0 warnings**.
- [ ] Unit & integration tests pass with >90% code coverage.
- [ ] `dart pub publish --dry-run` / `cargo package` passes with **0 warnings**.
- [ ] `example/` project compiles and runs cleanly.
- [ ] GitHub Actions CI workflow passes on `main` branch.
- [ ] Zero secrets, API keys, tokens, or internal URLs in Git history.
