# RIM — implement an attractive generated city

Prepared October 4, 2026. This is an implementation brief for the city generation and presentation work discussed with the user. Inspect the current files before changing them; the project is actively being edited.

Latest verified reevaluation: read [CITY.md: current gaps and 20 improvements](review/city_gaps_2026-10-04/REVIEW.md) and its six new rendered captures before implementation. It evaluates source `74641F82…` with 300 normal and 300 dry maps. Water is now narrower, land coverage is greater, and local streets meander. Prioritize connected routes, usable complete sites, coherent neighbourhoods, and consistent visual detail. The [earlier city planning review](review/city_planning_2026-10-04/REVIEW.md) and its measurements are historical; use the newer report where findings differ.

**Source changed after that audit:** during the France/UK research, `scripts/city.gd` was observed at `5D282035…`, with further implementation edits in progress. The audit's measurements and failure counts apply to `74641F82…`; recheck each finding against the current source before fixing it. This research pass did not rerun the generation sample or modify game code.

Dutch urban research: read [DUTCH_CITY_ANALYSIS.md](DUTCH_CITY_ANALYSIS.md) for the comparison of Amsterdam, Rotterdam, and The Hague, the proposed generation algorithm, and twenty research-informed improvements. Its [32 municipality profiles](review/dutch_city_research_2026-10-04/CITY_PROFILES.md) cover the working scope of Dutch municipalities above 100,000 residents. This is qualitative research; no Dutch zoning percentages or calibrated generator weights have been measured. Keep historical/existing conditions separate from future municipal plans.

France and UK extension: read [EUROPEAN_CITY_GENERATION.md](EUROPEAN_CITY_GENERATION.md) for the combined implementation decisions, then consult [FRANCE_CITY_ANALYSIS.md](FRANCE_CITY_ANALYSIS.md) and [UK_CITY_ANALYSIS.md](UK_CITY_ANALYSIS.md) for supporting cases. These add 12 representative French cities and 12 UK cities plus Milton Keynes, covering all four UK nations. They are a selected qualitative comparison, not an exhaustive inventory. Build reusable street, block, frontage, and housing patterns; a separate generator for each country is unnecessary.

Small-town extension: read [SMALL_TOWN_ANALYSIS.md](SMALL_TOWN_ANALYSIS.md) for 24 selected towns below 50,000 in their stated population geographies: eight each in the Netherlands, France, and UK. It includes six proposed town families, twenty improvements, [individual profiles](review/small_town_research_2026-10-04/TOWN_PROFILES.md), and a [population/source register](review/small_town_research_2026-10-04/POPULATION_SOURCES.md). Boundary and date caveats apply. For town-family generation, use the town-specific program below in place of the larger-city tower and apartment requirements; retain all connectivity, footprint, interaction, and visual-quality checks.

**Spatial direction:** generate connected places through a small number of growth stages. Use purposeful anchors, coherent housing expansions, several centre roles, a shopping hierarchy, and selective redevelopment. Separate neighbourhood identity from exclusive land use: homes can sit above shops, and a residential neighbourhood can contain local services. The main shopping centre, historic centre, and office skyline may occupy different connected locations. Adapt these relationships to RIM's compressed map and cyberpunk presentation.

## The user's goal

The generated city should look like a really nice, believable city, with recognizable residential areas, shopping centres, suburbs, downtown, parks, and related urban places.

The user's clearest description of the problem is: **"there is no city, but buildings on water."** Treat this as the main visual acceptance issue. The result must read immediately as a continuous city built on solid land: connected streets, substantial blocks, visible grounds, and adjoining neighbourhoods. Reducing the water percentage alone does not complete that change.

User feedback: road tiles look like crossroads everywhere, the whole map looks too rectangular, and water takes up too much space. Address road connectivity and markings, overall settlement shape, and the amount of land available for complete neighbourhoods. Generate an asymmetric urban footprint and varied internal street patterns, with restrained water coverage.

