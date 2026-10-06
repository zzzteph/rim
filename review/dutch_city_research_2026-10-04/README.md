# Dutch city research — 4 October 2026

- [Main analysis and proposed generator](../../DUTCH_CITY_ANALYSIS.md)
- [Profiles for all 32 municipalities in the selected scope](CITY_PROFILES.md)
- [CBS population selection](municipalities_over_100k_2026.json)
- [Claude implementation brief](../../CLAUDE_CITY.md)
- [Current RIM generator audit](../city_gaps_2026-10-04/REVIEW.md)

## Population selection provenance

Source: [CBS Regional key figures Netherlands 2026, table 86247NED](https://www.cbs.nl/nl-nl/cijfers/detail/86247NED), consulted 4 October 2026. The population reference date is 1 January 2026; the table metadata inspected during research reported an update on 14 July 2026.

Endpoint: `https://opendata.cbs.nl/ODataApi/OData/86247NED/TypedDataSet`.

The roster retains municipality rows, selects `Inwonertal_56 > 100000`, trims `Code_1` and `Naam_2`, and sorts by population descending. Output fields are `code`, `municipality`, and `population`. Filtering was applied locally because the queried endpoint did not honour the requested server-side filtering in this session. The resulting roster has 32 distinct `GM` codes.

This is a reproducible scope choice for a qualitative study, not a claim that municipal boundaries correspond to continuous cities. Names in the profiles use The Hague for `'s-Gravenhage`; the JSON preserves the CBS name.

## Research status

Completed: population roster, source-linked qualitative profiles, deeper Amsterdam/Rotterdam/The Hague comparison, proposed generation rules, and integration into the Claude handoff.

Not performed: parcel-level GIS ingestion, measured zone boundaries, citywide land-use percentages, street-network measurements, or fitting numeric generator parameters. The main document specifies how to perform that later calibration. No game code was changed for this research.
