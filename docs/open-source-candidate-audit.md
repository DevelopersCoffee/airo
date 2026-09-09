# Airo Open Source Candidate Audit

> **Objective**: Comprehensive evaluation of all 60 monorepo packages in `packages/` to identify reusable infrastructure, library candidates for public release (`pub.dev` / `crates.io`), and internal proprietary application components.

---

## 1. Candidate Evaluation Matrix

| Candidate | Language | Current Location | Capability | Reusable | Extraction Difficulty | Public API Needed | Dependencies | Recommendation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `platform_device_qualification` | Dart/Flutter | `packages/platform_device_qualification` | Resolution simulator, D-Pad remote control emulator, QA report builder | Yes | Low (0 local deps) | `ResolutionSimulator`, `DpadRemoteController`, `DeviceQualificationOverlay` | Flutter, `shared_preferences` | `PUBLISH` (Published as `DevelopersCoffee/dpad_qualification`) |
| `core_workers` | Dart | `packages/core_workers` | Isolate execution engine (`runOffMain<T>()`) with timeline tracing and web fallback | Yes | Low (0 local deps) | `runOffMain<T>()` | Dart SDK | `PUBLISH` (Proposed: `run_off_main`) |
| `platform_calendar` | Dart/Flutter | `packages/platform_calendar` | Native OS calendar capability (Android/iOS/macOS) with unit test fakes | Yes | Low (0 local deps) | `CalendarService`, `CalendarEvent` | Flutter SDK | `PUBLISH` (Proposed: `airo_calendar`) |
| `platform_downloads` | Dart/Flutter | `packages/platform_downloads` | Progressive background downloader with lifecycle pause/resume | Yes | Low (0 local deps) | `BackgroundDownloader`, `DownloadTask` | Flutter SDK | `PUBLISH` (Proposed: `airo_background_downloads`) |
| `platform_iptv_org_api` | Dart | `packages/platform_iptv_org_api` | Typed, cached relational client for public `iptv-org` database | Yes | Low (1 local dep: `core_workers`) | `IptvOrgClient`, `Channel`, `Stream` | `core_workers` | `PUBLISH` (Proposed: `iptv_org_api`) |
| `platform_playlist` | Dart | `packages/platform_playlist` | M3U, Xtream Codes, Stalker, Jellyfin parsers & provider health scoring | Yes | Medium (5 local deps) | `ContentSourceAdapter`, `M3uParser`, `XtreamClient` | `platform_worker_jobs`, `platform_epg` | `EXTRACT-FIRST` (Decouple worker jobs) |
| `platform_coin_vault` | Dart | `packages/platform_coin_vault` | Biometric-gated field-level AES database encryption & key rotation | Yes | Medium (2 local deps) | `VaultCipher`, `VaultKeyManager`, `EncryptedRepository` | `core_data`, `core_domain` | `EXTRACT-FIRST` (Decouple data models) |
| `core_native` / `airo_core` | Rust/Dart | `packages/core_native` | High-performance M3U/XMLTV Rust parser crate & `flutter_rust_bridge` v2 bindings | Yes | Medium (Rust Crate + FFI) | `airo_core` Rust crate & Dart bindings | `flutter_rust_bridge`, `cargokit` | `EXTRACT-FIRST` (Standalone Rust Crate) |
| `platform_worker_jobs` | Dart | `packages/platform_worker_jobs` | Cooperative CPU resource scheduler and worker isolate executor | Yes | Low (0 local deps) | `AiroWorkerExecutor`, `ResourceScheduler` | Flutter SDK | `PUBLISH` (Proposed: `airo_job_scheduler`) |
| `core_analytics` | Dart | `packages/core_analytics` | Vendor-neutral, privacy-preserving event analytics contracts | Yes | Low (0 local deps) | `AnalyticsTracker`, `PrivacyFilter` | Dart SDK | `PUBLISH` (Proposed: `airo_analytics`) |
| `core_pairing` | Dart | `packages/core_pairing` | Local device pairing, ticket verification, and secret handoff | Yes | Low (0 local deps) | `DevicePairingClient`, `PlaybackTicket` | Dart SDK | `PUBLISH` (Proposed: `airo_pairing`) |
| `core_protocol` | Dart | `packages/core_protocol` | Protobuf edge node envelope & connected device transport protocol | Yes | Low (0 local deps) | `ConnectedNodeEnvelope`, `TransportMessage` | Dart SDK | `PUBLISH` (Proposed: `airo_protocol`) |
| `platform_epg` | Dart | `packages/platform_epg` | Electronic Program Guide (EPG) XMLTV parsing and channel schedule contracts | Yes | Medium (2 local deps) | `EpgParser`, `ChannelProgramSchedule` | `core_native`, `core_entitlements` | `EXTRACT-FIRST` |
| `platform_streaming_engine` | Dart/Kotlin | `packages/platform_streaming_engine` | Android TV Media3 zero-copy streaming engine bridge | Yes | High (Platform channel + native) | `ZeroCopyStreamingEngine` | Android SDK, `platform_player` | `REWORK` |
| `platform_player` | Dart/Flutter | `packages/platform_player` | Multi-engine player wrapper (VLC, ExoPlayer, ChromeCast) | Yes | High (6 local deps) | `AiroMediaPlayerController` | `core_analytics`, `platform_channels` | `REWORK` |
| `feature_iptv` | Dart/Flutter | `packages/feature_iptv` | End-user IPTV TV UI, channels grid, player overlay, search | No | High (20 local deps) | App UI Screen | Monorepo dependencies | `KEEP-IN-AIRO` (App Presentation Layer) |
| `feature_coin` | Dart/Flutter | `packages/feature_coin` | End-user Coins finance UI, biometric prompt screens, document cards | No | High (4 local deps) | App UI Screen | `platform_coin_vault`, `core_ui` | `KEEP-IN-AIRO` (App Presentation Layer) |
| `feature_mind` | Dart/Flutter | `packages/feature_mind` | End-user Mind audio recorder, transcript search, meeting minutes UI | No | High (9 local deps) | App UI Screen | `core_ai`, `core_ui`, `platform_calendar` | `KEEP-IN-AIRO` (App Presentation Layer) |
| `airo_pro_bootstrap` | Dart | `packages/airo_pro_bootstrap` | Private overlay bootstrap shim for commercial Pro modules | No | N/A | Entitlement hooks | `core_entitlements` | `NOT-SAFE-TO-PUBLISH` (Commercial Open-Core Boundary) |

