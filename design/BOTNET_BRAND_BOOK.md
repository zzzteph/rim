# RIM Botnet — Design System & Brand Book

*The prototype is `scripts/botnet_proto.tscn` + `scripts/botnet_proto.gd`, with its numbers in
`scripts/botnet_cfg/*.gd` and its theme in `assets/ui_theme.tres`. This book is the single reference for how
every graphical element looks: the font and font size of each piece, the colours, the exact sizes, how it
behaves from a 1366-wide laptop to a 4K monitor, and how to wire new things in without hunting through code.*

**Source of truth.** The game draws almost everything procedurally in code — there are no sprite or icon image
files. So the real values live in the script, and this book mirrors them. Where a number here and the code ever
disagree, the code wins; fix the book. Every size below is a **design pixel (dp)**: a pixel at the 1280×720
reference canvas. On screen they are multiplied by the scale factor in §2.

**Visual key:** `design/brand_book/design_system_key.png` is a one-glance sheet of the palette, the resource /
building / card glyphs and the type ladder — rendered straight from the game's own colours and draw functions,
so it can never drift from the real UI. The live components are in `review/botnet_v2_2026-10-11/gallery/`.

---

## 1. Brand in one minute

A dark, calm, neon-on-slate **cyberpunk console**. One readable sans serif, never more than a handful of sizes.
A disciplined five-colour text palette (one meaning per colour) over a near-black field, with three sets of
*signal* colours that carry meaning on top of it: **faction** colours mark who owns a thing, **card-family**
neons mark which attack a card belongs to, and **resource** colours mark the four economies. Thin 1 dp strokes,
4 dp rounded corners, teal edges. Buildings are their own pictograms, not generic dots. Nothing shouts unless it
needs the player: an amber word, a red ring.

Tone: competent, quiet, a little clinical — a network operations console, not an arcade. Text is lower-case and
plain; headings are short uppercase kickers. The screen should read at a glance and reward a second look.

---

## 2. Canvas, resolution & scaling (1366 → 4K)

**Reference canvas: 1280 × 720.** Every size in this book is in those design pixels.

**Project settings** (`project.godot`): `window/stretch/mode = "canvas_items"`, `window/stretch/aspect =
"expand"`, renderer `gl_compatibility`, base viewport `1280 × 720`, default clear colour `#0D0F17`.

Because the stretch mode is **canvas_items**, Godot re-rasterises the UI and all vector/text drawing at the
window's real pixel density, then fits the 1280×720 design to the window. Nothing is a stretched bitmap, so text
and glyphs are **crisp at every resolution** — a 4K screen draws sharp glyphs, not a blown-up 720p image.

Because the aspect is **expand**, the layout does not letterbox. The script reads `get_viewport_rect().size`
(called `sz` throughout) and lays out against it, so extra width or height becomes more *game*, not stretched
chrome. Measured behaviour (verified by rendering the scene at each size):

| Window | Aspect | `sz` the layout sees | Result |
|---|---|---|---|
| 1366 × 768 | 16:9 | 1280 × 720 | base layout, scaled ≈ 1.07× |
| 1600 × 900 | 16:9 | 1280 × 720 | base layout, scaled 1.25× |
| 1920 × 1080 | 16:9 | 1280 × 720 | base layout, scaled 1.50× |
| 2560 × 1440 | 16:9 | 1280 × 720 | base layout, scaled 2.00× |
| 3840 × 2160 | 16:9 | 1280 × 720 | base layout, scaled 3.00× |
| 2560 × 1080 | 21:9 | 1706 × 720 | **wider map**, panel still 440 dp pinned right |
| 1920 × 1200 | 16:10 | 1280 × 800 | **taller map and panel** |

**The rule of thumb.** On any 16:9 display the layout is identical and the whole thing scales by
`scale = window_height / 720`. On wider-than-16:9 the map column grows (`sz.x` rises, the right panel stays 440 dp
and stays pinned to the right edge). On taller-than-16:9 the map and panel grow downward (`sz.y` rises).

