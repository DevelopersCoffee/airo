# First Library Selection Decision

> **Selected Candidate**: `dpad_qualification` (Extracted from [`packages/platform_device_qualification`](file:///Users/udaychauhan/workspace/airo/packages/platform_device_qualification))  
> **Public Repository**: [DevelopersCoffee/dpad_qualification](https://github.com/DevelopersCoffee/dpad_qualification)  
> **Package Registry**: [pub.dev/packages/dpad_qualification](https://pub.dev/packages/dpad_qualification)

---

## 1. Selection Rationale

`dpad_qualification` was chosen as the **Pilot #1 candidate** for the Airo Open Source Program based on six evaluation metrics:

1. **High External Usefulness**: Flutter TV, Android TV, Fire TV, and multi-device desktop/tablet developers urgently need D-Pad remote control emulation and viewport resolution testing tools without physical hardware or heavy emulators.
2. **Zero Internal Monorepo Dependencies**: 100% decoupled from Airo application state, requiring no complex dependency inversion adapters.
3. **Clean Conceptual API**: Clear exports (`ResolutionSimulator`, `DpadRemoteController`, `DeviceQualificationOverlay`, `DeviceQualificationReportBuilder`).
4. **Independent Testability**: 100% unit and widget test coverage achieved.
5. **Zero IP Risk**: Contains zero proprietary Airo business logic, commercial entitlement code, or private credentials.
6. **High Visual Impact for Community Distribution**: Live resolution scaling and on-screen remote overlays make excellent content for YouTube technical demos, technical blogs, and GitHub READMEs.

---

## 2. Evaluation of Other Candidates

* **`core_workers` (`run_off_main`)**: Scheduled for **Pilot #2**. Excellent 0-dependency candidate, but less visually demonstrative than `dpad_qualification` for the initial community launch.
* **`platform_iptv_org_api`**: Scheduled for **Pilot #3**. High value, depends on `core_workers` (will be published immediately after `run_off_main`).
* **`platform_playlist`**: Scheduled for **Phase 2**. Extremely high value, requires decoupling worker isolates.
* **`core_native` (`airo_core` Rust Crate)**: Scheduled for **Phase 2**. Requires publishing Rust crate to `crates.io` and configuring cross-compiled native assets for Dart FFI.

---

## 3. Public API Contract for `dpad_qualification`

```dart
library;

// Viewport Simulator & Preset Devices
export 'src/resolution_simulator.dart'; // ResolutionSimulator, SimulatedDevice

// On-Screen TV Remote Overlay
export 'src/dpad_remote_controller.dart'; // DpadRemoteController

// Interactive QA & Telemetry Testing Panel
export 'src/device_qualification_overlay.dart'; // DeviceQualificationOverlay

// Automated Headless Test Reporter
export 'src/device_qualification_report.dart'; // DeviceQualificationReportBuilder
```
