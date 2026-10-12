# RIM — botnet prototype v2: macro/micro free-for-all (current spec)

*Active specification for the standalone prototype (`scenes/botnet_proto.tscn` + `scripts/botnet_proto.gd`).
Supersedes the v1 attrition prototype (hub capture on a fixed 5×3 grid), archived in
`design/BOTNET_ATTACK_HISTORY.md` §14. All numbers are provisional test candidates. Engine checks establish
mechanical correctness only; they do not establish balance or novice usability.*

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
- A building has a **type** (below), **security** (neutral defenders: 2 + 5 × value + 0…5 + the type's
  bonus, clamped 4…28; the DOWNTOWN HUB 30), **value** (1…3: Cash per market packet; downtown 3, mid-town 2,
  rim 1). A building is drawn **as its type's pictogram**, filled in its owner's colour, sized by its slots, with a
  bot counter at its foot and a square frame for selection, focus and threat; `$` marks show value.
- **Three botnets, one town.** You start top-left, **NYX** bottom-right, **KRAKEN** bottom-left, each with a
  **Server** rig (2 Bot farms) and a **PC**. Everything else is **neutral**.

### Building types (random per town; the building is drawn as the type's pictogram)
| Type | Picture | Slots | Multipliers | Security bonus | Where it spawns |
|---|---|---|---|---|---|
| PC | monitor | 3 | — | 0 | rim 40 %, mid 30 % |
| IoT device | chip with antenna | 1 | — | −3 (soft) | rim 35 % |
| Server | rack | 3 | Intel ×1.5 | +2 | everywhere |
| Web server | globe | 3 | Intel ×1.5 | +2 | everywhere |
| Database | cylinder | 4 | Intel ×2 | +3 | mid 15 %, downtown 25 % |
| File server | cabinet | 4 | Intel ×2 | +3 | mid 15 %, downtown 20 % |
| ERP system | factory with gear | 5 | bots, Intel, Cash ×1.5 | +6 | downtown 20 %; the hub is always one |

Multipliers apply to what is built inside: a Bot farm in an ERP regenerates 1.5 bots/s, an Intel harvester
in a Database yields 2 Intel/s, a market in an ERP pays 1.5× its value per packet. The AI botnets prefer
Intel-rich types for harvesters and Cash-rich ones for markets, and value richer types as targets.

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
  AI = square in its colour, Cash = diamond. Amber street = link at capacity.

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
| Intel harvester | cyan eye with antenna | +1 Intel/s (global to its owner) |
| Darknet market | gold coin | one Cash packet worth the building's **value** every `CASH_INTERVAL` (3 s), travelling home to the owner's rig |
| Intel vault | violet vault door | +100 Intel capacity |

- Select one of your buildings → **Enter building** (`ENTER_TIME` 2 s to connect). Inside, the panel shows the
  building's **slots** as a row of boxes: an empty slot shows **+**, a built slot shows the building's icon and
  name (dimmed with "OFF" when the control stage has switched it off), a working slot shows a progress bar.
  Below the slots sit **cards**, one per building kind, each with its icon and build time.
- **Drag a card onto an empty slot** to build there: `BUILD_TIME` (10 s). **Drag a card onto an occupied
  slot** to replace: the old building goes offline at once, `DEMOLISH_TIME` (5 s) clears the slot, then
  `BUILD_TIME` (10 s) builds the new one — 15 s in all. Dropping the same kind on a slot does nothing.
  Clicking a card builds it into the first empty slot. A Demolish button per built slot clears it in 5 s.
- One job per building; it **progresses only while you stay inside**; Cancel stops it. While inside, the map
  is veiled but **alive**; you cannot command it; alerts still arrive. If the building falls while you are
  inside, you are thrown out.
- Each AI botnet runs **one build job at a time** (its attention), always progressing, into its first empty
  slot; it never replaces.

### Intel (under review — see "Open question: Intel")
Each attack bot released costs its owner 1 Intel; guards and reinforcement are free. Every botnet starts
with 50, cap 100 (+100 per vault). Departures are resolved in time order with a rotating tie-break.

### Cash and the win (decision: Cash)
- Markets emit Cash packets to the owner's **rig** (the sink). The rig's own market banks directly. Packets
  share links with bots. A packet is banked by **whoever holds the rig when it lands**; if a rig is lost, its
  owner's markets hold until it is retaken.
- **Win:** bank `CASH_GOAL` (600) first. **Defeat:** NYX or KRAKEN banks it first, or you lose every building.
  An AI with no buildings left is "out of the game".

