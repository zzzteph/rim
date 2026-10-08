# RIM city lore — content guide

Everything the city map *says* comes from **`data/city_lore.json`**: district names, megacorps, building
names, stories, residents and their quirks. The code (`scripts/city_lore.gd`) only picks entries at
random (seeded per map) and slots them together. **You can grow the content without touching code:** add
entries to the JSON lists, and every new map will use them.

This guide covers how generation works, the file's structure, the placeholder rules, how to check your
work, and a ready-to-paste prompt for producing more content with another AI.

---

## 1. How a building's lore is assembled

Every map picks a few **megacorps**. Each one is a name prefix plus an industry suffix (e.g. *Orbis* +
*Neural*), and each gets a profile: industry, founding year, CEO, slogan and blurb. Megacorps are the
**only** organisations: no gangs or syndicates.

| District type | What it gets |
|---|---|
| Corporate (`bus`) | Owned by a megacorp. One corp often owns two or three districts. |
| Commercial (`com`) | Run by a corp's retail arm (55%) or by independent traders. |
| Residential (`res`) | A landlord: a corp's *Housing Trust* (60%) or the *City Housing Authority*. |
| Park (`park`) | Public green space. |

Each building then gets a **name**, an **occupant**, a **security level** and a **story**:

```
story = one "history" sentence  +  one "now" sentence  +  (sometimes) "Rumour: " + one "rumour" sentence
```

The game adds the `Rumour: ` prefix itself, so never write it into rumour entries.

| Building | Story pool | Rumour chance | Extra |
|---|---|---|---|
| Corporate tower / office | `stories.corporate` | 75% | 20% are a rival corp's outpost |
| Shop | `stories.shop` | 60% | the **owner** gets a resident profile |
| Mall | `stories.mall` | 50% | |
| Hab block / hab tower | `stories.housing` | 65% | **3 residents** + a city-life line (rent, occupancy, noise) |
| Family house | `stories.home` | 50% | the **whole family**, one shared surname (parents, 0–2 kids, maybe a grandparent) |
| Central HUB | `stories.hub` | 100% | |

**Residents (Watch Dogs-style profiles)** are built like this:
`first_name surname, age — job · ¥income/yr`, then one detail line.
- Under 18 → job "student", detail from `kid_details`.
- 68 and over → job "retired", detail from `elder_details`.
- Everyone else → a job from `people.jobs` (with its income range) and a detail from `people.details`.

---

## 2. File structure (`data/city_lore.json`)

| Key | Type | Used for |
|---|---|---|
| `district_names.prefixes` | list of words | first word of a district name (*Neon*, *Chrome*…) |
| `district_names.suffixes.bus/com/res/park` | lists of words | second word, flavoured by district type (*Nexus*, *Bazaar*, *Stacks*, *Gardens*) |
| `district_names.standalone` | list | whole names occasionally used for residential districts (*Kowloon*, *The Sprawl*) |
| `corp_name_prefixes` | list | first word of a megacorp name |
| `industries.<key>` | object | one per industry; **you may add new industries** (see below) |
| `people.first_names`, `people.surnames` | lists | resident names |
| `people.jobs` | list of `{"text", "min", "max"}` | job line + yearly income range in ¥ (`0, 0` = no income) |
| `people.details` | list of sentences | one personal quirk per adult |
| `people.kid_details`, `people.elder_details` | lists | quirks for under-18s and over-68s |
| `places.old_buildings` | list | what a building used to be (`{old}`) |
| `places.small_old_buildings` | list | what a shop used to be (`{old_small}`) |
| `places.events` | list | past city events (`{event}`); may use `{year}` |
| `places.shop_types` | list | shop names: "*Zara*'s **Noodle Bar**" |
| `places.tower_words` | list | hab tower names ("**Skyreach** Hab Tower") and corp tower name variety |
| `places.mall_words` | list | "*District* **Galleria**" |
| `stories.<category>.history/now/rumour` | lists of sentences | the story pools (categories: `corporate`, `shop`, `housing`, `home`, `mall`, `hub`) |
| `security.<building kind>` | string | flavour security line. Keys are fixed: `hub corp off_m off_s mall shop_b shop_s sc ap fh` |

An **industry** object (to add one, copy an existing block and give it a new key such as `"energy"`):

