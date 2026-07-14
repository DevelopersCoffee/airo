# Airo TV Adaptive UI Mode Contract

This contract defines the v2.0.0.1 platform boundary for adaptive UI mode
resolution across TV, mobile companion, tablet, desktop, and constrained
receiver surfaces.

Implementation contract:

- Package: `packages/core_ui`
- Input model: `AiroAdaptiveUiInput`
- Policy: `AiroAdaptiveUiPolicy`
- Output model: `AiroAdaptiveUiMode`

## Inputs

Adaptive mode resolution uses:

- form factor;
- active input devices;
- viewing distance;
- window class;
- orientation;
- accessibility preferences;
- product UI profile hint.

The decision must not depend only on width. A TV with D-pad input, a tablet with
touch and remote input, and a desktop pointer surface can share dimensions while
requiring different focus, navigation, typography, and density behavior.

## Outputs

`AiroAdaptiveUiMode` resolves:

- interaction mode;
- density;
- typography scale;
- focus behavior;
- artwork policy;
- motion policy;
- navigation style;
- minimum target size;
- focus persistence requirement.

These outputs are stable contracts for Airo TV screens, IPTV widgets, companion
remote surfaces, and future profile navigation manifests.

## Consumer Rule

Airo TV app code should consume `core_ui` adaptive mode results. Product code
may choose screen-specific layout and copy, but it should not invent separate
remote/touch/pointer behavior models or hard-code density and accessibility
rules in individual screens.

## Out Of Scope

This issue does not rewrite Airo TV or IPTV screens, add golden tests, implement
runtime platform detection, certify physical remotes, define navigation
manifests, or enforce legacy performance budgets.
