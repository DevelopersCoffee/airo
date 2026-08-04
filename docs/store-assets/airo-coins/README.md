# Airo Coins store assets — `io.airo.app.coins`

Captured on the Pixel 9 rig and processed with
`scripts/process-store-screenshots.py`.

| Asset | Size | Notes |
| --- | --- | --- |
| `feature-graphic-1024x500.png` | 1024x500 | `scripts/make-feature-graphic.py --preset coins` |
| `coins-vault-home.png` | 1137x2274 | Standalone vault home |

## Notes

`FLAG_SECURE` does **not** blank the Coins home: it captures with plain
`adb exec-out screencap`. Earlier QA notes said otherwise; presumably only the
vault detail screen sets it. Check before assuming a screen cannot be captured.

This listing is **held**. Issue #1240 (persistent black screen on Pixel 9 /
Android 17) is open and unverified against the standalone Coins shell, and a
store listing is a worse place to discover it still reproduces than a GitHub
release is.
