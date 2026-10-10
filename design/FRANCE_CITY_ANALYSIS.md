# French city structure: research and generation rules for RIM

Prepared 4 October 2026. Read alongside [CLAUDE_CITY.md](CLAUDE_CITY.md), [DUTCH_CITY_ANALYSIS.md](DUTCH_CITY_ANALYSIS.md), and the [current generator audit](review/city_gaps_2026-10-04/REVIEW.md).

The combined implementation decisions and cross-country measurement method are in [EUROPEAN_CITY_GENERATION.md](EUROPEAN_CITY_GENERATION.md). Use that synthesis to resolve differences between country-specific examples and the game's scale.

## Scope and interpretation

This is a **qualitative comparison of 12 representative French cities**, with deeper cases for Paris, Lyon, and Marseille. Toulouse, Bordeaux, Lille, Nantes, Strasbourg, Nice, Rennes, Montpellier, and Le Havre extend the range of urban forms. It is not an exhaustive list or population ranking, and it does not measure zoning percentages, every suburb, or every employment cluster. References to a metropolitan business district can extend beyond the central municipality: La Défense is a metropolitan Paris example, not a district within Paris's municipal boundary.

The evidence below distinguishes **documented history/existing form** from **development plans**. Sources include municipalities, metropolitan authorities, municipal archives and museums, public development bodies, the Paris planning agency, and UNESCO. These sources describe selected places, not a complete inventory. The proposed generation rules are our interpretation for RIM; French cities were not created by one shared algorithm.

The useful finding is a sequence: **inherited routes and settlement nuclei → coordinated expansions → transport and employment anchors → selective redevelopment**. Copy these relationships into the compressed game map. Keep its cyberpunk presentation, readable land, connected streets, and complete neighbourhoods.

## Three cities in depth

### 1. Paris: older neighbourhoods, boulevard interventions, and a separate metropolitan office centre

