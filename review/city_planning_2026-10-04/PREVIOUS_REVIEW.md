# City planning reevaluation — October 4, 2026

Reviewed the current `0.8.2` city generator against the user's goal: an attractive, believable city with recognizable neighbourhoods, natural road connections, and a less rectangular layout.

**Assessment:** individual sites and density transitions have improved, but the overall city still reads as a repeating rectangular board. The latest requests about road junctions and city shape are not implemented in this source. Prioritize the settlement footprint, street network, and usable site planning next.

## Evidence

- Rendered six views in Godot 4.7.2 with the OpenGL Compatibility renderer: small/medium/large at seed 7, plus medium at seed 42; both medium maps also have close views. The city script was copied unchanged into an isolated project with minimal Session/Settings autoloads, reduced motion enabled, and 1280×720 output.
- Generated seeds 1–100 for each size: 300 maps total. Main probe used the unchanged city script. An additional probe exposed local block/role data without changing generation decisions or random calls.
- Current `review/city_checks.tscn` reported four passes and zero failures. Its process also reported leaked test objects at teardown; those messages are not evidence of a city-generation failure.
- Source SHA256: `3CA635C0D7D8240585513A2D811E70B69A69885E4741CCE21E1785001F8A3F95`.

Visual evidence: [medium overview](captures/medium_7_overview.png), [medium detail](captures/medium_7_detail.png), [large overview](captures/large_7_overview.png), [small overview](captures/small_7_overview.png), [second medium overview](captures/medium_42_overview.png), [second medium detail](captures/medium_42_detail.png).

## What now works better

Houses have small footprints and garden ground; apartments surround courtyards; shopping sites can contain a 2×2 mall; parks contain paths and trees. Small towns use modest offices and lower residential density. Residential block smoothing passed the one-tier adjacency check across the 300-map sample. Houses, downtown, and park tiles appeared in every sampled map.

These are useful improvements to preserve while changing the larger layout.

## Findings, in visual priority order

1. **The urban footprint and street frame are still rectangular.** `_is_street()` uses `x % 4 == 0 or y % 4 == 0`; every preset ends on a multiple of four, creating a road on every outer edge. Blocks are derived from `tile / 4`, and all remaining viable blocks become housing. There is no separate development mask or surrounding countryside. In the overview captures, the city ends at an exact straight perimeter and repeats the same small blocks throughout. References: `scripts/city.gd:74`, `:81`, `:101`, `:157`.

2. **Straight avenues still look like crossroads.** Both axis centre lines are drawn on every avenue tile. The visual cross therefore appears even where only one route passes through. Use actual neighbouring road connections to classify straight segments, bends, T-junctions, four-way junctions, and endpoints. The road lattice reserves approximately half the entire map, including bridge positions, reinforcing the repeated pattern. References: `scripts/city.gd:537–543`.

3. **Water and bridges reinforce the board appearance.** Every water tile has an outlined diamond, so the river reads as individual blue cells. Every road/water overlap becomes an inset deck; adjacent decks have visible gaps. Plan selected continuous bridge spans, render a coherent water surface, and let the river shape usable land, roads, and waterfront sites. References: `scripts/city.gd:189`, `:530–535`.

4. **Neighbourhoods remain uniform at the block scale.** Housing, parks, and retail largely occupy the same 3×3 interior size. The repeated apartment boxes dominate medium and large maps, and suburbs occupy small square patches. Allow different block proportions and several connected blocks per neighbourhood/site. Give larger parks and shopping grounds their own shapes and entrances. The close views also show that stronger entrances, roof forms, facade variation, and landscape paths would improve recognition once the layout is corrected. References: `scripts/city.gd:94–110`, `:291–381`.

5. **Reserved shopping blocks do not guarantee usable shopping centres.** Role assignment accepts blocks with at least three dry cells, but a mall requires a complete 2×2 footprint. A failed mall placement does not relocate the destination. Three medium maps had no mall at all; many maps fell below their intended mall count. Validate the complete mall, plaza, and access arrangement before reserving its site. The extra plaza at `mall_anchor + (0, 2)` is also unchecked; the sample contained such decoration on water in 23 cities and on roads in nine. References: `scripts/city.gd:106`, `:136`, `:310–327`.