Use SimCity / Constructor as references for readable urban layout and architecture. Keep RIM's cyberpunk, neon-noir atmosphere through lighting, signs, materials, and landmarks.

**Compose neighbourhoods and complete sites before filling them with individual buildings.** The result should feel deliberately arranged even though its layout varies with the seed. Visual quality and recognizable urban places are the main deliverable.

Implement the changes and inspect the rendered result. A revised algorithm or documentation alone does not complete this task.

## Read and reuse the current project

- `CITY.md`: current generation description; verify its statements against source.
- `scripts/city.gd` and `scenes/city.tscn`: city generation, rendering, camera, and hover.
- `scripts/menu.gd`, `scripts/session.gd`, `scripts/settings.gd`: entry point, size/seed, and accessibility.
- `CLAUDE_BRIEF.md`: wider game context and future integration requirements. Keep this pass focused on the physical city and its presentation.

The inspected city already has a continuous 2:1 isometric grid, an asymmetric developed footprint, explicit roads with directional markings, a river, an optional lake, bridge tiles, reserved neighbourhood roles, block-based density smoothing, and depth-sorted buildings and trees. Build on that foundation.

Rechecked October 4, 2026: tiles are 64×32 pixels and the final inspected presets are 18×15, 27×22, and 38×30 tiles. Roads now use explicit tile data and variable spacing. These are implementation values that may change to improve the composition, not required final dimensions. Recheck menu size labels when changing dimensions.

Preserve unrelated working-tree changes and existing systems. The broader component-map, hacking, and economy work remains separate scope. Keep city data suitable for that integration, including stable building and district IDs.

## Required visual composition

### Establish the city as a continuous place

- Compose a substantial main urban area with a compact centre and several adjoining neighbourhoods. Give housing, retail, parks, and downtown usable multi-block areas and shared street connections. Avoid scattered individual buildings on tiny remnants between water and roads.
- Keep the main centre and most development on a broad continuous land area. Prefer optional water along an edge or through a limited corridor. Any development across water must form a deliberate neighbourhood with complete access and enough land for its streets and amenities.
- Make the ground readable at normal zoom: continuous paving, sidewalks, gardens, courtyards, and visible foundations should anchor buildings to their blocks. Strengthen the distinction between dry ground, streets, and water while retaining the night atmosphere. Bright blue water and near-black land must not make the land visually disappear.
- Give shorelines a clear bank, green strip, or embankment where appropriate. Keep building footprints and their required access on dry land; inspect the entire footprint, waterfront decoration, draw order, and bridge approaches. Investigate literal water overlap separately from the visual impression of floating buildings.
- Render water as a calm continuous surface, removing the bright outlines around individual water tiles. Join bridge decks without blue seams and show their connection to the banks. Keep the visual emphasis on streets, neighbourhoods, and the skyline.
- First demonstrate a coherent layout with water disabled in a development fixture, then inspect a version with restrained water and preserved neighbourhood structure. Review both with district labels hidden and at normal zoom. This is a composition check, not a request to remove all water from the final generator.

| Place | Required appearance and arrangement |
|---|---|
| Main centre | A connected concentration of shopping, civic uses, housing, and public space. Mid-rise street frontage can establish a strong centre. Give it clear routes, a square, and selected landmarks. |
| Corporate skyline | The default cyberpunk city should include a compact, deliberate office/tower cluster, with medium-rise edges and readable streets below. It may sit near the main centre or at a separate transport-linked node. Other city families can use a lower skyline; the main shopping centre need not be the tallest place. |
| Residential neighbourhoods | Groups of apartments, terraced houses, or perimeter blocks with consistent scale, shared courtyards, gardens, playgrounds, and occasional corner shops. Each neighbourhood should have a coherent architectural family. Support shops below homes at selected frontages. |
| Suburbs | Coherent groups of terraced, semi-detached, or detached houses with visible gardens, setbacks, street-facing entrances, quieter streets, and pocket parks. Provide shared or individual parking where suitable. Concentrate these areas toward the outer city while allowing a local centre. |
| Shopping centres | Complete destinations: a low-rise mall, retail complex, or connected shopping street/square with obvious entrances, public space, nearby homes or shops, and suitable pedestrian, vehicle, and service access. Reserve the whole site. Distinguish this destination from smaller neighbourhood shops and specialised peripheral retail. |
| Parks | Connected green areas with paths, trees, clearings, and recognizable entrances. Include smaller parks near housing and a larger park where the map permits. |
| Waterfront | Where water exists, give suitable developed banks a promenade, green edge, or public space. Bridge approaches should connect clearly to the street network. |

