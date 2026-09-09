# Migration Record: `airo_core`

> **Status**: Completed & Verified  
> **Original Location**: `rust/airo_core`  
> **New Public Repository**: [DevelopersCoffee/airo_core](https://github.com/DevelopersCoffee/airo_core)  
> **Published Crate Version**: `airo_core: 0.1.0`

---

## 1. Migration Overview

1. Extracted high-performance Rust parsing & database engines (M3U SIMD parser, XMLTV EPG parser, bounded fuzzy search, relational store, FFI bridge contracts) into standalone public repository [`DevelopersCoffee/airo_core`](https://github.com/DevelopersCoffee/airo_core).
2. Prepared package metadata for `crates.io` publication (MIT License, `Cargo.toml` metadata, benchmark suites, 65 unit tests, 3 conformance integration tests, 1 doc test).
3. Created public GitHub repository `DevelopersCoffee/airo_core` and published initial release.
4. Preserved local workspace member linking in `rust/Cargo.toml` for zero-friction local FFI compilation while enabling external Rust developers and Flutter/Native projects to consume `airo_core` directly from GitHub or `crates.io`.

---

## 2. Remote Crate Dependency Usage

For external Rust or FFI projects:

```toml
[dependencies]
airo_core = { git = "https://github.com/DevelopersCoffee/airo_core.git", branch = "main" }
# Or from crates.io once published:
# airo_core = "0.1.0"
```

---

## 3. Verification

```bash
cd rust/airo_core
cargo test --all-targets  # 65 unit tests + 3 integration tests + 1 doc test passing
```

---

## 4. Rollback Procedure

If remote crate resolution fails during local Flutter FFI builds:
1. Ensure `rust/Cargo.toml` workspace member `airo_core` points to local `rust/airo_core`.
2. Run `cargo check --package airo_core`.