6. **The waterfront promenade is not usable.** It is assigned after sites have consumed their usable ground, and its vacancy check uses building anchors (`lots`) instead of full occupancy (`occ`). All 152 generated promenade tiles in the sample were inside building footprints. Reserve connected shoreline paths before filling sites. Reference: `scripts/city.gd:177–181`.

7. **District identity and downtown clustering are incomplete.** All 60,403 buildings in the sample had district ID 0. District assignment stores the correct ID in each block role, but the fillers never forward it to `_place()`. Downtown selection also takes the nearest blocks to the map centre without requiring a connected cluster; it split into multiple business components in 15 medium and seven large maps. Propagate district IDs and grow downtown from a viable connected site. References: `scripts/city.gd:127`, `:173–176`, `:260`, `:275`, `:304`.

## Seed-sample results

Each column covers seeds 1–100 for that size.

| Measure | Small | Medium | Large |
|---|---:|---:|---:|
| Tiles reserved by road lattice, including water crossings | 51.1% | 48.6% | 47.2% |
| Maps with no mall | 33/100 | 3/100 | 0/100 |
| Maps below intended mall count | 33/100 | 33/100 | 48/100 |
| Reserved shopping blocks without a mall | 33/100 | 36/200 | 52/300 |
| Open promenade tiles | 0 | 0 | 0 |
| Promenade tiles inside building footprints | 31 | 60 | 61 |
| Buildings with district ID 0 | 5,308 | 16,138 | 38,957 |
| Maps with disconnected downtown block groups | 0/100 | 15/100 | 7/100 |

Small settlements may intentionally use a compact retail destination; the missing-mall figure describes current generation, rather than requiring a huge mall in every town. Medium and large sites still need to fulfil their chosen destination plan.

Raw evidence: [main results](results.json), [additional results](extra_results.json), [existing checks](existing_checks.log), and [render log](render_engine.log). The main JSON's `fewer_park_districts_than_target` field must not be interpreted as missing parks: adjoining park blocks can merge into fewer districts. The additional probe confirmed all requested shopping-block and park-block reservation counts were met.

## Recommended next implementation

1. Correct the directional road drawing, then replace the periodic road rule with explicit connections and road classes.
2. Choose usable terrain and connected urban centres; plan main routes and selected bridges around them. Define an asymmetric development area with green wedges and uneven suburban extensions.
3. Derive varied blocks/parcels from that network. Maintain coherent neighbourhoods across local roads, keep the developed city connected, and leave surrounding terrain visible.
4. Reserve complete usable downtown, shopping, park, and waterfront sites before placing buildings. Enforce site access, validate decorations as well as footprints, and retry unsuitable locations.
5. Pass district ownership into every building and site. Preserve the density smoothing while adapting it to the new adjacency model.
6. Review screenshots again, then tune building families, entrances, grounds, signage, and landmark silhouettes.

The first visual milestone should show an uneven city outline, noticeably varied block shapes, correctly drawn streets, a coherent river, and continuous bridges. The next should show reliable destinations and usable waterfront space.

## Verification gaps to close

The existing four assertions cover only a few fixed maps. Reserved-site presence is checked on medium seed 7 alone; repeatability checks building anchors/kinds rather than the complete generated city. Tests currently miss road topology, false crossing marks, the rectangular perimeter, district ownership, occupied promenade tiles, and mall failures across seeds. `CK4` calculates a three-tile neighbour but never inspects it.

Add focused checks for these actual defects, and inspect rendered views at overview and normal zoom. Keep land coverage, district counts, reserved sites, and actual buildings as separate measurements.

The two probes and logs are preserved here for inspection. They were run in temporary projects with isolated autoloads and no player settings or save access. Game source was not changed for this reevaluation.