**Minimum size.** The layout assumes `sz.x ≥ 1280` and `sz.y ≥ 720`. The smallest target, 1366×768, is 16:9 so
it renders at exactly 1280×720 and scales up — it never falls below the floor. A window dragged smaller than
1280×720 would start to crowd the 440 dp panel. **Recommended:** set `get_window().min_size =
Vector2i(1280, 720)` in `_ready()` so that cannot happen.

**HiDPI / 4K.** No work and no second asset set are needed: all art is vector or procedural, and canvas_items
re-rasterises at native density. The trade-off of uniform scaling is that 4K shows the *same amount* of map as
1080p, just larger and sharper — it does not pack in more. That is the right default for readability. If you
later want a user "UI scale" slider, drive `get_window().content_scale_factor` (1.0 = this book; 1.25 / 1.5 for
larger UI) — every dp below scales with it automatically.

**If you ever allow live window-aspect changes mid-match,** rebuild the HUD and panel rectangles on
`NOTIFICATION_WM_SIZE_CHANGED` (they are positioned once in `_ready()` from `sz`). Today the window is maximised
and its aspect is stable, so this is not wired.

---

## 3. Typography

**One typeface, system-served** (`assets/ui_theme.tres`). A `SystemFont` with the fallback chain:

```
Segoe UI  →  Noto Sans  →  DejaVu Sans  →  Arial
```

A humanist sans that is on every target OS. Antialiasing on, hinting light, subpixel positioning on. A **bold
(weight 700)** cut of the same family is registered as `Fonts/fonts/bold` for the rare emphasis. There is no
second family — do not add one. The console's character comes from colour and layout, not type mixing.

**The size scale.** Keep to this ladder; do not invent in-between sizes.

| Role | Size (dp) | Weight | Where |
|---|---|---|---|
| Result banner | 46 | regular | "VICTORY" / "DEFEATED" end overlay |
| Map hero (rare) | 30 | regular | reserved large map callout |
| Panel title | 18 | regular | the one H1 per panel state (building name, screen title) |
| Body / button | 16 | regular | theme default; button labels; primary panel lines |
| Secondary body | 14 | regular | `_plabel` default; map target labels; help lines |
| Map label | 13 | regular | the status line under a hovered target |
| Small / caption | 12 | regular | small buttons (`_btn_row` ... 12), queue rows, tooltips-in-text |
| Micro / kicker | 11 | regular | `_kicker` uppercase labels, building name + value marks, strength badge, footers |
| Floor | 9–10 | regular | card cost figures, card type line, in-glyph marks (never smaller than 9) |

Reading the ladder: the **panel** is disciplined to roughly five steps — 18 title, 16 button/body, 14 body,
12 small, 11 kicker. The **map canvas** uses 11–14 for labels and badges, and only the end overlay reaches 30/46.
Theme defaults: `default_font_size = 16`; `Label` and `Button` both 16.

**Casing & voice.** Kickers are UPPERCASE (`_kicker` upper-cases for you). Everything else is sentence or
lower case. Numbers are plain (`30/30 bots`, `2/3 slots`, `≈14 s`). Units are spaced and lower-case (`s`, `%`,
`/s`). The clock is `M:SS`.

---

## 4. Colour

The field is near-black `#0D0F17`. On it sit four colour systems, each with one job. **Never reuse a colour
across systems** — that is the whole discipline.

### 4.1 Text palette — one meaning per colour (`C_*` in the script)

| Token | RGB | Hex | Meaning — use it only for this |
|---|---|---|---|
| `C_TEXT` | 0.88, 0.92, 1.00 | `#E0EBFF` | **facts** — ordinary readable text |
| `C_DIM` | 0.60, 0.68, 0.80 | `#99ADCC` | **secondary** — labels, kickers, the quiet clock |
| `C_WARN` | 1.00, 0.84, 0.45 | `#FFD673` | **needs you** — a warning, a thing to act on |
| `C_GOOD` | 0.60, 0.95, 0.75 | `#99F2BF` | **going your way** — you are ahead, a success, your own hold-to-win countdown |
| `C_BAD` | 1.00, 0.55, 0.50 | `#FF8C80` | **hostile or lost** — damage, a failed state |

