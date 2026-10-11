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
| How you command | **Two verbs:** CONNECT by drag, LAUNCH from the target's panel; guards arm themselves |

## The five experiments (what each tests)

1. **A local with an attention cost.** "Enter building" takes `ENTER_TIME` to connect, builds take `BUILD_TIME`
   and **progress only while you stay inside**, and while you are inside the map **keeps running and cannot be
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
- A building has **security** (neutral defenders, 7…22; the DOWNTOWN HUB 30), **value** (1…3: Cash per
  market packet; downtown 3, mid-town 2, rim 1), and **slots** (2…4; the hub 4). Drawn radius grows with slots;
  `$` marks show value.
- **Three botnets, one town.** You start top-left (YOUR RIG + one neighbour), **NYX** bottom-right, **KRAKEN**
  bottom-left, each with a rig (2 Bot farms) and one more building. Start buildings have value 1 and 3 slots.
  Everything else is **neutral**.

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

### Control stages (experiment 4)
`FULL` ≥ 2/3 cap: all slots work · `SHAKY` ≥ 1/3: the last slot is offline · `CRITICAL`: the last two are
offline (the first slot always works). A freshly captured building starts near 0 bots: only its first slot
runs until it is reinforced or regenerates.

### Buildings (the local, experiment 1)
| Kind | Effect |
|---|---|
| Bot farm | +1 bot/s regeneration in that building |
| Intel harvester | +1 Intel/s (global to its owner) |
| Darknet market | one Cash packet worth the building's **value** every `CASH_INTERVAL` (3 s), travelling home to the owner's rig |
| Intel vault | +100 Intel capacity |

- Select one of your buildings → **Enter building** (`ENTER_TIME` 2 s to connect). Inside: slots, one build job
  at a time (`BUILD_TIME` 6 s, progresses only while you are inside), demolish, leave (Esc / right-click).
- While inside: the map is veiled but **alive**; you cannot command it; alerts still arrive. If the building
  falls while you are inside, you are thrown out.
- Each AI botnet runs **one build job at a time** (its attention), always progressing.

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
LINK_CAP 2 · MAX_QUEUE 1 · BUILD_TIME 6 · ENTER_TIME 2 · CASH_INTERVAL 3 · CASH_GOAL 600 · INTEL_START 50 ·
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
Mechanics probe in `review/botnet_v2_2026-10-11/`: 16 cases — generation (three botnets, connected,
different per seed), faction routing, link capacity queueing, chronological arrivals with terminal freeze,
control stages, attention-gated jobs, capture and the neutral security cap, AI concentration and building,
Cash travel and banking, rally garrison and overfill, frame-rate consistency, attack-the-attacker, the two
verbs (dormant wiring, path constraint, launch, stop, Esc), guards arming and standing down, and ownership
changes (flows become guards, loss stands wires down). Rendered captures of the panel states and scripted
matches are in `gallery/`.

**Pacing readings (not verdicts), goal 600, 10 Hz, two AI botnets active:**

| Run | Outcome | Time | Buildings you / NYX / KRAKEN |
|---|---|---|---|
| You idle (seed 7) | KRAKEN banks 600 | 4:17 | 2 / 7 / 7 |
| Greedy scripted player, perfect attention (seed 7) | KRAKEN banks 600 | 4:15 | 3 / 7 / 5 |
| Greedy scripted player (seed 11) | NYX banks 600 | 3:51 | 7 / 8 / 6 |

The AIs now set a ~4-minute clock and beat the greedy script on both seeds, so as asked they are strong. A
first human run will need a handicap: raise `CASH_GOAL`, slow the AI `cadence`, or lower `aggr`. Tune one
value at a time after watching play; the AI only attacks what it can afford and beat, so the honest first
knob is its Intel start or cadence, not its combat numbers.

## Open question: Intel (explore before changing)
Today bots regenerate for free and **attacking** spends Intel. That reads as a duplicate: Intel is only an
attack tax. Options explored on 2026-10-11:

- **A. Intel pays for bots, attacking is free.** A Bot farm consumes 1 Intel per bot it produces and stops
  consuming at the cap. One currency, one budget: growing, defending (regenerating after damage) and attacking
  all draw on it. Needs a floor so a broke botnet can still regenerate slowly (no permanent lockout). The AIs
  already pay Intel like you, so the change applies to everyone. Thematically Intel-for-bots is a stretch;
  the basic game would call this fuel Cycles.
- **B. Intel pays for cards, bots are free.** Intel becomes a burst resource for **ultimate cards**:
  credential stuffing, a CVE exploit, phishing, a DDoS that freezes regeneration. Matches the basic game's
  resource-funded attack cards. Attack *types* then exist because each card is strong against a building
  **type** (offices/PCs for credentials, server farms for CVEs, residential for phishing) — the town already
  varies buildings, so types are cheap to add.
- **C. A + B.** Bots cost Intel to produce *and* cards cost Intel: the choice becomes "thirty bots or one
  exploit". Cards are additive and can be tested after A.

**Recommendation:** test **A** first (it changes the core loop; small code change: move the Intel charge from
`_emit_due` to regeneration and add the floor), keep attack types out of the bot flow, and bring them back as
**cards** against building types. Not implemented yet.

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

## Stoppers and status
Addressed in code: explicit launch, live panel, no map overlap, no Intel lockout (demolish/rebuild), neutral
siege problem (security cap), display agreeing with simulation (drain-aware diagnostic), feasible route to
victory (scripted wins recorded). **Pending:** human usability test (five new players, no coaching; gate 4 of
5 complete the core tasks: wire, launch, guard, enter a building, read a stalled attack), and a pacing pass
after it — now against two AIs that build and defend.