**History and housing.** Nineteenth-century transformation inserted broad routes into an older city, improved station access, added parks and public institutions, and incorporated surrounding settlements. Haussmannian buildings created continuous street frontage with coordinated heights; shops occupied ground floors and homes occupied upper floors. These are relationships between a street and its buildings, not a reason to make every block identical. [City of Paris: Haussmann and the transformation of Paris](https://www.paris.fr/pages/haussmann-l-homme-qui-a-transforme-paris-23091).

**Geometry.** Place Gambetta illustrates how a planned avenue-and-square system met older faubourgs and produced shaped blocks. Surviving historic areas also include courtyards, gardens, institutional plots, and narrow streets. The pattern is an overlay of different frameworks rather than a single rectangular lattice. [City of Paris: Place Gambetta](https://www.paris.fr/pages/une-place-gambetta-reamenagee-3863), [City of Paris: protected historic areas](https://www.paris.fr/pages/secteurs-sauvegardes-psmv-2351).

**Business and retail.** La Défense developed west of central Paris around a deliberate metropolitan axis, exhibition facilities, offices, housing, and subsequently improved rail access. The operator's history records both initial transport shortcomings and the importance of the RER. It therefore demonstrates a feedback between access and development, not a rule that towers must occupy the old centre. Meanwhile, Apur inventories Parisian commercial premises individually, including street, courtyard, corner, and shopping-complex locations. Retail must be represented at frontage or premises level rather than only as a district colour. [Paris La Défense: history](https://www.parisladefense.com/fr/territoire/quartier-et-son-histoire), [Apur: commercial premises database](https://www.apur.org/fr/open-data-cartes/open-data/base-donnees-commerces-parisiens).

**RIM translation.** Preserve an irregular mixed core, insert a few purposeful avenues, form coherent apartment frontages, and place selected shops beneath housing. A later office cluster may sit on a connected edge. A Seine-like corridor is optional in the game; Paris's lessons about frontage and public space also work on a dry map.

### 2. Lyon: different urban systems on hills, a peninsula, and an eastern plain

**Historic commercial core.** The Presqu'île developed through successive occupation and river-edge change. Small older streets and passages coexist with nineteenth-century avenues. Rue de la République is a major commercial axis containing shops, banks, and entertainment. Central shopping therefore has a street-based structure. [Lyon 1st arrondissement: Presqu'île](https://mairie1.lyon.fr/decouvrir-le-1er/au-fil-des-quartiers/la-presquile).

**Housing and work together.** Croix-Rousse's silk-working buildings were dimensioned to accommodate looms, while passages followed the slope and connected routes used by workers. On the eastern side of Lyon, the municipal planning diagnosis distinguishes the regular left-bank framework, older industrial faubourgs, and later large housing ensembles. Different economic activities and construction periods produced different building and street types. [City of Lyon: Croix-Rousse](https://www.lyon.fr/lieu/contemporaine-19eme-20eme/quartier-de-la-croix-rousse), [Lyon planning diagnosis: 8th arrondissement, historical urban structure](https://plu.grandlyon.com/data/communes/LYON8E/pdf/LYON8E-CAH_COMM.pdf).

**Later centres.** Part-Dieu combines a station, offices, housing, a shopping centre, and cultural institutions on a former barracks site east of the Rhône. Its continuing programme adds housing, local services, greenery, and improved movement; programme objectives should not all be treated as completed conditions. Confluence combines retained industrial history with redevelopment south of Perrache, while the railway/interchange has been a significant barrier. [Métropole de Lyon: Part-Dieu](https://www.grandlyon.com/mes-services-au-quotidien/sinformer-sur-les-projets-urbains-dans-la-metropole/lyon-part-dieu), [Métropole de Lyon: Confluence](https://www.grandlyon.com/mes-services-au-quotidien/sinformer-sur-les-projets-urbains-dans-la-metropole/lyon-confluence), [Lyon 2nd arrondissement diagnosis](https://pluh.grandlyon.com/data/communes/LYON2E/pdf/LYON2E-CAH_ARRON.pdf).

**RIM translation.** Use different street and housing grammars in adjoining neighbourhoods. Give the shopping street and station-business cluster separate identities, with shared access. Retain a warehouse or older block during regeneration. If using rivers, reserve broad buildable districts first: reproducing the full confluence on a tiny map would undermine the user's requirement for a substantial city on land.

### 3. Marseille: a port origin, absorbed villages, and directional growth

**Origins and expansion.** Settlement developed above the sheltered old harbour. Later expansion absorbed faubourgs, hamlets, and villages, leaving numerous local nuclei and different neighbourhood identities. Hills and the Huveaune valley shape movement; the municipality describes the valley as a former industrial route now accommodating tertiary and commercial activities. This is a useful alternative to uniform rings around downtown. [City of Marseille: early history](https://www.marseille.fr/decouvrir-marseille/histoire-de-marseille/pr%C3%A9sentation), [City of Marseille: neighbourhood mosaic](https://www.marseille.fr/decouvrir-marseille/histoire-de-marseille/une-mosaique-de-111-quartiers).

**Employment, retail, and housing.** Joliette's industrial heritage has been reused for offices, shops, services, culture, and housing. Rue de la République and the tram provide a connection to the existing centre. Arenc extends the business concentration and waterfront skyline, alongside housing and local institutions. Its operator describes a mixture of completed buildings and developing programmes; do not count every named tower or facility as delivered. [Euroméditerranée: Joliette](https://www.euromediterranee.fr/joliette), [Euroméditerranée: Arenc](https://www.euromediterranee.fr/arenc).

**RIM translation.** Start with a sheltered waterfront or market nucleus, then grow into a few reachable corridors and neighbouring settlement centres. Give each absorbed centre some local shops and a civic space. Put port-related industry in a directional corridor with freight access, and redevelop only a selected portion. Keep the coast mainly at the map edge, with complete dry blocks behind it. Terrain can produce asymmetry through a reserved hillside or green wedge without making every street curve randomly.

## Nine additional city profiles

### 4. Toulouse: faubourgs, specialised employment, and neighbourhood centres

Municipal descriptions identify mixed residential, economic, and commercial quarters around the centre; the Bayard area developed with Matabiau station, while Compans-Caffarelli became a business district during its 1980s transformation. The western sector combines village nuclei, twentieth-century housing estates, economic sites, aerospace heritage, and the Oncopole on the former AZF industrial site. The 2040 project seeks to strengthen local shops and services; this is a policy objective, not a measured present-day accessibility result. [Central neighbourhoods](https://metropole.toulouse.fr/quartiers/les-chaletsbayard-belfort-saint-aubin-dupuy), [Compans-Caffarelli](https://metropole.toulouse.fr/quartiers/amidonniers-compans-caffarelli-brouardel), [Western sector](https://metropole.toulouse.fr/kiosque/projet-urbain-toulousain-secteur-ouest), [Urban plan guide](https://metropole.toulouse.fr/kiosque/plan-guide-du-projet-urbain-toulousain).

**Generator lesson:** support specialised employment campuses as well as downtown offices. Connect them to housing, preserve smaller centres, and vary residential form by expansion era.

### 5. Bordeaux: low-rise continuous housing and new mixed employment areas

The Bordeaux *échoppe* is a particularly useful housing reference: a low-rise attached stone house aligned to the street, with rooms extending towards a rear garden. Groups produce substantial residential blocks without towers or a road around every individual house. Euratlantique's continuing redevelopment combines homes and employment, and its commercial strategy explicitly organises local clusters around public spaces while considering existing shopping centres. Bastide-Niel reuses railway and military land and preserves aspects of the inherited site arrangement; full delivery remains a future programme. [Métropole heritage inventory: échoppes](https://identificationpatrimoine.bordeaux-metropole.fr/lieux/echoppes-bordelaises), [Euratlantique: local retail structure](https://www.bordeaux-euratlantique.fr/fileadmin/user_upload/Livret_commerces__par_page_bd.pdf), [Métropole: Bastide-Niel](https://www.bordeaux-metropole.fr/metropole/projets-en-cours/amenagement-territoire/grands-projets-damenagement/projets-urbains-2).

**Generator lesson:** implement attached-house rows with garden interiors. Add new shopping clusters where demand and public routes justify them; retain older boundaries within redevelopment.

### 6. Lille: industrial neighbourhoods and a station-led metropolitan centre

Lille's own project overview describes eastern faubourgs with former industrial sites and southern districts separated by railway and road infrastructure. Wazemmes retains industrial traces, including a former textile factory converted to cultural use. Euralille began with the TGV project and combines offices, shopping, housing, facilities, and open space near the stations; Euralille 3000 represents further transformation. These are distinct development histories within one connected city. [City of Lille: neighbourhood projects](https://www.lille.fr/Nos-projets-urbains/%28statut%29/2492), [Wazemmes industrial reuse](https://www.lille.fr/Le-Grand-Sud/content/view/full/430546), [Euralille and its continuing programme](https://www.lille.fr/Votre-Mairie/Lille-en-bref/Les-projets-urbains/Euralille-3000).

**Generator lesson:** build a transport-linked business and retail node alongside established residential districts. Add actual crossings through infrastructure barriers and preserve a small number of industrial landmarks.

### 7. Nantes: radial routes, an industrial river district, and successive housing patterns

The metropolitan heritage account traces growth along routes converging on the old centre and a gradually formed belt boulevard, with tramways and later cars influencing expansion. The Île de Nantes developed from several islands into an industrial area; its eastern Beaulieu housing and offices were organised around a shopping centre during a later planning period. Former industrial buildings now accommodate a range of new uses, including housing, culture, education, and associations. [Nantes Patrimonia: urban history](https://patrimonia.nantes.fr/fiches-encyclopediques/urbanisme/), [Île de Nantes](https://patrimonia.nantes.fr/quartiers/ile-de-nantes/), [Industrial heritage and reuse](https://patrimonia.nantes.fr/dossiers-thematiques/dossier-patrimoine-industriel-2eme-volet/).

**Generator lesson:** grow along a few inherited routes, then link them. Retain useful structures through redevelopment. A large island district is appropriate only where bridges, local services, and sufficient dry land all fit.

### 8. Strasbourg: a compact old core beside a planned extension

The Grande-Île's waterways and crossings shaped the historic settlement. The later Neustadt introduced large axes, institutional buildings, and a different planned framework beside it. The Deux-Rives programme extends development along a tram-served axis through selected former port areas, while explicitly retaining active port functions. That programme mixes delivered places with future development. [City: historic river structure](https://www.strasbourg.eu/lieu/-/entity/sig/1661_CUL_187/ancienne-douane), [City cultural service: Grande-Île and Neustadt](https://www.culture.strasbourg.eu/parcours/grande-ile-et-neustadt/), [Deux-Rives programme](https://www.strasbourg.eu/deux-rives-les-grandes-etapes-du-projet).

**Generator lesson:** connect a fine-grained core to a more formal expansion without forcing identical street orientations. Use institutions as anchors. Keep active industry distinct from the portions selected for mixed redevelopment.

### 9. Nice: a constrained coastal city and a separate western business node

Nice's resort development combined promenades, planted avenues, parks, setbacks, villas, hotels, and hillside gardens. The city links these forms to its sea-and-mountain setting. Arénas is an existing employment concentration at the western entrance near the airport; Grand Arénas is a programme to add a fuller mixture of housing, offices, shops, and services around a multimodal interchange. Treat that mixture as the project's direction, not uniformly completed development. [City: garden-city history](https://www.nice.fr/agenda/nice-reine-des-fleurs/), [City: resort heritage and geography](https://www.nice.fr/nice-la-ville-de-la-villegiature-dhiver-de-riviera-inscrite-sur-la-liste-du-patrimoine-mondial/), [State: Grand Arénas project notice](https://www.alpes-maritimes.gouv.fr/index.php/contenu/telechargement/53972/416694/file/A2%20notice.pdf).

**Generator lesson:** use a long urban strip, terrain-limited expansion, green residential plots, and one separate transport-business anchor. Coastal character needs an edge and promenade, not water between every block.

### 10. Rennes: a compact centre and a network of surrounding settlements

Rennes Métropole describes its *ville archipel* model as a central city and surrounding settlements whose development is organised around existing centres, with intervening countryside. “Archipelago” here describes separated urban settlements, not water islands. The retail policy supports both the main Rennes centre and local commerce in metropolitan towns and urban neighbourhoods. It is a planning approach, not proof that every household already has the same service access. [Métropole: history and territorial structure](https://www.presse.metropole.rennes.fr/upload/espace/1/pj/27033_19684_Dossier_de_synthese_Convention_2023_2033_Label_Metropole_dArt_et_dHistoire.pdf), [Métropole: retail policy](https://economie.metropole.rennes.fr/politique-commerce/).

**Generator lesson:** keep green breaks at metropolitan scale, but use adjoining neighbourhoods within RIM's small city footprint. A detached satellite should appear only on a map with enough capacity for its own centre and access.

### 11. Montpellier: a medieval centre followed by deliberate extension axes

The Écusson contains narrow streets, small squares, shops, and historic institutions within a boulevard boundary. Antigone subsequently extended the centre towards the Lez, followed by Port Marianne to the southeast. Port Marianne includes contemporary housing, civic and educational anchors, neighbourhood shops, tram access, and larger destinations such as Odysseum. The ongoing Bofill project seeks to improve links between parts of the centre; those links should not be assumed complete. [City: central quarters](https://www.montpellier.fr/territoire/les-communes/montpellier/quartier-centre), [City: Port Marianne](https://www.montpellier.fr/territoire/les-communes/montpellier/quartier-port-marianne), [Bofill project and extension history](https://participer.montpellier.fr/zac-bofill/presentation).

**Generator lesson:** add a coordinated expansion along a chosen axis and give it public anchors, housing, and local retail. Join it to the old centre through usable public space rather than a narrow accidental road connection.

### 12. Le Havre: coherent reconstruction and a different upper-city housing landscape

Post-war reconstruction combined major axes, squares, ordinary residential streets, passages, and block interiors in an intentionally coordinated ensemble. Surviving buildings and older alignments influenced the new fabric. The upper city followed a different history: growth from village nuclei, extensive housing subdivisions, and later large residential estates. A rectangular pattern can therefore express a coherent development period rather than poor generation. [UNESCO: reconstructed Le Havre](https://whc.unesco.org/fr/list/1181), [Municipal planning diagnosis, 2024](https://lehavre.fr/sites/default/files/fichier/rapport-de-presentation-tome-1-plu-modifie-le-19.12.2024.pdf).

**Generator lesson:** allow one planned grid with a shared architectural family, substantial block interiors, public squares, and selected surviving landmarks. Contrast it with adjoining housing patterns instead of distorting every street to avoid rectangles.

## Twelve actionable rules for Claude

These are **proposed game rules**, inferred from the cases above. They are not measured French standards or calibrated numerical parameters.

1. **Assign a development history before buildings.** Store a neighbourhood's origin, expansion era, and later interventions. Generate coherent groups before introducing individual variation.
2. **Overlay a few major routes on inherited fabric.** Connect actual centres, stations, or edge gateways. Preserve some earlier lanes; place squares at selected important meetings. Do not turn every road tile into a junction.
3. **Create blocks from streets, then buildings from frontage.** Give adjoining buildings compatible setbacks and heights. Protect courtyards, gardens, and entrances; do not require a vehicle road around each building.
4. **Make street geometry locally consistent.** Combine a fine-grained core, one more regular extension, and quieter housing streets where capacity permits. Bends, changes of angle, and axes should have a geographic or historical reason.
5. **Separate the office skyline from the retail hierarchy.** They may overlap, but a station-business centre, historic shopping street, local shop cluster, and large retail destination need distinct placement and access logic.
6. **Represent vertical mixed use.** Store ground-floor activity separately from upper floors. Put shops on selected continuous frontages beneath homes or offices; retain quieter residential streets behind them.
7. **Support multiple residential forms.** Use attached houses with gardens, perimeter apartments, villas with setbacks, and planned apartment ensembles as coherent options. Avoid treating all suburbs as scattered detached boxes.
8. **Give outer neighbourhoods their own useful centre.** A small square, local shops, school or civic building, and nearby park establish a place. Scale the programme to accessible housing demand rather than allocating a mall to every district.
9. **Distinguish freight, office, and visitor economies.** A port or workshop district needs service access and suitable plots; a station-office cluster needs pedestrian connections; a resort frontage needs public space. One generic commercial zone cannot express all three.
10. **Redevelop selected sites while retaining structure.** Preserve a warehouse, earlier street, market hall, or courtyard. Add links before increasing density, and retain enough working space where industry remains part of the district.
11. **Keep water and topography subordinate to usable neighbourhood capacity.** On compact maps use a coast at an edge, one modest river, or no water. Reserve complete blocks and bridge approaches first. A water-related real city can still inspire a dry RIM layout.
12. **Validate a neighbourhood as a connected place.** Check entrances, pedestrian links, service access, continuous dry ground, usable block interiors, and reachability of centres. Review screenshots with labels hidden: road hierarchy, housing groups, shopping streets, and public spaces must remain legible.

## Implementation and verification priorities

For the first improved RIM family, combine **continuous mixed frontages**, **garden-backed housing rows**, **a compact transport-business cluster**, and **one connected shopping destination**. Use historical layers to explain variation, while keeping enough land for each place. The small map should compress or omit optional layers rather than leave incomplete sites.

Keep road topology and road rendering separate. Graph degree identifies endpoints and branching; route direction distinguishes a straight segment from a bend, since both can have degree two. Use both connectivity and geometry to classify T-junctions and crossroads, and preserve that topology during rasterisation. This is an engineering correction, not a conclusion that can be obtained by copying a French map. Preserve the dated audit's connectivity and water-footprint checks.

Future quantitative work should sample comparable built-up extents and measure block dimensions, junction types, frontage continuity, building height, land use, and access to centres. Apur's premises database can support Paris retail analysis, but a point inventory is not a complete building-use map, and it does not describe all France. No such spatial measurements were performed for this document.
