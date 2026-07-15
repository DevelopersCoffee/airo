# Airo TV Rust FFI Core Boundary

## Scope

This document defines the local foundation slice for the v2 Rust platform core.
It creates the repo boundary without enabling a new remote CI matrix.

## Ownership

- Framework Agent owns `rust/airo_core` and the FFI-safe native API surface.
- Framework Agent owns `packages/core_native` as the Dart package boundary.
- Airo TV and feature packages consume public APIs exported by `core_native`.
- Feature packages must not import generated FFI files or Rust bridge internals.

## Package Contract

`rust/airo_core` contains native engines that can later host playlist parsing,
EPG ingest, search, deduplication, and other high-throughput work.

`packages/core_native` exposes stable Dart APIs with pure-Dart fallbacks where
practical. The fallback path keeps host tests, web builds, and early migration
work usable before `flutter_rust_bridge` generated bindings are installed.

The initial vertical slice is `normalizeChannelName`, used to prove a small
Rust-owned text contract and matching Dart fallback.

The first playlist slice is `parseM3uEntries`. Rust owns raw M3U tokenization
and EXTINF attribute parsing. Dart platform packages still own URL safety,
dedupe preference, display formatting, and `IPTVChannel` construction so Airo
TV behavior stays stable while the parser engine moves behind the platform
boundary.

## Rules For Consumers

1. Import `package:core_native/core_native.dart`.
2. Do not import `packages/core_native/lib/src/frb_generated.dart`.
3. Keep product-specific orchestration in application packages.
4. Move reusable native, parsing, indexing, or storage contracts into platform
   packages before consuming them from Airo TV.
5. Keep every FFI-facing API deterministic, documented, and covered by both
   Rust and Dart fallback tests.

## Cost-Control Decision

This slice intentionally does not add or enable a Rust GitHub Actions matrix.
Agents must use focused local validation unless branch protection, release
ownership, or the issue explicitly requires remote CI.

Remaining #780 acceptance gates:

1. Replace the checked-in bridge stub with generated `flutter_rust_bridge`
   bindings.
2. Add the required multi-platform CI matrix when CI spend is approved.
3. Record binary-size delta evidence for Android and iOS artifacts.
4. Add an FFI round-trip benchmark for the first production native workload.
