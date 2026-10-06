# UK city structure: research and generation rules for RIM

Prepared 4 October 2026. Read alongside [CLAUDE_CITY.md](CLAUDE_CITY.md), [DUTCH_CITY_ANALYSIS.md](DUTCH_CITY_ANALYSIS.md), and the [current generator audit](review/city_gaps_2026-10-04/REVIEW.md).

The combined implementation decisions and cross-country measurement method are in [EUROPEAN_CITY_GENERATION.md](EUROPEAN_CITY_GENERATION.md). Use that synthesis to resolve differences between country-specific examples and the game's scale.

## Scope and evidence

This is a qualitative study of **12 representative cities across all four UK nations**, plus Milton Keynes as a planned-city comparison. England: London, Birmingham, Manchester, Liverpool, Leeds, Sheffield, Bristol, Newcastle upon Tyne, and Milton Keynes. Scotland: Edinburgh and Glasgow. Wales: Cardiff. Northern Ireland: Belfast. This is neither an exhaustive list nor a population ranking. A council boundary, urban settlement, and metropolitan region describe different areas; their populations or land shares must not be compared as interchangeable units.

The sources are municipal character assessments, planning documents, heritage bodies, and museum histories. Historical descriptions establish growth processes; planning documents supply both descriptions and future intentions. Proposals below are explicitly identified where relevant. No parcel-level GIS measurements, land-use percentages, or representative street statistics have been calculated. The generation rules are our design inferences, not algorithms used to create these cities.

The strongest lesson for RIM is **a city assembled from neighbourhoods with different origins, linked by a hierarchy of streets and centres**. UK examples strengthen the case for continuous residential streets, high streets, station districts, public squares, and reused industrial buildings. They also show why removing every rectangle would be a mistake: a locally coherent grid can give a district identity.

## Three cities in depth

### London: several economic centres and many everyday centres

**Employment and shopping.** London's central economy includes different concentrations rather than one uniform business zone. The City of London and Northern Isle of Dogs/Canary Wharf are major business locations; the West End combines offices, shopping, culture, education, and visitors. The 2021 evidence report describes these existing roles, without implying that every parcel has the same use. [GLA: commercial-location evidence, section 3.4](https://www.london.gov.uk/sites/default/files/strategic_evidence_to_support_commercial_to_residential_article_4s_in_london_july_2021_final_report.pdf).

The London Plan's network distinguishes international, metropolitan, major, and district centres. Outer centres such as Croydon or Bromley supplement central London; they are not merely residential land waiting to reach the centre. Treat this as a documented hierarchy and classification, not proof that all neighbourhoods enjoy equally good services. [GLA: 2021 town-centre network](https://www.london.gov.uk/programmes-strategies/planning/london-plan/the-london-plan-2021-online/annex-1-town-centre-network).