Five colours carry every piece of text meaning. If a new line needs a colour, it is one of these five by what
it *means*, not by taste.

### 4.2 Faction colours — who owns it (`FACTIONS` in `botnet_cfg/factions.gd`)

| Faction | RGB | Hex | Read as |
|---|---|---|---|
| City security (neutral, 0) | 0.35, 0.45, 0.60 | `#597399` | steel grey-blue — unowned |
| You (1) | 0.25, 0.85, 0.45 | `#40D973` | green — yours |
| NYX (2) | 0.85, 0.30, 0.33 | `#D94C54` | red — rival A |
| KRAKEN (3) | 0.70, 0.40, 0.95 | `#B266F2` | violet — rival B |

A building's pictogram is filled in its owner's colour; its routes are coloured by the **source** faction;
the BOARD tab's rows use these (the HUD shows only you). These four are owner-identity only — do not use them
for text meaning or card families.

### 4.3 Card-family neon — which attack (`FAMILY_COL` in `botnet_cfg/cards.gd`)

| Family | RGB | Hex | Feel |
|---|---|---|---|
| Credential (`cred`) | 1.00, 0.72, 0.20 | `#FFB833` | amber |
| Phishing (`phish`) | 0.30, 0.90, 1.00 | `#4CE6FF` | cyan |
| 1-day exploit (`oneday`) | 0.72, 1.00, 0.25 | `#B8FF40` | acid green |
| 0-day exploit (`zeroday`) | 1.00, 0.45, 0.20 | `#FF7333` | hot orange |
| Supply-chain (`supply`) | 1.00, 0.38, 0.75 | `#FF61BF` | magenta |
| Denial of service (`dos`) | 0.68, 0.55, 1.00 | `#AD8CFF` | periwinkle |

A family's neon is the card's border, cost-bar wash, glyph and type line; a supply-chain steal frame
on the map uses the supply magenta. These six are the card system's own identity — keep them distinct from
faction and resource colours.

### 4.4 Resource / build-kind colours (`BUILD_KINDS` in `botnet_cfg/buildings.gd`)

| Resource / kind | RGB | Hex | Icon |
|---|---|---|---|
| Cash (Darknet market) | 1.00, 0.85, 0.30 | `#FFD94C` | coin |
| Credentials (Credential harvester) | 1.00, 0.60, 0.45 | `#FF9973` | key |
| Research (Research lab) | 0.75, 0.55, 1.00 | `#BF8CFF` | flask |
| Intel (Intel harvester) | 0.40, 0.85, 1.00 | `#66D9FF` | eye |
| Bots (Bot farm) | 0.45, 0.95, 0.60 | `#73F299` | bot/chip |

Each resource keeps its colour everywhere it appears: the HUD readout, the research tab, each card's cost bar,
and the build cards inside a building.

### 4.5 Surfaces, edges & buttons (`assets/ui_theme.tres`)

| Surface | Fill | Border | Notes |
|---|---|---|---|
| App background | `#0D0F17` | — | the default clear colour |
| Panel / PanelContainer | `#0D0F17` | teal `#33FFE6` @ 45% | 1 dp border, 4 dp corners, 14/12 dp content margins |
| Card body | `#1A1C26` | family neon @ 80–100% | chamfered top-right corner |
| Card art window | `#0D0F17` | family neon @ 50% | neon scan-lines @ 6% |
| Button — normal | `#171F2B` | teal @ 40% | 14/7 dp margins, 4 dp corners |
| Button — hover | `#213040` | teal `#4CFFF2` @ 90% | |
| Button — pressed | `#29666B` | teal @ 100% | the one filled-teal state |
| Button — disabled | `#0F121A` | grey @ 35% | font `#6B7890` |
| Button font | `#DBF2FF` | — | hover/pressed → white |