For city families, medium and large maps should reliably include a main centre, apartment neighbourhoods, coherent suburbs, at least one recognizable shopping destination, and a connected park. Include the compact corporate cluster in the default cyberpunk city family. Reserve room for these places before optional random growth. For small city maps, use compact versions that fit: a modest centre and retail destination, houses, some apartments, and a small park. Apply the town program below when a town family is selected, regardless of grid size.

Keep one adjoining city with shared physical streets and a consistent architectural scale. Neighbourhoods should meet naturally through streets, transition blocks, and greenery. Their identity should remain understandable with district labels hidden.

## Generate the overall layout first

Use this order, adapting the existing code where useful:

1. **City family, terrain, and capacity:** choose the intended character and required places; budget enough connected usable land, then fit restrained optional water and an asymmetric development footprint around that requirement. Reserve major green space.
2. **Anchors and growth structure:** choose actual historic/civic, retail, employment, and transport destinations where suitable. Reserve their complete sites and grow adjacent housing neighbourhoods with coherent development eras. Scale the number of anchors to the map; small maps need only compact versions.
3. **Roads and blocks:** connect those destinations with a road graph, attach local streets, and rasterise connected routes. Plan complete bridge approaches. Derive usable blocks and recheck site capacity. Different neighbourhoods can have compact grids, longer residential blocks, branches, or loops. Curves should follow a destination, terrain, or boundary reason.
4. **Districts, uses, and density:** assign connected neighbourhood identity, then building uses and density around actual centres, access, and neighbourhood character. Plan a hierarchy of shopping destinations and local shops. Allow mixed uses and limited redevelopment without erasing the existing structure.
5. **Sites and parcels:** lay out entrances, pedestrian links, gardens, courtyards, shopping grounds, public squares, parks, and building footprints. Use distinct pedestrian links where a full vehicle road would waste space.
6. **Buildings, details, and repair:** populate those arrangements with coordinated architecture. Validate connectivity, occupancy, and required places; make bounded deterministic repairs and recheck affected sites. Add landscaping and lighting, then inspect rendered composition.

Keep neighbourhood growth seeded and varied. Let nearby blocks and road access guide expansion; local streets can connect a neighbourhood across blocks, avenues can encourage district edges, and water forms a meaningful geographic boundary. Separate neighbourhoods on opposite banks can share access through bridges.

Start with one attractive mixed-city family, then add a planned green town and a station/business variant. The 32 researched municipalities are references for spatial relationships, not a requirement to implement 32 generators. Straight streets and rectangular blocks can be appropriate locally; the problem is uniform repetition across the whole city. Keep earlier routes and selected landmarks when adding later development.

Add frontage-aware perimeter blocks, short terrace ensembles, and high streets from the France/UK comparison. A perimeter block needs reserved inner grounds and deliberate access; a terrace needs street-facing doors and a rear edge; a high street is a connected retail frontage that may pass through several blocks or neighbourhoods. A boulevard can gain identity through aligned frontage, trees, and squares without automatically doubling road-tile width. Keep these patterns legible at the current map scale.

## Required road and city-shape corrections

