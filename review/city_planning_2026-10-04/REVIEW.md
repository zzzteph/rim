# City planning reevaluation — October 4, 2026

**Assessment:** the latest update improves the developed outline, fixes false crossroads, and passes district IDs correctly. Wider street spacing gives sites more room. The next priority is a connected, well-proportioned city plan: 285 of 300 sampled maps still have disconnected road segments, roads occupy about 40–42% of developed land, and many leftover blocks are too small for complete neighbourhoods and parks.

## Reviewed snapshot

The source changed substantially during this review. This report evaluates the final inspected snapshot, SHA256 `7E6056AB7FB460BA2D605AB41A83AB5680453BF440F166D0D4FE636279F75BED`, preserved as [city_source_snapshot.gd](final/city_source_snapshot.gd). The project still declared version 0.8.2; the hash identifies the actual reviewed code.

Rendered six views in Godot 4.7.2 with OpenGL Compatibility at 1280×720: small/medium/large at seed 7 and medium at seed 42, including close views of both medium maps. Used isolated projects with minimal Session/Settings autoloads and reduced motion enabled. Generated seeds 1–100 for each size, 300 maps total, from the same frozen source.

Visual evidence: [medium overview](final/captures/medium_7_overview.png), [medium detail](final/captures/medium_7_detail.png), [large overview](final/captures/large_7_overview.png), [small overview](final/captures/small_7_overview.png), [second medium overview](final/captures/medium_42_overview.png), [second medium detail](final/captures/medium_42_detail.png).

Earlier findings and measurements are retained in [PREVIOUS_REVIEW.md](PREVIOUS_REVIEW.md) for comparison. They describe the earlier repeating-grid implementation and must not be presented as current results.

## Improvements verified

- The developed land has an asymmetric footprint with surrounding countryside. The automatic rectangular perimeter road is removed.
- Road markings follow actual neighbouring road tiles. Straight segments no longer receive false crossing lines.
- Road spacing varies from three to six tiles, and blocks are derived from the road network. The last spacing change increased ordinary central interiors to 2×2 tiles and reduced road coverage.
- Local roads are clipped to developed land; only arterials cross water in the final sample.
- Building district IDs are passed through correctly and all sampled IDs refer to valid districts.
- Houses, apartment courtyards, mall footprints, and distinct height families remain recognizable.

The rendered city has a less rigid built edge. Its internal layout still consists mostly of axis-aligned street fragments and small sites, with limited connected open space.

## Remaining findings, in priority order

1. **Road connectivity is now the main correctness problem.** Clipping long road lines to the irregular footprint and water breaks them into fragments. Generation does not reconnect or remove all stranded components. Only 11/100 small maps and 4/100 medium maps had one connected road network; no large maps did. There were 816 completely isolated road tiles across the sample. Some developed blocks had no road neighbour at all. Establish the connected main routes first, then attach each local street and repair or remove disconnected pieces before placing sites.

2. **Wider spacing helps, but clipping still produces tiny sites.** `_road_lines()` now places streets at least three tiles apart, allowing a 2×2 interior where both axes reach that spacing. `_carve_blocks()` still accepts single-tile remnants at the footprint and water edges. Depending on map size, about 26–44% of sampled blocks contained only one or two cells. Set minimum usable block dimensions and reserve enough contiguous ground for courtyards, gardens, parks, and retail access. Roads still occupy about 40–42% of developed land. Judge that proportion alongside the rendered city, using developed land as the denominator rather than the whole countryside map.

3. **Parks can be labels over path-only sites.** Park allocation counts blocks without requiring a usable green area. `_fill_park()` turns the chosen row into a path; a one-row site can therefore contain no park grass or trees. Every sampled map had a park district, but 52 small maps and one medium map had no actual `park` tile. Reserve parks by shape and minimum usable green area before assigning the role.

4. **Waterfront planning is still absent.** The occupancy check is fixed, but the promenade pass runs after all site ground has already been assigned to buildings or decoration. Zero promenade tiles were generated across all 300 maps. Reserve a connected shoreline strip and its access points before filling parcels. Water tile outlines and inset bridge decks also keep the river visually segmented; join decks into continuous directional spans and render the water as a coherent surface.

5. **Shopping centres still need complete site validation.** Site selection checks tile count rather than whether a 2×2 mall, entrance, plaza, and access fit together. An entrance plaza is stamped without validating its location, and later filling may overwrite it. Medium and large maps now all contained at least one mall in this sample, while 10 small maps did not. A compact town retail destination is acceptable when deliberately planned; a failed footprint should trigger a suitable alternative or another site.

6. **Downtown and neighbourhood identity need stronger composition.** Downtown takes several near-centre blocks, and the density centre is overwritten with the last selected block's centroid. Choose a connected downtown cluster and derive its centre from that cluster. Give suburbs larger coherent areas with connected quieter streets. Preserve the working district IDs while placing labels inside actual neighbourhood territory.

The complaint about rectangular repetition is only partly resolved. `_build_roads()` still draws selected horizontal and vertical lines across the development bounds, then clips them. A wavy outer mask changes the silhouette but does not create different neighbourhood street patterns. Plan main routes between centres and crossings, then grow local streets within neighbourhood areas: a compact downtown grid, longer residential blocks, suburban branches and loops, and paths following suitable banks. The existing tile grid can represent these arrangements; arbitrary diagonal movement is not required. Avoid adding random bends that consume site space without improving access or composition.

