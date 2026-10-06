# RIM — City Map Generation

How the cyberpunk city map is generated and drawn. `scripts/city.gd` (`scenes/city.tscn`), reached
from the menu's **New Game**. Presentation foundation; gameplay layers on later. Aesthetic:
SimCity/Constructor layout, Johnny-Mnemonic neon-noir. Deterministic from `Session.seed`; size from
`Session.city_size`. The city is **composed**: terrain → an explicit road network → a district plan
that reserves complete sites → parcels → coordinated architecture.

---

## 0. Generation algorithm (`_generate`)

**Determinism.** Two RNG sources, both derived from `Session.seed`, so *same seed + size ⇒
byte-identical map* (asserted by CK1):
- `rng` — a seeded `RandomNumberGenerator` for sequential random choices (where a line sits, which
  building goes on a tile, tree jitter).
- `_noise(x, y)` — a stateless integer hash of `(x, y, seed)` → `[-1, 1)`. Used wherever a value must
  be a **repeatable function of position** rather than of call order: the land edge, residential
  density, and the countryside patch type. (It's a hash, not Perlin — cheap and order-independent.)

**State** (fields on the node; all keyed by `Vector2i` tile unless noted):

| field | kind | holds |
|---|---|---|
| `land`, `water`, `roads` | set | which tiles are developed land / water / road |
| `road_class[t]` | map | `"art"` (arterial) or `"loc"` (local) |
| `deco[t]` | map | ground dressing: `park/garden/court/plaza/parking/path/prom` |
| `lots[k]` | map | one building, keyed by its **origin** tile `k`: `{kind, dtype, tier, h, tw, td, ins, vari, area, did}` |
| `occ[t]` | map | which lot origin owns tile `t` (so multi-tile footprints and hit-tests resolve) |
| `trees[]`, `districts[]` | array | scattered trees; merged named districts |
| `country[t]` | map | `forest/field/meadow` for undeveloped tiles |

**Pipeline** — each pass consumes the previous; order is load-bearing:

1. **Water** `_carve_water` *(first, so land forms around it)* — a 1-tile sine-meander river down the
   map, `x = base + amp·sin(y·freq + φ)` (`base ≈ 0.36–0.62·width`); plus one small round lake with
   40% probability. Restrained on purpose so it never fragments the city. `disable_water` skips it.
2. **Development centre** — `dev_c = grid · (0.5 ± rand 0.12)`, deliberately **off-centre** so the
   footprint is asymmetric.
3. **Land** `_build_land` — a lobed radial mask around `dev_c`:
   `r(θ) = rbase·(1 + 0.16 sin3θ + 0.1 sin5θ + 0.06 sin7θ) + _noise·rbase·0.07`, `rbase ≈ 0.82·min(dim)`.
   A tile becomes land iff `|t − dev_c| < r(θ)`, it is **not on the border**, and it is not water ⇒ one
   ~80%-coverage connected landmass with a gently irregular edge; the clear border guarantees no
   perimeter road can ever form.
4. **Roads** `_build_roads` *(explicit network, not a grid — see §2)* — choose line positions with
   `_road_lines` (spacing widens 4→9 outward); the line nearest each axis-centre is an **arterial**.
   Lay each line tile-by-tile, local lines **meandering** (slew-limited sine, rasterised 4-connected),
   clipped to land — arterials may bridge water. Then add arterial **leaving-spurs** to the edge and
   `_add_organic_lanes` (random lanes that `_grow_lane` turns/branches/dead-ends). Finally **prune**
   any water-road with <2 connections. Returns the downtown centre `down_c`.
5. **Blocks** `_carve_blocks` — flood-fill the 4-connected components of `land − roads`; each → a
   `{tiles, centroid}` parcel. These are the buildable sites.
6. **District plan + fill** `_plan_and_fill` *(see §4)* — sort blocks by distance to `dev_c`; reserve
   roles (downtown core → satellite business `n_biz` → shopping → parks → residential, tier from
   distance-to-downtown + `_noise`); **one-tier smooth** residential tiers across `_block_adjacency`
   (two blocks adjacent if a single road tile separates them); merge connected same-type blocks into
   named `districts` (`_assign_districts`); then **fill** each block (`_fill_downtown/_shopping/_park/
   _residential`) placing buildings via `_place`, which validates the footprint (on land, not
   road/water/occupied) before writing `lots` + `occ`. Dry land beside water becomes `prom`.
7. **Countryside** `_dress_countryside` — every still-undeveloped tile is classified by coarse
   `_noise` (~3-tile patches) into forest / field / meadow and populated (dense wild trees / furrows).
8. **Bounds + draw order** — compute `_world` (the iso bounding box for framing); `_build_draw_order`
   flattens `lots` + `trees` into `_draw_items` and **sorts once** by iso depth (`k.x+k.y+tw+td` for
   buildings, `tile.x+tile.y` for trees) so `_draw` never sorts or allocates per frame (see §5a).

Rendering (§5a) and interactivity (§7) run on this immutable result; nothing below regenerates it.

---

## 1. Space & footprint

True 2:1 isometric (`_iso(fx,fy) = ((fx-fy)·32, (fx+fy)·16)`), tile `64×32 px`. Grid presets
(`_grid_dims`): small `18×15`, medium `27×22`, large `38×30` tiles (menu labels match).

The grid is only the **storage** bounds. A **development mask** (`_build_land`) gives the city a
**substantial, continuous footprint** — a large radius (~0.82·min-dim) with *gentle* lobes so the
city stays one connected landmass (~80% of the map) with a lightly irregular edge. Everything
beyond, kept off the border, is a **countryside margin** (`_dress_countryside`): coherent
**forest / field / meadow** patches with dense trees and ploughed furrows. **Water is restrained and
added last** (a slim 1-tile meandering river, occasional small lake) so it threads through the city
without fragmenting it. `disable_water = true` (set before `_ready`) generates the pure-land
structure for inspection.

## 2. Explicit road network (no `tile/P` grid, no perimeter)

`_build_roads` lays an explicit network, not a periodic grid:
- **Varied spacing**: road lines at intervals that widen outward — ~4 tiles near the centre up to ~9
  (big blocks) at the rim — so block sizes vary by neighbourhood.
- **Meandering local streets**: every non-arterial line follows a per-line sine wiggle (slew-limited
  to ≤1 tile/row and rasterised with a connector so it stays 4-connected), so blocks — and the
  districts built from them — have **curvy, organic edges** instead of a rectilinear grid. Arterials
  stay straight for legibility.
- Roads are placed only on **land**; the central-most line each axis is an **arterial** (neon
  avenue). Arterials may cross **water as bridges** (limited crossings); local roads stop at the
  bank. A few **cul-de-sac** stubs and short **leaving spurs** add branches and city exits.
- Development stays off the map border, so **there is no automatic perimeter road**.

**Blocks** are the connected components of `land − roads` (`_carve_blocks`) → varied sizes/shapes,
each a complete site. Block adjacency is computed across the single separating road tile.

## 3. Connection-aware road tiles

Each road tile is drawn from its actual connections (`_road_dirs`, `_draw_road_tile`): the centre
line is drawn only toward directions that connect, so **straight stretches read as straight**, and
**crossroads markings appear only at real intersections** — plus bends, T-junctions and **endpoint
nodes** at dead-ends. Arterials use neon centre lines, local streets a dim marking; **curbs** outline
edges facing a parcel; bridges draw a raised deck over the water.

## 4. District plan — reserved sites

`_plan_and_fill` sorts blocks by distance to the development centre, then reserves (scaled to size):
**downtown** (central blocks → a tower cluster with a public square) plus **satellite business
districts** (`n_biz` corporate clusters out in the inner-mid ring, spaced from the core and each
other, so the city has several business quarters rather than one tiny downtown), **shopping centres**
(mid-ring, large enough for a 2×2 mall + plaza + parking + corner shops), **parks** (prefer
waterfront/large), and **residential** (the rest). Residential tier comes from distance to the real
downtown + smooth noise, then a **one-tier smoothing** pass so neighbouring house/apartment/tower
blocks never jump more than a step. Every parcel/building gets a **district id**; connected
same-type (within-one-tier residential) blocks form named neighbourhoods.

## 5. Complete sites & architecture

- **Downtown**: corporate towers + offices (modest offices for a small town) around a plaza.
- **Suburb**: warm **houses** with **pitched terracotta roofs**, a front door, small footprint on a
  **garden** plot (often a tree) — concentrated on the outer city.
- **Apartments**: cool concrete, **flat roofs**, **balcony bands**, ringing a green **courtyard**.
- **Residential towers**: tall glass with antenna beacons.
- **Shopping centre**: a broad **2×2 mall** with a lit entrance, a **plaza**, **parking**, corner
  shops — a destination with grounds and road access.
- **Parks**: grass with **paths** and trees. **Waterfront**: dry banks become a **promenade**.
- **Countryside**: sparse woodland/fields on undeveloped land.

Buildings have **setbacks** (footprint inset from the tile) and sit on a **lighter grounded block
pad (sidewalk)**, with **darker road channels** and bright **curbs** between — so blocks read as
solid ground and the street network is legible. Drawn as iso boxes back-to-front by depth so towers
don't hide the (deliberately low) streets. Zone colour + window tint carry function.

## 5a. Rendering performance (retained canvas + zoom LOD)

The static scene is **retained**: because the `Camera2D` transform pans/zooms already-drawn canvas
commands on the GPU for free, `_draw()` re-runs only when the drawn *content* changes, not on every
pan or animation frame. Two bands (`LOD_ZOOM`, `WIN_ZOOM`):
- **Baked band** (`zoom < WIN_ZOOM`): the *whole* map is drawn once and panned by the camera with no
  repaint; a zoom change triggers the next repaint. Below `LOD_ZOOM` buildings collapse to flat tops
  and trees to a single blob (overview); between the two they are full boxes without fine detail.
- **Detail band** (`zoom ≥ WIN_ZOOM`): the view **plus a margin** is culled and drawn, with windows,
  curbs, furrows and full trees; panning repaints only once the camera leaves the baked margin.

All animation (water **shimmer**, the selection **pulse**, the **hover** outline) lives on a separate
lightweight `_fx` overlay node so a neon tick never forces the heavy static scene to rebuild.

**Batched bake** — the real wall was *draw-call count*: GL-compatibility won't batch thousands of
per-colour `draw_colored_polygon` calls, so a large map re-submitted ~3400 canvas commands every
frame (≈5–7 FPS), independent of resolution. On heavy maps (`_draw_items > BAKE_MIN_ITEMS`, i.e. the
large city) the whole static scene is accumulated **once per zoom tier** into a single
`canvas_item_add_triangle_array` (`_build_bake`: ground, road centre-lines, building faces/roofs/edges
as thin quads, tree blobs). A frame becomes **~4–46 draw calls instead of thousands** — ~400 FPS at
overview and **~310 FPS zoomed in** (vs ~35 on the old live path), re-baked only when the LOD tier
flips. The bake is used at **every zoom** for the heavy map (`_is_baked`), so zooming in no longer
reloads the whole visible city each frame. Medium/small stay on the live path (already fast, full
detail incl. windows). Large shows boxes+edges (no window speckles) — the FPS trade-off.
Measured with `review/_fps.tscn` (`PROBE_MODE=raw|idle|pan|detail`, reports real-dt FPS + draw calls;
`Engine.get_frames_per_second()` mis-reads the retained/bursty path, so trust `realfps`).

## 6. Settlement character by size

Small = houses + modest office centre + local shops + a small park. Medium = apartment
neighbourhoods + a real downtown. Large = tower clusters, several shopping centres/parks, extensive
suburbs. Map size and character are separate (`down_tier`, `res_cap`, `dens_scale` per size).

## 7. Interactivity

Hover reports the tile (building + district, or Street/Avenue/Bridge, Water, Park, Plaza, Courtyard,
Countryside …). **Left-click selects a building** via an isometric silhouette hit-test (frontmost
wins) → white outline + pulsing marker + a floating inspector. Drag pans, wheel zooms, Esc
deselects then leaves. Reduced motion freezes shimmer; camera/hover still update.

## 8. Verification (`review/city_checks.gd` → `city_checks.tscn`)

8 checks, all passing: **repeatable** (same seed → identical), **valid footprints** (on land, not
road/water, consistent occupancy), **road reciprocity** (symmetric connections), **road classes**
present (straight/bend/T/cross/endpoint — straight tiles never draw a crossing), **no perimeter
frame** (<10% of border is road), **bridge continuity** (every water-road has ≥2 connections),
**reserved sites** (downtown + mall + park), **one-tier residential adjacency** (≤1). Land shares
and **road coverage** (~35%, curvy streets cost more than a grid) are reported separately from building counts. Visual
quality verified by rendered captures across several seeds and all sizes (`review/_cap.tscn`).

## 9. Key tunables (`scripts/city.gd`)

| What | Where | Current |
|---|---|---|
| Grid per preset | `_grid_dims` | 18×15 / 27×22 / 38×30 |
| Development radius | `_build_land` | 0.82·min(dim)·rand(0.94,1.06), gentle lobes (~80% land) |
| Road spacing | `_road_lines` | 4 (centre) … 9 (rim) |
| Render LOD bands | `LOD_ZOOM` / `WIN_ZOOM` | 0.5 (flat tops) / 1.3 (detail + culling) |
| Reserved sites per size | `_plan_and_fill` | downtown 1/3/4 + biz 0/2/4, shops 1/2/3, parks 1/3/5 |
| One-tier smoothing | `_plan_and_fill` | 3 passes, ≤1 tier between res blocks |
| River width / lake chance | `_carve_water` | 1 tile / 40% (restrained; `disable_water` to skip) |
