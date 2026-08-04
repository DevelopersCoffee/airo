# APKPure listing details — Airo and Airo Coins

Both listings must be registered by hand in the APKPure Developer Console before
any automation can target them. Nothing below is invented: every claim traces to
the README module table, the build profiles, or the shipped 0.0.6 artifacts.

---

## 1. Airo — `io.airo.app`

| Field | Value |
| --- | --- |
| App name | `Airo — AI, Money, TV & More` |
| Package ID | `io.airo.app` |
| Version / code | `0.0.6` / `10` |
| APK | `Airo-0.0.6-10-arm64.apk` (99.3 MB, **arm64 only**) |
| SHA-256 | `d99758a9b141a3d1f9625f9c481122125dfd375a122fab1e26bca6ded80b2bad` |
| minSdk / target | 26 (Android 8.0) / 36 |
| Category | Tools (or Productivity) |
| Website | `https://github.com/DevelopersCoffee/airo` |
| Privacy policy | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |

**Short description** (68 chars)
`Local-first super app: AI chat, money, IPTV, music, games, reading.`

**Full description**

```text
Airo is a local-first super app. AI chat, personal finance, an IPTV player,
music, games, and reading live in one open-source application, and your data
stays on the device unless you explicitly load something remote.

What is available today:
- Airo TV: bring-your-own-playlist IPTV player with EPG and favourites
- Airo Coins: a secure, local money vault with biometric unlock
- On-device AI chat with model management and agent skills (in development)

Modules still in development are visible in the app and clearly marked. Airo
does not bundle IPTV channels, movies, or any copyrighted media. You supply your
own authorized playlist or server credentials.

Open source, MIT licensed. SHA-256 checksums are published for every release.
No mandatory account and no hidden subscriptions.
```

**Honesty constraints — do not remove**
- Do not describe AI chat, Money, Music, Games or Reader as finished; the README
  marks them "In development".
- Do not claim bundled channels or content.
- This APK is **arm64 only** — it will not install on 32-bit devices.

---

## 2. Airo Coins — `io.airo.app.coins`

> Hold this listing. Issue #1240 (persistent black screen on Pixel 9 /
> Android 17) is open and unverified against the new Coins shell. A store
> listing is a worse place to discover it still reproduces than a GitHub
> release is.

| Field | Value |
| --- | --- |
| App name | `Airo Coins — Secure Money Vault` |
| Package ID | `io.airo.app.coins` |
| Version / code | `0.0.6` / `10` |
| APK | `AiroCoins-0.0.6-10-arm64.apk` (20.9 MB, **arm64 only**) |
| SHA-256 | `4be334e8c140896c17e592ea360ea736915992ea6194a3c863cfeaa7adb4ff25` |
| minSdk / target | 26 (Android 8.0) / 36 |
| Category | Finance |
| Privacy policy | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |

**Short description** (63 chars)
`Local-first money vault with biometric unlock. No account needed.`

**Full description**

```text
Airo Coins is a focused, local-first money vault. Records stay on your device,
protected by your device biometrics — there is no account to create, no sync,
and no server holding your data.

- Content-first money home
- Secure vault behind biometric or device-credential unlock
- Screen contents protected from screenshots and screen recording
- Works fully offline

Airo Coins is a preview release. It is part of the open-source Airo project.
```

**Honesty constraints — do not remove**
- Say "preview". This is a first standalone cut.
- Screenshots cannot be captured with normal tooling: the vault sets
  FLAG_SECURE, so screenshots come out blank. Use `uiautomator` on the device.
- arm64 only.

---

## Signing — decide before either listing goes live

Both APKs use the **stable dogfood keystore**. They upgrade cleanly over
v0.0.6-rc.1 and other dogfood-signed builds. A future production-signed release
**will not** upgrade over them: users would have to uninstall and lose local
data — which for Coins means their vault.

Publishing a dogfood-signed build to a store commits you to that keystore for
the life of the listing, or to a forced uninstall later. Worth settling first.

## Content rating and data safety

Both need an IARC questionnaire. Truthful answers for this codebase:
- No ads, no in-app purchases, no user-generated content sharing.
- No data collected or transmitted by the app itself.
- Airo TV plays user-supplied streams; content is not provided by Airo.
