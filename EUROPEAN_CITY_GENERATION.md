# RIM: generation lessons from the Netherlands, France, and the UK

Prepared 4 October 2026. This is the implementation synthesis for [CLAUDE_CITY.md](CLAUDE_CITY.md). Country evidence is in [DUTCH_CITY_ANALYSIS.md](DUTCH_CITY_ANALYSIS.md), [FRANCE_CITY_ANALYSIS.md](FRANCE_CITY_ANALYSIS.md), and [UK_CITY_ANALYSIS.md](UK_CITY_ANALYSIS.md). The [dated RIM audit](review/city_gaps_2026-10-04/REVIEW.md) remains the technical baseline; inspect current code before implementation.

## Scope and conclusion

The Dutch study covers 32 municipalities selected by population. The France and UK extension uses a **representative sample**, selected to expose different growth patterns rather than provide an exhaustive population ranking: 12 French cities, 12 UK cities across all four nations, and Milton Keynes as an additional planned-city comparison. The French sample is in metropolitan France; overseas cities are not covered. The UK sample includes Belfast and excludes cities in the Republic of Ireland.

The subsequent [small-town study](SMALL_TOWN_ANALYSIS.md) adds 24 selected examples below 50,000 in their stated population geographies, eight per country. Its [population register](review/small_town_research_2026-10-04/POPULATION_SOURCES.md) distinguishes municipality, commune, parish, locality, and settlement figures and records unresolved boundary details. Its [profiles](review/small_town_research_2026-10-04/TOWN_PROFILES.md) supply the sources. This extends the pattern library to town centres, coherent low-rise housing, ordinary services, institutional/work compounds, and countryside edges.

All three studies are qualitative. They distinguish documented history/existing conditions, plans, and our inferred generation rules. No citywide zoning polygons, land-use percentages, or calibrated national coefficients have been produced.

**Generate urban relationships and development history before choosing building appearances.** The useful output of this research is a library of compatible street, block, frontage, housing, centre, and landscape patterns. A country name should not determine a whole map. Cities within each country differ, and many patterns recur across borders.

## What the additional research changes

The companion [architecture guide](CITY_ARCHITECTURE.md) translates these street/block patterns into regional and development-era building families. It includes a [visual pattern sheet](review/city_architecture_2026-10-04/architecture_reference.png), frontage and roof rules, a proposed minimum building library, and checks for both live and baked rendering.

The linked country studies provide the source evidence for these design inferences.

| Pattern to support | Why it helps RIM | Required spatial representation |
|---|---|---|
| Continuous apartment frontage | Buildings define a street instead of appearing as isolated boxes. | Street-facing parcel edges, aligned building lines, corners, doors, and selected ground-floor shops. |
| Perimeter block with an inner courtyard | Creates an identifiable neighbourhood unit with useful open space. | Several buildings or wings around reserved grounds, with explicit access and ownership. |
| Terraced housing | Makes ordinary housing and suburbs coherent without requiring towers. | Repeated façade rhythm, connected rows, entrances, and rear gardens. |
| High street | Gives a neighbourhood a recognisable shopping and service spine. | A connected frontage corridor between destinations, possibly crossing district boundaries. |
| Boulevard | Adds a deliberate main route and public-space sequence. | Sustained alignment, coordinated frontage, trees and squares; vehicle-road width is budgeted separately. |
| Industrial quarter and selective reuse | Adds a legible earlier layer and varied work environments. | Larger plots, freight access, retained routes/structures, and limited conversion to mixed use. |
| Garden suburb or planned housing district | Creates a quieter edge with local services and meaningful green space. | Neighbourhood-scale layout, gardens, short access streets, pedestrian connections, and a local centre. |
| Several employment nodes | Avoids equating all work with the centre's tallest tower. | Separate office, institutional, campus, production, and logistics roles where space permits. |

These patterns should expand the existing Dutch-derived generator, not replace it with three disconnected systems.

## Correct the three visible problems

### Roads that look like crossroads

The audited version already derives directional markings from neighbouring road cells. Preserve that fix. Next distinguish the **intended route graph**, its **rasterised tiles**, and **rendered junction areas**. A degree-two bend is not an intersection. Consecutive tiles belonging to one junction should read as one junction, not a row of independent crosses.

Prevent separate routes from becoming an accidental junction when rasterisation places them beside each other. Keep enough separation or explicitly merge them into a planned junction, then recheck the resulting blocks. Junction frequency should follow route connections and block structure rather than decoration frequency.

### Repeated rectangles

The lesson is not to eliminate straight streets. Use different block proportions, selected changes of alignment, inherited routes, squares, longer terraced streets, and coherent neighbourhood boundaries. Keep some regular districts so the irregular parts have a spatial context.

