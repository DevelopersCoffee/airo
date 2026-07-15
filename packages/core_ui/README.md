# Core UI

Design-system contracts, theme primitives, adaptive mode policy, and shared widgets
for Airo products.

This package is platform/framework code. Airo TV, mobile companion, tablet,
desktop, IPTV, and future profile-specific surfaces consume these contracts
instead of defining separate input-mode, density, typography, focus, and
accessibility behavior in product screens.

## Scope

- Theme definitions and design primitives.
- Shared UI widgets.
- Adaptive UI mode inputs and resolver policy.
- Stable interaction, density, typography, focus, artwork, motion, navigation,
  and target-size outputs.

This package does not implement runtime platform detection, rewrite product
screens, define product navigation manifests, run device certification, or ship
golden-test assets.

## Image Rendering

Use `AiroNetworkImage` for user-supplied remote artwork that appears in product
UI at a known visual size, such as channel logos. The widget forwards to
Flutter's network image renderer with `cacheWidth` and `cacheHeight` derived
from layout constraints and device pixel ratio, so large source images decode
near display size instead of native size.

`AiroNetworkImageUrlPolicy` accepts only absolute `http` and `https` URLs with a
host. Unsupported values route to the widget fallback path before Flutter starts
a network image request or decode attempt. Fallback errors expose the stable
`unsupported_network_image_url` code and do not include the raw user-supplied
URL.

Android TV and Fire TV entrypoints should call
`AiroImageCacheBudget.configureAndroidTv()` after
`WidgetsFlutterBinding.ensureInitialized()` to keep Flutter's in-memory
`ImageCache` bounded on constrained devices. The default uses the constrained
Android TV memory budget from `platform_device_profile`; callers with a runtime
device profile can pass the selected `AiroRuntimeMemoryBudget` to apply a
device-class-specific image cache ceiling.

`AiroImageCacheSnapshot.capture()` records current and maximum ImageCache
entries/bytes, live image count, and pending image count. Airo TV benchmark and
QA harnesses should attach `snapshot.evaluate()` output to logo-scroll evidence
so image-cache budget violations use the same stable
`platform_device_profile` codes as RSS and heap reports.