---

## 2. Recommendation Classification Summary

1. **`PUBLISH`**:
   * [`platform_device_qualification`](file:///Users/udaychauhan/workspace/airo/packages/platform_device_qualification) → Published as `DevelopersCoffee/dpad_qualification`.
   * [`core_workers`](file:///Users/udaychauhan/workspace/airo/packages/core_workers) → Ready for standalone pub.dev release as `run_off_main`.
   * [`platform_calendar`](file:///Users/udaychauhan/workspace/airo/packages/platform_calendar) → Ready for `airo_calendar`.
   * [`platform_downloads`](file:///Users/udaychauhan/workspace/airo/packages/platform_downloads) → Ready for `airo_background_downloads`.
   * [`platform_iptv_org_api`](file:///Users/udaychauhan/workspace/airo/packages/platform_iptv_org_api) → Ready for `iptv_org_api`.
   * [`platform_worker_jobs`](file:///Users/udaychauhan/workspace/airo/packages/platform_worker_jobs) → Ready for `airo_job_scheduler`.
   * [`core_analytics`](file:///Users/udaychauhan/workspace/airo/packages/core_analytics) → Ready for `airo_analytics`.
   * [`core_pairing`](file:///Users/udaychauhan/workspace/airo/packages/core_pairing) → Ready for `airo_pairing`.
   * [`core_protocol`](file:///Users/udaychauhan/workspace/airo/packages/core_protocol) → Ready for `airo_protocol`.

2. **`EXTRACT-FIRST`**:
   * [`platform_playlist`](file:///Users/udaychauhan/workspace/airo/packages/platform_playlist) → Requires decoupling worker jobs.
   * [`platform_coin_vault`](file:///Users/udaychauhan/workspace/airo/packages/platform_coin_vault) → Requires decoupling domain models into a standalone crypto vault package.
   * [`core_native`](file:///Users/udaychauhan/workspace/airo/packages/core_native) → Requires isolating `airo_core` Rust crate for crates.io publication.

3. **`KEEP-IN-AIRO`**:
   * `feature_iptv`, `feature_coin`, `feature_mind`, `core_app_shell`, `core_product_shell`.
   * Product-specific UI, user journeys, navigation shells, and custom application themes.

4. **`NOT-SAFE-TO-PUBLISH`**:
   * `airo_pro_bootstrap`, proprietary prompts, internal entitlement keys, commercial licensing overlays.