## Final seed-sample results

### Follow-up: excessive water coverage

The user additionally reports that water takes too much space. The reviewed `_carve_water()` always creates a river with a three-tile width, widened to five every sixth row. Its variable `w` is a radius, so the `CITY.md` description of a one-to-two-tile river is inaccurate. On a small 18×15 map, the river alone occupies 51/270 tiles (18.9%) before adding a lake. The 70% lake chance and radius of 2.0–3.6 tiles do not scale down for towns. Water is carved before the development mask, with no budget ensuring that required neighbourhood sites will fit.

The user further clarifies the visual failure: **"there is no city, but buildings on water."** In the medium seed 7 capture, bright water contrasts with very dark land, and the river separates prominent building clusters. The source's building placement rejects water cells, but valid placement alone does not establish the appearance of a coherent city. Prioritize substantial adjoining neighbourhoods, continuous streets and visible ground, anchored building bases, and legible banks. Demonstrate the composition with water disabled in a development fixture, then add restrained water while retaining the city structure. Recheck literal overlaps as well as the rendered appearance.

Reduce actual channel width, make lakes occasional and size-aware, and allow inland maps. Start visual tuning around 5–10% water coverage for ordinary maps with water and a 15% default ceiling; these are proposed design targets, not sampled results. Also check water's overlap with the intended settlement footprint and the usable connected land left for sites. A smaller river still needs a continuous channel, complete bridge approaches, and planned banks. The updated `CLAUDE_CITY.md` includes this requirement before road and parcel planning.

### Previously sampled generation metrics

Each column covers seeds 1–100. Percentages aggregate the tiles across those seeds.

| Measure | Small | Medium | Large |
|---|---:|---:|---:|
| Roads as share of developed land | 40.3% | 39.8% | 42.2% |
| Maps with one connected road network | 11/100 | 4/100 | 0/100 |
| Completely isolated road tiles | 117 | 199 | 500 |
| Blocks with only one or two tiles | 612/1,403 | 820/2,800 | 1,428/5,567 |
| Maps with no actual park tile | 52/100 | 1/100 | 0/100 |
| Maps with no mall | 10/100 | 0/100 | 0/100 |
| Promenade tiles | 0 | 0 | 0 |
| Invalid building district IDs | 0 | 0 | 0 |
| Non-arterial road tiles over water | 0 | 0 | 0 |
| Developed blocks with no adjacent road | 61 | 95 | 296 |
| Buildings in those blocks | 43 | 37 | 143 |

All sampled maps contained houses and downtown buildings. Connectivity counts use four-neighbour road adjacency, including bridge tiles; the table does not claim that every disconnected component contains buildings. The last two rows separately count blocks with no road edge and their buildings. Road coverage is the sum of road tiles on developed land divided by the sum of developed land tiles; it excludes bridge tiles and countryside exits.

Raw evidence: [results](final/results.json), [probe](final/probe.gd), [probe log](final/probe.log), and [render log](final/render_engine.log). The probe source is preserved for inspection; it ran in a temporary project with isolated autoloads and no player save access.

## Recommended next milestone

1. Budget water and retain enough usable land for the city. Build a connected arterial network and complete bridge spans. Attach local streets to it, then validate connectivity after clipping and pruning.
2. Validate usable block shapes after clipping and remove one-cell slivers as independent neighbourhood sites. Keep those slivers as verges, landscaping, or parts of a neighbouring site where appropriate. Preserve the increased central spacing.
3. Reserve complete accessible parks, retail destinations, public squares, and waterfront paths before buildings. Validate footprints and decoration together.
4. Place residential neighbourhoods and downtown around those sites, preserving density transitions and district ownership.
5. Inspect the rendered city again, then refine building entrances, architecture families, facade variation, and landscape detail.

For the road change, first identify the developable land components and retain only areas that can be served. Select useful bridge corridors with land approaches on both banks, connect the required centres, then attach neighbourhood streets to that backbone. After rasterizing and clipping, flood-fill the network: repair useful disconnected routes with bounded connections or remove redundant fragments and reassign their ground. Do not connect every leftover road dot blindly, which would consume still more land. Recompute blocks after repairs and validate complete sites before filling them.

The acceptance image should show continuous routes, a compact downtown, coherent apartment areas, distinct suburbs, usable parks, recognizable retail grounds, and a connected riverfront. Keep the asymmetric developed outline already achieved.

## Verification and documentation

The updated `review/city_checks.gd` passed all eight assertions against the frozen source in the isolated project: [check source](final/existing_checks.gd), [check log](final/existing_checks.log). The harness also reported resource leaks at exit. These checks cover a few fixed maps and do not establish whole-network connectivity. In particular, its reciprocity condition simplifies to checking the currently iterated road tile exists, so it cannot detect stranded road components. Its bridge assertion checks neighbour count, which does not establish a complete crossing between accessible banks. Add explicit flood-fill reachability, complete bridge spans, minimum usable site shape, actual park ground, reserved promenades, and whole-site footprint checks across seeds.

`CITY.md` has been updated to describe the explicit network and wider spacing. Its statements about complete shopping grounds, usable parks, and promenades still describe intentions that generation does not reliably meet. Refresh those claims alongside the fixes. Preserve separate measurements for district roles, actual site contents, road coverage, and building counts.

Game source was not edited as part of this reevaluation. The repository continued changing during the review; use the preserved source hash and captures to identify the exact evidence behind these findings.
