# RIM: towns and small cities up to 50,000 residents

Prepared 4 October 2026. This extends the Netherlands, France, and UK research and supplies implementation guidance for [CLAUDE_CITY.md](CLAUDE_CITY.md). It changes the proposed town generation rules; it does not change game code or constitute a new generator audit.

## Scope and evidence

The study examines **24 selected towns: eight in the Netherlands, eight in metropolitan France, and eight in the UK**, including all four UK nations. The sample covers historic market centres, manufacturing towns, university towns, ports, visitor destinations, and planned residential towns. It is a representative comparison, not a census of every settlement below 50,000.

Read the [24 town profiles](review/small_town_research_2026-10-04/TOWN_PROFILES.md) for sources, spatial relationships, and individual generation lessons. The [population register](review/small_town_research_2026-10-04/POPULATION_SOURCES.md) records each figure, geography, reference year, and source.

The population boundary matters. Dutch figures are for municipalities and provide upper bounds for the selected town cores; French figures are for communes; UK sources use several different town, parish, locality, and settlement boundaries. The selected figures are below 50,000 at their stated dates. This is not a claim that every wider commuting region or adjoining urban area is below 50,000, or that every figure is a 2026 population. Aberystwyth's council-reported figure has a boundary caveat. These data must not be used for cross-country density rankings.

This is qualitative research using official statistics, municipal plans, conservation studies, and public heritage sources. Existing urban structure and historical development are evidence; proposed projects remain proposals. The generator rules below are design inferences. No parcel-level land-use inventory, measured street-network statistics, zoning percentages, or calibrated population-to-tile conversion has been produced.

## What should change in RIM

For the buildings themselves, read [CITY_ARCHITECTURE.md](CITY_ARCHITECTURE.md) and its [visual pattern sheet](review/city_architecture_2026-10-04/architecture_reference.png). It connects the town layouts below to street-facing architecture, coherent roofs/materials, mixed shop/housing facades, gardens, and complete civic/work sites.

**Give a town a reason to exist, a compact centre, coherent housing, an employment pattern, and a countryside edge.** Reserve these places together before placing buildings. A small-town family can have a strong identity through a market hall, civic building, mill, station, campus, or hospital. A corporate tower cluster is optional in this family.

The three user complaints remain the priority:

- **Crossroads everywhere:** create a small hierarchy of through routes, neighbourhood access streets, and pedestrian links. Preserve stretches of frontage between junctions. Verify both the intended road graph and its tile representation.
- **Repeated rectangles:** use inherited routes, different block depths, offset junctions, asymmetric expansion, and purposeful open space. Locally regular streets can be convincing; Libourne and St Andrews show that historic towns can have deliberate street structures.
- **Buildings on water:** reserve a complete town on connected dry land first. Water is optional. Represent a river, coast, or working waterfront with a limited corridor or edge, while keeping room for housing, grounds, streets, and everyday services.

## The cases and what they contribute

Population details and source links are in the linked register and profiles. The roles below are analytical descriptions; a town can have several roles.

| Netherlands | Useful relationship for generation |
|---|---|
| Gorinchem | A fortified centre, later housing neighbourhoods, and employment outside the old core. |
| Culemborg | Historic central retail, separate neighbourhood shopping, and a large employment area. |
| Wageningen | A knowledge campus and employment sites connected to a distinct town centre. |
| Enkhuizen | Historic streets, harbours, residential expansion, and a concentrated shopping core. |
| Harlingen | A mixed historic centre and working port with different waterfront functions. |
| Doesburg | A small historic core followed by identifiable housing expansion episodes. |
| Lochem | An off-centre historic core, landscape constraints, and employment north of the canal. |
| Leusden | Planned residential neighbourhoods supported by two daily shopping centres. |

| France | Useful relationship for generation |
|---|---|
| Bayeux | A visitor destination with central shops and separate everyday peripheral retail. |
| Fougères | Distinct upper/lower historic areas and a later industrial layer. |
| Saumur | River-related quarters, historic institutions, and different neighbourhood histories. |
| Libourne | A planned bastide street pattern attached to an older river-port settlement. |
| Pontarlier | A compact core, mixed approach streets, housing, and distinct retail/employment sites. |
| Vitré | A historic commercial centre with a railway connection and employment areas. |
| Dax | Thermal institutions and accommodation alongside housing, retail, and station-related activity. |
| Sarlat-la-Canéda | A strong visitor/market centre, a later through street, and outlying neighbourhood life. |

