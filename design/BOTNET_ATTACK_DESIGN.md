# RIM — botnet prototype v2: macro/micro race (current spec)

*Active specification for the standalone prototype (`scenes/botnet_proto.tscn` + `scripts/botnet_proto.gd`).
Supersedes the v1 attrition prototype (hub capture on a fixed 5×3 grid), archived in
`design/BOTNET_ATTACK_HISTORY.md` §14. All numbers are provisional test candidates. Engine checks establish
mechanical correctness only; they do not establish balance or novice usability.*

## Why v2 exists

The full game has two map scales: the **global** town map and the **local** network inside one building. The
framing we are testing: **global = MACRO** (redirect bots and traffic between buildings), **local = MICRO**
(build a lot inside a building). v1 collapsed the local into two instant, free slots, so the macro/micro trade
could not exist in it. v2 adds the five cheapest experiments that make that trade real, plus the decisions
taken on 2026-10-11:

| Decision | Answer |
|---|---|
| Who is the enemy | A **rival botnet**, starting from the bottom of the town |
| Does time run while you are inside a local | **Yes** |
| What are bots | A **stock held per building**; the more a building holds, the better it works |
| Win condition | **Cash** |
| Command unit (building / district / supply tree) | Undecided — the **rally point** is the experiment |

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

Plus the **rally point**: one standing order for the rear (every idle building auto-supplies it above a
garrison). *Tests:* does one order for the rear scale, or do we need districts?

## Current rules

### Town
- 6×6 cells; each non-forced cell is a gap with probability `EMPTY_CELL` (0.15). Positions jitter ±26 %.
  Grid streets exist with probability `LINK_KEEP` (0.78); diagonal shortcuts with `DIAG_P` (0.18), never
  crossing. Islands are joined by their shortest gap, so the town is always connected.
- A building has **security** (neutral defenders, 7…22; the DOWNTOWN HUB 30), **value** (1…3: Cash per
  market packet; downtown 3, mid-town 2, rim 1), and **slots** (2…4; the hub 4). Drawn radius grows with slots;
  `$` marks show value.
- **You** start top-left: YOUR RIG (2 Bot farms) and one neighbour. The **rival** starts bottom-right the same
  way. Start buildings have value 1 and 3 slots. Everything else is **neutral**.

### Factions, bots and combat
- Three factions: NEUTRAL (city security), PLAYER, RIVAL. Packets route **only through the sender's own
  faction network** (BFS to a building bordering the target, then the final hop).