On the current tile grid, start with varied orthogonal blocks, staggered junctions, short grouped turns, and deliberate branching. Do not promise convincing diagonal boulevards using one-cell zigzags. True oblique frontages would require additional geometry, occupancy, drawing, and selection work; they are a later option.

### Buildings that seem to float on water

Demonstrate every new block/housing pattern on dry land first. Preserve enough contiguous space for complete neighbourhoods, grounds, and access before optional water is introduced. A river or coast may be represented by a narrow corridor or map edge; large ports and open sea can be outside the scene.

Visible paving, gardens, foundations, courtyards, connected sidewalks, and restrained water colour are as important as water area. The latest audit found no literal buildings on water; the visual complaint still requires a better composition. Do not make a river mandatory because several reference cities happen to have one.

## A compact implementation model

Choose the settlement program independently of map dimensions. For town families, prioritise a compact centre, adjoining housing, ordinary retail/services, a reachable employment anchor, and usable green space. A shopping street and square can provide the complete retail destination. Apartments, additional centres, malls, and tower clusters depend on the selected family and capacity. Start the town work with a dry market/service fixture, then add planned green and institutional variants; the small-town study gives twenty concrete improvements and acceptance criteria.

Keep the staged pipeline from `DUTCH_CITY_ANALYSIS.md`, with these refinements:

1. Choose the intended city character, map capacity, and a limited set of required places.
2. Reserve continuous usable land, important open space, and optional landscape constraints.
3. Place a historic/civic centre and selected transport or employment anchors. Distinguish the main shopping destination from the office skyline.
4. Connect the anchors, then grow housing neighbourhoods with coherent eras and block patterns. Reserve main retail frontage and local service sites before infill.
5. Rasterise and validate routes; derive blocks that still have usable proportions. Repair geometry before detailed building placement.
6. Choose each block's arrangement: perimeter block, terrace rows, apartment ensemble, garden suburb, mixed high street, or work site.
7. Reserve frontage, entrances, courtyard/garden space, paths, and service access. Fit buildings to the resulting site, retaining stable IDs.
8. Add a limited later redevelopment episode where appropriate, preserving some earlier routes or landmarks.
9. Check topology, complete sites, required destinations, and composition; repair deterministically within a bounded budget.
10. Render and inspect the result in both detailed and batched paths, with labels hidden at normal zoom.

Keep changes to decoration independent from layout randomness so an extra tree does not regenerate all roads. Keep the number of systems proportional to the tiny scene: a transport anchor need not imply a working railway simulator, and an industrial edge need not contain an entire port.

### Data that must remain separate

| Concepts | Reason |
|---|---|
| Neighbourhood, block, site, and building identity | One neighbourhood has several uses; one site can contain several buildings. |
| Centre role and building use | A historic centre, shopping destination, and office cluster can occupy different places. |
| Ground-floor and upper-floor use | Homes above shops should exist in state and rendering, not only in a description. |
| Density, coverage, height, and housing form | Terraces and perimeter blocks can provide substantial housing without tall towers. |
| Frontage, entrance, rear edge, and service edge | Symmetric building inset cannot represent street-facing rows with rear gardens. |
| Public paths, private grounds, and decorative paving | A visible courtyard or green tile is not automatically traversable or public. |
| Route graph, road tiles, footpaths, and streetscape | A wide-looking boulevard need not consume several full vehicle-road tiles. |
| Growth era, block pattern, and architecture | A coherent place needs compatible structure; every building need not be identical. |

Extend current records instead of duplicating ownership systems. If a visual terrace ensemble stands for several homes, document whether it is one selectable site or several logical buildings. Do not create decorative front doors that imply nonexistent gameplay entities.

### Current implementation traps

These observations refer to the audited `scripts/city.gd` version; recheck before editing:

The source changed during this research; `5D282035…` was observed after the audited `74641F82…` version. The country studies do not establish which technical issues remain in that newer implementation, and no new generation benchmark was run. Preserve concurrent code changes and verify the current behaviour first.

- `_place()` represents rectangular lots with an inset; frontage direction and rear grounds need explicit representation.
- `_assign_districts()` groups by role. A mixed high street must not split one residential neighbourhood into unrelated identities merely because its ground floors contain shops.
- `_block_adjacency()` assumes one intervening road cell. If boulevard occupancy is widened, replace that assumption with appropriate shared-frontage/access relationships.
- `_fill_shopping()` favours a mall-shaped solution. Acceptance should recognise a complete shopping street and square as another valid retail destination.
- The normal and batched renderers must both display the features that make terraces, courtyards, entrances, and storefronts legible.

## Three proposed demonstration maps

These are small game compositions for review, not reconstructions of any real city or calibrated national templates.