```json
"energy": {
  "label": "energy",                                  // shown as "<label> megacorp"
  "blurb": "fusion plants, grid leases and fuel futures", // "Deals in <blurb>."
  "name_suffixes": ["Power", "Energy", "Fusion"],     // corp name = prefix + one of these
  "divisions": ["grid-trading", "fusion-research"],   // "{div}" in corporate stories
  "building_names": ["Reactor Spire", "Grid Tower"],  // "<Corp> Reactor Spire"
  "jobs": ["grid technician", "reactor operator"],     // "{corp_job} at {corp}" for residents
  "slogans": ["Power to the people who pay."]
}
```
(JSON allows no comments; they're shown here only to explain the fields.)

---

## 3. Placeholders

Write a word in curly braces and the game swaps in a value. **Every placeholder below is filled for
every template**, so you can use any of them anywhere (except `{corp_job}`; see the table).

| Placeholder | Becomes | Example |
|---|---|---|
| `{district}` | the district's name | Neon Blocks |
| `{org}` | the building's owning corp (else a random corp) | Orbis Neural |
| `{corp}` | a random megacorp on this map | Aegis Financial |
| `{corp2}` | a *different* megacorp | Kuroda Dynamics |
| `{landlord}` | the district's landlord | Aegis Housing Trust |
| `{year}` | a year, 2041–2079 | 2063 |
| `{event}` | a past city event (from `places.events`) | blackout riots |
| `{old}` | a former building (from `places.old_buildings`) | public library |
| `{old_small}` | a former small building | laundromat |
| `{floors}` | **this** building's real floor count | 11 |
| `{f}` | a random floor number, 13–88 | 47 |
| `{n}` | a small number, 2–9 | 7 |
| `{div}` | the corp division (corporate buildings; otherwise "operations") | data-brokerage |
| `{biz_l}` | the shop type in lower case (shops; otherwise "food") | noodle bar |
| `{corp_job}` | an industry job title. **Only valid inside `people.jobs[].text`** | data clerk |

A misspelt placeholder such as `{distirct}` is caught by the check in section 5.

---

## 4. Writing rules

1. **One complete sentence per entry**, ending with a full stop. Fragments are combined at random, so
   each must make sense next to *any* other: no "also", "however" or "as mentioned", and no references
   to a previous sentence.
2. **Length:** story sentences up to about 120 characters; `people.details` up to about 70; names 1–3
   words.
3. **Tone:** cyberpunk in the Gibson / Watch Dogs vein. Grounded, specific, a little wry. Small human
   detail beats melodrama ("Calls their mother every Sunday." is better than "Has a dark past.").
4. **Original names only:** no real companies or brands, and no names from existing franchises
   (Arasaka, Militech, Tessier-Ashpool, Weyland, Tyrell, Blume…). No real people.
5. **No gangs, syndicates or crime organisations as controllers.** Only megacorps own things. Petty
   crime in a *person's* detail is fine ("Wanted for unpaid transit fares.").
6. **Use "they"** for any person who isn't named in the same sentence.
7. **Use `{floors}`** for a building's own height, never a hard-coded floor count, so the story always
   matches the building.
8. **Don't write the `Rumour:` prefix**; the game adds it.
9. Keep it PG-13: no slurs, sexual content or graphic violence.
10. Avoid near-duplicates of existing entries. Variety is the whole point.

**Targets** (current → good). Story pools: 3–8 → **25+ each**. `people.details`: 36 → **100+**.
`kid_details` and `elder_details`: 5 → **25+**. `people.jobs`: 20 → **50+**. First names: 40 → **120+**,
surnames: 30 → **100+**. `stories.home.rumour` and `stories.mall.rumour` are empty, so add some.
Industry lists: 3–4 → **8+ each**.

---

## 5. Checking your edits

1. The file must stay **valid JSON**: double quotes, commas between entries, no trailing commas. Any
   JSON validator will confirm it.
2. Run the city check suite:
   ```
   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://review/city_checks.tscn
   ```
   **CK18_lore_content_valid** fails if the file doesn't load or any `{placeholder}` is unknown, and
   names the bad ones. **CK15_building_lore** fails if any building ends up without a name, occupant or
   story, or if a placeholder leaks onto the screen unfilled.
3. If the file is missing or broken, the game still runs on a tiny built-in fallback and logs
   `city_lore: could not load …`. If every building suddenly reads "Built in …", that's the cause.

---

## 6. Prompt for another AI

Copy everything in the box, fill in the **REQUEST** line, and paste the AI's reply into the matching
list in `data/city_lore.json`.

```text
You are writing content for RIM, a cyberpunk city game whose map is a neon "cyberspace" megacity
controlled by megacorps (Gibson's matrix meets Watch Dogs). Every building shows a short procedurally
assembled story, and homes list their residents with one personal detail each.

REQUEST: <e.g. "40 new entries for stories.housing.rumour" or "60 new people.details">

Rules:
- Output ONLY a JSON array of strings (or of {"text","min","max"} objects for people.jobs), with no
  commentary.
- One complete, standalone sentence per entry, ending with a full stop. It will be combined at random
  with other sentences, so never refer to "it/this" from a previous sentence or use connectors such as
  "also" or "however".
- Story sentences ≤ 120 characters; personal details ≤ 70 characters.
- You may use these placeholders exactly as written; the game fills them in:
  {district} {org} {corp} {corp2} {landlord} {year} {event} {old} {old_small} {floors} {f} {n} {div} {biz_l}
  ({corp_job} only inside people.jobs "text".) Never invent other placeholders.
- Use {floors} for the building's height; never hard-code a floor count.
- Do not start rumours with "Rumour:".
- Original names only: no real companies, brands or people, and no names from existing games, films
  or books.
- Megacorps are the only organisations: no gangs, syndicates or cartels in charge of anything.
- Use "they" for unnamed people. PG-13.
- Tone: grounded, specific, slightly wry cyberpunk. Prefer small human details to melodrama.
- Avoid repeating these existing examples: <paste the current list here>

Pools and what they mean:
- stories.<corporate|shop|housing|home|mall|hub>.history: what the building was or how it came to be.
- ….now: what happens there today.
- ….rumour: a whispered secret or urban legend about it.
- people.details: one quirk about an adult resident (debts, hobbies, secrets, routines, ambitions).
- people.kid_details / people.elder_details: the same for under-18s and over-68s.
- people.jobs: {"text": "job description", "min": yearly ¥ low, "max": yearly ¥ high}; text may use
  {corp}, {district} or {corp_job}.
```

Merge by appending the returned array's items to the end of the matching list, then run the checks
(section 5).
