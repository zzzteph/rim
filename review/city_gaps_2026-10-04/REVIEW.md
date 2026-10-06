# CITY.md: current gaps and 20 improvements

Reviewed October 4, 2026 against city source SHA256 `74641F82ACF12E49ED2F59EF81CF13221D7850937AD92BEFFAA847C05E7D54AA`. Preserved [CITY.md](CITY_snapshot.md), [generator](city_source_snapshot.gd), and [existing checks](existing_checks_snapshot.gd) identify this version. Earlier reviews describe older generators and are not current measurements.

## Assessment

The city now occupies substantial visible land, the river is much narrower, road markings follow their connections, local streets meander, and ground pads distinguish blocks from streets. Those are real improvements. The current images show recognizable residential and business concentrations.

The main gap is that CITY.md describes intended outcomes as guarantees. A radial land mask does not establish connectivity, a connected patch of leftover cells is not automatically a complete site, and a painted courtyard does not establish pedestrian access. The current view still has repetitive building rows, substantial tower concentrations, small leftover sites, and streets whose shapes are driven mostly by noise rather than destinations. Increasing coverage has also pushed much of the developed outline close to the rectangular storage boundary.

Prioritize the relationship between land, access, blocks, buildings, and public space. Further water reduction alone will not produce a convincing city.

## Current evidence

Generated seeds 1–100 for each of three sizes with water enabled, then the same seed/size combinations with water disabled: 600 maps total. Ran the existing eight assertions separately. All work used isolated Godot projects with minimal Session/Settings stubs and no player save access. Rendered six new views at 1280×720 in Godot 4.7.2, OpenGL Compatibility, with reduced motion enabled. These are generation and visual checks, not new performance benchmarks.

| Water-enabled sample, 100 seeds per size | Small | Medium | Large |
|---|---:|---:|---:|
| Water / whole map | 7.67% | 4.67% | 3.16% |
| Developed land / whole map | 69.5% | 78.5% | 83.3% |
| Roads on land / developed land | 35.5% | 37.1% | 40.3% |
| Maps with one road component | 56 | 24 | 13 |
| Mean share of roads in largest component | 95.1% | 96.9% | 97.6% |
| Isolated road tiles across sample | 19 | 68 | 145 |
| Blocks with one or two cells / all blocks | 264/1,092 | 488/2,263 | 1,145/4,553 |
| Maps with no actual park ground | 25 | 6 | 1 |
| Maps with no mall | 11 | 0 | 0 |
| Promenade tiles across sample | 0 | 0 | 0 |
| Invalid building footprints | 0 | 0 | 0 |
| Buildings overlapping water | 0 | 0 | 0 |

Thus 207/300 maps contain disconnected road fragments, though most road tiles belong to the largest component. This does not mean every neighbourhood is isolated. In the dry fixtures, 117/300 maps still have disconnected roads and 71/300 have disconnected development masks. Water is not the sole cause.

Water tiles form 2–23 four-neighbour components per water-enabled map, including any deliberately separate lake. The one-cell river does not fill connectors when its x-coordinate changes between rows; assess the river separately from lakes when validating continuity. Dry land on opposing riverbanks need not be one component if complete bridges provide access.

Visual evidence: [small overview](captures/small_7_overview.png), [medium overview](captures/medium_7_overview.png), [medium detail](captures/medium_7_detail.png), [large overview](captures/large_7_overview.png), [large detail](captures/large_7_detail.png), [medium without water](captures/medium_7_dry_overview.png). All captures use seed 7. The dry image is a separate generated layout: disabling water also changes subsequent RNG consumption, so it is not a controlled removal of water from an identical plan.

Raw evidence: [water-enabled results](results.json), [dry results](results_no_water.json), [generation probe](probe.gd), [dry probe](probe_no_water.gd), [existing check log](existing_checks.log), [capture script](render_probe.gd), and [render log](render.log).

## Twenty improvements, in implementation order

1. **Plan a substantial city footprint with a deliberate outer edge.** `_build_land` uses a large radius and clips at the storage border (source lines 176–195). It does not validate connected usable areas; the enlarged mask can also recover a nearly rectangular developed outline. Reserve a dominant urban area, coherent suburban extensions, and green wedges, then validate their usable area and access. Acceptance: a continuous city with a visibly varied edge in both wet and dry fixtures, with stranded slivers assigned to landscape instead of occupied sites.