### Reduce water coverage and protect usable land

The user explicitly wants water to support a substantial city on land. The latest `_carve_water()` now uses a one-tile river, a 40% lake chance, and lake radius 1.6–2.6 tiles. The current sample averages 7.67%, 4.67%, and 3.16% water for small, medium, and large maps. The earlier three-to-five-tile river and 70% lake chance have been replaced. Focus next on preserving usable city land, joining the thin river through bends, and keeping clear banks and accessible neighbourhoods.

- Express river width as the actual number of occupied tiles. Start with one to two tiles for small/medium maps and two to three for large maps; use gentle bends and occasional natural widening instead of widening every sixth row. Keep the rasterized water channel connected when its centreline shifts.
- As an initial visual tuning guide, 5–10% total water coverage is sufficient on ordinary maps with water, with a default ceiling of 15%. These are proposed composition settings, not real-world planning standards. Do not add water to meet a target when the city already works with less. Inland maps may have no water.
- Make lakes occasional and scale their area to the remaining water budget. Prefer a narrow river or a small lake on compact maps; combine them only when enough usable city land remains. Avoid broad central pools that displace downtown or divide suburbs into scraps.
- Evaluate water against both the whole terrain grid and the intended settlement footprint before water is removed. A low map-wide percentage can still consume much of the city centre. Preserve enough contiguous sites for all required places and connect any developed banks with complete bridges.
- If a water layout leaves inadequate sites, narrow, move, or omit optional water using bounded deterministic retries. Use the recovered land for neighbourhoods, gardens, parks, and shopping grounds. Keep attractive banks and short promenades where water remains.

Inspect before/after screenshots at the same seed, size, and zoom. Report water coverage and usable site area, including small maps. Update `CITY.md` so width means total channel width and its figures match the implementation.

### Give the city an asymmetric footprint

The rectangular grid may remain the storage and placement boundary. Create a separate development mask so the visible city occupies an irregular portion of that grid, with surrounding woodland, fields, open ground, or water. Use several connected neighbourhood clusters with uneven suburban extensions, green wedges, and waterfront edges. Vary the interior street patterns as well as the outer silhouette.

Keep essential developed areas connected through roads and bridges. Let development taper toward the countryside, with smaller buildings and more open parcels. Retain valid terrain beyond the settlement instead of filling every unused block with housing.

The earlier automatic road perimeter has been removed. Preserve that improvement. Generate roads from the planned network and provide complete connections where routes intentionally leave the settlement. Validate the entire network after clipping to the footprint: the latest sampled maps contain many disconnected fragments and isolated road tiles.

The next layout change must also address the interior: the current implementation clips long routes based on horizontal and vertical line positions, now with sine meanders on local streets. Plan main routes between centres and complete bridge crossings, then grow local streets attached to those routes within each neighbourhood. Use a compact centre grid, longer residential blocks, and suburban branches or loops. Retain the tile grid; use deliberate street patterns and contiguous open space to reduce rectangular repetition. After clipping, repair useful disconnected routes or remove redundant fragments before deriving final blocks. Avoid joining every stray road dot at the cost of usable land. Check that rasterisation does not create unintended junctions where separate routes become adjacent; a street bend must not render as a crossing.

### Render each road tile from its connections

Store road presence, class, and the neighbouring directions it connects to. Render straight segments, bends, T-junctions, four-way junctions, and endpoints from that connectivity. Most tiles along a route should read as continuous straight segments. Centre lines, curbs, and optional markings must follow the actual road directions.

The directional road renderer now follows neighbouring road tiles, fixing the earlier false crossroads. Preserve this behaviour. Nominal street spacing is now four to nine tiles, but meanders can reduce the usable distance between routes. Tiny remnants still arise between streets and at footprint/water edges; validate their usable shape before assigning a site.

### Derive varied blocks and sites from roads