### Links (experiment 2)
`LINK_CAP` 2 packets per `LINK_TIME` per direction. A link at capacity draws amber. The packet timeline
(every hop's entry time) is fixed at departure; arrivals resolve chronologically; results do not depend on
frame rate (checked at 60 Hz vs 2 Hz).

### Rate dial (experiment 5) and rally (command-unit experiment)
- `− rate / + rate` on any selection: 25 %…100 % of `SEND_RATE` (1 bot/s).
- **Set rally point** on one building: every **unwired** idle building of yours sends its surplus above
  `RALLY_RESERVE` (10) to it, never overfilling it (inbound counted), and **pauses while under attack**.

### The AI botnets (decision: rival botnets; "super clever", they build too)
Every `cadence` (NYX 3 s, KRAKEN 3.5 s) an AI runs one think, in this order:
1. **Housekeeping:** release wires whose target it now holds (once full and safe) or cannot reach; drop an
   attack that made **no progress for `AI_PATIENCE`** (30 s) and avoid that target next time.
2. **Defence:** for each of its buildings under attack, compare the hostile streams' damage with its
   regeneration plus the help already flowing; if losing, wire idle neighbours with surplus as live guards.
   If an attacker is **soft** (≤ 14 bots) and streaming out, it **counter-attacks it with two sources**.
3. **Build** (one job at a time): an Intel harvester in its safest building while income is below
   1 + running attacks or the reserve is low; a second Bot farm in a building that borders another botnet;
   otherwise a market in its richest building.
4. **Offence** (one front, two for NYX once it holds 5 buildings): every bordering foreign building is scored
   by benefit (value, slots, buildings inside, +bonus if owned by a botnet, +bonus if others are already
   softening it, +bonus if it sits on its rig's doorstep) over time-to-capture; only attacks it can afford
   in Intel and beat in regeneration are considered; it concentrates `ceil((regen + 0.5) / 0.667)` sources
   (2…`AI_MAX_STREAMS` 4), nearest first, each keeping a garrison of `AI_RESERVE` (6).
5. **Supply:** full rear buildings wire **dormant guards** to the weakest frontier building, so help is
   pre-wired and arms itself when that building is hit.
NYX is aggressive (`aggr` 0.8: prefers botnet targets, opens a second front); KRAKEN is economic (0.45).

## Provisional values
`NODE_CAP 30 · PROD_RATE 1 · ATTACK 1 / DEFEND 1.5 · SEND_RATE 1 · LINK_TIME 1 · NODE_ROUTE_DELAY 0.25 ·
LINK_CAP 2 · MAX_QUEUE 1 · SCAN_BASE 10 · SCAN_PER_BUILD 5 · BUILD_TIME 10 · DEMOLISH_TIME 5 · ENTER_TIME 2 · CASH_INTERVAL 3 · CASH_GOAL 600 · INTEL_START 50 ·
INTEL_CAP_BASE 100 · RALLY_RESERVE 10 · AI cadence 3 / 3.5 · AI_RESERVE 6 · AI_PATIENCE 30 ·
AI_MAX_STREAMS 4 · EMPTY_CELL 0.15 · LINK_KEEP 0.78 · DIAG_P 0.18`

## Arithmetic that decides the game (for designers)
- Streams needed to beat a building's regeneration: `floor(regen × 1.5) + 1` → 2 against one Bot farm, 4
  against the hub's two. Concentration is cheaper in Intel and time: a 20-bot building costs 120 Intel with
  two streams and 60 with three.
- A building that is streaming out loses 1 bot/s on top: one stream drives a streaming attacker down to its
  garrison; a second finishes it. Attacking the attacker is the counter-play, and the AIs use it.
- From a cold start, 50 Intel buys 25 s of a two-stream attack: enough for a rim building (security 7…12),
  not for downtown. Building an Intel harvester early is mandatory; the idle panel says so.

## Validation (2026-10-11, Godot 4.7.2 headless + rendered under Xvfb)
Mechanics probe in `review/botnet_v2_2026-10-11/`: 19 cases — generation (three botnets, connected,
different per seed), faction routing, link capacity queueing, chronological arrivals with terminal freeze,
control stages, attention-gated jobs, capture and the neutral security cap, AI concentration and building,
Cash travel and banking, rally garrison and overfill, frame-rate consistency, attack-the-attacker, the two
verbs (dormant wiring, path constraint, launch, stop, Esc), guards arming and standing down, and ownership
changes (flows become guards, loss stands wires down), and the slot board (build into a chosen slot, replace in
5 + 10 s with the slot offline meanwhile), and building types (slots, Intel ×2 in a Database, bots ×1.5 in an ERP,
the single IoT slot), and scanning (a quiet scan raises no alarm, consumes bots, reveals at the threshold and stands
down; a blind attack alarms, wounds and reveals; a changed inside needs a rescan). Rendered captures of the panel states and scripted
matches are in `gallery/`.

**Pacing readings (not verdicts), goal 600, 10 Hz, two AI botnets active, 10 s builds, typed buildings,
scanning before attacks:**

| Run | Outcome | Time | Buildings you / NYX / KRAKEN |
|---|---|---|---|
| You idle (seed 7) | NYX banks 600 | 4:25 | 2 / 8 / 6 |
| Greedy scripted player, perfect attention (seed 7) | NYX banks 600 | 4:22 | 2 / 8 / 6 |
| Greedy scripted player (seed 11) | NYX banks 600 | 4:26 | 3 / 7 / 6 |

Scanning before every attack slowed the AIs by about half a minute. They still set a ~4½-minute clock and beat
the greedy script, so as asked they are strong. A first human run will need a handicap: raise `CASH_GOAL`,
slow the AI `cadence`, or lower `aggr`. Tune one value at a time after watching play; the AI only attacks what
it can afford and beat, so the honest first knob is its Intel start or cadence, not its combat numbers.

## Next: Cash buys attack cards (designer's direction, 2026-10-12 — not built yet)

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

## Stoppers and status
Addressed in code: explicit launch, live panel, no map overlap, no Intel lockout (demolish/rebuild), neutral
siege problem (security cap), display agreeing with simulation (drain-aware diagnostic), feasible route to
victory (scripted wins recorded). **Pending:** human usability test (five new players, no coaching; gate 4 of
5 complete the core tasks: wire, launch, guard, enter a building, read a stalled attack), and a pacing pass
after it — now against two AIs that build and defend.
