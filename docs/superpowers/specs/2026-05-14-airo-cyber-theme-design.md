# Airo Cyber Theme Design

## Context

Airo currently uses a simple Material 3 purple theme from `core_ui`, with a separate Bedtime theme applied by `AppShell` when bedtime mode is active. The user wants the product to move toward the futuristic, dense, grid-led visual language seen on the Hermes Agent site while keeping the app extensible for more themes later.

This spec defines an original Airo theme system inspired by that direction. It does not copy Hermes assets, fonts, or exact source styling. It translates the broad cues into an Airo-owned design language that is safe to ship.

## Goals

- Make `Airo Cyber` the default app theme.
- Preserve the existing Material theme as `Airo Classic`.
- Keep Bedtime as the low-light override.
- Add a theme registry so future themes are data-driven instead of hard-coded through scattered conditionals.
- Add a settings picker so users can switch themes without reinstalling or changing OS mode.
- Keep changes compatible with the current Flutter/Riverpod structure.

## Non-Goals

- No exact clone of Hermes fonts, textures, or animations.
- No full redesign of every feature screen in this slice.
- No new remote asset dependency.
- No migration of all feature-specific color usage in this slice.

## Design Direction

`Airo Cyber` uses a dark teal-black base, warm cream text, amber primary actions, and cyan/green status accents. Surfaces use thin outlines, low-radius corners, and low elevation. The goal is a focused operating-system feel, not a marketing landing page.

The theme should avoid a one-note palette. Amber is the primary accent, but semantic success/info/error colors remain visually distinct. Text must keep accessible contrast against dark surfaces.

## Theme Architecture

The `core_ui` package owns reusable theme definitions:

- `AppThemeId`: stable identifiers for `cyber`, `classic`, and `bedtime`.
- `AppThemeDefinition`: label, description, light theme, dark theme, and preferred mode.
- `AiroThemeTokens`: a `ThemeExtension` for non-Material tokens such as grid line, glow, warning, success, and chrome surface colors.
- `AppTheme`: registry facade for default theme lookup and compatibility getters.

The app package owns user preference persistence:

- `appThemeProvider`: Riverpod state notifier backed by `SharedPreferences`.
- `AiroApp`: watches the selected theme and passes the correct `theme`, `darkTheme`, and `themeMode` to `MaterialApp.router`.
- `AppShell`: continues to apply `BedtimeTheme.bedtimeTheme` when bedtime mode is enabled.

## User Experience

The profile/settings screen gets an `Appearance` section with theme choices:

- Airo Cyber: default futuristic dark theme.
- Airo Classic: existing Material light/dark behavior.
- Bedtime: warm AMOLED theme for low-light use.

Selecting a theme saves immediately and updates the app in place.

## Testing

- `core_ui` unit tests cover theme IDs, registry defaults, token presence, and compatibility getters.
- App widget/provider tests cover the default `Airo Cyber` selection and persisted theme restore.
- Existing app smoke tests continue to pass.

## Rollout

This is a first complete slice. It makes the global theme system real and visible, then leaves deeper per-feature visual polish for follow-up work by module: Coins, Money, Agent, Media, Games, and Quest.