| UK | Useful relationship for generation |
|---|---|
| Wells, England | Cathedral precinct, market, shopping street, and surrounding residential areas. |
| Frome, England | Numerous local character areas, meaningful settlement edges, and grouped housing. |
| Ludlow, England | Castle/market focus, a countryside setting, and services for a wider catchment. |
| Letchworth Garden City, England | Planned green housing, a town centre, and substantial employment premises. |
| Stirling, Scotland | A constrained historic core, narrow plots, later leafy residential streets, and lanes. |
| St Andrews, Scotland | Long historic streets with distinct frontage, institutional grounds, and smaller connections. |
| Aberystwyth, Wales | Coastal centre, national institutions, housing, and surrounding hills. |
| Enniskillen, Northern Ireland | An island town centre and wider service role; a specialised water setting. |

## How these towns acquired their structure

There is no single historical creation algorithm. Some layouts were deliberately planned; others accumulated through successive decisions. For RIM, a short sequence of development episodes can reproduce the resulting relationships without simulating centuries.

### 1. A founding activity establishes routes and a centre

A crossing, market, castle, religious institution, harbour, or planned employment project creates an initial destination. Early streets connect that destination to approaches from outside the town. Broad Street in Stirling developed as a market and administrative focus below the castle; Libourne's bastide added a planned structure beside an older settlement. These are different starting conditions. [Stirling City Heritage Trust](https://www.stirlingcityheritagetrust.org/explore-historic-stirling/broad-street), [Libourne municipal heritage history](https://www.libourne.fr/fileadmin/medias/Arborescence/Culturelle/Patrimoine/108132_Mairie_Libourne_Gazette_150x210-AR_16pages_v4.pdf).

**Inference:** choose a founding anchor and two or three meaningful approach directions as an initial prototype setting. Their positions should explain the first streets. Do not place the centre automatically at the grid midpoint.

### 2. Frontages and plots establish the everyday centre

Shopping occupies connected streets and squares; homes, services, yards, and institutional grounds occupy adjoining space. Wells' plan treats the High Street and its surrounding visitor destinations as related places. Culemborg distinguishes its main centre from neighbourhood shopping centres. [Wells Neighbourhood Plan](https://www.wells.gov.uk/userfiles/files/Neighbourhood%20Plan%20Files/Wells%20Neighbourhood%20Plan%20March%202023.pdf), [Culemborg economic vision](https://omgevingsvisie.culemborg.nl/onze-koers-richting-2040/economie/detail).

**Inference:** identify a short continuous shopping frontage before assigning individual shop buildings. Allow homes above shops and small offices among them. The street behind a shop may contain a courtyard or housing; it need not be another shopping street.

### 3. Housing grows in recognisable episodes

