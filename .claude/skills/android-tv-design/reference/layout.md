# Layout: grid, patterns, templates

- Design canvas: 960x540 (MDPI, 1px=1dp), 16:9. Assets target 1080p (downscales cleanly to 720p).
- Overscan-safe margins: ~5% — 48dp left/right, 27dp (round to 24-28dp) top/bottom. Keep critical content inside; background/decorative elements may bleed full-screen (don't clip backgrounds to the safe zone).
- Grid: 12 columns, 52dp wide, 20dp gutters, 58dp side margins, 4dp vertical line spacing.

## Layout patterns

- **Horizontal Stack** — row of varied-size items, groups content/components.
- **Vertical Stack** — flexible vertical grouping of text, controls, and layout patterns.
- **Grid** — rows x columns; account for focus-scale growth in item spacing so focused items don't overlap neighbors.

## Panel structures

- **Single-pane** — content-forward, critical-info pages.
- **Two-pane** — hierarchical/task-forward content.
- Avoid 3+ panels — causes cognitive overload and back-and-forth focus paths. Group related content in one panel rather than splitting across many.

## Layout templates

Pick per screen intent — don't invent new nav shapes:

| Template | Use |
|---|---|
| Browse | Vertical stack of content rows/clusters; up/down between rows, left/right within a row |
| Left overlay | Nav/action panel over background content, left side |
| Right overlay | Independent action panel over background content, right side |
| Center overlay | Modal — urgent info or forced decision |
| Bottom overlay | Bottom sheet — mini flow without losing page context |
| Actions | Title/subtitle left, options/actions right |
| Content Details | Horizontal stack — title, metadata, description, quick actions, related clusters |
| Compilation | Item details left (e.g. podcast), elements right (e.g. episodes) |
| Grid | Organized content collection, clear remote-nav logic |
| Alert | Full-screen message, requires action to dismiss |

## Card columns (row density → card width)

| Cards per row | Card width |
|---|---|
| 1 | 844dp |
| 2 | 412dp |
| 3 | 268dp |
| 4 | 196dp |
| 5 | 124dp |

Peaking spacing between cards: 20dp.
