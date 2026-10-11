# RIM — botnet attrition prototype (current spec)

*Active specification for the standalone prototype (`scenes/botnet_proto.tscn` + `scripts/botnet_proto.gd`).
Earlier design explorations (fuel economy, interior objectives, Net-Watch siege, persistent-assignment
dispatch) are **archived** in `design/BOTNET_ATTACK_HISTORY.md` and do NOT describe current behavior. All
numbers here are provisional test candidates; automated checks do not establish balance or novice usability.*

## Goal

You are a netrunner taking a city network node by node. **Capture the central HUB → win. Lose every node you
own → defeat.** The skill under test: allocate your production as timely supply while protecting the sources
and routes that sustain it.

## Current rules

- **A node's bots ARE its health, capped at 30** (`NODE_CAP`). Every node — yours and the enemy's —
  **regenerates** toward the cap at `PROD_RATE` (1 bot/s).
- **Command production, don't micro bots.** You **wire** where each source's output would go; the source
  **releases one bot per second** (`SEND_RATE`) along its own network only while that wire is **live** (a
  launched attack, or a guard that armed itself). Reinforcement arrivals become **resident stock that can
  later be re-dispatched**.
- **Bots act ONLY on arrival.** A bot in transit does nothing; on reaching the final target each bot
  **reduces an enemy node by 1** (attrition) or **adds 1 to a friendly node** (reinforce, capped at 30).
  Reduce an enemy node to **0 → it flips to the attacker** (overflow occupies it).
- **Bots route only through the sender's own network** (BFS over same-faction nodes to a node bordering the
  target, then the final hop). No owned route → no dispatch.
- **Movement is hop by hop with pauses, and transit never adds to pass-through nodes.** A bot crosses a link
  (`LINK_TIME`), **pauses at each intermediate node** (`NODE_ROUTE_DELAY`), then continues. Travel time =
  **hops × `LINK_TIME` + intermediate-nodes × `NODE_ROUTE_DELAY`** → **1 hop = 1.0 s, 2 hops = 2.25 s**. Many
  bots can be on one link at once (a visible single-bot stream). Farther defenders arrive later — you can lose
  a node before help reaches it.

### Combat power & the Intel economy (new)

- **A defending node is worth 1.5× an attacking bot — `DEFEND_POWER = 1.5 × ATTACK_POWER` (D = 1.5·A).** Each
  arriving **attack** bot removes `A/D ≈ 0.667` of the target's bots; **reinforcement** adds a full bot. So
  capturing a node with *B* bots takes ≈ `1.5·B` attack bots — defenders have the edge, attackers must
  concentrate.
