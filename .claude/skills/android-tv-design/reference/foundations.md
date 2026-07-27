# Foundations: navigation, focus, color, typography, icons

## Navigation

- 4-way D-pad moves focus to nearest element in the pressed direction. Every focusable element must be reachable — no dead ends, no controls off the reachable axis.
- **Axis convention**: vertical = categories/rows, horizontal = items within a row/category. Don't mix without reason.
- **Back button**: navigates to previous destination, chain ends at Home/Launcher. Never gate back with confirmation dialogs (no exit gating). Never render an on-screen back button — remote hardware handles it. Only show a Cancel button for destructive/purchase/confirm-only screens.
- **Home button**: always suspends app, returns to system Home/Launcher.
- Fixed start destination: app's first screen == last screen shown before returning to launcher via back.
- Deep links behave as if the user manually navigated — back from a deep-linked screen walks back through the app, not straight to launcher (exception: Live Tab direct playback).
- Efficient, predictable, intuitive: fewest screens to content, standard patterns, no novel/reinvented nav.

## Focus system

Focusable element = single unit (button, card, list item, custom surface). Focusable group = container of elements/groups, nestable. Only one element focused at a time.

States: default, focused, pressed (+ enabled/disabled/selected variants).

Focus indicators (mix as needed):
- **Scale**: 1.025x / 1.05x / 1.1x on focus, tune to element size.
- **Glow**: diffused shadow, 2dp–32dp elevation, brand/image-derived color.
- **Outline**: width + inset (spacing from element) + color, independent of border.
- **Color**: background/content color shift on focus.
- **Tonal elevation**: surface tint via primary-color overlay at elevation +1 to +5 (background color itself stays static).
- **Disabled**: lower opacity/prominence, no focus feedback implying interactivity.

## Color

- Follow Material 3 color system: 5 key colors → tonal palettes → Primary/Secondary/Tertiary/Surface/Outline roles. Use Material Theme Builder.
- Prefer **dark theme** for cinematic feel; darker colors also reduce TV power draw. Avoid full-white backgrounds unless necessary.
- Design/test in **sRGB + Standard picture mode** — broadest device compatibility. DCI-P3 looks richer but only on advanced panels; don't rely on it for core UI.
- No Android TV dynamic/wallpaper-based user theming — use **content-based color** (extract seed color from poster/album art via Material Color Utilities) instead.
- Accessibility: high text/background contrast, never color-only signaling, test across picture modes/lighting/display tech (LCD/LED/QLED/OLED vary in contrast & color reproduction).
- Gradients: use ≥10-bit depth, avoid sharp color jumps, apply dithering, or fall back to solid colors/subtle patterns to avoid banding.

## Typography

- Default typeface: Roboto (system, use for unbranded/native UI).
- Custom brand font: must be legible at a glance, adequate stroke width, avoid decorative/handwriting fonts. Pair sans-serif for body/labels; expressive font ok for Display/Headline only if line-height/letter-spacing preserved.
- Type scale roles (large→small):
  - **Display** — short, high-impact, main heading/numerals. Not for section headers.
  - **Headline** — short high-emphasis, carousel/cluster titles.
  - **Title** — cards/lists, secondary content.
  - **Body** — longer passages, no decorative fonts.
  - **Label** — buttons, captions, utilitarian.

## Icons (Fire TV / Android TV manifest assets)

Two mandatory AndroidManifest.xml assets: `android:icon` (1:1 launcher) and `android:banner` (16:9 banner). `android:roundIcon` is deprecated — use adaptive icons instead. No themed/monochrome icon support on TV.

Banner (16:9) sizes:
| Density | Size | Folder |
|---|---|---|
| mdpi | 160x90 | mipmap-mdpi |
| hdpi | 240x135 | mipmap-hdpi |
| xhdpi | 320x180 | mipmap-xhdpi |
| xxhdpi | 480x270 | mipmap-xxhdpi |
| xxxhdpi | 640x360 | mipmap-xxxhdpi |

Launcher icon (1:1) sizes:
| Density | Size | Folder |
|---|---|---|
| mdpi | 80x80 | mipmap-mdpi |
| hdpi | 120x120 | mipmap-hdpi |
| xhdpi | 160x160 | mipmap-xhdpi |
| xxhdpi | 240x240 | mipmap-xxhdpi |
| xxxhdpi | 320x320 | mipmap-xxxhdpi |

Rules:
- Banner text baked into image; localize per supported language.
- Adaptive icon/banner = separate foreground + background layers; keep logo inside safe zone (72x72 safe area for launcher).
- Don't: add extra text/graphics, misleading elements, spill outside safe area, add borders (get cropped), or crop the logo.
- Banner should show full logo (icon + wordmark), not icon alone.
