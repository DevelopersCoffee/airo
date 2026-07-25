# Components

Design source: Figma TV Design Kit (goo.gle/tv-desing-kit). Implementation: Jetpack Compose `androidx.tv.material3`.

## Buttons

6 variants: Filled, Outline, Icon, Outline icon, Wide (long), Image.

- **Filled** — highest emphasis, primary/final action (Save, Confirm, Download). Solid container.
- **Outline** — medium emphasis, secondary action, pairs with filled. Stroke, fills solid on focus.
- **Icon / Outline icon** — compact, for open-actions (search, overflow) or toggles (favorite, play/pause). Sizes: small/medium/large.
- **Wide (long)** — higher-emphasis grouped actions, container + leading icon + title + subtitle.
- **Image** — thumbnail-style nav button, image layer = scrim + gradient (from surface color) + image, plus icon/title/subtitle.

States: Default, Focused, Pressed (scale ~1.1x on focus, padding preserved).

Rules:
- Container: text/icon buttons fully rounded; wide/image buttons 12dp rounded corners. Width responsive to content, icon/label stay centered as width grows.
- Icon: leading side only, vertically centered. Never 2 icons per button, never center-align icon+text together.
- Label: sentence case (first word + proper nouns only), single line, no wrap. Use a scrim behind outline buttons placed on images for legibility.
- Groups: first button in a row/column = primary action (gets initial focus). Row layout can mix variants if hierarchy stays clear; column layout should use one variant only. Don't mix long + image buttons in one group.
- Don't overuse buttons — too many disrupts visual hierarchy.

## Cards

5 variants: Standard, Classic, Compact, Wide standard, Wide classic. One topic per card — never merge/split cards.

Content blocks (in order): Title, Subtitle, Description, Extra text.

Aspect ratios:
- **16:9** — default, images/video (e.g. movie cards).
- **1:1** — balanced/square (cast & crew, team/channel logos).
- **2:3** — taller, breaks grid rhythm, extra emphasis (e.g. books).

Card widths by row density (peaking spacing 20dp): 1-card 844dp, 2-card 412dp, 3-card 268dp, 4-card 196dp, 5-card 124dp.

Rules:
- Content block width = image thumbnail width; use Wide variant if more text needed.
- Wide cards: only short (few-word) descriptions — avoid long text on vertically stacked cards.
- Compact cards: keep title/subtitle/description brief; always add a semi-transparent black gradient scrim over the background image for text legibility.

## Immersive list

Row of content + large preview pane of the currently focused item (progressive disclosure).

Anatomy: Image background (cinematic scrim + poster + background color) → Content block → Card on focus → Content grid.

Behavior: navigating the row updates the preview immediately; focusing the immersive list expands its height to reveal title/description.

Rules:
- Focused card: scale 1.1x + border/elevation, thumbnail title stays legible.
- Background image: high-quality, 16:9 where possible.
- Composition: scale/align subject to top-right for cinematic feel — don't full-screen-crop the subject under content.
- Use for featured/promoted content (new releases, exclusives), not routine browsing.

## Navigation drawer

TV drawer shows both expanded and collapsed states (unlike mobile, which hides collapsed items). Two variants:

- **Standard** — expands and pushes page content aside.
- **Modal** — overlays content with a scrim (gradient or solid) behind it for readability.

Anatomy: Top section (logo/profile/search) → Navigation item (icon + label, icon-only when collapsed) → Navigation rail (3–7 destinations) → Bottom section (1–3 actions: settings/help/profile).

Rules:
- Order destinations by importance; group related ones.
- Always show a navigation rail when collapsed (both variants).
- Active indicator: distinct background shape on current destination.
- Dividers: optional, use sparingly (visual noise).
- Badges: optional (e.g. "N new"), use sparingly.
- Labels: short, single line; truncate with ellipsis only if unavoidable — never wrap.
- Never mix icon-only items with text-only items in the same drawer; never omit icons entirely.
- Limit to 5–6 primary destinations — more forces vertical scroll and hurts navigation.

## Featured carousel

Showcases curated/personalized content, typically homepage. Two variants: **Immersive** (full background image) and **Card** (bounded card background).

Anatomy: Image background (cinematic scrim + poster + background/card color) → Content block (overline, title, description, button) → Pagination (background + active/inactive/total elements) → Content grid.

Rules:
- Background images: high-resolution, relevant, no embedded text.
- Always scrim the image so title/description/CTA stay legible and visual hierarchy stays on the content block, not the art.

## Lists

Vertical, single-column, scannable groups of text/images. Not buttons — no container by default, no forced selection/focus state.

Variants: One-line, Two-line, Three-line (increasing prominence/decoration).

Anatomy: Icon (optional) → Overline (optional context) → Title → Subtitle → Control (checkbox / radio / switch).

Selection controls: Checkbox (multi-select), Radio (single-select), Switch (on/off toggle).

Rules:
- Use container background only when necessary — default list items are containerless.
- Show a selection indicator (icon), never rely on background color alone to signal selection.
- Never put a full button inside a list item — ambiguous focus target.
- Omit icons when all items are the same content type (reduces noise); never reuse the identical icon across every item.
- Avatars/images in lists: circular crop for person/entity representation.

## Tabs

Peer-level categories of equal importance, horizontally scrollable, unlimited count.

Two indicator styles:
- **Pill** — full-page-level primary destinations.
- **Bar (underline)** — sub-navigation within a content area, secondary hierarchy.

Anatomy: Icon (optional) → Label → Active indicator (pill or bar) → Container.

States: Default, Focused, Selected.

Behavior: switching tabs slides underlying content left/right in the direction of tab movement.