- **Buildings — up to 2 per node** (`BUILD_SLOTS`), chosen from three types; build on a node you own (select
  it → the panel's build buttons). Every node starts with **one Bot building** (the HUB has two); the second
  slot is yours to fill:
  1. **Bot production** — each adds `PROD_RATE` (1 bot/s) of regeneration to that node.
  2. **Intel production** — each makes `INTEL_PER_BUILD` (1) **Intel/s** (a global resource).
  3. **Intel capacity** — each raises your Intel cap by `CAP_PER_BUILD` (100) above the `INTEL_CAP_BASE` (100).
- **Attacks cost Intel: each player attack bot released needs 1 Intel.** Out of Intel → your attacks **hold**
  (production/regen continue) until Intel returns. **Reinforcement is free.** You start with
  `INTEL_START` (50) Intel; build Intel production to sustain offensives and capacity to stockpile. (Enemy
  streams do not spend Intel in this prototype.) The HUD shows **reserve, +income/s, and −spend/s** together.
- **Fair Intel, no index bias.** When several sources share scarce Intel, departures are resolved in **time
  order** (earliest-scheduled bot first) with a rotating tie-break — not by internal source order, so no source
  wins Intel just because of its index. A held source never builds a catch-up backlog.
- **No permanent lockout.** Because every slot can be **rebuilt** (Manage node → "Slot n → Intel production"),
  filling both slots without Intel production and spending to zero can always be recovered.

**Provisional values** (in `botnet_proto.gd`): `NODE_CAP 30`, `PROD_RATE 1/s` per Bot building, `SEND_RATE 1/s`,
`LINK_TIME 1.0 s`, `NODE_ROUTE_DELAY 0.25 s`, `ATTACK_POWER 1` / `DEFEND_POWER 1.5`, `BUILD_SLOTS 2`,
`INTEL_START 50`, `INTEL_CAP_BASE 100`, `CAP_PER_BUILD 100`, `INTEL_PER_BUILD 1`, enemy re-activates every
`ENEMY_CADENCE 6 s`. `full_hold` (off) is the overflow-hold experiment (below).

### The three flow dials
1. **Speed of sending** — `SEND_RATE` (bots/s released). Raise to push harder; it spends resident stock faster
   but **does not create bots** — production still limits sustained output.
2. **Speed through a link** — `LINK_TIME`. Lower to travel faster.
3. **Speed of routing through a node** — `NODE_ROUTE_DELAY`. Per-packet latency at each intermediate node;
   **it is not a throughput limit or queue** — unlimited bots may pass concurrently. Lower to route faster.

At `SEND_RATE = PROD_RATE = 1/s` an unthreatened full source stays ~29–30 while sending; one stream only
matches an idle target's regeneration, so **concentration (two+ sources) is how you overcome regen**. A source
under attack does pay a real defensive cost for what it sends out. (2/s is a possible separate experiment
after correctness; don't silently restore older rates.)

## Controls & order lifecycle

A command targets a **building's aggregate production** (one node in this prototype). You never pick individual
bots.

**Two separate verbs — CONNECT wires a dormant plan; what fires is the wire's STATUS: an attack launches from
the ⚔ button on the enemy node's own panel, a guard arms itself when the protected node is threatened.
Neither a click nor a drag ever fires anything.**

- **① CONNECT — drag-and-drop ONLY.** **Left-click** your node(s) to select (Shift-click adds/removes;
  **drag on empty map** = box-select), then **DRAG a line onto the target**; dragging from a selected group
  member wires the whole group. **Clicking never wires** — a click only selects / opens a node's panel.
  **A link can only be made where a path runs through your own nodes** — never through enemy territory (the
  rubber band turns red with "✖ no path" over an unreachable target; a failed wire keeps your selection).
  A wire is a **dashed, dormant connection**: no bots move, no Intel is spent. One connection per node;
  wiring again **replaces** it (a rewired connection is dormant until launched again), and wiring a node's
  current target changes nothing (it never interrupts a live flow). The plan has no timer — wires sit for
  minutes and can be rewired forever. After wiring, the selection clears and the **target's panel opens**.
- **② ATTACK and DEFEND are the wire's STATUS.**
  - **Wire → an ENEMY node = an attack.** Click that node: its panel lists **everything connected to it**
    ("3 node(s) — 1 flowing · 2 dormant", per-source states) and carries the **⚔ ATTACK** button — the only
    trigger. Pressing it turns every **dormant** wire into that node **live at the same moment** — a
    coordinated strike. Each target launches **independently**, and wires added **after** a launch stay
    dormant until the button is pressed again. Unrouted wires are held and reported, never silently launched.
  - **Wire → YOUR OWN node = a GUARD.** No button: guards **arm themselves automatically** the moment the
    protected node is under attack (or below full, counting help already in the air) and **stand down** once
    it's safe and topped up. Capturing a node turns your attack flows into guards that top it up and stop;
    **losing** a node stands your wires down — assaulting it back is your explicit call.
- **Stop vs Disconnect.** **"Stop N flow(s) (keep connections)"** pauses an attack's live flows but keeps the
  wires — relaunch anytime. Guards are never hand-stopped (the status does the work) — only **disconnected**.
  **"Disconnect"** removes wires (from selected sources, or all into a node). Both affect *future* departures
  only — travelling bots and enemy attacks continue. Player commands never touch enemy wires. **SPACE** pauses;
  **Esc / right-click** clears selection and panel — **never your wires**.
- **Focus / fog — strict, with gold and red rings.** Opening a node's panel (or dragging a line over one)
  brightens ONLY the nodes a link runs **from** (wired into it) and **to** (its own target); the route lines
  stay lit but the nodes a route merely **passes through** fog like everything else, as do network neighbours
  and even nodes under attack elsewhere (their full-brightness **red ring** still shows through the fog, so a
  threat is never invisible). **Gold ring = friendly connection**; **red ring (wide) = an enemy node connected
  into it**. The focused node shows the yellow ring + an on-canvas **⚔ attack / 🛡 defend** label. A
  **↻ Restart run** button is always available at the bottom of the panel.
- **Visual language.** Thin links = the network (where travel is possible). **Dashed** line = a **dormant wire**
  (the plan; bright yellow while being dragged or focused). **Solid** line = a **live flow**, coloured by the
  *source's* faction (your attack = amber **arrow**, your defence/reinforcement = green **diamond**, an enemy
  attack on you = red **arrow**) — attack vs defence reads by shape as well as colour. Moving dots/squares =
  actual bots (yours = circle, enemy = square). A node of yours under attack always carries a small
  full-brightness **red ring** — even fogged, a live threat is never invisible.
- **Rewiring affects future departures only.** Already-dispatched bots keep their faction, destination, and
  route and **finish even after a source or relay changes ownership** (declared prototype simplification).
- **Ownership transitions are announced.** Capturing a destination turns your incoming attack flows into
  **guards** that top it up and stand down; **losing** a destination **stands your wires down** (dormant, kept)
  — retaking it is an explicit ⚔ ATTACK. Capturing or losing a source clears its own connection and
  immediately changes who can command it.
- **Route loss pauses the flow and says so** ("flow stopped — no route; connection kept; launch again when
  routed"); the wire survives, and an alternate owned route is used automatically if one exists.
- **Future hook (not built):** dormant wires could later be **detectable** — a defender noticing connections
  planted into their hosts before the strike fires (risk/reward for long preparation).

## Enemy behavior

Simple, adjacency-based. Every `ENEMY_CADENCE` the enemy (a) **releases any order whose target is no longer a
reachable hostile node** so a completed attacker can re-engage, then (b) **activates one idle frontier node to
stream single bots** at a bordering node of yours. Multiple enemy streams can run at once. No global planner,
economy advantage, or new unit types.

## Terminal resolution

- Arrivals in a step are resolved **in chronological order** (by arrival time), independent of internal list
  order; truly simultaneous arrivals use a fixed deterministic tie order (arrival time → target → the current
  owner's reinforcements before attacks).
- **HUB capture = immediate win; losing the last owned node = immediate defeat.** Once a result is reached,
  **all further gameplay events and order changes stop** and the **result screen** appears immediately with the
  **outcome, its cause** ("You captured the CENTRAL HUB." / "You lost your last node."), **elapsed time**, and a
  **Restart** button. Win and defeat can never both be active; a later arrival in the same step cannot mutate the
  board after a terminal event. The 10-minute target is a pacing goal, **not** a defeat timer.

## Prototype simplifications (intentional)

- One node = one producer (a future building may aggregate several production nodes; no per-internal-node UI).
- In-flight bots complete even through a relay/source that later changes hands.
- `NODE_ROUTE_DELAY` is pure latency (no congestion/queue). Upgrades, congestion, and an upgrade tree are
  future work and are out of scope.
- **Full-friendly overflow:** by default a full friendly node still accepts dispatch and the surplus is wasted
  at the cap (shown as **FULL**). `full_hold = true` is an **experiment** that instead holds future supply when
  the target has no room (counting friendly bots already in transit), keeping the order to resume when room
  opens — at the risk of help arriving late under a fresh attack. Evaluate separately; off by default.

## Validation questions (not balance verdicts)

Headless check suites currently pass for: the simulation core (chronological arrivals and the false-HUB-win
case; terminal freeze — never both outcomes; frame-rate consistency; hop/pause travel; two sources capture
where one stalls against regen); the economy (D=1.5A power, Intel cost/hold, time-fair emission with no
source-index bias, lockout recovery via rebuild); and the control scheme (wiring fires nothing and spends
nothing; drag-only wiring with the own-territory path constraint; per-target launch; stop-keeps-wires;
rewire-moves-one-wire; guards arm/stand down/heal automatically; node loss stands wires down; Esc never
touches wires; strict fog; enemy AI unaffected by player commands). Open for a small player round: can
players predict where the next bot goes, explain why a node was lost, and adapt their wiring in a few
actions? Is `1/s` the right baseline, or `2/s`? Is the full-hold experiment worth keeping?

## Change log — how this design evolved (all 2026-10-10 → 2026-10-11)

Each change was driven by playtesting feedback from the designer; the current spec above always wins over
anything older. Historical pre-attrition designs live in `BOTNET_ATTACK_HISTORY.md`.

1. **Bot-attrition core** replaced the fuel/interior/siege drafts: bots = node health (cap 30), universal
   regeneration, hop-by-hop travel with pauses, effects only on arrival, HUB win / last-node defeat.
2. **Simulation hardening** (review-driven): one shared clock with absolute depart/arrive times; chronological
   arrival resolution (fixed a false HUB win); terminal freeze; hop leftover-time carry; cancellation scoped
   to player-owned sources.
3. **Combat power + Intel economy:** D = 1.5·A (defenders' edge → concentration matters); 2 build slots from
   Bot / Intel production / Intel capacity; player attack bots cost 1 Intel each, reinforcement free.
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
   with cause + elapsed time; "stop supply/disconnect" terminology (never "remove link" — the network
   connection remains); routes coloured by **source** faction (an enemy attack can never look green/friendly);
   attack = arrow vs defence = diamond; your bots = circles vs enemy = squares; time-fair Intel emission;
   building rebuild (no permanent Intel lockout); panel reserves map space; always-available **↻ Restart**.
8. **Wiring constraints:** links are made by **drag-and-drop only** (clicking selects / opens panels, never
   wires) and only where a **path runs through your own nodes** (red rubber band + "✖ no path" otherwise).
9. **Focus highlighting, user-tuned:** clicking a node highlights STRICTLY its connections — from-whom
   (gold ring = friendly, wide red ring = enemy attacker) and to-whom (gold ring); route pass-through nodes,
   network neighbours, and unrelated under-attack nodes all stay fogged (the small red threat ring still
   shows through). Earlier cyan rings were dropped — cyan belongs to the HUB alone.
10. **Attack and defend as the wire's STATUS:** wire → enemy = attack (manual ⚔ launch); wire → own node =
    **guard** — arms itself while the protected node is under attack or below full (counting inbound help),
    stands down after; capture turns attack flows into topping-up guards; loss stands your wires down.
11. **Future hook (agreed, not built):** dormant wires may later be *detectable* by their target's owner —
    discovery risk for long-prepared strikes.

---

# Prototype success and evaluation

These are **separate axes**. Winning proves neither: a player can win while confused, or lose while fully
understanding the game. **Automated engine checks never establish usability** — that requires human testing,
which is **PENDING**.

## A. Player success / failure (and progress)

- **Objective (shown in the HUD and the idle panel):** *"Wire connections from several nodes, then launch
  them — capture the HUB."* This matches the implementation (HUB capture is the only win).
- **Victory:** the exact instant an attack reduces the **CENTRAL HUB** to 0 bots and it flips to you.
- **Defeat:** the exact instant you own **zero** nodes.
- **Progress (observable before victory):** nodes owned (HUD `nodes k/15`), total bots, Intel reserve/income/
  spend, the HUB's current defender count, and captured/lost announcements.
- **Result screen:** outcome + cause + elapsed time + **Restart**. The 10-minute target is pacing, **not** a
  defeat timer.

## B. Temporary blockers (a stalled attack is not a lost game)

Each blocker names its cause, how the UI shows it, the player's next action, and whether the order auto-resumes.
Advice is shown only when the current rules actually support it.

| Blocker | How the UI shows it | What to do | Auto-resumes? |
|---|---|---|---|
| **Insufficient Intel** | source state "no Intel"; HUD −spend vs +income; the target panel's "⚠ Out of Intel" line | add Intel production, or **Stop** another attack's flows | **Yes**, when Intel returns |
| **No available bots** | source state "no bots" | let the source regenerate, or wire a guard to it | **Yes**, when a bot is ready |
| **No route** | flow pauses: "flow stopped — no route (connection kept)" | capture a node bordering the target, then press ⚔ ATTACK there again | **No** — the wire survives, but relaunch is manual |
| **Bots travelling, not yet arrived** | moving dots/squares; "in transit toward it" | wait; bots act only on arrival | n/a |
| **Pressure < regeneration** | target panel: "↔ Not overcoming regeneration (−x/s vs +y/s) — add another source" | wire + launch another source at it | continues, but won't capture |
| **A source is captured** | it leaves your selection; its connection clears; authority changes | re-take it or re-plan from remaining nodes | **No** |
| **A destination changes owner** | announced; captured → your flows become guards, top it up, stand down; lost → your wires stand down (kept, dormant) | captured: nothing to do; lost: press ⚔ ATTACK there to retake | capture: auto-guards; loss: **no** — relaunch is your call |

Representative wording in the build: *"Waiting for Intel — add Intel production or stop another attack."*
*"Not overcoming regeneration — add another source."*

## C. Prototype success = two separate questions

1. **Can a new player understand and control the system?** (usability)
2. **Once understood, does combining and redirecting supply create worthwhile decisions?** (depth)

Provisional **usability** targets (initial testing targets, not validated benchmarks):
- Start a first attack within **60 s** after the short intro.
- Combine **two sources on one target** within **2 min**.
- Identify selected sources, destination, and whether the order is running.
- Diagnose a stalled attack from the interface.
- Redirect and stop supply without coaching.

Evaluate **pacing** separately: aim for an **~8–12 min** successful first run *after* the controls are understood.

## D. Stoppers (fix the smallest underlying problem before adding mechanics)

- UI commits an unintended source/destination.
- Displayed order state disagrees with simulation state.
- Essential controls or nodes inaccessible.
- Player enters an unrecoverable resource state with no clear defeat or recovery path.
- **No demonstrated feasible route to victory.**
- Multiple new players cannot complete the basic attack flow without coaching.

A too-fast win, a slow attack, or a player's strategic mistake is evaluated **separately**, not treated as an
interface defect.

**Current status of the stoppers (2026-10-11):** the first four are addressed in code (explicit button commit;
live panel refresh so display tracks simulation; panel no longer overlaps nodes; building rebuild prevents an
unrecoverable Intel lockout). The **feasible-route stopper is OPEN**: three scripted greedy strategies with
enemy AI enabled either lose (~3 min from the 2-node start) or **stalemate** (survive 20 min from a 3-node
start without winning). This indicates a **pacing/balance** problem — attacks struggle to overcome the 1/s
regeneration under enemy pressure — **not** a simulation defect (capture, HUB-win, frame-rate, and chronology
checks all pass). It must be resolved by a **tuning pass (one change at a time)** and/or confirmed by human
play before expanding features; combat values were **not** silently changed to hide it. *Note: those runs
predate the connect/guard control rework — automatic guards may change defensive economics, so the
feasibility probe should be re-run on the current build before any tuning decision.*

## E. Evaluation method (human test — PENDING)

Run an initial test with **five** people new to the prototype. Give them the objective and the same short intro;
**no coaching** during the core tasks. Record, per player: time to first committed attack; time to first
two-source attack; incorrect selections, cancelled attempts, help requests; whether they tell a **preview** from
a **running order**; whether they correctly explain why an attack stalls; outcome and total time; and one
meaningful decision they can describe. Separate *deciding* time from *confused/waiting* time. **Provisional gate:
4 of 5 complete the core tasks without coaching.** If the same confusion hits ≥2 players, fix it before
expanding.

## F. Result and next decision

- **PASS** — core interaction understood; proceed to pacing and strategic depth.
- **REVISE** — specific interaction/feedback failures need changes and another test.
- **BLOCKED** — a technical/systemic stopper prevents meaningful evaluation.

**Current verdict (2026-10-11):** usability **PENDING** (no human test run yet — automated checks cannot
substitute). Mechanical correctness: **PASS** (engine/UI/economy checks green). Pacing/feasibility: **BLOCKED**
on the open feasible-route stopper above until a balance tuning pass or human play demonstrates a win. List
usability, mechanical, and pacing findings separately in any report.