Keep blocks/parcels derived from the explicit road network and development mask. Enforce minimum usable dimensions for the assigned site. Treat tiny leftover slivers as landscaping or parts of another site where appropriate. Support several block sizes, longer roads between junctions, and neighbourhood-specific patterns. A compact regular grid can fit downtown while suburbs, parks, and waterfront areas use more varied arrangements.

Reduce the visual dominance of roads. The latest sample reserves roughly 35.5–40.3% of developed land for roads. Measure coverage against developed land separately from the whole countryside map and review the rendered result when tuning spacing.

Allow parks and shopping-centre grounds to occupy larger or irregular sites where suitable. Keep site entrances and access deliberate. Plan a limited set of crossings over water and draw each bridge as a complete directional span, with adjoining deck tiles meeting without gaps.

## Important generation changes

### Separate area, growth, and density

Give a district independent target area, growth weight, and preferred density. A suburb can occupy a large area with small houses; a corporate core can occupy a compact area with tall buildings.

Use flexible area targets and minimum viable sizes for reserved sites. Count district area using usable parcels, excluding roads and water. Scale neighbourhood counts using available development land. Retry failed seed placements or use a bounded deterministic fallback so required places do not silently disappear.

Retain district ownership after generation. Give every parcel and building a district ID; keep a complete district record separately from the subset chosen for labels. Treat connectivity through the block adjacency model explicitly, so streets within a neighbourhood do not make its parcels appear disconnected.

### Build coherent density transitions

Use distance from the generated centre locations, neighbourhood density, and smooth spatial noise. Keep modest variation inside each area and gradual transitions at its edges.

For neighbouring residential parcels, including across local streets and district boundaries, enforce a maximum one-tier change: house → apartment → residential tower. Define the adjacency rule clearly; water-separated areas are not immediate neighbours. Apply the rule before choosing building kinds.

The current implementation already assigns density per block and applies residential smoothing. Preserve and verify those improvements while changing road and block geometry. Base downtown height on the actual downtown location rather than a fixed radius around the geometric map centre.

### Place amenities as actual destinations

Place shops and parks near housing using connected street/path access. Reserve visible, usable sites rather than relying only on seed probabilities. Include local shops as well as larger retail destinations where the family supports them. Use reachable households, nearby destinations, frontage, and existing competing centres to rank retail sites. Do not add a mall automatically to every district. Preserve a complete retail destination appropriate to the family: a connected high street and market square can satisfy the town requirement. Keep shopping-centre and public-space layouts legible at normal zoom.

Validate every cell in a multi-tile footprint against map bounds, roads, water, existing occupancy, and district ownership. Buildings should have street access or an explicit shared courtyard/path. Store complete occupancy and ownership data so selection and hover work over the whole footprint.

### Make settlement size affect character

Small settlements should favour coherent housing, a compact shopping/civic centre, a reachable employment role, and useful green space. Larger-city families can support secondary centres, apartment districts, several retail destinations, tower clusters, and extensive suburbs. Their required program is selected before assigning a terrain size.

Treat map dimensions and settlement character as separate concepts internally. Keep dimensions scalable and document whether they measure terrain tiles or parcels. The wider brief's configurable-size requirement remains relevant to eventual integration; a larger footprint alone is not this task's visual improvement.

### Generate a complete town as a distinct family

Use the smaller-city research to support market/service, historic visitor, university/institution, manufacturing/service, planned green, and working harbour towns through shared layout patterns. Start with a dry market/service town, then add planned green and institutional variants. A town's economic role, growth history, and landscape should explain its arrangement.