Teal (`#33FFE6` and its brighter kin) is the **interface accent**: panel and button edges, the downtown HUB, and
focus highlights. It is never an owner or a card colour.

### 4.6 Alpha conventions

Opacity is meaning, not decoration. Fogged / unknown ≈ 0.4. Dormant (a wire not yet fired, a disabled card)
≈ 0.4. Scan-lines and wash fills 0.06–0.25. Active strokes 0.8–1.0. A hovered card lifts its border from 0.8 to
1.0; a hovered/active building gets a brighter frame.

---

## 5. Spacing & layout

The screen is two columns: the **map** on the left, a fixed **panel** on the right, with the **HUD** as a strip
across the top-left.

| Region | Geometry (dp) |
|---|---|
| Right panel width | `PANEL_W = 440` |
| Panel rect | position `(sz.x − 452, 12)`, size `(440, sz.y − 24)` |
| Panel content margins | 14 left/right, 12 top/bottom (theme) |
| Panel scroll inset | `(14, 12)`, size `panel − (28, 24)` |
| HUD bar | position `(24, 10)`, height 32, width `sz.x − PANEL_W − 60`, **clipped** to that width |
| Map area | origin `(60, 100)`, width `sz.x − PANEL_W − 130`, height `sz.y − 204` |
| Row separation (panel) | 10 dp typical; button rows 30 dp tall; section pad 44 dp |
| Corner radius | 4 dp everywhere |
| Stroke weight | 1 dp (frames, borders), up to 2–2.5 dp for active/hover |

All of these are derived from `sz`, so they reflow with the window per §2. The map area is whatever is left of
the panel, with a 60 dp left gutter, a 100 dp top band (for the HUD and breathing room) and a 104 dp bottom band
(for the flash line).

---

## 6. Components

Each entry gives the element's size, font and colour. All sizes in dp.

### 6.1 HUD bar

One line, top-left, mouse-transparent, **clipped** to its width so it can never bleed under the panel, and
**about you only** — rivals live in the BOARD tab. Every item owns a **fixed column**, so a number growing from
9 to 10 or 99 to 100 never shifts anything to its right. An item with an icon draws the icon (16 dp) then a
22 dp step, then its text at **15 dp**. Columns, left→right:

| Column | Width (dp) | Content | Colour |
|---|---|---|---|
| Time | 150 | elapsed match time `⏱ M:SS` (there is no time limit). While **you** hold a majority this slot becomes your own countdown `⏳ you 12/45s`; a rival's hold shows only on the BOARD tab | `C_DIM`; your countdown `C_GOOD` |
| You | 150 | `you N% · held/needed` — your control %, your buildings against the majority line | `C_TEXT`; `C_GOOD` once you hold more than half |
| Intel | 150 | `◎ Intel/cap`, with `−N/s` while an attack drains it | `C_TEXT`; `C_WARN` while draining |
| Cash | 90 | `$ Cash` | `C_TEXT` |
| Credentials | 110 | `key Creds/cap` | `C_TEXT` |
| Research | 110 | `flask Research/cap` | `C_TEXT` |

Total 760 dp inside the 780 dp bar at the 1280 reference.

### 6.2 Right panel

A `Panel` styled per §4.5 with a `ScrollContainer`. Three tabs sit at its top as a button row — **🗺 MAP**
(context: the selected building, a target, the idle help), **🧪 RESEARCH · n** (cards; key R) and **🏆 BOARD**
(the leaderboard; key L); the active tab is the disabled button. The scroll position is **kept across the
panel's periodic refresh** and **reset to the top on a tab switch**, so the view never jumps under the reader.
Every panel *state* leads with one 18 dp title (or an uppercase `SELECTED` / section kicker at 11 dp) and its
primary 32 dp button, then quieter lines. Helpers:

- `_kicker(text)` — 11 dp uppercase `C_DIM` label above a group.
- `_plabel(text, size=14, col=C_TEXT)` — a wrapping body label, min-width `PANEL_W − 64`.
- `_lbl(parent, text, size, col, minw)` — a wrapping label with explicit size/colour.
- `_btn(text, cb, enabled, parent, tip, height=32)` — a primary button; rules text rides in its tooltip.
- `_btn_row([...])` — buttons side by side; small buttons set font 12 and 24–30 dp height.