**Housing and growth.** London's housing vocabulary includes terraces, mansion blocks, garden suburbs, detached and semi-detached houses, and later estates. That vocabulary is documented in Historic England's character thesaurus; it does not supply their citywide proportions. Underground rail connected expanding suburbs with the centre, changing which locations could function as residential districts. [Historic England: London character types](https://historicengland.org.uk/research/methods/characterisation/historic-landscape-characterisation/london-thesaurus/), [London Museum: Victorian underground railway](https://www.londonmuseum.org.uk/collections/london-stories/building-victorian-underground-railway/).

**Spatial consequence.** There are residential streets inside the central area as well as large employment concentrations outside the historic core. The Plan also recognises essential industrial, distribution, maintenance, and servicing activities supporting central functions. A convincing city needs working back streets and service yards alongside its attractive frontages. [GLA: spatial development, SD4 and supporting text](https://www.london.gov.uk/programmes-strategies/planning/london-plan/the-london-plan-2021-online/chapter-2-spatial-development-patterns).

**RIM translation.** Generate an older mixed centre, a distinct employment anchor, and smaller high streets serving coherent housing catchments. Connect them before subdividing land. Let a main street carry shops while its side streets hold homes and gardens. Represent rail access with an abstract transit anchor if full railway simulation is outside scope. Centrality should depend on reachable destinations, not distance from the map's midpoint.

### Birmingham: productive quarters, retail heart, and contrasting suburbs

**Central structure.** Birmingham's 2045 framework identifies a city heart including Bull Ring, Colmore Business District, Snowhill, and other quarters, surrounded by named neighbourhoods such as Digbeth, Jewellery Quarter, Ladywood, and Balsall Heath. These are useful spatial identities; the framework's regeneration ambitions are future policy. [Birmingham: Central Birmingham Framework 2045](https://www.birmingham.gov.uk/info/50273/our_future_city_plan_ofcp/2303/our_future_city_-_central_birmingham_framework_2045).

**Formation.** Jewellery Quarter began as a planned residential area and accumulated workshops and manufacturing premises. Buildings expanded into rear plots and courtyards. Its later ring road severed connections with the central core. The important causal relationship is between plot form, productive work, and transport barriers: the quarter cannot be recreated merely by changing tower colour. [Birmingham: Jewellery Quarter design guide, historical context](https://www.birmingham.gov.uk/download/downloads/id/29821/appendix_1_-_design_in_the_jewellery_quarter_2022-2023.pdf).

Digbeth offers another industrial inheritance supporting creative businesses and cultural activity. A manufacturing origin can therefore remain legible after its economic role changes. [Birmingham: Digbeth and the Cultural Quarter](https://growth.birmingham.gov.uk/info/2/discover/7/major-developments-brum/6).

**Residential contrast.** Bournville's late nineteenth-century estate differs from surrounding districts through semi-detached houses, generous open space, and a coordinated architectural vocabulary. This supplies a specific garden-suburb model; it is not a description of all Birmingham housing. [Birmingham: Bournville character appraisal](https://www.birmingham.gov.uk/download/downloads/id/1264/bournville_village_conservation_area_designation_and_article_42_designation_reports.pdf).

**RIM translation.** Put the main shopping destination near, but distinguishable from, the office quarter. Create one smaller workshop district with enclosed plots, loading access, and reused buildings. Add a coherent residential ensemble with different setbacks and greenery. Where an arterial separates districts, provide purposeful crossings connected to entrances and destinations. More road tiles alone do not improve integration.

### Manchester: industry creates a framework that later uses inherit

**Historical sequence.** Ancoats streets were laid out in the late eighteenth century. The expected transport advantage of the Rochdale Canal encouraged mill construction, followed by extensive industrial development and workers' housing. Transport infrastructure, employment, and residential demand reinforced one another. [Manchester: Ancoats history](https://www.manchester.gov.uk/parks-leisure-and-the-arts/parks-playgrounds-allotments-and-open-spaces/conservation-areas/introduction24/history).

The municipal public-realm study identifies a fine-grained industrial street grid, canal infrastructure, mills, warehouses, red brick, and framed views as important surviving characteristics. This is an explicit example of a believable rectangular district. Its character comes from building-to-street relationships and inherited sites, rather than a uniformly rectangular whole city. [Manchester: Ancoats Poland Street public-realm strategy, section 3.3](https://www.manchester.gov.uk/download/downloads/id/28585/ancoats_poland_street_zone_public_realm_strategy_april_2022.pdf).

**Jobs, housing, and shops.** The council distinguishes the Central Business District, Spinningfields, Retail Core, Northern Quarter, and Oxford Road Corridor. Its 2009-12 plan describes the Market Street/Arndale shopping concentration and complementary commercial activity elsewhere; use that document for the historical spatial relationship, not current retail rankings or statistics. [Manchester: central regeneration areas](https://www.manchester.gov.uk/planning-and-regeneration/regeneration/central-manchester-regeneration), [2009-12 city-centre plan: retail core](https://www.manchester.gov.uk/download/downloads/id/27366/city_centre_strategic_plan_2009-12.pdf).

Ancoats now contains apartments, shops, eateries, and small businesses. Further Poland Street development is described as the next phase, so proposed homes must not be counted as already built. [Manchester: Ancoats regeneration](https://www.manchester.gov.uk/planning-and-regeneration/regeneration/projects-outside-the-city-centre/ancoats).

**RIM translation.** Preserve an industrial street skeleton, replace selected sites with apartments or offices, and retain recognisable warehouses. Assign retail to a connected frontage sequence and civic spaces, not isolated random buildings. Different phases may share streets while differing in footprint, height, materials, and ground-floor use. A canal is one optional historical trace; an entirely dry industrial-city preset remains plausible for a compressed game scene.

## Other cities: patterns worth retaining

### Liverpool: a landward city attached to a waterfront economy

Liverpool's housing character study describes a western waterfront corridor with former industrial and dock land, converted warehouses, newer apartments, and contrasting southern residential forms. The draft local plan also records terraced streets and Victorian parks as elements of the city's existing identity. The draft status concerns its proposed policies, not a claim that those historic forms are future construction. [Housing characterisation study](https://liverpool.citizenspace.com/planning/liverpool-housing-design-guide/supporting_documents/appendix-1b_liverpool-hdg_characterisation-study_rev01_final_251006_low-respdf-1), [draft plan, chapter 13](https://liverpool.citizenspace.com/planning/draftlocalplan2025-2041/supporting_documents/local-plan-whole-documentpdf).

The government's 2024 regeneration report distinguishes the Knowledge Quarter, retail/cultural areas, and Fabric District while identifying future opportunities. **Rule:** connect a waterfront employment/reuse strip to inland housing and separate commercial destinations; keep the river at an edge of the composition instead of fragmenting the entire landmass. [Liverpool strategic futures report](https://www.gov.uk/government/publications/liverpool-strategic-futures-advisory-panel-final-report/liverpool-strategic-futures-advisory-panel-final-report).

### Leeds: connect the business, shopping, station, and residential edges

The council identifies a pedestrian retail core around Commercial Street/Lands Lane and a route through Bond Court joining the legal/financial district, shopping area, and station. Its South Bank planning statement describes land south of the Aire linking the older centre, Holbeck, Beeston Hill, Hunslet, and the Aire Valley; redevelopment and a park were proposals in that historical document. [Leeds: city-centre spaces](https://www.leeds.gov.uk/commercial-opportunities/city-centre-promotional-and-event-spaces), [South Bank planning statement](https://www.leeds.gov.uk/docs/South%20Bank%20planning%20statement%20ADOPTED%20web%20LR.pdf).

**Rule:** give each central destination a role, then create usable pedestrian connections between them. A new mixed quarter should connect surrounding residential areas as well as its own buildings. Do not import obsolete transport assumptions from older plans as present facts.

### Sheffield: terrain orders industry, landmarks, and streets

The urban design compendium describes an older settlement extending along higher ground and industry concentrated in river valleys. The council's more recent city-centre framework differentiates Cathedral/University, Kelham/Neepsend, retail areas, and other neighbourhoods, with residential growth and redevelopment proposed for selected locations. [Sheffield: urban design compendium, topography](https://www.sheffield.gov.uk/sites/default/files/2022-07/urban-design-compendium-complete.pdf), [priority neighbourhood frameworks](https://www.sheffield.gov.uk/sites/default/files/2023-03/city_centre_priority_neighbourhood_frameworks.pdf).

**Rule:** route important streets along plausible slopes and crossings; cluster larger productive plots in a valley or corridor and place landmarks where they are visible. Even a flat renderer can imply this structure through orientation, green corridors, and sightlines. Curves should express constraints or destinations.

### Bristol: harbour reuse alongside an independent retail centre

Bristol's conservation appraisal documents the harbour's change from industrial backland to connected recreation space. The 2023 publication local plan describes Cabot Circus as a major shopping destination, institutional employment, and an established mixed harbour area; its policy programme remains distinct from these baseline descriptions. [Bristol: City Docks appraisal, section 6](https://www.bristol.gov.uk/files/documents/2926-city-docks-conservation-area-appraisal), [2023 publication local plan, DS1](https://services.bristol.gov.uk/files/documents/6894-bristol-local-plan-main-document-publication-version-nov-2023).

Temple Quarter's framework proposes mixed development around station infrastructure while saying new retail should complement the centre. **Rule:** a waterfront neighbourhood needs homes, employment, paths, and public spaces; it need not receive another major mall. Give its water a continuous bank and navigable public edge. [Temple Quarter framework](https://www.bristol.gov.uk/ask/projects/temple-quarter/development-framework).

### Newcastle upon Tyne: historic routes plus a planned commercial intervention

Newcastle's council history describes medieval streets, markets, and quayside followed by Grainger's nineteenth-century transformation of the commercial centre. South Jesmond provides another coherent layer: Victorian terraces and villas in a mature landscape, with some houses later converted to other uses. [Newcastle: city history](https://www.newcastle.gov.uk/our-city/history-and-heritage), [municipal historic environment record: South Jesmond](https://sitelines.newcastle.gov.uk/SMR/11418).

**Rule:** retain a few older through-routes, insert a formally composed commercial district, and attach residential ensembles with their own plot depth and greenery. New development can alter use while retaining the street and building shell. A neighbourhood should have more internal consistency than the city as a whole.

### Edinburgh: two strong geometries within one city

Historic Environment Scotland identifies the contrast between medieval Old Town and planned New Town as fundamental to Edinburgh. The municipal appraisal describes the New Town's coordinated buildings and integrated gardens. Its retail baseline places the core around Princes Street and George Street, showing that present commercial use can occupy an inherited formal townscape. [HES: Old and New Towns](https://www.historicenvironment.scot/protect-and-care/protected-historic-places/world-heritage-sites/old-and-new-towns-of-edinburgh/), [New Town appraisal](https://www.edinburgh.gov.uk/downloads/file/23392/new-town-conservation-area-character-appraisal), [city-centre environmental baseline](https://www.edinburgh.gov.uk/downloads/file/30051/strategic-environmental-assessment).

**Rule:** contrast a compact irregular quarter with a deliberate formal expansion, separated or joined by meaningful open space. Use coordinated terraces, tenements, squares, and gardens. Randomly rotating each individual building would destroy the ensemble that makes this pattern readable.

### Glasgow: dense urban housing and a coherent grid

A municipal planning assessment describes the Business District/Blythswood area's dense commercial and retail fabric with a coherent grid and generally consistent building scale. Historic Environment Scotland explains tenements as multi-storey housing with shared stairs and rear greens, sometimes with ground-floor shops. Such housing spans different social and architectural settings. [Glasgow planning assessment: character context](https://onlineservices.glasgow.gov.uk/councillorsandcommittees/viewSelectedDocument.asp?c=P62AFQDNDXT1NTZ3ZL), [HES: Scottish urban housing](https://blog.historicenvironment.scot/2020/09/urban-housing-scotland/).

**Rule:** use attached perimeter buildings and shared rear space to produce dense housing without isolated towers. Maintain a district-scale grid where appropriate, but vary block dimensions, uses, frontage and public spaces. The objective is fewer meaningless repetitions, not a ban on right angles.

### Cardiff: port-led growth and neighbourhood shopping

The city-centre appraisal connects nineteenth-century dock/rail expansion with substantial growth of surrounding residential suburbs. The Royal Commission describes Butetown's combination of docks, warehouses, residential streets, and commercial buildings, including housing around Mount Stuart Square. Cardiff Council separately describes community shopping centres as local combinations of shops, businesses, services, and facilities. [Cardiff: city-centre historical appraisal](https://www.caerdydd.gov.uk/ENG/resident/Planning/Documents/Cathays%20Park-A.pdf), [RCAHMW: Cardiff Bay history](https://rcahmw.gov.uk/cardiff-bay-a-constantly-changing-environment-part-i/), [Cardiff: community shopping centres](https://www.cardiff.gov.uk/shoppingcentreregeneration).

**Rule:** let a port or employer generate nearby housing and local centres. Preserve a land connection between the main centre and waterfront district. Represent a large bay beyond the playable edge when its full area would displace neighbourhoods.

### Belfast: an employment quarter adjacent to distinct communities

The council's 2016 Linen Quarter study describes a grid south of City Hall, inherited linen-industry buildings, an office concentration, and surrounding communities including Donegall Pass, the Markets, and Sandy Row. It distinguishes the retail focus farther north/east and identifies road barriers between places. Its proposed transport-hub and public-space improvements are historical proposals, not a present completion report. [Belfast: Linen Quarter analysis, especially sections 2.5-3.12](https://www.belfastcity.gov.uk/documents/the-linen-quarter-vision-and-guidance).

**Rule:** give a business quarter an inherited street scale, landmarks, active ground floors, and routes into nearby housing. Evaluate whether residents can actually cross its bordering road. A perfectly connected road graph can coexist with poor pedestrian access, so both networks need validation.

### Milton Keynes: an intentional hierarchy, not one road pattern everywhere

The 2017 Plan:MK document describes existing grid roads carrying through movement separately from streets within residential and employment grid squares. The complementary redway network provides walking/cycling links and separated crossings. It also identifies central and local centres with different roles. These descriptions are useful even though that document's new development policies were proposals. [Milton Keynes: 2017 Plan:MK, transport chapter and local-centre appendix](https://www.milton-keynes.gov.uk/sites/default/files/2022-01/Proposed%20Submission%20PlanMK%20October%202017%20MKSUB001.pdf).

**Rule:** a planned-city preset may deliberately use a coarse distributor grid with different neighbourhood streets inside it. Pedestrian connections must not disappear simply because local roads do not join. Do not shrink every distributor junction until every game road tile becomes a crossroads.

## Twelve improvements to carry into the generator

These are inferred implementation recommendations. No numeric thresholds below should be treated as measured UK averages.

1. **Generate a street graph before road tiles.** Store route segments, actual junction nodes, street class, and access permissions. Raster adjacency alone must not create intersection markings.
2. **Choose a district street grammar.** Use irregular old cores, industrial grids, formal terraces/squares, garden suburbs, or planned neighbourhoods. Join them with deliberate transition blocks.
3. **Separate junction frequency from tile resolution.** A long street segment can occupy many tiles while containing no intersection. Collapse raster stair-step bends into their parent segment when classifying junctions.
4. **Give homes street frontage and usable rear space.** Support terraces, tenements, perimeter blocks, semi-detached houses, gardens, and courts. A suburb is an ensemble of plots and amenities.
5. **Build shops along selected streets.** Generate contiguous active frontage, small centres, markets, and occasional larger destinations. Assign catchments through reachable paths; do not put a mall in every district.
6. **Separate office, productive, institutional, and retail employment.** Their footprints, servicing, preferred neighbours, and transport requirements differ.
7. **Allow mixed use by floor.** A shop beneath flats remains a housing building as well as a commercial frontage. Avoid exclusive district-wide use assignments.
8. **Preserve earlier phases.** Store creation era, original site role, and later reuse. Selective redevelopment should retain some routes, plot boundaries, landmarks, and warehouses.
9. **Make crossings first-class infrastructure.** Reserve bridges, approaches, arterial crossings, and station exits before buildings. Validate pedestrian accessibility separately from vehicle connectivity.
10. **Reserve parks, squares, and rear greens before filling plots.** Their size and enclosure should match their role. A leftover grass tile is not a neighbourhood park.
11. **Constrain water by city type and map capacity.** Use a narrow connected corridor or waterfront edge only where a complete landward city still fits. Maintain clearly rendered continuous ground under buildings and streets.
12. **Validate city composition in screenshots.** At normal zoom, the viewer should distinguish housing, shopping, employment, public space, and the route between them without relying on labels. Inspect both dry and water-enabled seeds.

## A practical generation sequence

Choose an archetype and its historical phases; establish continuous buildable land and landscape constraints; place a market/civic/employment anchor and older routes; add major transport and later employment sites; attach residential ensembles with local centres; subdivide blocks into plots; allocate frontage and upper-floor uses; selectively redevelop some older sites; furnish public space and render materials; then validate access, geometry, and visual composition.

For a small RIM map, preserve a compact centre and two or three recognisably different neighbourhoods before adding a major mall, port, or tower cluster. That count is a proposed composition starting point, not a real-city statistic. Reduce the number of represented functions when the map cannot fit complete examples; compress distances while preserving the relationships between places.

Keep the existing Dutch research's connected-land, correct-footprint, and amenity checks. Add district-level frontage continuity, plausible block interiors, pedestrian reachability, and street-graph junction checks. Calibrate thresholds against the game's scale and visual tests; this study does not justify importing numerical real-world zoning ratios.