- Reserve a compact main centre, adjoining residential ensembles, ordinary shopping/services, a reachable work or institutional site, and shared green/civic space. A high street or market square is a complete shopping destination. Include apartments, a second centre, a mall, or a tower when the family and capacity justify them.
- Build housing in a few coherent episodes, with aligned frontage, rear gardens/courtyards, and quieter local streets. Support a school, clinic, community site, or playing ground as an ordinary destination. Preserve grounds and access when fitting buildings.
- Let the main work destination be a factory/workshop court, campus, medical institution, or modest office group. Represent an external service catchment as a simple attribute if needed; do not invent extra visible homes to explain every workplace or visitor shop.
- Connect a few purposeful approach routes and anchors, then add local access and pedestrian shortcuts. Preserve frontage between junctions and detect accidental junctions introduced by tile adjacency. Vary block depths and offset new streets while retaining useful earlier routes.
- Allow an off-centre centre and directional expansion. Compose countryside edges with gardens, hedges, fields, playing grounds, or woodland. Keep a substantial dry town footprint; water remains optional even for Dutch-inspired towns. Harbour/island layouts are specialised variants and must preserve complete neighbourhoods and bridge approaches.
- Treat prototype counts and water settings as tunable game composition choices. The research provides no universal residents-per-building ratio, road density, or national zoning percentages.

At labels-hidden overview and normal zoom, the town must read as an inhabited connected place with a centre, homes, work, everyday services, and a meaningful edge. Keep RIM's cyberpunk identity through materials, signs, lighting, and selected landmarks. A tower cluster is optional in town families.

## Architecture and rendering

Read [CITY_ARCHITECTURE.md](CITY_ARCHITECTURE.md) for the regional/era research, current renderer gaps, minimum building library, proposed data model, and implementation order. Review the [nine-pattern visual reference](review/city_architecture_2026-10-04/architecture_reference.png) alongside it; these are schematic design studies, not current game captures. The architecture inspection observed source changes from `CB19D9D5…` to `B44EC81F…`, including new market-hall/workshop kinds. Reinspect the current implementation and reuse work already present.

- Select a shared architectural family for each housing/street ensemble, including compatible materials, roof forms, eaves, and frontage rules. Apply small per-building variation within that family. Keep material and development era separate from district/use colour.
- Store the actual street-facing edge and entrance relationship. Replace uniform inset as the sole placement rule with front/rear/side clearances and shared-wall conditions. Align roof ridges, doors, shopfronts, and gardens to the site's orientation.
- Prioritise terraces, paired garden houses, shops with homes above, modest apartments, courtyard ensembles, civic halls, and workshops. Their silhouettes, entrances, and grounds must distinguish them. Keep taller corporate forms for suitable city families.
- Generate floors and facade bays deliberately; project openings onto their wall planes. Omit windows on shared party walls. Separate the shop ground floor from upper housing in both state and appearance.
- Preserve useful roof silhouettes and ensemble grouping at overview. Share architectural geometry/material data across live and baked drawing paths, with detail selected by projected size. Verify all four frontage directions, composite roofs, culling, depth order, and selection ownership.

- Give buildings visible setbacks and leave room for gardens, sidewalks, courtyards, and entrances. Coordinate roof silhouettes, facade rhythms, materials, and heights within a neighbourhood.
- Make setbacks depend on frontage and block form. Allow continuous street-facing buildings with rear courtyards or gardens; a symmetric gap around every building would defeat perimeter blocks and terraces. Preserve individual building/site identity for selection and future gameplay.
- Houses need recognizable roofs and domestic grounds. Apartments need balconies or a clear residential facade rhythm. Shops need storefronts and awnings. Shopping centres need a distinctive broad form and complete site layout. Corporate landmarks can use stronger silhouettes and selective neon accents.
- Use restrained material colours and zone lighting: warm homes, concentrated retail signs, cooler corporate highlights, and natural green spaces. Architecture and arrangement should also communicate function.
- Keep roads, bridge approaches, parks, and plazas visible through the skyline. Verify depth ordering, culling, hit geometry, and camera framing for large footprints and tall buildings.
- Place district labels inside their territory and avoid label collisions. Use stable, distinct neighbourhood names where helpful.
- Preserve pan, drag, zoom, Esc, hover, text scaling, and reduced motion. Reduced motion should freeze decorative animation while camera changes and hover still update correctly.
- Keep detail levels and culling appropriate to map size. Prioritize the visible city composition before adding optional cars, crowds, or other animated decoration.

