# Small-town sample: population and boundary register

Research date: 4 October 2026. Supports [SMALL_TOWN_ANALYSIS.md](../../SMALL_TOWN_ANALYSIS.md) and the [town profiles](TOWN_PROFILES.md).

The 24 cases are selected examples, not a complete list. Each published figure is below 50,000 at the stated reference date. Administrative city status is not a selection criterion. Different geographical units are explicitly retained: these figures do not form a harmonised population ranking. The surrounding urban region, catchment, or municipality may differ from the town being studied.

## Netherlands: municipality upper bounds

Source: CBS, [Regional key figures Netherlands, table 86247NED](https://www.cbs.nl/nl-nl/cijfers/detail/86247NED), [official OData records](https://opendata.cbs.nl/ODataApi/OData/86247NED/TypedDataSet). Reference date: **1 January 2026**. Retrieved fields: `Code_1`, `Naam_2`, `Inwonertal_56`; municipality names/codes were trimmed before matching.

These are **municipal populations**, not populations of the individual built-up town. Each selected town core lies within its municipality, so the municipal total establishes a useful upper bound. Lochem and Leusden particularly include other settlements and countryside. The population of a contiguous urban area extending into another municipality is not established by this method.

| Town studied | Municipality code | Municipal residents | Use in this study |
|---|---|---:|---|
| Gorinchem | GM0512 | 39,060 | Upper bound for town core |
| Culemborg | GM0216 | 30,413 | Upper bound for town core |
| Wageningen | GM0289 | 42,779 | Upper bound for town core |
| Enkhuizen | GM0388 | 18,738 | Upper bound for town core |
| Harlingen | GM0072 | 16,270 | Upper bound for town core |
| Doesburg | GM0221 | 11,173 | Upper bound for town core |
| Lochem | GM0262 | 34,213 | Municipality includes other settlements; do not label this town population |
| Leusden | GM0327 | 32,287 | Municipality includes other settlements; do not label this town population |

## France: commune populations

Source: INSEE, *Comparateur de territoires*, population in **2023**, commune geography at **1 January 2026**, published 27 August 2026. The links below lead directly to each selected commune. A commune is not the wider *unité urbaine*, intercommunal authority, or employment catchment. Saumur's commune includes associated communes; its administrative population is not just the historic central town.

| Town/commune | INSEE code | Residents, 2023 | Source |
|---|---|---:|---|
| Bayeux | 14047 | 12,659 | [INSEE Bayeux](https://www.insee.fr/fr/statistiques/1405599?geo=COM-14047) |
| Fougères | 35115 | 20,307 | [INSEE Fougères](https://www.insee.fr/fr/statistiques/1405599?geo=COM-35115) |
| Saumur | 49328 | 26,241 | [INSEE Saumur](https://www.insee.fr/fr/statistiques/1405599?geo=COM-49328) |
| Libourne | 33243 | 25,036 | [INSEE Libourne](https://www.insee.fr/fr/statistiques/1405599?geo=COM-33243) |
| Pontarlier | 25462 | 18,067 | [INSEE Pontarlier](https://www.insee.fr/fr/statistiques/1405599?geo=COM-25462) |
| Vitré | 35360 | 19,365 | [INSEE Vitré](https://www.insee.fr/fr/statistiques/1405599?geo=COM-35360) |
| Dax | 40088 | 22,109 | [INSEE Dax](https://www.insee.fr/fr/statistiques/1405599?geo=COM-40088) |
| Sarlat-la-Canéda | 24520 | 8,763 | [INSEE Sarlat-la-Canéda](https://www.insee.fr/fr/statistiques/1405599?geo=COM-24520) |

## UK: retain each source's geography

| Town | Population used | Reference date | Geography and source |
|---|---:|---|---|
| Wells, England | 11,145 | Census 2021 | Parish, reported by [Wells City Council](https://www.wells.gov.uk/about). |
| Frome, England | 28,569 | Census 2021 | Town figure reported in [Frome Town Council's profile](https://www.frometowncouncil.gov.uk/council/frome-town-council/frome-town-profile/); not relabelled as a built-up-area statistic. |
| Ludlow, England | 10,041 | Census 2021 | Town Council area, in [Shropshire Council's 2023 town-centre audit](https://www.shropshire.gov.uk/media/26828/ludlow-town-centre-audit-report-2023.pdf). |
| Letchworth Garden City, England | Approximately 34,000 | Census 2021 | Rounded town figure in [North Hertfordshire Economic Strategy, printed page 9 / PDF page 11](https://democracy.north-herts.gov.uk/documents/s28978/Appendix%20A%20-%20North%20Hertfordshire%20Economic%20Strategy%20-%20Final.pdf). The town portrait does not specify a statistical boundary code. |
| Stirling, Scotland | 37,910 | Mid-2020 | NRS locality `S19002512`, [NRS publication and tables](https://www.nrscotland.gov.uk/publications/population-estimates-for-settlements-and-localities-in-scotland-mid-2020/). |
| St Andrews, Scotland | 18,410 | Mid-2020 | NRS locality `S19002498`, [NRS publication and tables](https://www.nrscotland.gov.uk/publications/population-estimates-for-settlements-and-localities-in-scotland-mid-2020/). |
| Aberystwyth, Wales | Approximately 10,700 | Census 2021 as reported in the plan | Figure in the council-hosted [2024 draft Place Plan, printed pages 6–8](https://www.ceredigion.gov.uk/media/n1dldqae/2024-aberystwyth-place-plan.pdf). The precise boundary for this headline number is not established here; see caveat below. |
| Enniskillen, Northern Ireland | 14,086 | Census 2021 | NISRA settlement, 2015 boundary `N11000346`, [official Census data](https://build.nisra.gov.uk/en/custom/data?d=PEOPLE&v=SETTLEMENT15&~SETTLEMENT15=N11000346). |

The Scottish numbers were checked in the [NRS workbook](https://www.nrscotland.gov.uk/media/wtwjdfuo/data-tables.xlsx), locality rows with sex `All` and total population. Stirling's **wider NRS settlement** `S20001992` had **49,950** residents in the same dataset; it includes additional localities. Neither number is the Stirling council-area population. These are explicitly 2020 figures, not estimates for 2026.

**Aberystwyth caveat:** the plan includes neighbouring communities and several statistical geographies. The headline number's precise boundary is unresolved here. Treat the case as provisional for population screening; do not infer a population trend or assign this number to the whole plan area. Resolve the Census boundary before quantitative calibration. Its morphology remains useful qualitative evidence.

## Limits for implementation

- The sample is concentrated on towns of roughly 9,000–43,000 in the reported geographies. Very small villages are not systematically covered.
- Resident population does not measure commuters, students' term-time patterns, visitors, or the number of people served by regional shops and institutions.
- A town's major employer, retail catchment, or commuting region can be much larger than its resident population suggests.
- Do not convert these figures into district percentages or a residents-per-rendered-building multiplier. That requires separately defined, measured data and a game capacity model.
