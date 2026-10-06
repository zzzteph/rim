# RIM: architecture for believable cities and towns

Prepared 4 October 2026. Architectural extension to [CLAUDE_CITY.md](CLAUDE_CITY.md), [SMALL_TOWN_ANALYSIS.md](SMALL_TOWN_ANALYSIS.md), and [EUROPEAN_CITY_GENERATION.md](EUROPEAN_CITY_GENERATION.md). This is research and an implementation brief. The reference images are original schematic studies, not captures of implemented game features.

**Generate related buildings that belong to their streets and neighbourhoods.** Establish the footprint, street-facing side, height, roof, entrance, and grounds before adding small details. Keep RIM's cyberpunk identity through selected technology, signs, materials, and lighting on that readable physical structure.

Visual reference: [nine architecture patterns, PNG](review/city_architecture_2026-10-04/architecture_reference.png), [scalable SVG](review/city_architecture_2026-10-04/architecture_reference.svg). These show proposed massing and frontage relationships. They are not dimensioned historical reconstructions or a finished art specification. In the game, select a coherent regional/era palette for an area rather than randomly mixing all nine studies building by building.

## What the current renderer provides, and the gaps

Source inspection began at `scripts/city.gd` SHA-256 `CB19D9D5BEC8159E0809EE9E0A0B67FCD16A94C65D455376A5D8A48486012C25`. An update arrived during this research; a subsequent check observed `B44EC81F28817242918DA789FE5600D61C185DB64794FB12CF1E25D3BCF0BABB`, including market-hall and workshop kinds. Inspect current code again before implementation. This pass did not run the game or remeasure its generation results.

The existing renderer already supplies isometric bodies, house pitched roofs, height variants, apartment bands, shop signs, some entrances, grounds, and different rendering detail levels. Reuse these foundations and the newly added town-specific kinds.

| Inspected limitation | Consequence | Architectural improvement |
|---|---|---|
| Lot records have kind, dimensions, height, inset, variation, and district, but no explicit street-facing direction. | Roof orientation and entrance placement cannot consistently express the actual frontage. | Store a frontage edge and entrance/access relationship selected from the site layout. |
| `_place()` chooses one of three per-building variations. | Local changes in colour and height provide limited neighbourhood identity. | Select a shared architectural family and roof/eaves rules at ensemble level, then vary individual buildings within it. |
| `_draw_isobox()` and `_bake_building()` start from the same rectangular body; pitched roofs are special cases. | Many uses retain similar silhouettes. | Add connected rows, paired houses, corner forms, wings around a court, halls, and sheds using a small shared geometry vocabulary. |
| A scalar `ins` insets all sides of a building. | Street frontage, party walls, rear gardens, and service edges cannot be expressed independently. | Use front/rear/side clearances and shared-wall flags; reserve grounds separately. |
| Palette and window colour are largely driven by `dtype`. | Residential, commercial, and work buildings risk reading as coloured categories. | Separate material palette from use; communicate use through ground-floor layout, entrances, signs, and site arrangement. |
| Window rows are derived from height, and drawn as small screen-aligned rectangles. | Windows provide weak floor/bay rhythm and limited relation to the facade plane. | Define floors and bays, project openings onto wall faces, and suppress openings on shared walls. |
| One `kind`/`dtype` describes the building. | A shop with housing above lacks an explicit combined program. | Retain logical use data for ground and upper floors, with a corresponding mixed facade. |
| The lowest detail level flattens roof shapes; the baked path omits several features of the detailed path. | The most useful architectural distinctions may disappear at the view where the town is assessed. | Preserve roof profile, frontage grouping, broad shop bands, and major entrances where they remain readable; share geometry between paths. |

These are architectural observations about the inspected code, not new claims that earlier road, water, or footprint failures remain unresolved.

## What to borrow from the Netherlands, France, and UK

Use **regional and development-era families**. Historical centres, nineteenth-century streets, postwar housing, and contemporary infill can coexist within each country. A country flag alone is not enough to choose a building.

### Netherlands: brick frontage, ordinary housing rows, and planned ensembles

Enkhuizen's architectural guide links buildings to their surroundings, distinguishes area types, and addresses roof silhouette, brickwork, street-facing entrances, and homes above shops. It supports a family of related historic street buildings rather than isolated ornamental objects. [Enkhuizen architectural guide, 2013](https://openpdc.drechterland.nl/wp-content/uploads/sites/2/2021/06/E_welstandsnota_enkhuizen_20131.pdf).

