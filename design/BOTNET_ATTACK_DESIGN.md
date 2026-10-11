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
- **Command production, don't micro bots.** You set where each source's output goes; it then **releases one
  bot per second** (`SEND_RATE`) along its own network. Reinforcement arrivals become **resident stock that
  can later be re-dispatched**.
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

**Three deliberate steps — nothing starts until you press the button; neither a click nor a drag commits:**

- **① Select:** **Left-click** your node(s) to select, **replacing** the previous selection. **Shift-click**
  adds/removes; **drag on empty map** = box-select. Left-click an enemy with no selection = inspect it.
- **② Aim (two interchangeable ways):** with sources selected, either **left-click any other node**, or
  **drag a line from your node onto it** (the line is a pure aiming gesture — release just aims). Either sets
  the **pending target** (`sel_target`) and **starts nothing**. Dragging from an *unselected* owned node picks
  just that source; dragging from a *selected* group member keeps the whole group.
- **Focus / fog on aim:** the moment you aim, the target, **every node connected to it**, and the **routes your
  sources take to it** stay bright; **every other node and link fades** (~20% opacity) so the active subgraph is
  all you read. The target shows a yellow ring + an on-canvas **⚔ attack / 🛡 reinforce** label; the panel
  shows `N/M can reach` and the command button.
- **③ Commit:** **press the ⚔ ATTACK / 🛡 REINFORCE button** to issue the order. Only this button commits;
  a click or a drag never does. `A→X` then `B→Y` stay independent.
- The group **stays selected** after a command, so **retargeting is: aim a new target → press the button**.
- **Commit is an explicit button.** Aiming shows an **ORDER PREVIEW** panel (destination + ownership, how many
  of your selected sources can reach, send rate and its Intel cost); pressing **START ATTACK / REINFORCE**
  commits. Neither a click nor a drag ever commits. After commit the group stays selected and the panel shows
  the running order so **Change target** (aim again) and **Stop supply** are one step.
- **A supply order persists until you STOP it** (the network *connection* stays — you can re-order later).
  Stopping affects *future* departures only (incoming reinforcement, enemy attacks, and already-travelling bots
  all continue):
  - **From a source** — select it → **"Stop supply"** (or "Stop supply (N)" for a group).
  - **Into a node** — select or inspect it → **"Stop all supply into it"**. This touches **only your own
    sources**; enemy attacks on the node are never affected by your commands.
  **SPACE** pauses; **Esc / right-click** clears selection, pending target, and inspect together.
- **Visual language.** Thin links = the network (where travel is possible). A bright **dashed** line = a preview
  (what you're about to order). A solid line = a **committed** supply order, coloured by the *source's* faction
  (your attack = amber **arrow**, your reinforcement = green **diamond**, an enemy attack on you = red **arrow**),
  so attack vs reinforcement reads by shape as well as colour. Moving dots/squares = actual bots (yours = circle,
  enemy = square). A node of yours under attack keeps a **red ring** and stays visible even while you aim
  elsewhere (the focus/fog never hides a live threat).
- **Retargeting affects future departures only.** Already-dispatched bots keep their faction, destination, and
  route and **finish even after a source or relay changes ownership** (declared prototype simplification).
- **Ownership transitions are announced.** Capturing a destination turns its incoming attack supply into
  reinforcement ("Captured X — N sources now reinforce it"); losing one turns supply into attack. Capturing or
  losing a source clears its own outgoing order and immediately changes who can command it.
- **Route loss stops future dispatch and says so** ("…order stopped — no route; reissue to restore"); it does
  not auto-resume. An alternate owned route is used automatically if one exists.

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

Engine checks currently pass for: independent orders; group retarget in one command; source-scoped stop
preserving incoming + travelling bots; chronological arrivals (earlier reinforcement prevents a false HUB win;
reversing the flight list changes nothing); terminal freeze (no retake after a win; never both outcomes);
frame-rate consistency (60 Hz vs large hitches within tolerance); enemy retargeting of a completed order. Open
for a small player round: can players predict where the next bot goes, explain why a node was lost, and adapt
their allocation in a few actions? Is `1/s` the right baseline, or `2/s`? Is the full-hold experiment worth
keeping?

---

# Prototype success and evaluation

These are **separate axes**. Winning proves neither: a player can win while confused, or lose while fully
understanding the game. **Automated engine checks never establish usability** — that requires human testing,
which is **PENDING**.

## A. Player success / failure (and progress)

- **Objective (shown in the HUD and the idle panel):** *"Build your botnet, combine supply from several
  sources, and capture the HUB."* This matches the implementation (HUB capture is the only win).
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
| **Insufficient Intel** | source state "no Intel"; HUD −spend vs +income; preview "⚠ Out of Intel" | add Intel production, or **Stop supply** on another attack | **Yes**, when Intel returns |
| **No available bots** | source state "no bots" | let the source regenerate, or reinforce it | **Yes**, when a bot is ready |
| **No route** | the order is dropped with "supply stopped — no route" | capture a node bordering the target, then re-order | **No** — must re-order |
| **Bots travelling, not yet arrived** | moving dots/squares; "in transit toward it" | wait; bots act only on arrival | n/a |
| **Pressure < regeneration** | inspect: "↔ Not overcoming regeneration (−x/s vs +y/s) — add another source" | add/concentrate another source | continues, but won't capture |
| **A source is captured** | it leaves your selection; its order clears; authority changes | re-take it or re-plan from remaining nodes | **No** |
| **A destination changes owner** | labels flip attack⇄reinforce live; announced | retarget if the intent changed | order persists on the same node |

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
play before expanding features; combat values were **not** silently changed to hide it.

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
