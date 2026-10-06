# Dutch city profiles for procedural generation

Prepared 4 October 2026. Supporting evidence for [DUTCH_CITY_ANALYSIS.md](../../DUTCH_CITY_ANALYSIS.md) and [CLAUDE_CITY.md](../../CLAUDE_CITY.md).

## How to read these profiles

Coverage: the 32 municipalities above 100,000 residents in the [CBS regional figures for 2026](https://www.cbs.nl/nl-nl/cijfers/detail/86247NED). The [local JSON roster](municipalities_over_100k_2026.json) contains municipality codes, names, and populations. The Hague is listed by CBS as `'s-Gravenhage`.

Each profile describes selected spatial relationships, not every zone or neighbourhood. **Existing/history** refers to a documented condition or historical process. **Plan** refers to an intended or ongoing change. **Generator inference** is our proposed adaptation, not a municipal algorithm. Older planning documents are used for their descriptions of urban form, not as assertions of current legal status. The evidence is uneven: the three major cases have deeper historical coverage, while several smaller cases currently rely more on planning documents. Exact zone extents and percentages require the separate GIS work described in the main analysis.

## 01. Amsterdam

**Existing/history:** The historic centre and canal expansions contain differentiated streets and plots. Later residential layers include enclosed blocks, garden villages, and planned greener districts. Zuidas provides an employment concentration separate from the historic shopping core. Retail examples span Kalverstraat, neighbourhood Lambertus Zijlplein, and peripheral clusters. [Canal history](https://www.amsterdam.nl/stadsarchief/canon/venster/12/), [residential and green-space history](https://publicaties.rekenkamer.amsterdam.nl/groen-in-de-stad/), [Zuidas](https://zuidas.nl/en/the-history-of-zuidas/), [retail dashboard](https://onderzoek.amsterdam.nl/static/dashboard-winkelgebieden/).

**Generator inference:** Combine a mixed historic centre, coherent residential expansions, and a separate transport-linked business node. Canals are one structural ingredient; continuous land and usable blocks remain essential.

## 02. Rotterdam

**Existing/history:** The reconstructed centre, older closed-block neighbourhoods, and postwar housing ensembles have different forms. Lijnbaan, Zuidplein, and Alexander illustrate differentiated shopping/centre roles. Port facilities extend along a freight corridor; Kop van Zuid illustrates reuse of former port land. [Centre types](https://welstandsnota.rotterdam.nl/verdieping/reguliere-criteria-gebieden/stadscentrum-en-centrumgebieden), [housing ensembles](https://welstandsnota.rotterdam.nl/verdieping/reguliere-criteria-gebieden/stempel-en-strokenbouw), [Kop van Zuid history](https://stadsarchief.rotterdam.nl/herontwikkeling-kop-van-zuid).

**Generator inference:** Keep the commercial centre, ordinary housing, industrial edge, and regenerated waterfront distinguishable. Use connected transport destinations and retain some inherited structures during redevelopment.

## 03. The Hague / 's-Gravenhage

**Existing/history:** The court is an early settlement anchor. Employment clusters around the station areas differ from Scheveningen's village, harbour, avenue, and villa environments. A documented retail hierarchy includes central and neighbourhood destinations. **Plan:** CID growth and Binckhorst conversion remain development processes. [Court history](https://haagsgemeentearchief.nl/ontdek-de-stad/verhalen-van-de-stad/vroege-bewoning-hof-en-dorp-1230-1568), [CID](https://www.denhaag.nl/nl/projecten-in-den-haag/central-innovation-district/), [Scheveningen](https://www.denhaag.nl/nl/stadsdelen/scheveningen/wijken/), [retail framework](https://denhaag.raadsinformatie.nl/document/7054713/1/RIS300626_Bijlage_1_Kadernota_detailhandel_De_Haagse_hoofdwinkelstructuur_centraal).

**Generator inference:** A civic anchor, station-linked business area, varied housing, and a separate coastal destination can coexist. They do not need concentric zoning rings.

## 04. Utrecht

**Existing/history:** The station lies beside the historic centre; Hoog Catharijne and Jaarbeurs add major destinations. Station-area reconstruction joined shopping, offices, housing, public space, and crossings. Papendorp and Rijnsweerd are distinct office locations; Lage Weide is a business area. [Inner-city structure](https://omgevingsvisie.utrecht.nl/gebiedsbeleid/gebiedsbeleid-wijk-binnenstad/beschrijving-van-wijk-binnenstad), [station redevelopment](https://www.utrecht.nl/wonen-en-leven/bouwprojecten-en-stedelijke-ontwikkeling/bouwprojecten/binnenstad/stationsgebied), [office locations](https://www.utrecht.nl/ondernemen/vestigen/kantorenlocaties), [business areas](https://www.utrecht.nl/ondernemen/vestigen/bedrijventerreinen).

**Plan:** The 2040 strategy proposes a more distributed network of accessible centres. [Spatial strategy](https://omgevingsvisie.utrecht.nl/de-koers/ruimtelijke-strategie-2040).

**Generator inference:** Make a station a second anchor beside an existing centre, with meaningful crossings over its transport barrier. Allow office sites at other accessible nodes.

## 05. Eindhoven

**Existing/history:** Philips employment growth placed major pressure on Eindhoven and surrounding settlements. The later economy combines knowledge institutions, advanced industry, and suppliers. These processes explain why employment should have several forms. Municipal documents distinguish district shopping centres and local centres such as Haagdijk, Trudoplein, and Kastelenplein. [Philips-era history](https://www.eindhoven.nl/stad-en-wonen/stad/erfgoed/de-geschiedenis-van-eindhoven/stad-van-philips-1900-1940), [economic history](https://www.eindhoven.nl/stad-en-wonen/stad/erfgoed/de-geschiedenis-van-eindhoven/eindhoven-als-economische-wereldspeler), [municipal centre categories](https://parkeernota.eindhoven.nl/docs/Nota%20parkeernormen%202024.pdf).

**Plan:** Compact growth links housing and amenities to accessible locations. [Municipal vision](https://www.eindhoven.nl/bouwen/omgevingsvisie).

**Generator inference:** Connect employment anchors to coherent housing expansions and local shopping. Preserve distinctions between production sites, a knowledge campus, and ordinary offices.

## 06. Groningen

**Existing/history:** The city distinguishes its centre, older neighbourhoods, and later residential areas. Europapark combines housing, employment, and other destinations; further growth is planned. The economic agenda recognises both central retail and neighbourhood/village centres. [Neighbourhood structure](https://gemeente.groningen.nl/wijken-dorpen-wijkwethouders-en-gebiedsteams), [Europapark](https://gemeente.groningen.nl/europapark), [economic agenda 2023–2026](https://gemeente.groningen.nl/file/economische-agenda-2023-2026).

**Plan:** Further development within the city should retain separation and landscape around villages. [Spatial vision](https://gemeente.groningen.nl/omgevingsvisie-levende-ruimte).

**Generator inference:** Keep a strong main centre but give newer mixed destinations and outlying neighbourhood centres their own role. Preserve green space between genuinely separate settlements.

## 07. Almere

**Existing/history:** Almere began as a planned settlement with multiple centres and green areas between them. Stad and Buiten subsequently grew together. Stad, Haven, Buiten, and Poort have distinct centre identities and mixtures of housing, services, shops, and work. Stad accommodates major civic destinations; Haven relates to its harbour. [Municipal history](https://www.almere.nl/wonen/inburgeren-in-almere/welkom-in-almere/hoe-is-almere-ontstaan), [centre descriptions](https://www.almere.nl/bouwen-en-verbouwen/welstand-en-erfgoed-oa-reclame-uiting/welstandsnota), [historical structure plans](https://stadsarchief.almere.nl/publicaties/rapporten-tijdlijn-almere).

**Generator inference:** Reserve neighbourhoods, centres, and green links together before subdividing plots. Give each centre a different scale and identity. Planned growth can produce considerable variety without an invented medieval core.

## 08. Tilburg

**Existing/history:** Tilburg's historical morphology includes persistent routes, squares, and textile-related development around places such as Goirke, Veldhoven, and Korvel. Later plans work with these inherited structures and a stronger connected centre. The historical morphology study is particularly useful for explaining irregularity that has a reason. [Municipal morphology study, 1993](https://denkmee.tilburg.nl/2050/uploads/attachments/clv3jibxr014f0i08looa7vws-bestand-06b-stadsvorm-tilburg-1993.pdf), [2040 vision, historical policy context](https://denkmee.tilburg.nl/2050/uploads/attachments/clv2cxtkk03p00i08bgjuqqs4-bestand-06-omgevingsvisie-tilburg-2040.pdf).

**Generator inference:** Start with several route junctions and older settlement fragments, then connect housing and employment expansions around them. Retain selected squares and shopping routes rather than flattening everything into one uniform grid. A current retail inventory remains a later data task.

## 09. Breda

**Existing/history:** The municipal morphology document distinguishes a compact historic centre, nineteenth-century blocks, garden neighbourhoods, postwar housing, business areas, and later development around the railway. **Plan:** CrossMark links the station, centre, and northern areas through mixed redevelopment of former industrial land. Its full intended extent is not completed development. [Municipal morphology descriptions, 2023 document](https://lokaleregelgeving.overheid.nl/CVDR714214), [municipal 2026 programme](https://breda.begrotingsapp.nl/begroting-2026/programma/ondernemend-breda).

**Generator inference:** Retain the historic shopping/civic centre while adding a connected mixed station quarter. Place newer housing and work in distinct ensembles rather than copying the core's block pattern across the entire map.

## 10. Nijmegen

**Plan grounded in existing area types:** The 2025 vision differentiates historic centre, high-urban and mixed areas, residential areas, campuses, business areas, industry, and countryside. Economic documents identify Heijendaal and Novio Tech as campus locations and TPN-West, Winkelsteeg, and Bijsterhuizen as employment areas. Winkelsteeg's transition towards mixed use is ongoing. [Spatial vision](https://www.nijmegen.nl/over-de-gemeente/plannen/omgevingsvisie/), [economic vision](https://www.nijmegen.nl/over-de-gemeente/plannen/economische-visie/), [Winkelsteeg project](https://winkelsteeg.nijmegen.nl/).

**Generator inference:** Treat campus, production, central shopping, and housing as different urban roles. Selected work districts can acquire housing and amenities while other employment areas remain productive. These sources do not establish measured present-day shares for each type.

## 11. Arnhem

**Existing/history:** Planning descriptions identify the historic/reconstructed centre, relationships with the Rhine and station, and secondary shopping destinations including Kronenburg and Presikhaaf. Presikhaaf illustrates the relationship between a postwar residential district, its shopping centre, and park. These are descriptions in older plans, not a verification of current zoning permissions. [Centre description](https://open.arnhem.nl/ruimtelijkeplannen/plannen/NL.IMRO.0202.734-/NL.IMRO.0202.734-0201/t_NL.IMRO.0202.734-0201.html), [Presikhaaf](https://open.arnhem.nl/ruimtelijkeplannen/plannen/NL.IMRO.0202.788-/NL.IMRO.0202.788-0501/t_NL.IMRO.0202.788-0501_2.4.html).

**Generator inference:** A district centre should be planned with surrounding housing and green space. It can complement a main centre instead of competing for identical buildings and skyline height. A full employment-location comparison remains unmeasured.

## 12. Apeldoorn

**Existing/context:** The municipality combines city, villages, and substantial landscape. **Plan:** Its growth strategy emphasises greener urban development and mixed redevelopment around the centre/station, with work and services included. The vision's park-like centre is an intended direction rather than a description of every current street. [Municipal development overview](https://www.apeldoorn.nl/provada/), [2022 vision](https://digitaleplannen.apeldoorn.nl/NL.IMRO.0200.sv1009-vas1/vb_NL.IMRO.0200.sv1009-vas1.pdf).

**Generator inference:** Use a substantial green framework, residential neighbourhoods with visible grounds, and a concentrated centre that can accommodate retail and work. Do not estimate urban land-use ratios from this large municipality's total area.

## 13. Haarlem

**Existing/context:** The historic centre and Schalkwijk's shopping centre perform different roles. **Plan/in progress:** Schalkwijk is being developed into a broader district centre with homes, work, shopping, culture, and other amenities. The intended full programme should not be drawn as if already complete. Municipal vision documents also distinguish the Waarderpolder employment area. [Schalkwijk project](https://haarlem.nl/vernieuwing-centrum-schalkwijk), [2045 vision](https://gemeentebestuur.haarlem.nl/bestuurlijke-stukken/20210492095-2-Bijlage-1-Omgevingsvisie-Haarlem-2045-Toekomstgericht-met-aandacht-voor-historie-3.pdf), [supporting environmental assessment](https://gemeentebestuur.haarlem.nl/bestuurlijke-stukken/Document/20210492095-4-Bijlage-3-OER-Omgevingsvisie-Haarlem-met-aanvulling-definitief.pdf).

**Generator inference:** Upgrade a district shopping destination into a mixed centre while preserving its surrounding neighbourhood identity. An employment area need not become the main shopping street.

## 14. Haarlemmermeer

**Existing/context:** This municipality contains many villages and centres, polder routes, the Ringvaart, rural land, and airport-related employment. Hoofddorp is a major service/retail centre. **Plan:** Greater urban intensity is focused particularly on Hoofddorp and Nieuw-Vennep, rather than filling every gap between settlements. [Municipal vision summary](https://haarlemmermeergemeente.nl/haarlemmermeer-van-morgen/de-omgevingsvisie-in-het-kort), [Hoofddorp centre vision](https://haarlemmermeergemeente.nl/file/visie-stadscentrum-hoofddorp-2040).

**Generator inference:** Separate the settlement network from large infrastructure and employment zones. Straight polder alignments are a useful inherited framework; variety comes from differentiated centres, neighbourhoods, and open land. Do not turn the whole municipality into one circular city.

## 15. Zaanstad

**Existing/history:** Ribbons, dikes, and paths underpin distinct settlement identities. **Policy:** The retail framework distinguishes principal centres at Zaandam, Krommenie, and Wormerveer; supporting daily-shopping centres; and bulky-goods clusters such as Noorderveld and Zuiderhout. The spatial vision promotes further development within the existing urban area. [Historic structure](https://www.zaanstad.nl/direct-regelen/wonen-bouwen-en-omgeving/buiten/behoud-van-de-identiteit-van-zaanstad-linten-dijken-paden/), [retail framework announcement](https://www.zaanstad.nl/actueel/zaanstad-presenteert-nieuw-beleidskader-detailhandel/), [spatial vision](https://www.zaanstad.nl/direct-regelen/bouwen-en-verbouwen/omgevingswet/omgevingsvisie/).

**Generator inference:** Preserve multiple centres along inherited routes. Let housing and work grow around this structure, and distinguish local shopping from large peripheral retail sites.

## 16. Amersfoort

**Existing/context:** The old centre, station, and Eem-side areas provide separate spatial anchors; former and current business sites occupy redevelopment areas. **Plan/in progress:** Langs Eem en Spoor and station-related areas introduce more housing and mixed uses. Eemplein and Kop van Isselt have different development states. [Langs Eem en Spoor](https://www.amersfoort.nl/langs-eem-en-spoor), [municipal vision](https://www.amersfoort.nl/omgevingsvisie-amersfoort).

**Generator inference:** Connect old-centre shopping and public space to new mixed districts around transport. Keep portions of an earlier industrial layout visible, and represent redevelopment selectively. Do not populate an entire future project area with completed housing at once.

## 17. Enschede

**Existing/context:** The municipality distinguishes central neighbourhoods, southern residential districts, a western harbour/industrial area, and northern university/Kennispark-related locations. Its business overview separates production, innovation, and central retail roles. **Plan:** Parts of the harbour area are being considered in relation to Kennispark's development, not as wholesale conversion of all industry. [City districts](https://www.enschede.nl/stadsdelen), [employment and retail areas](https://www.enschede.nl/ondernemersloket-contact-voor-ondernemers), [Kennispark vision change](https://www.enschede.nl/vaststelling-wijziging-omgevingsvisie-kennispark).

**Generator inference:** Give the campus and freight industry different access, parcel sizes, and appearance. Connect both to the city while preserving coherent residential areas and a recognisable retail core.

## 18. 's-Hertogenbosch

**Plan grounded in existing structure:** The municipal vision distinguishes urban neighbourhoods within the motorway ring, local centres, major urban streets, and other employment locations. It proposes concentrating additional activity around centres and accessible routes, while retaining productive space. [Urban neighbourhoods](https://www.s-hertogenbosch.nl/omgevingsvisie/samenvatting/gebied-de-stedelijke-wijken/), [spatial principles](https://www.s-hertogenbosch.nl/omgevingsvisie/samenvatting/principes/).

**Generator inference:** Put mixed housing, shops, and services along selected connecting streets and centre nodes; keep quieter residential interiors. A planned intensification corridor should affect a limited part of the map rather than raise density uniformly across every neighbourhood.

## 19. Zwolle

**Existing/context:** The railway station links a regional transport role to the nearby historic centre. The Spoorzone occupies the relationship between that centre and the wider landscape. **Plan/in progress:** Its framework combines housing, jobs, innovation, amenities, and public space. [Spoorzone overview](https://www.zwolle.nl/spoorzone-zwolle-hier-ga-je-verder), [development framework](https://www.zwolle.nl/ontwikkelkader-spoorzone).

**Generator inference:** Reserve a complete station quarter connected to established urban destinations and surrounding housing. Use a green edge to shape the quarter. The retrieved evidence supports this relationship; it does not provide a complete citywide inventory of retail centres or employment sites.

## 20. Zoetermeer

**Existing/history:** Growth-town planning introduced residential districts around a future centre. The Stadshart subsequently established a major shopping and civic destination. A documented retail hierarchy distinguishes Stadshart, Dorpsstraat, Woonhart, and daily-shopping centres. [Municipal history](https://www.zoetermeer.nl/zoetermeer-geschiedenis-in-een-notendop), [economic and retail policy background](https://www.zoetermeer.nl/economie-en-werkgelegenheid).

**Plan:** The 2040 vision addresses subsequent renewal of the planned town. [Vision](https://www.zoetermeer.nl/omgevingsvisie-zoetermeer-2040).

**Generator inference:** Generate neighbourhoods with reserved local services and a stronger town centre, then add later renewal. A planned town does not require medieval geometry to feel coherent.

## 21. Leiden

**Existing/context and planning interpretation:** Municipal documents distinguish the old centre, station, Bio Science Park, and Lammenschans area, with different intensity and use patterns from quieter residential areas. Shops and culture in the centre perform a different role from the knowledge cluster. **Plan:** Improved connections and development around the station should join these areas more effectively. [2040 vision](https://gemeente.leiden.nl/wp-content/uploads/2024/02/omgevingsvisie-leiden-2040.pdf), [municipal development programme](https://programmabegroting.leiden.nl/beleidsbegroting/programmaplan/stedelijke-ontwikkeling).

**Generator inference:** Put a knowledge/employment cluster beyond a transport boundary, retain the old mixed centre, and make crossings and connecting routes explicit. Preserve quieter housing even near an active city centre.

## 22. Leeuwarden

**Existing/context:** Leeuwarden serves a wider region and includes numerous villages within its municipality. **Plan:** The vision treats inner-city retail as a regional asset while seeking a more compact shopping structure and a broader mix of functions. It also addresses green/blue connections and the city–village relationship. [Adopted vision](https://www.leeuwarden.nl/wp-content/uploads/import/2021222_omgevingsvisie_leeuwarden_-_vastgesteld_webversie_extra_klein.pdf), [vision position paper](https://www.leeuwarden.nl/wp-content/uploads/2022/10/Positionpaper-Omgevingsvisie-Leeuwarden.pdf).

**Generator inference:** A compact centre can serve residents beyond the visible map. Give it civic, retail, and work destinations without scattering equally large shopping sites through every residential neighbourhood.

## 23. Maastricht

**Existing/context:** Municipal descriptions identify several active centres and employment roles: the historic centre, Sphinxkwartier, station area, and the Randwyck cluster of health, education, offices, and other activity. Peripheral retail and other destinations have separate sites. [Randwyck](https://www.gemeentemaastricht.nl/ondernemen/duurzaam-ondernemen/verduurzamen-bedrijventerreinen/bedrijventerrein-randwyck), [2023 Palace Wyck planning description](https://vastgoed.gemeentemaastricht.nl/sites/vastgoed/files/2025-02/B-2%20Toelichting%20vastgesteld%20bestemmingsplan%20Palace%20Wyck%20e.o.%2028-2-2023.pdf).

**Generator inference:** Generate distinct historic, station, knowledge, and peripheral destinations linked through residential fabric. The office/campus cluster does not need to displace the main shopping streets or become the geometric centre.

## 24. Ede

**Existing/context:** Ede combines urban areas, villages, and landscape. **Plan/in progress:** The World Food Center develops former barracks land near Ede-Wageningen station into a food-related employment and residential area. Its programme explicitly avoids new shops because nearby shopping areas already serve the location. [World Food Center](https://www.ede.nl/in-de-gemeente-ede/ede-in-ontwikkeling/world-food-center), [2040 vision](https://www.ede.nl/fileadmin/ede.nl/Pdf-en/EDE_Omgevingsvisie_2040_DIGITAAL-Vastgesteld_raad_12-5-2022.pdf).

**Generator inference:** Before adding a shopping centre, check whether connected nearby centres already meet demand. A new residential/work neighbourhood can depend on an adjacent retail destination instead of receiving an automatic duplicate mall.

## 25. Dordrecht

**Existing/history in the municipal vision:** The island city contains an older centre, a nineteenth-century surrounding layer, and later residential areas with a different green-space and building structure. **Plan:** The 2025 vision coordinates development and quality at island scale. [Dordtse Omgevingsvisie 2.0, adopted 2025](https://raad.dordrecht.nl/Vergaderingen/Gemeenteraad-Dordrecht-1/2025/23-september/14%3A00/Vaststellen-Dordtse-Omgevingsvisie-2-0-Eiland-met-kwaliteit-Raadsvoorstel/30-1-Dordtse-Omgevingsvisie-2-0-Eiland-met-kwaliteit-Geamendeerd-Vastgesteld.pdf), [municipal project overview](https://cms.dordrecht.nl/Inwoners/Overzicht_Inwoners/Projecten/Wijken/Meerdere_wijken/Dordtse_Omgevingsvisie_2_0_Eiland_met_kwaliteit).

**Generator inference:** Water can define an outer boundary while complete urban neighbourhoods occupy substantial land inside it. Preserve differences between the old centre and later housing. Detailed work/retail catchments still require spatial measurement.

## 26. Westland

**Existing/context:** Westland is a network of villages within a major horticultural production landscape. Its municipal population does not represent one continuous city. Village identities and centres coexist with a large production economy. **Plan:** The horticultural vision addresses the future of that economic landscape. [Horticultural vision](https://www.gemeentewestland.nl/aanvragen-en-regelen/ondernemen-en-arbeidsmigratie/glastuinbouw/glastuinbouwvisie-2040), [municipal spatial workbook](https://www.gemeentewestland.nl/fileadmin/Gemeente_Westland/site_assets/Ondernemen/Werkboek_Westland.pdf).

**Generator inference:** A production landscape can support several smaller residential/service centres. Avoid forcing a skyscraper CBD into this family. For RIM's default city, this is a specialised optional family rather than the main template.

## 27. Alphen aan den Rijn

**Existing/context:** Municipal area descriptions distinguish urban neighbourhoods, village centres, and employment sites. The business-area inventory lists multiple parks instead of one central office district. Historical descriptions around Lagewaard and Hoogewaard relate settlement and later employment to inherited routes and river geography. [Area descriptions](https://www.alphenaandenrijn.nl/Bouwen_en_verbouwen/Omgevingswet_Alphen_aan_den_Rijn/De_omgevingsvisie/Gebieden_in_Alphen_aan_den_Rijn), [business areas](https://www.alphenaandenrijn.nl/Ondernemen/Bedrijventerreinen_in_gemeente_Alphen_aan_den_Rijn), [local development history](https://ro-online.alphenaandenrijn.nl/manifest/NL.IMRO.0484.Khoogewaard1her-VA01/t_NL.IMRO.0484.Khoogewaard1her-VA01.html).

**Generator inference:** Preserve old routes and several settlement/service nodes while assigning larger work sites suitable access. Do not infer the whole city's shopping hierarchy from one local plan.

## 28. Alkmaar

**Existing/context:** The Alkmaars Kanaal description distinguishes greener, roomier northern areas, the historic centre/Overstad/station relationship, and southern areas currently dominated by work sites. **Plan:** Southern mixed-use conversion is a future development direction, not evidence that housing is already widespread there. [Municipal canal-area vision](https://alkmaarskanaal.alkmaar.nl/visie/).

**Generator inference:** One connected canal can organise distinct neighbourhood and employment areas without becoming a broad central lake. Differentiate an established centre from future redevelopment land, and let work/housing mix vary along the corridor.

## 29. Delft

**Existing/context:** Delft's historic centre, TU-related knowledge areas, and residential neighbourhoods such as Voorhof, Buitenhof, and Tanthof provide different urban environments. **Plan/in progress:** Nieuw Delft, Schieoevers, and campus-related locations accommodate different forms of change and intensification. [2040 vision](https://media.delft.nl/pdf/Omgevingsvisie/Omgevingsvisie-Delft-2040.pdf), [municipal development locations](https://www.delft.nl/kansrijke-locaties).

**Generator inference:** Keep central shopping and heritage frontage distinct from campus buildings and postwar housing. Use selected connection corridors for mixed development rather than turning every residential block into a tower site.

## 30. Emmen

**Existing/history:** Industrial development helped create a regional urban centre. Postwar neighbourhoods including Angelslo, Emmerhout, and Emmermeer illustrate the “open green city”: residential ensembles integrated with landscape and neighbourhood services. [Postwar neighbourhood description](https://ro.emmen.nl/imro2008/NL.IMRO.0114.2022025-B701/t_NL.IMRO.0114.2022025-B701.html), [industrial growth and Angelslo history](https://ro.emmen.nl/imro2008/NL.IMRO.0114.Zaak319583-V501/t_NL.IMRO.0114.Zaak319583-V501.html).

**Generator inference:** Design housing, local amenities, and green space as complete units. A low or medium-rise city can be visually rich through its grounds and neighbourhood composition; towers and canals are unnecessary ingredients.

## 31. Deventer

**Existing/history and policy:** The historic centre has public-facing functions distributed along streets and squares; planning supports residential use above active ground floors. **Plan/in progress:** Haveneiland offers a former work area for mixed redevelopment with links to the centre and transport. [Historic-centre use structure](https://ruimtelijkeplannen.deventer.nl/manifest/NL.IMRO.0150.D111-VG01/t_NL.IMRO.0150.D111-VG01_5.3.html), [Haveneiland project](https://www.deventer.nl/projecten-woningbouw-en-wijkvernieuwing/1e-stap-naar-ontwikkeling-haveneiland-tot-levendig-woon-werkgebied).

**Generator inference:** Build a connected sequence of shopping streets and small squares with homes above. Convert a limited former work site while preserving its relationship to the wider city and remaining employment.

## 32. Venlo

**Existing/context:** Municipal sources distinguish mixed centres at Venlo, Blerick, and Tegelen; these combine retail with housing, work, and other activities. The municipal atlas provides the wider settlement and employment geography, including Trade Port areas, for a later spatial comparison. [Municipal centre descriptions](https://www.venlo.nl/subsidie-transformatiefonds-venlo), [Atlas Venlo 2023](https://nu.venlo.nl/media/1054/download).

**Generator inference:** Keep several centres and a separately connected trade/logistics area. Residential growth should link centres without turning freight land into random neighbourhood infill. Atlas maps have not been digitised or used to calculate land shares in this study.

## What this comparison supports

The recurring relationships are multiple centre roles, housing built in coherent episodes, shopping hierarchies, distinct employment types, inherited route structure, and purposeful green/water systems. These support the proposed generator in the main document.

The comparison does not establish numerical zoning proportions, a universal street pattern, or a single causal growth law. Several profiles need more detailed present-day employment and retail mapping before quantitative calibration. Treat the municipal sources as evidence for specific relationships and keep proposed generator rules labelled as inferences.