| Demonstration | Composition | What it proves |
|---|---|---|
| Mixed centre and perimeter housing | A civic/shopping square, connected apartment frontages, courtyard blocks, a nearby office node, and a garden suburb. | The centre reads clearly without every building being a tower; grounds form complete blocks. |
| High street and terraced neighbourhoods | A purposeful shopping route between two destinations, quieter parallel housing rows, rear gardens, a park, and a modest work quarter. | A retail destination can span several blocks; dense housing can be low-rise. |
| Planned green district with redevelopment | A larger green structure, several coherent housing groups, a district centre, and one reused industrial site. | Straight streets and planned repetition can remain attractive when neighbourhood roles and open space are deliberate. |

For each, capture a dry version and a restrained-water version under controlled configuration. Preserve the default cyberpunk family's compact corporate skyline, but give it a distinct employment role. Other families may use a mid-rise centre; tower count is not the definition of urban quality.

## Acceptance and priorities

**First:** retain correct markings, repair the intended road network, and guarantee complete accessible housing, retail, and park sites on readable land. The country research should not postpone the already audited connectivity work.

**Then:** implement frontage-aware lots, one convincing terrace arrangement, one perimeter-block arrangement, and a high-street destination. Inspect them at the actual scene scale before adding more variations.

**Finally:** introduce richer growth histories, secondary centres, and optional terrain or transport features.

Track the intended graph's junctions separately from raster neighbour counts; road area separately from public space; usable park area separately from tree count; and retail destinations separately from buildings named `mall`. Check entrance reachability, frontage orientation, reserved grounds, route continuity, and accidental road contacts. Compare land shares and screenshots across fixed seeds and all map sizes.

The current ordinary-housing transition rule remains a game design constraint. Evaluate residential height/massing separately from nominal density so compact low-rise housing is not incorrectly treated as a tower tier. Office landmarks should be deliberate exceptions with suitable sites, not random residential jumps.

## How to extend this into measured research

Do not compare French communes, UK council districts, and Dutch municipalities as if their boundaries describe equivalent pieces of city. Choose comparable urban extents or representative neighbourhood samples, record the observation date, and distinguish the built footprint from the commuting region.

| Source | What it can contribute | Limitation to retain |
|---|---|---|
| [INSEE urban-unit definition](https://www.insee.fr/fr/metadonnees/definition/c1501) and [urban attraction areas](https://www.insee.fr/fr/statistiques/5039879) | Separate built continuity from the wider functional urban area. | Neither should be silently substituted for the commune boundary or for a RIM map. |
| [IGN BD TOPO catalogue](https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-TOPO) | Candidate source for French physical urban geometry. | Verify the selected release's layers and specifications before extraction; no extraction was performed here. |
| [INSEE BPE 2025 geolocated facilities](https://www.insee.fr/fr/statistiques/8217525) | Locate shops, services, education, health, and other facilities for catchment studies. | An equipment/service record is not automatically a unique building or a complete frontage survey; some coordinates are withheld. |
| [ONS built-up-area analysis, England and Wales](https://www.ons.gov.uk/peoplepopulationandcommunity/housing/articles/townsandcitiescharacteristicsofbuiltupareasenglandandwales/census2021) | Compare physical settlement geography and housing characteristics. | London has special treatment; the article's method differs from its 2011 predecessor. It does not cover all four UK nations uniformly. |
| [National Records of Scotland settlement/locality method](https://www.nrscotland.gov.uk/publications/geography-settlement-and-localities-information-note/) | Select Scottish settlements and named localities. | This geography differs from administrative council areas and from the England/Wales method. |
| [NISRA settlement documentation](https://www.nisra.gov.uk/publications/settlement-2015-documentation) | Define Northern Ireland study areas with documented boundaries. | Record which boundary vintage and population vintage are combined. |
| [OS OpenMap Local](https://www.ordnancesurvey.co.uk/products/os-open-map-local) and [OS open products](https://www.ordnancesurvey.co.uk/products/open-data) | Physical mapping, roads, green space, and related layers for Great Britain. | Generalised map geometry is not automatically a fully routable graph or complete land-use classification. Great Britain excludes Northern Ireland. |
| [OSNI open-data products](https://www.nidirect.gov.uk/articles/osni-open-data-product-list) | Northern Ireland mapping resources. | Choose a scale suitable for the measurement and verify available feature coverage. |

Measure comparable samples of historic centres, ordinary housing, suburbs, shopping destinations, and work areas. Useful outputs are distributions of block dimensions, frontage continuity, building coverage, housing form, junction spacing, park accessibility, and walking distance to shops. Keep built condition, registered use, permitted use, planned use, and inferred use as different evidence fields. The research documents supply hypotheses; they do not supply measured parameter values.