Leusden's guide describes different housing arrangements, including rows, paired houses, courtyards, flat roofs, and gardens/parking relationships. RCE's postwar research likewise distinguishes row housing and apartment forms. These sources support a broader Dutch library than historic canal-front facades. [Leusden guide, 2018](https://www.leusden.nl/fileadmin/user_upload/Bestanden/Documenten/Bouwen_en_wonen/Welstandsnota_Gemeente_Leusden_2018.pdf), [RCE postwar housing study](https://www.cultureelerfgoed.nl/binaries/cultureelerfgoed/documenten/publicaties/2017/01/01/wederopbouw-een-kansrijke-erfenis-handreiking-bij-transformatieopgaven/wederopbouw_een_kansrijke_erfenis_handreiking.pdf).

**Proposed RIM families:** narrow historic brick frontage with selected gabled ends; restrained brick housing rows with coordinated roofs; paired garden houses; postwar apartment ensembles with shared green space. Choose roof direction relative to the street and plot. Reserve ornate gables and distinctive corners for selected buildings; an entire suburb should not resemble a row of canal-house landmarks.

### France: choose the region before choosing the palette

Saumur's municipal heritage diagnosis identifies tuffeau and slate as defining traditional materials. The CAUE guide to the Bessin, Caen plain, and Falaise describes different local masonry, roof, chimney, and dormer features, including steep symmetrical roofs. This supports distinct local families and variation within them. [Saumur heritage diagnosis](https://www.ville-saumur.fr/images/pages/2020/Urbanisme/DIAG_Saumur_190517-web.pdf), [CAUE Bessin architectural guide](https://caue14.com/wp-content/uploads/2021/04/plaquette-BESSIN-PLAINE-09-02.pdf).

The CAUE's study of Courseulles explicitly discusses the problem of importing a generic Normandy image into a different local context. Apply the same care when translating references into the game. [CAUE study of regional identity](https://caue14.com/wp-content/uploads/2021/01/style_neo_normand.pdf).

**Proposed RIM families:** a pale-stone/dark-roof town frontage inspired by Saumur; a separate Bessin-inspired masonry and pitched-roof family; ordinary rendered garden housing; contemporary apartments and retail buildings. Give central buildings defined ground floors, vertical window rhythm, and selected roof features. More regional packs can follow. Parisian boulevard buildings, mansards, shutters, and half-timbering should each be optional, context-specific choices.

### UK: terraces, varied local materials, and garden-town housing

Historic England describes nineteenth-century terraces alongside factories, shops, schools, and other contemporary buildings. Its shopfront research distinguishes the entrance, display windows, fascia, and other ground-floor components. This provides separate rules for a residential row and a mixed high street. [Historic England housing character](https://historicengland.org.uk/advice/planning/housing/low-demand-housing/), [Lowestoft shopfront research](https://historicengland.org.uk/research/results/reports/8427/TheShopfrontsofLowestoftHighStreetSuffolk_ResearchandInvestigation).

St Andrews' appraisal records differing masonry and roof forms; Cadw's Flint study describes changes between stone, render, brick, and slate across development periods. Letchworth supplies a planned residential reference. These examples support regional/era variation rather than a universal British brick palette. [St Andrews appraisal](https://www.fife.gov.uk/__data/assets/file/0027/93582/St-Andrews-Final_With_Warning-102023.pdf), [Cadw's Flint study](https://cadw.gov.wales/sites/default/files/2019-05/Flint-%20Understanding%20Urban%20Character_0.pdf), [Letchworth residential design guide](https://www.north-herts.gov.uk/sites/default/files/files/spg20_letchworth_design_guide_oct_2000.pdf).

**Proposed RIM families:** a coordinated terrace with rear gardens and selected chimneys; a stone/render town frontage; paired or detached garden-town homes; a mixed high street with homes or modest offices above shops. Place bay windows, dormers, and decorative door surrounds selectively and only when readable at the intended zoom.

These are representative architectural references, not a complete inventory of the three countries. The planning guides are used for built character and design relationships, not as a statement of current legal requirements. No national style frequencies or building-height distributions have been measured.

## The minimum useful building library

The floors below are **proposed prototype ranges**, not measured national averages or a fixed population model. Actual site capacity, camera scale, and town character take precedence. Store roof height separately from occupied floors.

| Archetype | Proposed form | What makes it recognisable | Required site relationship |
|---|---|---|---|
| Row / terrace houses | Repeated narrow units, commonly two floors in the prototype. | Shared or coordinated roofline, repeated doors, limited facade variation. | Street-facing front, shared side walls, rear gardens/yards and access. |
| Paired / detached garden houses | One or two floors plus roof; coherent pairs or groups. | Domestic roof, entrance, front path, hedge or boundary. | Reserved gardens, quiet street, intentional gaps; garages optional. |
| Historic town frontage | Two to four floors, narrow or moderately wide plots. | Related facade proportions and roof forms with selected individual features. | Strong street edge and rear courts; correct corner/end conditions. |
| Shop with homes above | Two to four floors; distinct ground-floor program. | Display glazing and sign band below smaller residential openings. | Accessible shopfront, separate/shared residential entry as modelled, service access. |
| Small apartment building | Three to five floors; a simple bar or corner form. | Common entrance and repeated apartment/window rhythm; balconies optional. | Shared grounds and pedestrian access; a useful edge to the street. |
| Courtyard apartment ensemble | Several coordinated wings, commonly three to five floors. | A visible inner court and coherent perimeter/frontage. | Reserved courtyard, entrances and passage; opening positions follow actual walls. |
| Civic / community building | Low hall with optional raised roof or small tower. | Larger public entrance and distinctive massing. | Square, forecourt, or accessible community grounds. |
| Workshop / light industry | Broad one- or two-floor volume; pitched, repeated shed, or flat roof. | Loading doors, broad bays, yard and service edge. | Work access and useful yard space; compatibility with neighbours. |
| Supermarket / retail building | Broad low building, canopy, selected display frontage. | Main entrance, servicing, pedestrian approach and grounds. | Complete site; parking/service space appropriate to the town and capacity. |
| Institution / office | Modest compound or coordinated wings. | Shared entrance and a consistent facade system; selected signage. | Grounds, public access, and any service boundary appropriate to its role. |

Retain the existing corporate and residential tower vocabulary for city families. Town identity should remain complete without towers. A school, hall, campus, or workshop should be recognisable through its form and site rather than merely a new label on an existing office box.

## The architecture generation algorithm

### 1. Give the neighbourhood a shared architectural family

Choose a development era, compatible building types, a small material palette, roof options, normal eaves heights, frontage rules, and garden/court arrangements. Start with one dominant family per housing ensemble. Select a compatible infill or later-extension family only for deliberate exceptions.

Treat material, building use, and district identity as separate data. A brick building can contain homes, shops, or offices. A residential neighbourhood can contain a school or corner shop without becoming visually unrelated.

### 2. Fit the form to a real frontage and complete site

Identify the street or public path that serves the building. Store its front edge and entrance location. Choose plot width/depth, front setback, side clearances or shared walls, and rear grounds before selecting decorative features.

Terraces align along a street; paired houses share a composition; a civic hall addresses its forecourt; a workshop faces its working yard. A corner building can address two streets while keeping one coherent mass. No street-facing opening is required on an internal party wall.

### 3. Generate a small vocabulary of masses and roofs

Use rectangular volumes as reusable parts, then compose rows, pairs, L/U arrangements, and hall or shed forms where the reserved site permits. For the first implementation, use orthogonal footprints compatible with current occupancy. Curved buildings and true diagonal plots can be later work.

Support a limited roof set: pitched ridge parallel to frontage, pitched ridge perpendicular to frontage, hipped roof, and flat/parapet roof. More elaborate stepped gables, dormers, mansards, and sawtooth roofs can follow after these read clearly. A decorative gable is a facade/roof composition, not a different randomly coloured box.

Party-wall neighbours should meet deliberately. Do not draw a gap, external windows, or decorative garden strip through the middle of an attached row. Reserve service alleys and passages explicitly rather than mistaking random gaps for usable access.

### 4. Compose floors and window bays

Derive facade openings from occupied floor count, bay count, wall direction, and use. Keep the sill/lintel or opening rhythm coherent along an ensemble. Selected missing lights or altered windows can add life after this structure is fixed.

Project openings and signs onto the wall plane. Avoid using identical floating screen-space squares for every facade. A shopfront needs broad ground-floor openings and an entrance; upper housing needs a different rhythm. Apartments need a visible shared entrance, and workshops need service doors rather than residential window patterns.

### 5. Add meaningful grounds and contact with the ground

Place front paths, door steps, rear yards, gardens, hedges, forecourts, and shared courts according to the archetype. Use a readable base line, material transition, and restrained contact shading to anchor walls. Public paths must lead to actual entrances and respect private space.

Check the whole reserved site against roads, water, neighbouring sites, and terrain boundaries. Roof overhangs and entrance canopies must not visually intrude into a bridge, neighbouring roof, or water unexpectedly. Keep private garden decoration separate from logical traversability.

### 6. Apply constrained variation and the cyberpunk layer

Vary compatible brick/render tones, doors, selected chimneys, shop identities, and occupied windows within the established family. Larger changes in roof pitch, floor count, or setback should normally follow a plot/era change. Use separate seeded choices for layout, architecture, and decoration so adding a lamp does not move the neighbourhood.

Put cyberpunk elements where they serve the building: a shop sign on the shopfront, rooftop equipment on an appropriate roof, an access panel beside an entrance, a corporate mark on an office, selected cables along a service edge. Keep ordinary homes quieter. Prefer calm wall materials and limited luminous accents; keep dry ground readable in the night palette.

### 7. Preserve identity through level of detail

At overview, retain footprint grouping, broad roof shape, dominant material, major court/garden voids, and landmarks. At normal zoom, add entrances, meaningful window rhythm, shop bands, and boundaries. At close zoom, add selected roof fixtures, mullions, steps, and signs.

Use projected size to decide when a detail is useful. Roof silhouettes and whole-ensemble identity should survive longer than individual window divisions. Do not render every brick or tile. Share a stable geometry/material description between the current live and baked rendering paths so one path does not become an older visual version of the town.

## Data and implementation boundaries for Claude

Extend the existing lot/site records rather than building an unrelated asset system. Suggested concepts are:

| Scope | Data to represent |
|---|---|
| Neighbourhood / ensemble | `architecture_family`, development era, compatible archetypes, palette, roof/eaves rules, seed. |
| Site / plot | Frontage edge, entrance connection, rear/service edge, per-side setbacks, shared-wall relationships, reserved grounds. |
| Building | Archetype, footprint/mass parts, floor count, roof type/ridge direction/height, facade bays, ground/upper uses, material choices. |
| Rendering | Geometry parts and projected bounds derived from the same building record, cached detail variants, separate selected/animated overlays. |

These are proposed concepts, not required exact property names. Inspect the current schema and future gameplay integration before choosing representation. Keep stable district, site, and building IDs, complete occupancy, hover and selection over the intended logical entity, and correct visibility/depth ordering for multi-part forms.

A visual terrace can stand for one logical ensemble or several independently selectable homes, but that decision must be explicit. Do not silently introduce multiple gameplay buildings through decorative doors. If several geometry parts form one building, they need one documented ownership relationship and a combined selection model.

## Priorities and verification

1. **Street-facing data and coherent rows.** Make one attractive terrace, one garden-house group, and one shop-with-homes row, with correctly oriented entrances and reserved grounds.
2. **Distinct silhouettes and materials.** Add useful roof directions, a stone-frontage family, corners/end buildings, and a consistent facade system. Apply a neutral light preview before tuning the night palette.
3. **Complete destinations.** Build a courtyard apartment ensemble, civic hall, workshop compound, and local retail site. Reuse the newly added hall/workshop kinds where suitable.
4. **Rendering parity and selective detail.** Preserve important shapes in the baked path and at overview; add restrained cyberpunk details and check performance on the larger map.

For each implemented archetype, inspect frontage on all four grid directions, an end/corner condition, and any shared-wall condition. Check entrances and access, footprints and overhangs, projected bounds/culling, depth ordering, and hover/selection. Check courtyard openings and roof junctions on composite forms. Run targeted checks when these geometry and ownership changes are implemented.

Capture overview, normal, and close views of the same fixed town seed in a neutral inspection palette and the final night palette. Check live/baked paths and reduced motion. The important proof is that a row, a garden suburb, a mixed high street, a civic site, and a work site remain visually distinct with district labels hidden. Randomising window lights must not change their layout or architectural family.

The reference sheet is an aid for reviewing these relationships; it does not establish game performance, finished visual quality, or completed implementation. Update `CITY.md` after the actual architecture changes are implemented and inspected.