2. **Budget water against the city plan.** The river is now one tile wide and lake probability is 40%; the earlier three-to-five-tile diagnosis is obsolete. Water still runs first and a randomly located lake can displace valuable central land (`_generate`, `_carve_water`, lines 116–173). Make water optional and constrain its overlap with planned centres and neighbourhoods, using bounded retries. Acceptance: every required place fits with access; report water share of the map and of the intended development footprint. Do not force extra water to meet a percentage target.

3. **Make rivers and banks continuous.** A single tile at each rounded sine position creates corner-only joins or gaps when x changes (lines 161–164). Rasterize a connected narrow channel and derive banks from its boundary. Render water as a calm continuous surface, with coherent grass banks or quays and visible dry building grounds. Acceptance: each river connects its intended endpoints; lakes are separately identified; normal zoom shows a readable shoreline rather than a chain of blue diamonds.

4. **Guarantee road access after every terrain operation.** Full-length lines are clipped independently, and only low-degree water tiles are pruned (lines 198–260). Build the main network between useful anchors, attach neighbourhood streets, then reconnect useful fragments or remove redundant ones. Acceptance: retained roads reach the main network; occupied sites reach it through a street or explicit path. Use graph traversal, not merely reciprocal-neighbour checks.

5. **Give street shapes a purpose.** Sine offsets and random branches do not distinguish a shopping approach from a quiet residential lane. They can also bring streets close together after spacing has been selected (lines 217–290). Use a compact central grid, longer residential blocks, suburban loops/branches, and deliberate junction spacing. Choose one initial branch direction consistently at line 277. Acceptance: neighbourhood patterns differ, junctions remain separated, and extra bends preserve useful site space. Track adjacent junctions and road-only 2×2 patches to detect accidental wide intersections.

6. **Generate bridges as complete crossings.** The current validation checks road-neighbour count, while both renderers inset every deck on all sides (lines 890 and 1020). Plan crossings between accessible dry banks, and draw adjoining decks through to their connected edges with clear approaches. Acceptance: a bank-to-bank traversable span with no blue seams between deck pieces or at its street connections.

7. **Reject unusable building sites.** `_carve_blocks` accepts even one cell (lines 337–351). Approximately 22–25% of blocks in the new sample have only one or two cells. Enforce minimum area, width, frontage, and shape for each role; merge suitable remnants or turn them into verges. Acceptance: every assigned site actually fits its buildings, grounds, and access before filling begins.

8. **Create parcels with entrances and access.** `_place` validates occupied cells but does not require frontage or an entrance route (lines 492–504). Filling every available tile can trap interior buildings behind other buildings. Subdivide blocks from street edges, orient buildings to those edges, and provide explicit shared access where needed. Acceptance: trace a traversable route from each entrance to the street network, including gardens, courts, and shopping premises.

9. **Compose one clear primary downtown.** Central blocks need only two cells, are selected by distance, and overwrite `down_c` with the last chosen centroid (lines 370–374). Select a coherent cluster with a usable public square, derive an area-weighted centre, and add secondary business areas only where access and remaining land support them. Acceptance: the skyline has a clear main centre, readable streets, and a deliberate transition into mid-rise areas; satellites do not consume the best residential and amenity sites.

10. **Reserve residential and suburban area explicitly.** Residential use receives whatever remains after business, retail, and parks. Fixed block counts can allocate very different land shares when block sizes vary. Set flexible area budgets and minimum coherent neighbourhood sizes for each settlement size; reserve gardens and quieter suburban streets. Acceptance: every size has recognizable housing districts, and medium/large maps reliably retain substantial suburbs rather than isolated edge houses.

11. **Base districts and density on meaningful adjacency.** `_block_adjacency` only recognizes blocks exactly one road tile apart (lines 448–463); meandering and widened sections can escape that model. `_noise` is an independent positional hash despite the document calling the density noise smooth. Define neighbourhood adjacency from shared street frontage and access, then apply correlated density variation around actual centres. Acceptance: stable district ownership, coherent boundaries, and verified one-tier residential transitions under the documented adjacency rule.

12. **Lay out apartment courtyards as usable places.** `_fill_residential` marks one tile as the courtyard and fills the rest of an apartment block (lines 554–581). Reserve a connected interior green area, entrances, pedestrian links, and building groups with space between them. Acceptance: the courtyard is visible, reachable, and proportionate to the apartment site; it is not just one green tile buried in repeated boxes.

