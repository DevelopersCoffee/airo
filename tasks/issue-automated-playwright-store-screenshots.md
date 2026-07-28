# Issue: Automate App Store Screenshots & Feature Graphics via Playwright

## Overview

Establish an automated Playwright screenshot capture pipeline (`e2e/` / `scripts/`) to automatically capture, validate, and format store listing screenshots and feature graphics for Airo TV and Airo profiles across desktop, web, and mobile viewports.

---

## Technical Specifications & Compliance Requirements

All generated assets must strictly meet the following distribution platform standards (APKPure & Google Play Store):

### 📸 Store Screenshots
- **Format:** JPEG or 24-bit PNG (**no alpha channel**)
- **Min Dimension:** `320px`
- **Max Dimension:** `3840px`
- **Aspect Ratio Rule:** Max dimension must **not exceed twice the minimum dimension** (e.g., `1920×1080` is valid: `1920 <= 2 * 1080 = 2160`).
- **Content Guidelines:** Must portray actual app runtime UI. Avoid performance claims, rankings, pricing, or promotional badge overlays.

### 🖼️ Feature Graphic / Banner
- **Format:** JPEG or 24-bit PNG (**no alpha channel**)
- **Exact Dimensions:** `1024px` × `500px`
- **Style:** Clean, professional product showcase matching Airo design system guidelines.

---

## Tasks & Deliverables

- [ ] **Playwright Test Runner Setup:** Configure Playwright in `e2e/screenshots.spec.ts` to launch the Flutter web/desktop validation profile.
- [ ] **Viewport Configurations:**
  - `1920×1080` (TV / Desktop landscape)
  - `1280×720` (Tablet / HD landscape)
  - `390×844` (Mobile portrait — padded/formatted to 2:1 aspect constraint)
- [ ] **Automated Alpha Removal & Resizing Pipeline:** Add a post-processing script (`scripts/process-store-screenshots.py`) using Pillow to convert RGBA → RGB (remove alpha channel) and ensure exact `1024×500` feature graphic export.
- [ ] **CI Integration:** Wire screenshot capture into `.github/workflows/airo-tv-release.yml` or release orchestrator so fresh screenshots are published as release evidence artifacts.

---

## Acceptance Criteria

1. Automated script captures live app screens (Browse, Search, Channel Player, EPG Guide).
2. All generated PNGs are verified 24-bit (no alpha).
3. `1024×500` feature graphic is automatically exported and validated.
4. No promotional text, price, or ranking claims present on screenshots.