- A building's bots are its health. An **owned** building regenerates `PROD_RATE` (1/s) per active Bot farm
  up to `NODE_CAP` (30). A **neutral** building regenerates only up to **its own security level** — so a
  neutral never becomes a 30-bot fortress (v1's hidden siege problem).
- `DEFEND_POWER = 1.5 × ATTACK_POWER`: an attack arrival removes 0.667 of a defender; a reinforcement adds 1.
  At 0 the building **flips to the attacker**, keeps its buildings and slots, loses its orders and job.
- Bots act only on arrival. Movement is hop by hop: `LINK_TIME` 1 s per link, `NODE_ROUTE_DELAY` 0.25 s per
  intermediate building, plus any **queue** time waiting for link room.

### Control stages (experiment 4)
`FULL` ≥ 2/3 cap: all slots work · `SHAKY` ≥ 1/3: the last slot is offline · `CRITICAL`: the last two are
offline (the first slot always works). A freshly captured building starts near 0 bots: only its first slot
runs until it is reinforced or regenerates.

### Buildings (the local, experiment 1)
| Kind | Effect |
|---|---|
| Bot farm | +1 bot/s regeneration in that building |
| Intel harvester | +1 Intel/s (global) |
| Darknet market | one Cash packet worth the building's **value** every `CASH_INTERVAL` (3 s), travelling home to your rig |
| Intel vault | +100 Intel capacity |

- Select one of your buildings → **Enter building** (`ENTER_TIME` 2 s to connect). Inside: slots, one build job
  at a time (`BUILD_TIME` 6 s, progresses only while you are inside), demolish, leave (Esc / right-click).
- While inside: the map is veiled but **alive**; you cannot command it; alerts still arrive. If the building
  falls while you are inside, you are thrown out.
- The rival runs **one build job at a time** (its attention), always progressing.

### Intel (unchanged from v1, under review — see "Open question: Intel")
Each **player** attack bot released costs 1 Intel; reinforcement and rival attacks are free. Start 50, cap 100
(+100 per vault). Departures are resolved in time order with a rotating tie-break (no index bias).

### Cash and the win (decision: Cash)
- Markets emit Cash packets to the owner's **rig** (the sink). The rig's own market banks directly. Packets
  share links with bots. A packet is banked by **whoever holds the rig when it lands**; if your rig is lost,
  your markets hold until you retake it.
- **Win:** bank `CASH_GOAL` (600) first. **Defeat:** the rival banks it first, or you lose every building.

### Links (experiment 2)
`LINK_CAP` 2 packets per `LINK_TIME` per direction. A link at capacity draws amber. The packet timeline
(every hop's entry time) is fixed at departure; arrivals resolve chronologically; results do not depend on
frame rate (checked at 60 Hz vs 2 Hz).

### Rate dial (experiment 5) and rally (command-unit experiment)
- `− rate / + rate` on any selection: 25 %…100 % of `SEND_RATE` (1 bot/s).
- **Set rally point** on one building: every building of yours with no explicit order sends its surplus above
  `RALLY_RESERVE` (10) to it, never overfilling it (inbound counted), and **pauses while under attack**.

### The rival (decision: rival botnet from the bottom)
Every `RIVAL_CADENCE` (4 s): release orders whose target it now holds or cannot reach; start one build job
(frontier buildings → Bot farms up to 2, rear → markets up to 2); if no attack is running, pick the
**softest** bordering building (bots − 3 × value − 3 if yours) and concentrate `floor(regen × 1.5) + 2`
sources (max `RIVAL_MAX_STREAMS` 4), nearest first, each keeping a garrison of `RIVAL_RESERVE` (6). An attack
that makes **no progress for `RIVAL_PATIENCE`** (30 s) is dropped and that target avoided next time. The
rival pays no Intel (prototype simplification). It does not defend or reinforce.

## Controls (unchanged scheme)
① left-click your building(s) to select (Shift-click / box-select for several) · ② click a target or drag a
line to it → ORDER PREVIEW with regen, streams, Intel cost and an estimate of time-to-capture · ③ press
**START ATTACK / REINFORCE**. Nothing fires on a click or a drag. Stop supply from a source or into a target;
Esc / right-click clears or leaves a building; Space pauses everything.

**Diagnostics:** the inspect panel's "not overcoming regeneration" now subtracts the target's **own outgoing
stream** — a building that is attacking someone is the softer target it really is (v1 hid this).

## Provisional values
`NODE_CAP 30 · PROD_RATE 1 · ATTACK 1 / DEFEND 1.5 · SEND_RATE 1 · LINK_TIME 1 · NODE_ROUTE_DELAY 0.25 ·
LINK_CAP 2 · MAX_QUEUE 1 · BUILD_TIME 6 · ENTER_TIME 2 · CASH_INTERVAL 3 · CASH_GOAL 600 · INTEL_START 50 ·
INTEL_CAP_BASE 100 · RALLY_RESERVE 10 · RIVAL_CADENCE 4 · RIVAL_RESERVE 6 · RIVAL_PATIENCE 30 ·
RIVAL_MAX_STREAMS 4 · EMPTY_CELL 0.15 · LINK_KEEP 0.78 · DIAG_P 0.18`

## Arithmetic that decides the game (for designers)
- Streams needed to beat a building's regeneration: `floor(regen × 1.5) + 1` → 2 against one Bot farm, 4
  against the hub's two. Concentration is cheaper in Intel and time: a 20-bot building costs 120 Intel with
  two streams and 60 with three.
- A building that is streaming out loses 1 bot/s on top: one stream drives a streaming rival building down to
  its garrison; a second finishes it. Attacking the attacker is the counter-play.
- From a cold start, 50 Intel buys 25 s of a two-stream attack: enough for a rim building (security 7…12),
  not for downtown. Building an Intel harvester early is mandatory; the idle panel says so.

## Validation (2026-10-11, Godot 4.7.2 headless + rendered under Xvfb)
Mechanics probe in `review/botnet_v2_2026-10-11/`: 13 cases, all pass — generation (connected, different per
seed), faction routing, link capacity queueing, chronological arrivals with terminal freeze, control stages,
attention-gated jobs, capture and the neutral security cap, rival concentration and building, Cash travel and
banking, rally garrison and overfill, frame-rate consistency, attack-the-attacker. Rendered captures of the
four panel states are in `captures/`.

**Pacing readings (not verdicts), goal 600, 10 Hz:**

| Run | Outcome | Time | Buildings (you / rival) |
|---|---|---|---|
| Rival alone, you idle (seed 7) | rival banks 600 | 5:37 | 2 / 12 |
| Greedy scripted player, perfect attention (seed 7) | you win | 5:30 | 10 / 11 |
| Greedy scripted player (seed 11) | rival wins | 4:26 | 10 / 9 |

The unopposed rival sets the clock at ~5.5 min; a human will be slower than the script, so the first human
run will likely need `RIVAL_CADENCE` or `CASH_GOAL` raised. Tune one value at a time after watching play.

## Open question: Intel (explore before changing)
Today bots regenerate for free and **attacking** spends Intel. That reads as a duplicate: Intel is only an
attack tax. Options explored on 2026-10-11:

- **A. Intel pays for bots, attacking is free.** A Bot farm consumes 1 Intel per bot it produces and stops
  consuming at the cap. One currency, one budget: growing, defending (regenerating after damage) and attacking
  all draw on it. Needs a floor so a broke player can still regenerate slowly (no permanent lockout), and the
  rival must pay the same way. Thematically Intel-for-bots is a stretch; the basic game would call this fuel
  Cycles.
- **B. Intel pays for cards, bots are free.** Intel becomes a burst resource for **ultimate cards**:
  credential stuffing, a CVE exploit, phishing, a DDoS that freezes regeneration. Matches the basic game's
  resource-funded attack cards. Attack *types* then exist because each card is strong against a building
  **type** (offices/PCs for credentials, server farms for CVEs, residential for phishing) — the town already
  varies buildings, so types are cheap to add.
- **C. A + B.** Bots cost Intel to produce *and* cards cost Intel: the choice becomes "thirty bots or one
  exploit". Cards are additive and can be tested after A.

**Recommendation:** test **A** first (it changes the core loop; small code change: move the Intel charge from
`_emit_due` to regeneration, add the floor, make the rival build harvesters), keep attack types out of the bot
flow, and bring them back as **cards** against building types. Not implemented yet.

## Other open questions
- Command unit: if the rally point suffices on 6×6, buildings stay the unit; if players still drown in
  orders, test district orders next.
- Whether a neutral building's security should be visible before you scan it (Intel as information).
- How a prototype building maps to a basic-game building (which component exports bots, Intel, bandwidth,
  defence): see the local/global contract sketched in chat on 2026-10-11.

## Stoppers and status
Addressed in code: explicit commit, live panel, no map overlap, no Intel lockout (demolish/rebuild), neutral
siege problem (security cap), display agreeing with simulation (drain-aware diagnostic), feasible route to
victory (scripted win recorded on seed 7). **Pending:** human usability test (five new players, no coaching;
gate 4 of 5 complete the core tasks), and a pacing pass after it.
