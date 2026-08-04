# Airo Coins store assets — `io.airo.app.coins`

Captured on the Pixel 9 rig and processed with
`scripts/process-store-screenshots.py`.

| Asset | Size | Notes |
| --- | --- | --- |
| `feature-graphic-1024x500.png` | 1024x500 | `scripts/make-feature-graphic.py --preset coins` |
| `coins-home.png` | 1137x2274 | App home, showing the vault card and recent transactions |

## Notes

`FLAG_SECURE` is set on the **vault screen**, not the app home. Measured with
repeated captures:

| Screen | Dominant colour share | Result |
| --- | --- | --- |
| App home | 89.2% | capturable (that share is the dark theme) |
| Secure Vault | 99.7% | blanked |

So this listing has exactly one screenshot, and no amount of sample data changes
that: vault records can be stored, but they can never be photographed. The
standalone app also has no UI path for adding transactions, so "Recent
transactions" stays empty.

If the listing needs more screenshots, the only route is a build with
`FLAG_SECURE` disabled, used solely for asset capture and never distributed.
That is a deliberate decision to make, not a default.

This listing is **held**. Issue #1240 (persistent black screen on Pixel 9 /
Android 17) is open and unverified against the standalone Coins shell, and a
store listing is a worse place to discover it still reproduces than a GitHub
release is.