### 6.3 Map — buildings

A building is **its own pictogram**, drawn at its node, filled in the owner's colour, not a generic dot.

| Part | Spec |
|---|---|
| Node radius | `r = 11 + 2.5 × slots` dp → 1-slot 13.5, 3-slot 18.5, 5-slot (ERP) 23.5 |
| Pictogram | the type glyph (§7), filled in the owner faction colour |
| Name + value | centred above the node at **11 dp**: name in `#D9EBFF` (yours slightly green), then the value marks `$`/`$$`/`$$$` in amber `#E6CC66` @ 75% |
| Strength badge | below the node, bots count in an `#081014` @ 88% pill at **11 dp** `#F2F7FF`; `?` until scanned, `≈N` from memory |
| One warning word | under the glyph, most-urgent-first: `junction` · `CRITICAL` · `SHAKY` · `FULL ↩` (only when true) |
| Selection frame | square, `r + 6`, white @ 95% |
| Inspect frame | `r + 8`, gold `#FFE64D` |
| Aim (drag target) frame | `r + 9`, gold, 2 dp |
| Steal frame | `r + 7.5`, supply magenta, 1.5 dp |
| Threat ring | red ring when under attack (shows through fog at reduced size) |

The **value marks are a worth tier, not money** (`$` = tier 1 poor rim, `$$` = 2 mid, `$$$` = 3 rich downtown);
they drive Cash-per-packet, starting defenders and the type mix. They are amber to tie to the Cash economy but
sit above the building, apart from the HUD's Cash readout.

### 6.4 Map — streets, wires & selection

| Element | Spec |
|---|---|
| Street (link) | thin slate line between linked buildings |
| Highway | a wide pale street bridging a gap (nothing to cross) |
| Junction street | a street touching a junction carries double traffic (drawn heavier) |
| Busy link | tinted amber while at capacity this tick |
| Dormant wire | a **dashed** line in the source faction's colour — a plan that never fires until launched |
| Rubber band (dragging) | 1.8 dp line + 3 dp dot; gold `#FFF28C` when a path exists, red `#FF664C` when none |
| Selection box | fill teal @ 8%, border teal @ 60% 1 dp |
| Route colour | by **source** faction; attack = arrow, defence = diamond; your bots = circles, others = squares |

### 6.5 Map — packets in flight

Bots and Cash travel as small moving marks along the streets. A **card** travels as a glowing card icon with its
path dashed ahead of it, from the nearest connected building, landing on arrival. Own packets are drawn as ~3.5 dp circles in `#80FFB3`; a card-in-flight carries its family
neon.

### 6.6 Cards

A Magic-style face. Two sizes share one layout, scaled by `k = width / 190`:

| Variant | Size (dp) | Used in |
|---|---|---|
| Big | 190 × 262 | the research catalogue |
| Hand | 124 × 174 | your hand (research tab and a target's panel) |
| Drag preview | 96 × 134 | the card under the cursor while dragging |

Anatomy (positions × k):

| Part | Spec |
|---|---|
| Body | `#1A1C26`, top-right **chamfer** 12·k; outline = family neon (0.8, →1.0 on hover) |
| Title bar | family neon @ 20%, 26·k tall; title at 13·k dp white |
| Art window | inset 8·k, 100·k tall; `#0D0F17` fill, neon scan-lines @ 6%, neon frame @ 50% |
| Family glyph | centred in the art, ~0.8 of its height, in family neon (§7) |
| Type line | `Single host — Credential Attacks` / `Worm — …`, 10·k dp, family neon @ 95% |
| Rules text | 11·k dp `#EBF2FF`, up to 3 lines, under a 1 dp neon rule |
| Flavour / note | big cards only, or the per-target effect note in `C_WARN` |
| Cost bar | bottom 22·k, neon @ 14% wash; coin/key/flask icons + figures at 10·k `#FFF2CC`, then `N s` time |
| Chain marker | three linked dots by the title, on worm cards only |
| Count badge | `×N` top-right when holding copies |

The six families each have a single card and a worm; see `BOTNET_ATTACK_DESIGN.md` for their numbers.

### 6.7 Slot board (in the panel) & type badge

Selecting a building you own opens its slots **right in the panel** — there is no separate inside view and no
connect delay; the map stays commandable. A `SlotBox` is 76 × 90 dp (`+` when empty, the build glyph when
filled; a slot being worked is offline and shows its progress bar). Draggable build cards are ~72 × 94 dp with
a 48 dp icon; a build costs `BUILD_COST_INTEL` and several jobs may run at once, each listed as a 12 dp row
with its own `✖` cancel. A `TypeBadge` (42 dp tall) shows the building's picture, name (13 dp) and one-line
description (11 dp `#B3CCE6`).

### 6.8 End overlay & flash line

On a win/loss, a dim scrim over the map and **"VICTORY"** (teal `#80FFFF`) or **"DEFEATED"** (`#FF8080`) at
46 dp, with the cause and elapsed time beneath. The transient **flash message** wraps inside the map area (never
under the panel) at 15 dp, fading via alpha.

### 6.9 Leaderboard (BOARD tab)

One 18 dp title, a 12 dp `C_DIM` line stating the majority line ("Hold more than 15 of 31 buildings for 45 s"),
then one 15 dp row per botnet ranked by buildings held — `1.  NYX — 12 buildings · 38 %  ·  majority` — in the
faction colour (you in `C_GOOD`; a botnet with nothing left in `C_DIM`, marked "out"). Under your own row a
12 dp `C_DIM` line gives your bots, cards played and Cash; under a rival's only its cards played — their bots
and resources stay under the fog. A holder of the majority shows its countdown here as well.

---

## 7. Iconography — all procedural

There are **no icon image files**. Every glyph is drawn in code so it inherits colour, scales to any size and
never blurs. Three families of glyphs, each a `match` on a string key:

- **`_draw_kind_icon(canvas, kind, centre, size, colour, font)`** — the five resource/build marks: `cash` coin,
  `cred` key, `lab` flask, `intel` eye, `bot` chip. Used in the HUD, the research tab, card cost bars and build
  cards.
- **`_draw_type_glyph(canvas, type, centre, size, ink, back)`** — the seven building pictograms: PC, IoT,
  Server, Web, Database, File server, ERP. Used on the map (the building *is* the glyph) and in the type badge.
- **`_draw_card_glyph(canvas, card, centre, size, colour, font)`** — the six family emblems: credential (open
  lock), phishing (hook/envelope), 1-day & 0-day (bug/shard), supply-chain (package/cert), DoS (flood arrows).
  Used on card art.

Glyph rules: draw inside a unit box scaled by `size`, stroke/fill in the passed colour, keep any in-glyph detail
≥ 9 dp, no text baked into a glyph except single marks. A glyph should read at the 16 dp HUD size and at the
80 dp card-art size without change.

---

## 8. Motion & state

Motion is subtle and functional. Packets slide along streets at the simulation's pace; a card-in-flight glows
and dashes its path. A building under attack shows a red ring; a guard arms (brightens) while its building is
hit or below full, and stands down after. Selection/inspect/aim frames appear instantly. The flash line fades by
alpha. Hover lifts a card's border and a building's frame. No easing curves are specified — keep motion linear
and short; readability over flourish.

---

## 9. Extensibility — wiring new things

The game is deliberately **config-first**: the tables live in `scripts/botnet_cfg/*.gd` and the script reads
them through aliases, so most new content is a data edit plus, at most, one procedural glyph. A changed value
needs the scene restarted (constants load when the script loads). Recipes, cheapest first:

**Add a card to an existing family** — *data only.*
1. Add an entry to `CARDS` in `cards.gd` (`name`, `fam`, `chain`, `effect`, `power`, `dur`, `cost`, `time`,
   `rules`, `flavor`).
2. Add its key to `CARD_ORDER`.
Reuse an existing `effect` (`defenders` / `breach` / `steal` / `deny`) and family and nothing else is needed.

**Add a whole card family** — *data + one glyph.*
1. In `cards.gd`: the single and worm entries in `CARDS`, their keys in `CARD_ORDER`, a `FAMILY_NAME` entry and
   a distinct `FAMILY_COL` neon (pick one not already in §4.3).
2. In `types.gd`: add the new family key to the `RESIST` row of **each** of the seven building types (how each
   resists or folds to it).
3. In `botnet_proto.gd`: add a `match` case in `_draw_card_glyph` for the family emblem. *(This is the only code
   touch-point.)*
4. Optional: teach the AI to use it by adding its keys in the card-use blocks of `_ai_think`.

**Add a new effect** — *code.*
1. Handle it in `_apply_effect` (what it does on landing) and describe it in `_effect_text` (the hover preview),
   plus any map indicator (as the steal frame and DoS do).
2. Set a card's `effect` field to the new name in `cards.gd`.

**Add a building type** — *data + one glyph.*
1. In `types.gd`: a `NODE_TYPES` entry (`name`, `short`, `slots`, the five production multipliers, `sec`,
   `desc`), its spawn weights per district in `TYPE_WEIGHTS`, and a `RESIST` row for all six families.
2. In `botnet_proto.gd`: a `match` case in `_draw_type_glyph` for its pictogram.

**Add a resource / building kind** — *data + several code points (the heaviest).*
1. In `buildings.gd`: a `BUILD_KINDS` entry (`name`, `card`, `short`, `col`, `desc`).
2. In `botnet_proto.gd`: a production path (model it on `_cash_rate` / `_research_rate`), a cap function, a HUD
   item in `_hud_items`, a `_draw_kind_icon` case, and the per-tick credit in `_process`.

**Add a faction** — *data + engine touch-points.* A `FACTIONS` entry and an AI profile, plus the places that
assume three botnets (`BOTNETS` / `AIS` and the HUD's three control readouts). Expect code, not just data.

**The seams to keep clean.** The three glyph dispatchers (`_draw_kind_icon`, `_draw_type_glyph`,
`_draw_card_glyph`) and the two effect dispatchers (`_apply_effect`, `_effect_text`) are the only places code
must grow when content grows. Everything else is a table. If the catalogue of families or types ever gets large,
turn those `match` statements into a small registry so new content is pure data — until then, the dispatchers
are short and a new case is a two-minute edit.

---

## 10. Where the numbers live

| File | Holds |
|---|---|
| `scripts/botnet_cfg/factions.gd` | the four factions and their colours; AI speed, cash handicap, reaction and personality knobs |
| `scripts/botnet_cfg/town.gd` | grid size, street density, jitter, highways, junctions |
| `scripts/botnet_cfg/types.gd` | the seven building types, their district spawn weights, the family `RESIST` table |
| `scripts/botnet_cfg/buildings.gd` | the five build kinds (bot / intel / cash / cred / lab), their colours and effects; build and demolish times; `BUILD_COST_INTEL` |
| `scripts/botnet_cfg/cards.gd` | the twelve cards, the six families and their neons, worm fall-off, steal duration |
| `scripts/botnet_cfg/tuning.gd` | node cap, regen, combat (A = D), link time/capacity, the scan cost, `RIG_INTEL`, control stages, the win (`HOLD_FRACTION`, `HOLD_SECS`) |
| `assets/ui_theme.tres` | the font, the type sizes, the panel and button styles |
| `scripts/botnet_proto.gd` | the palette constants (`C_*`, `PANEL_W`), all drawing, and the glyph/effect dispatchers |

*Companion docs: `BOTNET_ATTACK_DESIGN.md` (mechanics, economics, card values, the AI) and the rendered
reference in `review/botnet_v2_2026-10-11/` (`gallery/` — 49 scripted states; `all_cards.png` — every card
face). This book covers how it all looks and how to extend it.*