13. **Reserve complete shopping-centre grounds atomically.** Four cells need not fit a mall and its grounds. The plaza at line 530 is unchecked, and later filling can overwrite it. Plan the mall, entrance square, parking/service access, shops, and pedestrian approaches as one validated site. Acceptance: all parts lie on appropriate ground within the reserved site and survive later filling. A deliberately compact retail alternative is valid for towns when a mall cannot fit.

14. **Guarantee usable parks.** Park selection can exhaust its candidates, and a one-row park can become entirely path (lines 398–406 and 542–551). Reserve connected green interiors and route paths between planned entrances, with a deterministic fallback for the minimum required park. Acceptance: actual accessible green space of an appropriate minimum size, not merely a park label or a single tile. The new sample still has 32 maps with no park ground.

15. **Reserve waterfront space before filling blocks.** Promenade allocation runs after lots and ground decoration have consumed the bank tiles (lines 424–434). Reserve suitable connected bank corridors earlier and link them to neighbourhood paths and bridges. Acceptance: fixtures selected for a public waterfront contain usable promenade segments that later site placement cannot overwrite. All 600 sampled maps currently have zero promenade tiles, including the intentionally dry fixtures.

16. **Use neighbourhood architecture families and deliberate landmarks.** Buildings largely share repeated boxes with three variation values and fixed height ranges (`_place`, `_height_for`). Define small coordinated families for houses, apartments, shops, offices, and landmarks, varying roof shape, massing, frontage, and materials within each family. Acceptance: neighbourhoods are recognizable with labels hidden; a few civic or commercial landmarks help orientation without making every tower compete for attention.

17. **Preserve useful detail in the batched renderer.** Once `_draw_items` exceeds 400, the batch path is used at every zoom. It omits entrances, shop signs, balcony bands, antennas, parking markings, and curbs, in addition to windows (lines 789–797 and 851–942 versus the live rendering routines). Share semantic geometry or add detail batches for the visible neighbourhood. Acceptance: a large city's houses, malls, apartments, and public spaces remain identifiable when zoomed in, while measured performance remains acceptable. The threshold is based on item count, not strictly the size preset.

18. **Make district labels and inspection match the visible city.** Labels use raw centroids without collision handling; click and hover use different hit methods, and water is checked before bridge roads in hover (lines 736–775 and 815–820). Place important labels inside their territory, declutter by zoom, and use consistent object picking with bridge-aware descriptions. Acceptance: readable labels and correct feedback over roofs, streets, bridges, and large footprints.

19. **Make repeatability and validation meaningful.** Separate random streams by generation stage so disabling water or changing tree dressing does not reshuffle the entire city. CK1 compares counts and building kinds, CK3 is tautological, CK6 only counts neighbours, and CK8 samples fixed two-tile offsets. Compare canonical full generated state, validate actual graph/site invariants, and exercise multiple seeds, sizes, water modes, and rendering paths. Acceptance: reproducible failing fixtures; water/no-water comparisons with controlled stage inputs; checks that catch the measured failures rather than still reporting eight passes.

20. **Rewrite CITY.md around implemented behaviour and evidence.** It says water is both first and last, claims a connected landmass without enforcement, calls sites complete without access validation, says water shimmer exists although the current overlay explicitly excludes it, and overstates what CK1 proves. The lots schema also lists `tier`, which `_place` does not store. Separate current behaviour, intended requirements, and verified results. Name the source revision, seed, size, viewport, renderer, hardware, and method beside performance claims. Acceptance: every claimed guarantee points to a meaningful check or reproducible visual fixture; no historical benchmark is presented as current universal behaviour.

## Suggested delivery

Address 1–8 first to establish sound terrain, routes, and usable sites; then 9–15 to compose the actual city; then 16–18 to improve architectural identity and legibility. Apply 19–20 throughout. Preserve the improvements already made: narrow water, grounded blocks, correct road markings, explicit district IDs, and efficient drawing.

This review changes documentation and adds isolated evidence only. It does not implement the proposed generator changes. The existing eight assertions passed on this snapshot; that result does not invalidate the broader failures above. Captures support visual observations for the shown seed, not a claim that every map has the same appearance.