Doesburg's municipal history distinguishes Molenveld, postwar extensions, De Ooi, and later Beinum growth. Frome's design statement identifies 27 character areas, demonstrating that even a modest town contains several distinct local forms. [Doesburg history](https://www.doesburg.nl/geschiedenis-van-de-gemeente), [Frome Town Design Statement](https://www.frometowncouncil.gov.uk/council/frome-town-council/planning-for-frome/frome-town-design-statement/).

**Inference:** generate a few adjoining housing ensembles with consistent plot depth, frontage, roof scale, and garden arrangement. Vary the ensemble between neighbourhoods. Individual random building choices should remain subordinate to that structure. Twenty-seven research areas are not a request for 27 tiny game districts.

### 4. New employment and transport create additional anchors

Wageningen's adopted vision distinguishes knowledge locations and other work areas. Letchworth combines garden-city residential form with substantial industrial and office premises. [Wageningen environmental vision](https://lokaleregelgeving.overheid.nl/CVDR764733/1), [North Hertfordshire Economic Strategy, Letchworth portrait](https://democracy.north-herts.gov.uk/documents/s28978/Appendix%20A%20-%20North%20Hertfordshire%20Economic%20Strategy%20-%20Final.pdf).

**Inference:** employment form follows the town's role. A campus, workshop court, factory compound, medical institution, or modest office group can establish the main work destination. Reserve its access and grounds. Nearby housing and the main shopping street should remain reachable through the network.

### 5. Landscape and prior development steer later growth

Lochem's spatial study describes housing, industry, water, roads, and the Lochemse Berg as constraints around an unevenly positioned centre. Fougères' upper and lower historic areas reflect its particular terrain and river setting. [Lochem spatial analysis, appendix 2](https://www.lochem.nl/fileadmin/internet-doc/Wonen-Leven-Vervoer/visie/TOE_WOONVISIE_LOCHEM-ZWIEP.pdf), [Fougères public tourism office](https://www.destination-fougeres.bzh/la-destination/passion-patrimoine/plongez-dans-laventure-medievale/).

**Inference:** favour growth along selected accessible corridors; stop it at a meaningful green edge, slope constraint, work site, or landscape boundary. A flat renderer can express an unbuildable landscape reserve without implementing physical elevation. Add bends where these relationships justify them.

### 6. Selective reuse changes uses while retaining structure

Fougères documents the reuse of the Réhault factory; Culemborg proposes a future transition of part of Pavijen towards a station district while retaining other employment areas. The first is an existing reuse example; the second is a planning intention. [Fougères factory history](https://fougeres.fr/lactualite/le-mardi-des-archives-lhistoire-des-ateliers/), [Culemborg Pavijen vision](https://www.culemborg.nl/visie-op-pavijen).

**Inference:** an optional final episode may convert one established site while preserving its access, plot size, or distinctive building. This provides visual history without scattering incompatible buildings everywhere.

## Proposed town families

These are reusable combinations of patterns, not separate national generators. Country references guide materials and details after the spatial layout works.

| Family | Centre and shopping | Housing and employment | Landscape treatment |
|---|---|---|---|
| Market/service town | Market square and short mixed high street; daily grocery. | Adjoining homes, civic/service buildings, a modest workshop or employment site. | Fields, gardens, playing grounds, and uneven outward roads. Water optional. |
| Historic visitor town | Compact old core, landmark, visitor shops and ordinary daily services. | Homes in and around the centre; accommodation in selected groups; later residential extension. | A legible edge and pedestrian approaches; large attractions may be implied off-map. |
| University/institution town | Centre connected to a campus or major institution. | Student/ordinary housing, institutional grounds, selected research or service workplaces. | Green links and complete campus plots; terrain and water optional. |
| Manufacturing/service town | Modest centre and local services. | Worker housing or mixed housing, larger work plots, loading/service access, possible reused factory. | Employment near a suitable outward route; a buffer where the activity requires it. |
| Planned green town | Planned shopping/civic node; a secondary daily centre only if capacity supports it. | Coherent garden housing, apartments in selected locations, local jobs or a work area. | Connected open space, tree-lined streets, gardens, and pedestrian shortcuts. |
| Working harbour town | Mixed centre near an old harbour; separate working frontage. | Residential neighbourhoods on substantial land; sheds/workshops and service yards near port access. | Water at an edge, complete quays, and limited crossings. Larger sea/port areas can be off-map. |

A town may combine two roles. A large institution can coexist with a small centre; an attractive historic town can retain manufacturing. Do not derive a mandatory mall, ring road, airport, tower district, or second centre from a population threshold.

## Twenty concrete generator improvements

These are proposed changes to verify against the current source. P0 establishes the composition; P1 adds variety after P0 is visible and reliable.

| # | Priority | Improvement | Observable acceptance |
|---|---|---|---|
| 1 | P0 | Separate settlement family from map dimensions. | A larger grid can contain a low-rise town and countryside; a small grid can show a compressed urban centre. |
| 2 | P0 | Choose the town's economic/service role before zoning. | Each town has a coherent reason for its centre and main employment site. |
| 3 | P0 | Reserve one compact main centre before general infill. | A square or connected street concentration is recognisable with labels hidden. |
| 4 | P0 | Reserve shopping frontage as a connected sequence. | Shops share a street/square and entrances, with housing or yards behind. |
| 5 | P0 | Make a shopping street/square a complete retail destination. | Small-town fixtures pass retail acceptance without requiring a mall building. |
| 6 | P0 | Generate coherent residential ensembles. | Adjacent homes share setbacks, scale, garden structure, and street orientation. |
| 7 | P0 | Support mixed-use buildings and modest workplaces. | Work and shopping remain visible without a compulsory corporate skyline. |
| 8 | P0 | Construct a sparse route hierarchy before rasterisation. | Several buildings can face a street between actual junctions. |
| 9 | P0 | Add pedestrian shortcuts independently of vehicle roads. | Neighbourhoods remain accessible without spending a road tile on every connection. |
| 10 | P0 | Protect complete sites from road and water placement. | Homes, grounds, entrances, shopping, and park sites survive final placement. |
| 11 | P0 | Make dry land the default foundation of every family. | A complete inland fixture works with zero water; water variants retain complete neighbourhoods. |
| 12 | P0 | Validate accidental road connections after rasterisation. | Adjacent routes do not become an unplanned chain of junctions or leave severed side streets. |
| 13 | P1 | Add coherent growth episodes and inherited routes. | New neighbourhoods differ in form while connecting to retained earlier streets. |
| 14 | P1 | Allow off-centre centres and directional expansion. | The visible silhouette and density follow anchors and constraints rather than a central circle. |
| 15 | P1 | Use a countryside edge with functional landscape. | Gardens, hedges, fields, playing grounds, or woodland explain where development stops. |
| 16 | P1 | Distinguish daily shops, visitor retail, and bulky retail. | Each retail form has appropriate frontage and access; neighbourhoods do not all contain identical malls. |
| 17 | P1 | Model an external catchment as a simple town attribute. | A market, hospital, or institution can serve surrounding places without filling the map with extra homes. |
| 18 | P1 | Reserve ordinary civic and community amenities. | A school/clinic/community site or playing ground has usable access and visible grounds. |
| 19 | P1 | Add a bounded optional reuse episode. | One adapted work or institutional site adds history while retaining coherent surroundings. |
| 20 | P0 | Make required-site failures explicit and repair deterministically. | A failed placement triggers a bounded repair or simpler complete layout, with diagnostics and repeatable output. |

## A practical generation sequence

1. **Choose character and capacity.** Select town family, optional secondary role, terrain constraints, and required places. Real population is a reference for character; map cells and visible buildings are a separate representation budget.
2. **Reserve land.** Establish one substantial developable area and countryside/green edges. Reserve enough room for the centre, housing, employment, shared amenities, and their grounds. Fit optional water around this program.
3. **Place anchors.** Choose the centre and a limited number of employment/transport/civic destinations. A useful first prototype has one main centre, two to four housing ensembles, one work anchor, and one shared green/civic site, subject to capacity. These counts are proposed game settings, not measured town averages.
4. **Connect approaches and anchors.** Create a few through routes and add local access. Reserve adequate spacing for plots. Insert pedestrian connections where a full road is unnecessary.
5. **Grow neighbourhoods.** Attach coherent housing episodes to the existing routes. Use different block proportions and selectively offset new streets. Keep useful open space rather than filling every leftover cell.
6. **Assign frontage and sites.** Concentrate central shops, select homes above them, place quiet residential frontage, and fit a complete work site. Rank access using the street/path network, not only straight-line distance.
7. **Fit buildings and grounds.** Place entrances, rear gardens, courts, service space, and paths before decoration. If an ensemble represents several homes, preserve a documented selection and ownership model.
8. **Apply limited renewal.** Optionally change one eligible site while preserving its physical history. Keep the decision in a separate seeded phase.
9. **Validate and repair.** Check graph and tile connectivity, valid sites, reachable destinations, frontage continuity, and required program. Simplify optional water or extras before sacrificing a required neighbourhood.
10. **Inspect the rendering.** Check dry and restrained-water versions at the same seed and scale, with labels hidden. Roads, dry ground, yards, and entrances must remain legible in the cyberpunk lighting.

Do not establish a universal equation such as one building equals a fixed number of residents. A visible building may represent a single house, terrace ensemble, mixed-use block, or institution. Population-based realism requires a separate explicit capacity model if the game later needs it.

## Implementation order and acceptance

Start with a **dry market/service town**. Make its centre, houses, work site, gardens, and countryside boundary convincing before adding other families. Then produce a **planned green town** and an **institutional town** using the same underlying systems. A working-harbour family follows after dry-land composition and complete waterfront sites work.

Compare several fixed seeds at each supported map size. Record which required places were reserved and successfully placed, road/path reachability, junction counts, remaining usable site area, water coverage, and deterministic repair events. Report junction counts alongside network size and screenshots; there is no researched universal "correct" junction percentage here. Attribute any failure to the exact source version tested.

For a town fixture, acceptance requires a recognisable centre, an inhabited residential fabric, ordinary shopping/services, a reachable employment role, coherent grounds, and a meaningful edge. Apartments, a secondary retail centre, a waterfront, and a tower are conditional on the selected family and available capacity. For a large-city fixture, retain the larger-city requirements in the main brief. Both families must satisfy the same connectivity, valid-footprint, interaction, and rendering checks.

The [existing technical audit](review/city_gaps_2026-10-04/REVIEW.md) is dated and the implementation has changed since it ran. Recheck current code before treating an old failure as unresolved. Update `CITY.md` only after implementation and verification so it describes the actual generator.
