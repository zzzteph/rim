# RIM — botnet prototype v2: macro/micro free-for-all (current spec)

*Active specification for the standalone prototype (`scenes/botnet_proto.tscn` + `scripts/botnet_proto.gd`;
every number and table lives in `scripts/botnet_cfg/*.gd` — see "Where the numbers live").
Supersedes the v1 attrition prototype (hub capture on a fixed 5×3 grid), archived in
`design/BOTNET_ATTACK_HISTORY.md` §14. All numbers are provisional test candidates. Engine checks establish
mechanical correctness only; they do not establish balance or novice usability.
For how the game looks — fonts, sizes, colours, every graphical element, the 1366→4K scaling, and how to wire
new cards, types and effects — see the design system in `design/BOTNET_BRAND_BOOK.md`.*

## Why v2 exists

The full game has two map scales: the **global** town map and the **local** network inside one building. The
framing we are testing: **global = MACRO** (wire where bots go, redirect traffic between buildings),
**local = MICRO** (build a lot inside a building). v1 collapsed the local into two instant, free slots, so the
macro/micro trade could not exist in it. v2 adds the five cheapest experiments that make that trade real,
plus the decisions taken on 2026-10-11:

| Decision | Answer |
|---|---|
| Who is the enemy | **Two AI botnets** (NYX, KRAKEN) in a **free-for-all** with you, over a neutral town |
| Does time run while you are inside a local | **Yes** |
| What are bots | A **stock held per building**; the more a building holds, the better it works |
| Win condition | **Cash** |
| Command unit (building / district / supply tree) | Undecided — the **rally point** is the experiment |
| How you command | **Two verbs:** CONNECT by drag, LAUNCH from the target's panel (quiet SCAN or loud ATTACK); guards arm themselves |

## The five experiments (what each tests)

1. **A local with an attention cost.** "Enter building" takes `ENTER_TIME` to connect, builds take `BUILD_TIME`
   (a replace `DEMOLISH_TIME` + `BUILD_TIME`) and **progress only while you stay inside**, and while you are inside the map **keeps running and cannot be
   commanded**. *Tests:* does micro cost you buildings on the map?
2. **Link capacity shared by bots and Cash.** Each link direction admits `LINK_CAP` packets per `LINK_TIME`;
   later packets queue at the building before the link; a source whose first link cannot admit its packet
   within `MAX_QUEUE` holds. *Tests:* does redirecting become a decision when two flows want one pipe?
3. **A generated town** (6×6 cells with gaps, jitter, missing and diagonal streets, rich downtown, poor rim;
   different every run, `town #seed` in the HUD). *Tests:* does the per-building scheme survive a bigger,
   irregular map, and does territory matter?
4. **Staged loss instead of a flip.** Fewer bots → fewer working slots. *Tests:* do players reinforce earlier?
5. **The output-limit dial** from the basic game: 25 % steps per source. *Tests:* is a partial hold used?

Plus the **rally point**: one standing order for the rear (every unwired idle building auto-supplies it above
a garrison). *Tests:* does one order for the rear scale, or do we need districts?

## Current rules

### Town
- 6×6 cells; each non-forced cell is a gap with probability `EMPTY_CELL` (0.15). Positions jitter ±26 %.
  Grid streets exist with probability `LINK_KEEP` (0.78); diagonal shortcuts with `DIAG_P` (0.18), never
  crossing. Islands are joined by their shortest gap, so the town is always connected.
- **Several paths, several fronts.** A gap gets a **highway** across it with probability `HIGHWAY_P` (0.85)
  per direction: a street from the building before the gap to the one after it, drawn wide and pale, with
  nothing to cross — so a park becomes a corridor and most districts have two ways in. The two best-connected
  crossroads of the mid town (value ≥ 2, three or more streets, never a start cell or the hub) are
  **junctions** (`JUNCTIONS`): every street touching a junction admits `JUNCTION_CAP_MULT` (×2) packets per
  second. A junction wears a thin double frame and the word "junction"; its panel says so. Holding one is a
  logistics prize: the second front runs through it.
- A building has a **type** (below), **security** (neutral defenders: 2 + 5 × value + 0…5 + the type's
  bonus, clamped 4…28; the DOWNTOWN HUB 30), **value** (1…3: Cash per market packet; downtown 3, mid-town 2,
  rim 1). A building is drawn **as its type's pictogram**, filled in its owner's colour, sized by its slots, with a
  bot counter at its foot and a square frame for selection, focus and threat; `$` marks show value.
- **Three botnets, one town.** You start top-left, **NYX** bottom-right, **KRAKEN** bottom-left, each with a
  **Server** rig (2 Bot farms) and a **PC**. Everything else is **neutral**.

### Building types (random per town; the building is drawn as the type's pictogram)
| Type | Picture | Slots | Production multipliers | Security bonus | Weak to (×1.5) | Resists | Where it spawns |
|---|---|---|---|---|---|---|---|
| PC | monitor | 3 | — | 0 | phishing | — | rim 40 %, mid 30 % |
| IoT device | chip with antenna | 1 | Credentials, Research ×0.5 | −3 (soft) | credential ×1.5, exploits ×1.25 | phishing 90 %, supply-chain 25 % | rim 35 % |
| Server | rack | 3 | Intel ×1.5, Research ×1.5 | +2 | — | phishing 50 %, credential 25 %, supply-chain 25 % | everywhere |
| Web server | globe | 3 | Intel ×1.5, Credentials ×2 | +2 | exploits | phishing 25 % | everywhere |
| Database | cylinder | 4 | Intel ×2, Credentials & Research ×1.5 | +3 | — | credential 50 %, phishing 50 % | mid 15 %, downtown 25 % |
| File server | cabinet | 4 | Intel ×2, Research ×2 | +3 | supply-chain | credential 25 %, exploits 25 % | mid 15 %, downtown 20 % |
| ERP system | factory with gear | 5 | bots, Intel, Cash, Credentials, Research ×1.5 | +6 | supply-chain | credential 50 %, exploits 50 %, phishing 25 % | downtown 20 %; the hub is always one |

Multipliers apply to what is built inside: a Bot farm in an ERP regenerates 1.5 bots/s, an Intel harvester
in a Database yields 2 Intel/s, a market in an ERP pays 1.5× its value per packet, a Credential harvester in a
Web server yields 1 Credential/s. The **second role** of a type is its resistance table (`RESIST`): a card
family lands at `1 − resist` (clamped 0…1.5), so phishing takes 10 % on an IoT device and 150 % on a PC. The
AI botnets prefer Intel-rich types for harvesters and Cash-rich ones for markets, and value richer types as
targets.