## Suggested implementation milestones

1. Establish a continuous city on readable land, with adjoining neighbourhoods and connected streets. Demonstrate the layout with water disabled, then add restrained optional water while preserving usable sites and access. Preserve the asymmetric footprint and correct markings, resolve unusable block remnants, and reserve complete accessible sites.
2. Compose the selected family's skyline and density transitions; establish coherent housing and employment layouts, including suburban and apartment patterns where appropriate.
3. Build recognizable shopping-centre sites, public squares, connected parks, and waterfront treatment.
4. Add coordinated architectural variation and landscaping, then refine the rendered composition across seeds.

A milestone should produce a visibly improved city. Adjust site proportions, road spacing, and building scale from rendered evidence as needed.

## Verification and acceptance

Inspect the running game and capture overview and normal-zoom screenshots for several fixed seeds across all supported sizes. Review the images and revise layouts before declaring success.

The visual result is accepted when:

- The first impression is a continuous city on solid land. Buildings visibly belong to blocks and connected neighbourhoods, with readable ground and streets between them. Passing a water-percentage check alone does not satisfy this requirement.
- At an overview, the selected family's centre, housing, shopping, employment, and green space are recognizable without labels. City fixtures include their required apartment neighbourhoods and suburbs; the default cyberpunk city family also has a clear corporate cluster. Town fixtures satisfy the town program above.
- The developed city's outline is asymmetric, with an uneven suburban edge and visible surrounding landscape. The map has no automatic rectangular perimeter road.
- Water occupies a restrained part of the composition, with sufficient connected land for complete neighbourhoods. Small maps retain the selected family's required housing, retail, employment, and green-space program; optional water cannot displace these requirements.
- Streets contain long continuous stretches, bends, branches, and correctly drawn junctions. Straight road tiles do not display crossing markings.
- Neighbourhoods have visibly different block and street arrangements. Parks and shopping-centre grounds can exceed a single repeated square block.
- Bridges are complete spans with connected approaches and continuous decks.
- At normal zoom, site layouts, gardens, courtyards, entrances, streets, and building functions are readable.
- The skyline has coherent clusters and gradual transitions; houses and residential towers follow the defined adjacency rule.
- The shopping destination reads as a complete place with frontage, entrances, public space, and access appropriate to its form. A shopping street and square can satisfy this requirement; a building named `mall` is not required in every family.
- Different seeds produce distinct cities with the required places reliably present at an appropriate scale.

Run targeted generation checks for repeatability with the same seed/configuration, reciprocal road connections, correctly classified straight/corner/T/cross/endpoint tiles, bridge continuity, district connectivity, valid footprints, non-overlap, reserved site presence, road access, and density transitions. Flood-fill roads from the main network and require every retained road tile to be reachable, including cul-de-sacs. Require each occupied site to connect to that network directly or through a deliberate traversable path. A neighbour-count or reciprocal-edge check alone does not establish connectivity. Count usable park ground and complete retail sites separately from district labels. Report land shares separately from building counts. Use isolated verification fixtures that preserve player saves and settings.

Run the project's applicable Godot checks and launch the rendered game. If the normal project delivery workflow includes a Windows build, verify that build launches. State what was actually checked and provide screenshot locations; headless generation checks alone do not establish visual quality.

## Documentation and handoff

Update `CITY.md` and size labels to describe the final implementation accurately. Recheck its existing probability, width, height, density, and tree-count statements against code. Historical measurements of the earlier rectangular-grid generator are not verification of the current isometric implementation.

Finish with a concise report of the visible improvements, affected files, generation checks, rendered inspection, screenshot locations, and any remaining limitations.
