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
  streams do not spend Intel in this prototype.)

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
- **A link persists until you remove it.** Removing a link stops *future* departures only (incoming
  reinforcement, enemy attacks, and already-travelling bots all continue):
  - **From a source** — select it → **"✖ Remove this link"** (clears that source's outgoing order). For a
    multi-source selection, **"✖ Remove links from all selected (keep bots here)"** clears them all.
  - **Into a node** — select or inspect it → **"✖ Remove all links into it"**. This touches **only your own
    sources**; enemy attacks on the node are never affected by your commands.
  **SPACE** pauses; **Esc** deselects.
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
  **all further gameplay events and order changes stop** and Reset appears immediately. Win and defeat can
  never both be active; a later arrival in the same step cannot mutate the board after a terminal event.

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