### Factions, bots and combat
- Four owners: NEUTRAL (city security), YOU, NYX, KRAKEN. Packets route **only through the sender's own
  faction network** (BFS to a building bordering the target, then the final hop). Every botnet plays by the
  **same rules**: one build job at a time, 1 Intel per attack bot, Cash travels home, guards.
- A building's bots are its health. An **owned** building regenerates `PROD_RATE` (1/s) per active Bot farm
  up to `NODE_CAP` (30). A **neutral** building regenerates only up to **its own security level** — so a
  neutral never becomes a 30-bot fortress (v1's hidden siege problem).
- `DEFEND_POWER = 1.5 × ATTACK_POWER`: an attack arrival removes 0.667 of a defender; a reinforcement adds 1.
  At 0 the building **flips to the attacker**, keeps its buildings and slots, loses its orders and job.
- Bots act only on arrival. Movement is hop by hop: `LINK_TIME` 1 s per link, `NODE_ROUTE_DELAY` 0.25 s per
  intermediate building, plus any **queue** time waiting for link room.

### Controls — two verbs (the designer's scheme; nothing ever fires from a gesture)
- **① CONNECT — drag-and-drop ONLY.** Left-click your building(s) to select (Shift-click adds/removes;
  drag on empty map = box-select; clicking a building also opens its panel), then **DRAG a line onto the
  target**; dragging from a selected group member wires the whole group. **Clicking never wires.** A link can
  only be made where **a path runs through your own buildings** (the rubber band turns red with "✖ no path").
  A wire is a **dashed, dormant connection**: no bots move, no Intel is spent. One connection per building;
  wiring again **replaces** it (dormant again); wiring a building's current target changes nothing. After
  wiring, the selection clears and the **target's panel opens**.
- **② ATTACK and DEFEND are the wire's STATUS.**
  - **Wire → a foreign building = an attack.** Click that building: its panel (the launch pad) lists
    everything wired into it, previews what launching would do (streams vs regeneration, time to capture,
    Intel), and carries the **⚔ ATTACK (launch N)** button — the only trigger. Pressing it turns every
    **dormant** wire into that building **live at the same moment**. Each target launches independently;
    wires added after a launch stay dormant until the button is pressed again. Unrouted wires are held.
  - **Wire → your own building = a GUARD.** No button: guards **arm themselves** the moment the protected
    building is under attack (hostile bots inbound or a hostile live wire) or below full (counting help
    already in the air), and **stand down** once it is safe and topped up.
- **Stop vs Disconnect.** "Stop N flow(s) (keep connections)" pauses an attack's live flows but keeps the
  wires. "Disconnect" removes wires (from selected sources, or all into a building). Both affect *future*
  departures only. **Esc / right-click** clears selection and panel — **never your wires**. Space pauses.
  **R** (or the tab bar at the top of the panel) switches between the MAP panel and the RESEARCH tab. A card is
  played by **dragging it from your hand onto a building** (the third drag gesture, next to wiring and
  building). Inside a building, **right-click a built slot** to demolish it.
- **Ownership transitions.** Capturing a building turns your attack flows into **guards** that top it up and
  stand down ("N flow(s) now top it up as guards"); **losing** a building **stands your wires down** (dormant,
  kept) — retaking it is an explicit ⚔ ATTACK. The same applies to the AI botnets. A flow whose route is
  lost pauses ("connection kept; launch again when routed"); an alternate owned route is used automatically.
- **Focus / fog — strict.** Opening a building's panel (or dragging over one) brightens only the buildings
  wired **into** it and the one its own wire points **to**; routes stay lit but pass-through buildings fog.
  **Gold ring** = friendly connection; **wide red ring** = a hostile building wired into it. A building of
  yours under attack always keeps a small full-brightness red ring. "↻ Restart in a new town" is always
  available at the bottom of the panel.
- **Visual language.** Dashed = dormant wire (yellow for an attack plan, green for a guard, faction-tinted
  for the AIs). Solid = live flow, coloured by the **source's** faction: your attack = amber arrow, your
  defence = green diamond, an AI's flow = its colour, brighter when aimed at you. Packets: yours = circle,
  AI = square in its colour, Cash = diamond, **a card in flight = a glowing card shape in its family's colour
  with its remaining path dashed**. Amber street = link at capacity. Wide pale street = a highway across a
  gap; a thin double frame and the word "junction" = a junction (double traffic). Text uses five colours
  with one meaning each: facts, secondary, needs you (amber), going your way (green), hostile (red). Each building carries only its name with
  its "$" value marks and a strength badge ("?" until scanned); one warning word under it when true (CRITICAL,
  SHAKY, FULL ↩, OFF 12s, CUT 8s); what is built inside and the send rate show only while it is selected or
  its panel is open. The HUD is one line: your Cash against the goal, the two rivals' Cash, Intel with its
  drain while attacking, the clock. A card landing flashes an
  expanding frame in the caster's colour; a worm draws its jumps for four seconds; a building with production
  off wears an orange frame and "PROD OFF Ns", one with routing cut a pink frame and "ROUTE CUT Ns".

### Scanning — quiet reveal, or attack blind and raise the alarm
- A foreign building you have not scanned shows **?** for its bots; its slots and what is inside are unknown.
  Its type (the pictogram) and district value are visible.
- **Flow: CONNECT → SCAN or ATTACK.** Wire into the building; its panel offers two launches.
  - **🔍 SCAN quietly:** your sources release scan bots along their network (1 Intel each, like attack bots).
    They are **consumed on arrival and never wound a defender, and the owner is never alerted**: no red frame,
    no guards arming, no AI reaction, and other botnets' scan packets are invisible to you. The building's
    **scan protection** is a fixed threshold, not regenerated and not depleted: `SCAN_BASE` (10) bots plus
    `SCAN_PER_BUILD` (5) per building inside. One source at 1 bot/s scans an empty PC in about 10 s; a full
    Database takes 30. When the threshold is reached the building is **revealed** (bots, slots, contents), the
    scan flows **stand down** (dormant, wires kept) and the panel switches to **⚔ ATTACK** — nothing auto-fires.
  - **⚔ ATTACK blind:** attack bots wound as usual and **reveal the building as they land** (the same 10 + 5
    threshold), but the attack **is an alarm**: the owner sees it, guards arm, the AI defends.
- Knowledge is per botnet and does not expire unless the inside changes (a building built, demolished or
  replaced), which requires a rescan. Partial progress is kept. A building you own needs no scan.
- The AI botnets scan quietly before an attack and counter-attack blind.

### Control stages (experiment 4)
`FULL` ≥ 2/3 cap: all slots work · `SHAKY` ≥ 1/3: the last slot is offline · `CRITICAL`: the last two are
offline (the first slot always works). A freshly captured building starts near 0 bots: only its first slot
runs until it is reinforced or regenerates.

### Buildings (the local, experiment 1)
| Kind | Icon | Effect |
|---|---|---|
| Bot farm | green server rack | +1 bot/s regeneration in that building |
| Intel harvester | cyan eye with antenna | +1 Intel/s (global to its owner) and **+50 to the Intel limit** |
| Darknet market | gold coin | one Cash packet worth the building's **value** every `CASH_INTERVAL` (3 s), travelling home to the owner's rig; Cash is the win **and** pays for cards |
| Credential harvester | orange key | +0.5 Credentials/s (× the type) and **+50 to the Credentials limit**; Credentials pay for cards |
| Research lab | violet flask | +0.5 Research/s (× the type) and **+50 to the Research limit**; Research pays for cards |

Credentials and Research are pools like Intel (start 0, limit 50 + 50 per building); Cash has no limit because
it is the score. A building whose **production is switched off** by a card makes none of this and does not
regenerate; a built harvester or lab still counts toward the limit.

- Select one of your buildings → **Enter building** (`ENTER_TIME` 2 s to connect). Inside, the panel shows the
  building's **slots** as a row of boxes: an empty slot shows **+**, a built slot shows the building's icon and
  name (dimmed with "OFF" when the control stage has switched it off), a working slot shows a progress bar.
  Below the slots sit **cards**, one per building kind, each with its icon and build time.
- **Drag a card onto an empty slot** to build there: `BUILD_TIME` (10 s). **Drag a card onto an occupied
  slot** to replace: the old building goes offline at once, `DEMOLISH_TIME` (5 s) clears the slot, then
  `BUILD_TIME` (10 s) builds the new one — 15 s in all. Dropping the same kind on a slot does nothing.
  Clicking a card builds it into the first empty slot. Right-clicking a built slot clears it in 5 s.
- One job per building; it **progresses only while you stay inside**; Cancel stops it. While inside, the map
  is veiled but **alive**; you cannot command it; alerts still arrive. If the building falls while you are
  inside, you are thrown out.
- Each AI botnet runs **one build job at a time** (its attention), always progressing, into its first empty
  slot; it never replaces.

### Intel (settled — kept distinct from the card resources)
Each attack **and scan** bot released at a foreign building costs its owner 1 Intel; guards and reinforcement
are free. Every botnet starts with 50, limit 100 (+50 per Intel harvester). Departures resolve in time order
with a rotating tie-break. Intel gates aggression; Cash, Credentials and Research fuel cards (see Economics).

### The win — control the town (decision: hold the majority)
Cash stopped being the win; **control decides**, which removed the old bank-vs-buy tension. A match resolves
three ways, checked every tick:
1. **Outright domination** — hold **more than `HOLD_FRACTION` (0.5) of all buildings** for `HOLD_SECS` (45 s)
   without a break. A 31-building town needs 16. Rare, but a snowball wins fast.
2. **Last botnet standing** — capture every rival building (elimination), detected the instant a capture
   leaves one botnet with buildings.
3. **The bell** — at `MATCH_TIME` (300 s = 5 min) whoever controls the **most buildings** wins (ties broken by
   total bots, then faction order). This guarantees the match ends and makes control matter throughout.

Measured, a straight ">50 % of all" almost never resolves in a three-way (the two AIs hold each other near
42 %), so the bell is what actually decides most matches. You lose immediately if you ever hold zero buildings.
The HUD shows each botnet's control %, marks the leader with a dot, and counts the match clock down; when
someone holds a true majority it shows the hold timer.

### Economics — the four resources (documented for tuning)
Everything is a rate or a packet; all the numbers live in `scripts/botnet_cfg/tuning.gd` and `cards.gd`.

| Resource | What it does | Produced by | Rate (× the type) | Limit |
|---|---|---|---|---|
| **Bots** | a building's health **and** its defence; an attack bot removes `ATTACK/DEFEND` (0.667) of a defender, a reinforcement adds one | Bot farms | `PROD_RATE` 1/s each, × the type's `bot` | `NODE_CAP` 30 (owned); a neutral regenerates only to its `security` |
| **Intel** | fuels attacks and scans: **1 per bot sent at a foreign building** (guards and reinforcement are free) | Intel harvesters | `INTEL_PER_BUILD` 1/s each, × `intel` | `INTEL_CAP_BASE` 100 + 50 per harvester |
| **Cash** | fuels **cards** (no longer the win) | Darknet markets | one packet worth the building's **value** × `cash`, every `CASH_INTERVAL` 3 s, travelling to the owner's rig | none |
| **Credentials** | fuels cards | Credential harvesters | `CRED_PER_BUILD` 0.5/s each, × `cred` | `RES_CAP_BASE` 50 + 50 per harvester |
| **Research** | fuels cards | Research labs | `RESEARCH_PER_BUILD` 0.5/s each, × `research` | 50 + 50 per lab |

Production goes to the **beneficiary** of a building: normally its owner, but a **supply-chain** card makes
the caster the beneficiary for a few seconds (the siphon). The per-type multipliers are in the Building types
table above (e.g. a Web server makes ×2 Credentials, a File server ×2 Research, an ERP ×1.5 of everything).
Inside a building you build five kinds — Bot farm, Intel harvester, Darknet market, Credential harvester,
Research lab — each taking `BUILD_TIME` 10 s (replace = 5 s demolish + 10 s), with a 2 s connect to enter.

### Cards — ultimate weapons (the RESEARCH tab, `R`)
Cards ruin defenders, deny production, cut logistics or **siphon** an enemy's output. **They never capture**:
a card only weakens a building — a bot of yours still has to arrive to take it, so a worm prepares a chain and
your streams take it.

**Six families, each a SINGLE card and a WORM (mass) version — twelve cards.** The family decides the effect;
the shape decides whether it hits one building or spreads. A worm hits one building and jumps along the streets:
jump 1 is certain, then the chance falls by `WORM_FALLOFF` (25 %) per jump — 75 %, 50 %, 25 %, 0 — at most four
jumps out, never onto the caster's own buildings, each building once, stopping at one immune to the family.

| Family | Effect (× the type's resist factor) | Single | Worm | Single cost (LINKED) | Single time |
|---|---|---|---|---|---|
| **Credential** | wipe **all** defenders (−100 %) | Credential stuffing | Credential worm | 20 $ · 35 K · 10 R | 25 s |
| **Phishing** | **−50 %** defenders | Phishing | Phishing worm | 20 $ · 25 K · 15 R | 22 s |
| **1-day exploit** | **−25 %** defenders | 1-day exploit | 1-day worm | 20 $ · 10 K · 25 R | 20 s |
| **0-day exploit** | **−50 %** defenders **and** routing cut 20 s | 0-day exploit | 0-day worm | 50 $ · 25 K · 55 R | 40 s |
| **Supply-chain** | **steal** the building's production for 5 s (its Cash, Intel, Credentials, Research go to you) | Supply-chain hit | Supply-chain worm | 40 $ · 30 K · 40 R | 35 s |
| **Denial of service** | production off **and** routing cut for 25 s | DoS | DDoS | 30 $ · 20 K · 30 R | 25 s |

Worms cost roughly 3× the Cash/Credentials and 2× the time of their single. Each family has its own neon colour
and glyph (padlock, envelope-and-hook, shield-1, shield-0, crates on a belt, a flood of arrows). The full
rendered sheet is `review/botnet_v2_2026-10-11/all_cards.png`.

- **Resist scaling (the type's second role):** the landed effect multiplies by `1 − RESIST[type][family]`
  (clamped 0…1.5). A PC is weak to phishing (×1.5), an IoT device resists it 90 % (×0.1) but is weak to
  exploits, a Database resists credential attacks 50 %, an ERP resists 0-day 50 % but is weak to supply-chain.
  A defender effect is capped at 100 %; a timed effect's duration scales too.
- **Research, not purchase:** the RESEARCH tab shows the catalogue as Magic-style card faces grouped by family
  (single then worm), with a LINKED / ANY switch. Clicking a card queues it; the head of the queue runs for the
  card's time and **consumes its cost spread over that time** (stalls without a resource, Pause stops the
  consumption, Cancel loses progress). A finished card goes into your **hand**, which accumulates without limit.
  The queue lets you push a later card to the front.
- **Two reaches:** **LINKED** needs a connection into the target (the CONNECT verb is the delivery route);
  **ANY** works anywhere at `ANY_COST_MULT` (×4) the cost and `ANY_TIME_MULT` (×2) the time.
- **Playing — drag and drop:** drag a card from your hand (under a foreign building's panel, or the research
  tab) onto a building. Valid targets light up; the one under the pointer previews the effect. Dropping it
  launches the card as a **packet** that travels the links (a LINKED card from the nearest connected building,
  an ANY card from your rig over any streets), drawn as a glowing card with its path dashed ahead. The effect
  lands **on arrival**; if the building became yours meanwhile it fizzles. Every hit **reveals** the building
  to you and **alarms** its owner for `CARD_ALARM` (8 s). The AI botnets research and play the same cards.
- A routing cut makes a building relay nothing (flows through it pause, the wire kept). A siphon shows
  "SIPHON Ns" in the supply-chain colour; production-off shows "OFF Ns"; a routing cut "CUT Ns". Effects wear
  off on their own; a captured building starts clean.

### Links (experiment 2)
`LINK_CAP` 2 packets per `LINK_TIME` per direction. A link at capacity draws amber. The packet timeline
(every hop's entry time) is fixed at departure; arrivals resolve chronologically; results do not depend on
frame rate (checked at 60 Hz vs 2 Hz).

### Rate dial (experiment 5) and rally (command-unit experiment)
- `− rate / + rate` on any selection: 25 %…100 % of `SEND_RATE` (1 bot/s).
- **Set rally point** on one building: every **unwired** idle building of yours sends its surplus above
  `RALLY_RESERVE` (10) to it, never overfilling it (inbound counted), and **pauses while under attack**.

### The AI botnets — strong, under your fog, and playing like a human
**NYX** (red, bottom right, `aggr` 0.8: prefers botnet targets, opens a second front) and **KRAKEN** (purple,
bottom left, `aggr` 0.45: economic) are the two AI botnets. Every `cadence` (NYX 3 s, KRAKEN 3.5 s, × `AI_SPEED`)
an AI runs one think. They have the **same knowledge and the same limits as the player** — no cheats.

**Like a human (attention and reaction).** Building costs attention exactly as it does for you: starting a build
**enters** that building (a 2 s connect), the job progresses only while the AI is attending it, and while it is
heads-down on a build it issues **no map commands**. A building coming under attack pulls it off the build to
defend (the job pauses); it re-connects and resumes once safe. A **reaction delay** (`AI_REACT` 1.5 s) means it
takes a moment to notice a loss and scramble reserves — its pre-wired guards still arm instantly, as yours do.
So an AI, like you, cannot build and attack in the same instant; measured, this costs it a building or two of
expansion and makes it beatable while still winning the idle match.

**What an AI may know (the same as you).** Its own buildings: everything. A foreign building it has
**scanned** (record done, contents unchanged): the live bots and what is built — exactly your badge and panel.
Anything else: **"?"**, so it reasons like you would from public facts — the type (the pictogram), the value
(the `$` marks), the owner, the streets, the rig frames, the hub, the OFF / CUT frames — and from **memory**:
what it last saw there (regrown at one Bot farm's rate since), the kinds it saw inside, a building it lost, a
capture it witnessed (a just-taken building is known to be near empty), where it was last hit. It sees other
botnets' **live attack flows** and their bot, Cash and card packets, and rival Cash in the HUD; it never sees a
dormant plan, a quiet scan, a rate dial, a job, or the inside of a building it has not scanned. Two gates
enforce this in code: `_ai_known_bots` and `_ai_known_builds`; every other AI reader is built on them, and a
twin test (probe 27) proves the AI's decisions do not change when only hidden fields change. The public
estimate for an unscanned building: hub 30; a botnet's building `AI_PRIOR_BOTNET` × 30 = 18; a neutral
`2 + 5 × value + 2.5 + type bonus` (4…28).

**The same rule for you.** The map and panel no longer show other botnets' dormant wires or quiet scans, nor the
SHAKY / CRITICAL band under a foreign building you have not scanned, and your **memory of a scanned building
refreshes every tick** just like the AI's, so when it goes dark you recall what it last was, not a stale snapshot.

**One think, in order:**
1. **Remember** — refresh the memory of every building it currently sees.
2. **Housekeeping** — release wires whose target it now holds (full and safe) or cannot reach; patience runs on
   what it can see: a scan landing bots, a reveal, a scanned target's bots dropping all count as progress;
   `AI_PATIENCE` (30 s) without any → give up, avoid that target next time.
3. **Defence** — remember the edge that is under attack; wire idle neighbours with surplus as live guards when
   the visible threat (every attacker assumed at 100 % rate) beats regeneration plus help; **counter-attack a
   visible attacker** with two streams when, on what it knows, that attacker falls within patience and the
   Intel is there (a building streaming out is net-zero at home).
4. **Build** — Intel harvester in the safest building while income is short; a second Bot farm on a botnet
   border; once it holds three buildings and a market, a Credential harvester and a Research lab in the rear;
   otherwise a market in its richest building.
5. **Research** — a DoS first when a rival leads on buildings by `AI_CHOKE_LEAD` (2), else the cheap 1-day
   (−25 %), then Credential stuffing (−100 %), a Credential worm (NYX), a second 1-day.
6. **Cards on its current targets** — drop defenders to speed a kill: a Credential worm on the seed whose
   **public types** promise the longest chain, else stuffing, phishing or a 1-day down the ladder.
7. **Choke the control leader** — DoS a known production building (market, harvester, lab) of the rival ahead,
   laying a dormant wire to deliver the LINKED card.
8. **Offence — scout, then strike.** Every bordering foreign building is scored by benefit over time-to-fall
   **on what the AI knows**; a known building gets +2 (trust what it learned), a visibly bleeding one +1.5, one
   someone else is visibly cracking +3 (+8 and a two-stream dash when it is nearly down: steal the kill), one it
   lost +4…6, a junction +3; a siege longer than `AI_SIEGE_MAX` (120 s) on what it knows is not started (know
   your limits — a slow steady siege still counts as progress for patience). An **unknown**
   pick is first **scanned quietly with two sources** (no alarm) — unless it is already alarmed by someone else;
   the next think re-scores it as known and attacks with the sized force, dropping its defenders with the best
   card in hand first.
9. **Idle scouting** — with nothing worth striking and `AI_SCOUT_INTEL` (20) in reserve, one source quietly
   scans the richest unknown neighbour so the knowledge is banked for the next expansion.
10. **Supply** — full rear buildings pre-wire dormant guards to the frontier building hit most recently
    (`AI_EDGE_MEMORY` 60 s), else to the weakest; the guard arms itself when the next blow lands.

Tuning for a human (all in `scripts/botnet_cfg/`): `AI_CASH_MULT` (0.75 ≈ a slower economy), `AI_SPEED`,
`AI_PRIOR_BOTNET`, `AI_REACT`, then the win knobs `HOLD_FRACTION` / `HOLD_SECS` / `MATCH_TIME`. Measured, the AIs'
clock is their **expansion**, not their thinking: slowing `AI_SPEED` barely moves it, lowering their income or
tightening the win line does.

## Where the numbers live
Everything tunable is in `scripts/botnet_cfg/`, one file per concern, and the game script only aliases them
(`const MATCH_TIME := CfgTuning.MATCH_TIME`), so probes and the panel keep their names:

| File | Holds |
|---|---|
| `factions.gd` | the four owners, names and colours; the AI personalities (`aggr`, `cadence`), its reserve/patience/stream limits, the **human knobs** (`AI_SPEED`, `AI_CASH_MULT`, `AI_REACT`) and the fog priors (`AI_PRIOR_BOTNET`, `AI_SCOUT_INTEL`, `AI_CHOKE_LEAD`, `AI_EDGE_MEMORY`, `AI_SIEGE_MAX`) |
| `town.gd` | grid size, gap chance, street keep chance, diagonal chance, street names |
| `types.gd` | `NODE_TYPES` (slots, production multipliers, security bonus), `TYPE_WEIGHTS` by district, `RESIST` (the card families each type resists or is weak to) |
| `buildings.gd` | `BUILD_KINDS` (the five things you build inside) and the build, demolish and enter times |
| `cards.gd` | the twelve cards (six families × single/worm: cost, time, effect, rules, flavour), family names and colours, the ANY multipliers, the worm fall-off, the steal duration and the alarm |
| `tuning.gd` | bots and combat; the resources and their limits; Cash; scanning; links; control stages; rally; and the **win knobs** `HOLD_FRACTION` / `HOLD_SECS` / `MATCH_TIME` |

Change a value, restart the scene. Nothing in `botnet_proto.gd` defines a number.

## Provisional values
**Win:** `HOLD_FRACTION 0.5 · HOLD_SECS 45 · MATCH_TIME 300`
**AI (human + fog):** `AI_SPEED 1 · AI_CASH_MULT 1 · AI_REACT 1.5 · AI_PRIOR_BOTNET 0.6 · AI_SCOUT_INTEL 20 · AI_CHOKE_LEAD 2 · AI_EDGE_MEMORY 60 · AI_SIEGE_MAX 120 · AI cadence 3 / 3.5 · AI_RESERVE 6 · AI_PATIENCE 30 · AI_MAX_STREAMS 4`
**Town:** `HIGHWAY_P 0.85 · JUNCTIONS 2 · JUNCTION_CAP_MULT 2 · EMPTY_CELL 0.15 · LINK_KEEP 0.78 · DIAG_P 0.18`
**Bots/combat/links:** `NODE_CAP 30 · PROD_RATE 1 · ATTACK 1 / DEFEND 1.5 · SEND_RATE 1 · LINK_TIME 1 · NODE_ROUTE_DELAY 0.25 · LINK_CAP 2 · MAX_QUEUE 1`
**Scan/build:** `SCAN_BASE 10 · SCAN_PER_BUILD 5 · BUILD_TIME 10 · DEMOLISH_TIME 5 · ENTER_TIME 2`
**Resources:** `INTEL_START 50 · INTEL_CAP_BASE 100 · INTEL_CAP_PER_BUILD 50 · CASH_INTERVAL 3 · CRED_PER_BUILD 0.5 · RESEARCH_PER_BUILD 0.5 · RES_CAP_BASE 50 · RES_CAP_PER_BUILD 50 · RALLY_RESERVE 10`
**Cards:** `ANY_COST_MULT 4 · ANY_TIME_MULT 2 · WORM_FALLOFF 0.25 · STEAL_DUR 5 · CARD_ALARM 8`

## Arithmetic that decides the game (for designers)
- Streams needed to beat a building's regeneration: `floor(regen × 1.5) + 1` → 2 against one Bot farm, 4
  against the hub's two. Concentration is cheaper in Intel and time: a 20-bot building costs 120 Intel with
  two streams and 60 with three.
- A building that is streaming out loses 1 bot/s on top: one stream drives a streaming attacker down to its
  garrison; a second finishes it. Attacking the attacker is the counter-play, and the AIs use it.
- From a cold start, 50 Intel buys 25 s of a two-stream attack: enough for a rim building (security 7…12),
  not for downtown. Building an Intel harvester early is mandatory; the idle panel says so.

## Validation (2026-10-12, Godot 4.7.2 headless + rendered under Xvfb)
Mechanics probe in `review/botnet_v2_2026-10-11/`: **46 cases**. The town and factions (connected, different per
seed; highways bridge gaps, two junctions carry double traffic); faction routing and link-capacity queueing;
chronological arrivals with a mid-delivery terminal freeze (elimination); control stages; the **attention rule
for both the player and an AI** (a build progresses only while its owner attends it, after a connect delay);
capture and the neutral security cap; scanning (quiet vs blind, the threshold, rescan on change); building types
and their multipliers; the fog-bound AI (the twin test that perturbs only hidden fields and asserts identical
decisions; the public prior; scout-then-strike; visibility of others' flows; scan memory; the lawful
counter-attack; limits; retaking; idle scouting; choking the leader; learned edges; worm value) and the player's
matching fog (a UI twin test; stale-memory display); the **card system** — the research queue (consume over time,
pause, stall, accumulate, ANY ×4/×2), the single-card **defender ladder** (1-day −25 %, phishing −50 %, stuffing
−100 %) with **resist scaling** (DB resists credential ×½, PC weak to phishing ×1.5, IoT resists it 90 %), a
**supply-chain steal** (the target's production flows to the caster, the owner denied, then recovers), a **DoS**
(production off and routing cut together, then recover), worms (a chain at 100/75/50/25 %, never the caster's own,
no capture), and cards travelling as packets that land on arrival; the AI card economy; the **win** (a
domination-hold with a clock that resets on loss, an elimination freeze). The **AI attention and the symmetric
memory** have their own cases. Rendered captures (49 shots) and the all-cards sheet are in `gallery/` and
`all_cards.png`.

**Pacing (not verdicts), 10 Hz, two AI botnets under the player's fog and playing like a human, control win,
5-minute match:** every match resolves at the bell by control.

| Run | Outcome | Time | Buildings you / NYX / KRAKEN | Cards played NYX / KRAKEN |
|---|---|---|---|---|
| You idle (seed 7) | NYX controls the most | 5:00 | 2 / 9 / 5 | 2 / 2 |
| Greedy scripted player (seed 7) | NYX controls the most | 5:00 | 3 / 9 / 5 | 2 / 2 |
| Greedy scripted player (seed 11) | NYX controls the most | 5:00 | 3 / 10 / 6 | 5 / 3 |

In a three-way the two AIs hold each other near 30-42 % of the town, so a straight ">50 % hold" rarely fires and
the **bell decides by control** — which is why the match clock exists. The human attention cost trimmed the AIs
from ~9-12 buildings to ~7-10 at the bell, so they are more beatable while still beating an idle or naive player.
**The AIs' clock is expansion, not thinking:** `AI_SPEED` barely moves it; lowering `AI_CASH_MULT` or tightening
`HOLD_FRACTION` / `MATCH_TIME` does. Tune those after the first human runs.

**Worm reach (a tuning note):** with the 100/75/50/25 % jumps on a 6×6 town (0.78 street density), a worm fired
at the downtown hub reached ~18 of 31 buildings; if that is too much for a 60-second card, lower the first jump
or raise `WORM_FALLOFF`. The designer's rule is kept until play says otherwise.

## Earlier draft: Cash buys attack cards (designer's direction, 2026-10-12 — superseded by "Cards" above)

Cash is only the win condition today. The direction: **Cash also buys attack cards**, so banking for the win
competes with buying weapons, and building **types** gain a second role — each type is **vulnerable** to some
cards and resistant to others, on top of its production affinity.

**Two shapes of card.** A **single-host** card hits one building. A **worm** hits one building, then tries to
jump along the streets to every connected building: the first jump is certain, then the chance falls by 25 %
per jump (jump 2: 75 %, jump 3: 50 %, jump 4: 25 %, jump 5: 0 %). A worm does not care whose buildings it
crosses — your own, if adjacent and vulnerable, are at risk, which is the price of the chain.

| Card | Shape | Effect on a vulnerable host | Vulnerable types | Cost (provisional) |
|---|---|---|---|---|
| Credential stuffing | single host | defenders −12 | PC, IoT (soft), Web | 40 |
| 1day | single host | defenders −10; nothing on a patched type | Server, Web, DB, File | 60 |
| 0day | single host | defenders −20, works on any type | all | 150 |
| Supply chain | single host → every connected host of the **same type** | defenders −8 and production off for 20 s | File, ERP (strong), Server | 120 |
| Credentials worm | worm | defenders to **0** on each infected host | PC, IoT, Web | 200 |
| 0day worm | worm | defenders −20 on each infected host | all | 400 |

Rules to keep the cards inside the existing model:
- A card never captures: it only removes defenders (or switches production off). Capture still needs an
  arriving bot, so a worm that zeroes a chain of PCs is followed by one stream per building — the card
  prepares, the bots take.
- Cards are bought in a **shop** panel with Cash and sit as cards in your hand; you **drag a card onto a
  target building** on the map (the same gesture as wiring and building) and its panel previews the effect,
  including the worm's expected reach and which of your own buildings are in the blast.
- The AI botnets buy the same cards under the same rules (a credentials worm against a rim of PCs is exactly
  the opening an aggressive NYX would take).
- Because Cash is spent, `CASH_GOAL` and card costs are tuned together; the first test is whether players
  ever prefer a card to banking.

Open before building it: whether a worm respects faction ownership or not (the risk is the fun, but a novice
will wipe their own PCs once), whether a card has a cooldown or an inventory cap, and whether the shop is in
the rig only (you must go home to buy) — which would make the rig a real base.

**Resolved on 2026-10-12 (see "Cards" above and change-log item 18):** built as research rather than purchase;
a worm never crosses the caster's own buildings; no cooldown and no inventory cap; no shop — the RESEARCH tab is
global. Still open: whether a card should need the target scanned first (today a card hit itself reveals), and
whether cards should be visible to the victim before they land (a research race).

## Other open questions
- Command unit: if the rally point suffices on 6×6, buildings stay the unit; if players still drown in
  wires, test district orders next.
- Whether a neutral building's security should be visible before you scan it (Intel as information).
- **Future hook (agreed, not built):** dormant wires could later be **detectable** by their target's owner —
  discovery risk for long-prepared strikes.
- How a prototype building maps to a basic-game building (which component exports bots, Intel, bandwidth,
  defence): see the local/global contract sketched in chat on 2026-10-11.

## Change log — how this design evolved (2026-10-10 → 2026-10-11)

Each change was driven by playtesting feedback from the designer; the current spec above always wins over
anything older. Historical pre-attrition designs live in `BOTNET_ATTACK_HISTORY.md`.

1. **Bot-attrition core** replaced the fuel/interior/siege drafts: bots = node health (cap 30), universal
   regeneration, hop-by-hop travel with pauses, effects only on arrival, HUB win / last-node defeat.
2. **Simulation hardening** (review-driven): one shared clock with absolute depart/arrive times; chronological
   arrival resolution (fixed a false HUB win); terminal freeze; hop leftover-time carry; cancellation scoped
   to player-owned sources.
3. **Combat power + Intel economy:** D = 1.5·A (defenders' edge → concentration matters); build slots from
   Bot / Intel production / Intel capacity; attack bots cost 1 Intel each, reinforcement free.
4. **Command scheme, iteration 1 — rejected:** drag auto-started attacks ("you drag and drop an attack
   immediately started"). Rule since then: **nothing ever auto-fires from a gesture.**
5. **Iteration 2 — rejected:** select sources → click target → per-group START button. Problem: each group's
   press fired immediately — impossible to stage a multi-pronged strike ("I start the attack! I want first to
   make connections, and when I will be ready — I can press attack").
6. **Iteration 3 — CURRENT: two verbs.** **CONNECT** (wires = dashed dormant plans, rewirable forever,
   Esc never touches them) and **LAUNCH from the target's own panel** (its button fires all dormant wires
   into it at once; each target independent; later wires wait for the next press).
7. **Readability pass:** decision-oriented panel; combined contribution at a target (flowing vs dormant,
   per-source states); cause→action stall diagnostics; Intel reserve/income/spend in the HUD; result screen
   with cause + elapsed time; "stop / disconnect" terminology (never "remove link" — the network connection
   remains); routes coloured by **source** faction; attack = arrow vs defence = diamond; your bots = circles
   vs others = squares; time-fair Intel emission; demolish/rebuild (no permanent Intel lockout); panel
   reserves map space; always-available **↻ Restart**.
8. **Wiring constraints:** links are made by **drag-and-drop only** (clicking selects / opens panels, never
   wires) and only where a **path runs through your own buildings** (red rubber band + "✖ no path").
9. **Focus highlighting, user-tuned:** opening a building's panel highlights STRICTLY its connections —
   from-whom (gold ring = friendly, wide red ring = hostile attacker) and to-whom (gold ring); pass-through
   buildings, neighbours and unrelated under-attack buildings stay fogged (the small red threat ring still
   shows through). Cyan belongs to the DOWNTOWN HUB alone.
10. **Attack and defend as the wire's STATUS:** wire → foreign = attack (manual ⚔ launch); wire → own =
    **guard** — arms itself while the protected building is under attack or below full (counting inbound
    help), stands down after; capture turns attack flows into topping-up guards; loss stands wires down.
11. **Future hook (agreed, not built):** dormant wires may later be *detectable* by their target's owner.
12. **v2 — macro/micro race:** generated 6×6 town (gaps, jitter, diagonals, rich downtown, poor rim; a new
    town every run); neutral security that regenerates only to its own level (v1's hidden siege problem);
    Cash as the win, markets and travelling Cash packets; link capacity shared by bots and Cash; the local
    view with an attention cost (enter time, timed builds that progress only while inside, the map keeps
    running); control stages; the rate dial; the rally point; the drain-aware "not overcoming" diagnostic.
13. **Free-for-all:** two AI botnets (NYX, KRAKEN) under the player's rules — one build job at a time, Intel
    per attack bot, Cash home to a rig — with defence, counter-attacks on soft attackers, cost-aware target
    choice, pre-wired frontier guards, progress-based patience and personalities. An AI with no buildings is
    out; any botnet banking the goal first ends the run.
14. **Merged** the two-verb scheme (items 6, 8, 9, 10) into v2; guards replaced v1's "full-hold" experiment
    and manual reinforcement orders; the rally point now applies only to **unwired** buildings.
15. **Slots as a drag-and-drop board (2026-10-12):** the local view shows positional slots (empty = +, built =
    icon) and draggable building cards; drop on an empty slot to build in 10 s, on an occupied slot to replace
    in 5 s clear + 10 s build; a slot being worked on is offline; icons are drawn procedurally.
16. **Building types (2026-10-12):** PC, IoT, Server, Web, Database, File server, ERP — each with its own
    picture, slot count (1…5), production multipliers and security bonus, spawned by district; rigs are
    Servers, the hub is an ERP. Buildings are no longer circles: the pictogram itself is the building on the
    map (filled in the owner's colour, square frames for selection, focus and threat).
17. **Scanning (2026-10-12):** a foreign building is unknown ("?") until scanned. A quiet SCAN launch sends
    bots that are consumed without wounding and never alert the owner; the protection is a fixed 10 + 5 per
    building inside; a completed scan stands its flows down. Any ATTACK reveals the building as bots land
    but raises the alarm. A changed inside needs a rescan; the AIs scan quietly before attacking.
18. **Cards (2026-10-12):** the designer's card direction built as a RESEARCH tab. Two new resources with
    their own buildings (Credential harvester, Research lab) that also raise their limits; the Intel vault is
    folded into the Intel harvester (+50 limit each). Cards are researched over time from Cash, Credentials
    and Research (consumed while running, pausable, stalling without a resource) and accumulate in a hand.
    Seven cards in two shapes (single host / worm chain with 100-75-50-25 % jumps that never cross the caster's
    own buildings) and two reaches (LINKED: only where you hold a connection; ANY: anywhere at ×4 cost, ×2
    time). Effects: wipe defenders, production off, routing cut, or breach (both) — never a capture. Every
    type now carries a resistance table (its second role), e.g. IoT resists phishing 90 %, PC is weak to it
    ×1.5. The earlier draft (Cash-only purchase, a shop, drag-to-play, worms crossing own buildings, single-
    host supply chain) was replaced by the designer's refined brief on 2026-10-12: research instead of
    purchase, three resources, pausable research, linked/any reach, type resistances. Each card has its own
    **art**: a procedural skill-icon tile (dark, chamfered corner, neon glyph in its family's colour — amber
    credential, cyan phishing, magenta supply-chain, acid-green exploit; a chain marker on worms; the reach
    tag L/A and the count in the hand), shown in the catalogue, the queue, the hand and a target's play list.

19. **Relaxed UI, card faces, drag-to-play, config files (2026-10-12):** the designer asked for less text,
    Magic-style cards and drag-and-drop. Every panel was cut to the lines a player acts on (the idle help is
    six lines; the launch pad explains scanning in one; the inside view relies on tooltips; the launch pad's
    source list is one line). Cards became full faces (190×262 in the catalogue, 124×174 in the hand: title,
    art window, type line, rules text, flavour, cost bar, copies held, L/A reach tag, a chain marker on worms)
    with a LINKED / ANY switch instead of two buttons per card. A card is played by **dragging it from the hand
    onto a building**; valid targets light up and the hovered one previews the effect. A played card travels
    as a **card packet** along the links (a LINKED card from the nearest connected building, an ANY card from
    the rig over any streets) and lands on arrival; it is drawn as a glowing card with its path dashed ahead.
    All tables and numbers moved to `scripts/botnet_cfg/*.gd` (factions, town, types, buildings, cards,
    tuning) with aliases in the game script.
20. **Information hierarchy pass (2026-10-12):** the designer asked for a calmer, more spacious screen with
    only the most important readings on the most-seen view. Two independent UI reviews (HUD and map; the panel
    states) were run and applied: the HUD is one line led by the Cash race; buildings carry name, value and
    badge, with one warning word when true and details only when focused; the map has more air (lower jitter,
    wider pitch, floating labels flip below a building near the top edge). Every panel state leads with one
    status line and its primary 36 px button; rules text moved into button tooltips (SCAN, ATTACK, Enter,
    Rally, the RESEARCH tab); the preview, diagnostics and transit lines merged into one "✔ 2 flowing ·
    −0.3/s net · ≈14 s · 2 bots in transit" line; Intel shows only when it is short; faulted sources only;
    the hand shows only on a foreign building's panel under its weakness line; a built slot is demolished by
    right-click; Restart is a flat text button at the bottom. Three text sizes (18 / 14 / 12, one 11 px
    footer), 10 px row separation, 14 px panel inset.
21. **Several paths and fronts (2026-10-12):** highways bridge the town's gaps (a wide pale street from the
    building before a gap to the one after it, nothing to cross) and two junction spots, the best-connected
    crossroads of the mid town, carry double traffic on every street that touches them. Most districts now
    have two ways in; a junction is a logistics prize and the natural seat of a second front.
22. **Readability pass (2026-10-12):** a programmatic overlap check (six seeds; names with value marks,
    glyphs, warning words against the HUD strip, the panel, the flash strip and each other) drove tighter
    jitter (±18 % × ±9 %) and a lower warning line; it reports zero overlaps. Resources got pictures: the
    HUD, the research tab and every card's cost bar use the same icons as the building cards (coin = Cash,
    key = Credentials, flask = Research, eye = Intel). The research queue lists what comes next with
    "▲ research first" (the running card keeps its progress) and remove. One five-colour text palette with
    one meaning per colour (facts, secondary, needs you, going your way, hostile) replaced some forty colour
    literals; owners keep faction colours and cards keep their family neon. The flash message wraps inside
    the map instead of running under the panel.
23. **The AI plays under your fog (2026-10-12):** the designer's rule — the AI must have the same knowledge
    as the player, scan to learn, and plan from what it learned. An audit (three independent readers) found
    the AI omniscient in three places (target bots, target insides, attacker softness) and leaky in five more
    (rate dials, quiet-scan wires, the scheduler); a judged panel of three designs chose "two knowledge gates,
    scout-then-strike, eleven small tricks". Built as designed: `_ai_known_bots` / `_ai_known_builds` (own =
    exact, scanned = live, else memory regrown or a public prior), derived readers for regeneration, visible
    outflow, time-to-fall, third-party pressure and worm reach; memory in the scan record (bots, cap, time),
    lost buildings, witnessed captures, edges under attack. Tricks: scout quietly with two sources before any
    strike; price the dark from type and value; trust unchanged memory; pile on what others visibly crack and
    steal the kill; hit the bleeder; know your limits (`AI_SIEGE_MAX`); retake what it lost; idle scouting;
    choke the Cash leader with phishing over a dormant wire; pre-wire guards where it was last hit; worm the
    softest cluster by public types; counter a visible attacker on its prior. The attacker's rate dial is
    hidden from everyone (`_threat_rate` assumes 100 %). The same rule now applies to the player's screen: other
    botnets' dormant wires and quiet scans are not drawn or listed, and the SHAKY / CRITICAL band shows only on
    scanned buildings. A twin test (probe 27) perturbs only hidden fields and asserts identical AI decisions;
    thirteen more cases cover the gates, memory and every trick; a pacing guard asserts both AIs still capture
    within 150 s on two seeds. `AI_SPEED` is the human handicap knob.
24. **Verification pass on the fog (2026-10-12):** three independent skeptics (hidden reads, decision logic,
    UI symmetry) reviewed the rewrite. Fixed: the capture memory was written before the owner flipped (the
    loser never got it) and carried the hidden contents key (now blank; a fresh scan keeps the old memory);
    the visible-outflow reader counted an undrawn, routeless rally; the pre-strike phish was checked before the
    strike was wired; the choke-the-leader delivery wire was never released; dormant guards could never be
    re-targeted; a stalled target was shunned forever (now 2 × patience, and only while it keeps its owner);
    a cut route released a wire at once (now paused for patience, as the engine does for everyone); Intel
    budgets assumed `SEND_RATE` 1 and counted route nodes as seconds; a phish was wasted on a target about to
    fall; a dead botnet could be "the leader". On the player's side: opening a foreign building's panel lit the
    target of its hidden wire (the one real leak); the launch pad's preview and the attack line used the
    target's hidden job and rate dial (now the same readers as the AI); the scan line revealed the inside
    count; streets glowed amber from invisible scan packets (now visible traffic only); and the player got less
    memory than the AI (now a stale scan shows "last seen … ≈N bots now", a witnessed capture shows "≈0", and an
    unscanned building shows the same public prior the AI uses). Probe: a UI twin test (41) joins the AI twin
    test (27).

## Stoppers and status
Addressed in code: explicit launch, live panel, no map overlap, no Intel lockout (demolish/rebuild), neutral
siege problem (security cap), display agreeing with simulation (drain-aware diagnostic), feasible route to
victory (scripted wins recorded). **Pending:** human usability test (five new players, no coaching; gate 4 of
5 complete the core tasks: wire, launch, guard, enter a building, read a stalled attack), and a pacing pass
after it — now against two AIs that build and defend.
