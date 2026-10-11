# RIM — the botnet attack loop (design specification)

*Scope: design spec. A standalone sandbox prototype (`scenes/botnet_proto.tscn` + `scripts/botnet_proto.gd`)
implements the model. **The prototype has been re-centred on a simpler bot-attrition model — see §0 "Rules of
engagement", which is the CURRENT truth and supersedes the fuel / interior-objective / Net-Watch-siege
machinery described in the later sections (§1–§13, kept for history).** All numbers are provisional test
candidates; no playtesting has been run yet.*

---

## 0. Rules of engagement (current prototype — bot-attrition model)

Strict rules the prototype follows (prototype scope; §1+ is earlier, now-superseded thinking):

- **A node's bots ARE its power/health. Max 30 per node** (`NODE_CAP`). Every node — yours and the enemy's —
  **regenerates** toward the cap (`PROD_RATE` 1/s). Production is the whole game.
- **Attack:** link one or more of your nodes to an enemy node (drag, or click), then press **ATTACK**. Your
  nodes **send bots** at it as a **continuous flow of single bots** (`SEND_RATE` 2.5/s, one at a time — never a
  lump of 10 moving as one). **Sending drains the source** over time. The enemy streams the same way.
- **Bots only act ON ARRIVAL.** A packet travels the route and does nothing until it reaches the target; then
  each bot **reduces the enemy node's bots by one** (attrition). Reduce an enemy node to **0 → it becomes
  yours** (leftover bots occupy it).
- **Defend:** link your nodes to a *friendly* node, press **DEFEND**. Those bots flow and, **on arrival, add
  to that node's bots** (never past the cap — no stockpiling beyond 30). When the enemy attacks you it reduces
  your node's bots the same way; outlast it or the node flips.
- **Travel time = distance** (`HOP_TIME` 1.0 + `NODE_ROUTE_DELAY` 0.25): **1s per hop + 0.25s per node routed
  through**. So 1 hop ≈ 1.5s, 2 hops ≈ 2.75s. **The farther your defenders are, the slower they arrive — you
  can lose a node before help reaches it.** Position matters.
- Bots travel **only through your own network** (a route over nodes you own), so reach spreads with territory.
- **Win:** capture the central **HUB**. **Lose:** lose every node.
- **Win condition in practice:** whoever **out-produces and out-pushes** wins. Example: you hold 2 nodes (30
  each), the enemy holds 1 (30). The enemy pours bots into one of yours; you reinforce it from your second
  node. Two producers out-push one → the enemy exhausts its bots while yours hold, then you roll over it.

Controls: **drag** from your node to another to link (enemy → attack, friendly → defend) and press the button
to commit; **right-click** a node to cancel its routes; **SPACE** pauses. Nothing is sent until you commit.
Provisional values live in `botnet_proto.gd`: `NODE_CAP 30`, `PROD_RATE 1/s`, `SEND_RATE 2.5/s`, `HOP_TIME 1.0`,
`NODE_ROUTE_DELAY 0.25`, enemy attacks every `ENEMY_CADENCE 6s` of `ENEMY_SEND 10` bots.

---

## 1. Player promise

You are a netrunner taking a cyberpunk city host by host. You don't micro a fresh strike each time — you
**assign your buildings to operations and let their production feed the fight** while you decide where to
push next. Your reach spreads along the wires toward the **CENTRAL HUB**; taking it triggers the **CITY
OVERLOAD** — the win. The interesting decisions are *what each building is working toward*, *how much you keep
home to defend*, and *how to break into each target* — not repetitive clicking.

---

## 2. Locked constraints

These are fixed; everything else is open.

- **Buildings are stationary.** Nothing relocates on the map.
- **Bots are disposable operation payloads, not an army.** You never move or park units.
- **Dispatched bots never return.** Once a bot leaves its source it is irreversibly committed; it is used up
  and does not come back or become reusable.
- **No forward staging.** Bots are never stored at, or massed at, a building that isn't their source. A bot is
  only ever: resident at its source, in transit to a target, or active inside that target.
- **Enemy targets must border owned territory.** You can only attack a host wired to a host you own.
- **Resident bots are the shared offensive and defensive stock.** The same bots that could be dispatched to
  attack are what defend their own building; committing them outward leaves that building thinner.
- **Combat happens inside the target building**, on its internal node network.
- **Capturing the HUB triggers CITY OVERLOAD** (victory).

The example figures in this document (e.g. "ten active bots", "30") are illustrative test fixtures, **not**
confirmed production rates, capacities, or balance values.

---

## 3. Persistent building assignments  [PROPOSED]

The core interaction. It replaces re-assembling a separate force for every breach.

- **Each eligible source building holds one target assignment at a time.** Several source buildings may be
  assigned to the **same** target (they aggregate against it).
- The assignment applies to the **aggregate bot output of the source building's production nodes.** (The
  prototype's single "war-building" flag per host is an implementation baseline, not a rule that a final
  building has exactly one production node.)
- An assigned source **continuously supplies** its operation from new production, automatically, while the
  player does other things — but **on demand, not by dumping** (see §4.1).
- **Unassigned buildings keep their bots for local defense.** Choosing which buildings back which operations
  is the player's standing strategic decision; the game does **not** auto-assign every reachable building.

**Interaction (proposed):**
1. Select a source building you own.
2. Select a legal target (see §7 for legality).
3. Inspect the assignment preview (route, what it will do; costs nothing — see §4.2).
4. Confirm the order.
5. Choose the operation's **internal objective** (see §6).
6. The source then supplies that objective automatically.

Avoid mandatory host-by-host toggles inside each attack — the persistent assignment *is* the source-selection
decision. A reserve limit or "defend-only" policy may be explored later; do not require another control before
the basic assignment interaction is testable.

---

## 4. Dispatch & reinforcement lifecycle  [PROPOSED]

### 4.1 Demand-gated dispatch (automation must not dump)

A persistent assignment **directs** production toward an operation; it does **not** blindly empty the source's
stockpile. Dispatch is sized to the operation's **current demand**, accounting for:

- bots already engaged (active inside the target),
- bots already in transit,
- their remaining work capacity (see §5),
- the operation's remaining known requirements,
- available fuel.

Do not send redundant bots merely because a source has more. If no internal objective is active, or the
operation cannot currently accept or fuel more bots, **keep the new bots at their source** (where they remain
available for defense).

### 4.2 Assignment lifecycle

- **Select / inspect a target:** spends nothing.
- **Confirm an assignment:** authorizes future dispatch. A bot becomes irreversibly committed only when it
  *leaves* its source.
- **Retarget:** changes where *future* bots go. Does **not** recall bots already dispatched.
- **Cancel:** stops *future* dispatch. Does **not** refund dispatched bots.
- **Capture (operation succeeds):** stops further dispatch to that target, clears the completed assignment,
  **notifies the player**, and production at those sources returns to resident accumulation. The game does
  **not** auto-pick the next enemy.
- **Invalid connection** (route broken by a lost relay): stops future dispatch and **clearly marks the
  assignment as blocked**. (For the initial test, bots already dispatched may finish their work.)
- **Loss of the source:** stops that source's production contribution and its future dispatch.

Cancelling one source's assignment is distinct from **retreating the whole operation** (§9).

### 4.3 Ongoing operations & reinforcements

- An operation **can receive newly produced bots** from its assigned sources over time. *(This explicitly
  replaces the earlier "no reinforcements during an operation" rule, which is removed.)*
- **Internal progress persists while the same operation continues.** Waiting for production is **not** a
  retreat.
- Running out of bots *temporarily* means **waiting for production** if valid sources remain assigned; it does
  **not** auto-terminate the operation.
- An operation ends only via: **CORE capture**, **explicit retreat**, or a defined **defeat/invalidation**
  condition.
- A thin production stream may eventually finish an attack. In a throughput economy that is not inherently a
  defect — evaluate it by its **time cost, fuel consumption, and defensive exposure** under Net Watch
  pressure, not by forbidding it.

---

## 5. Bots execute; resources fuel  [PROPOSED]

**Resources never deal damage on their own.** Damage requires *both*:

1. an **active bot** with remaining work capacity, and
2. the appropriate operation **fuel**.

**Bot states to distinguish in UI and logic:** resident · dispatched/in-transit · active · remaining work
capacity · production arriving over time.

**Each bot has a finite firing allowance:**
- while firing, it deals damage and consumes fuel;
- firing consumes its allowance; **waiting does not**;
- an exhausted bot is consumed;
- a dispatched bot never returns or becomes reusable.

**Provisional model (test candidates):**
- Damage: **1 defense per active bot per second.**
- Fuel: **0.2 Intel per active bot per second.**
- Firing allowance: **10 seconds per bot** → **max 10 defense of damage per bot.**

**Key property — total fuel is independent of how many bots you commit.** For a fixed amount of damage *D*,
total fuel ≈ `fuel_rate × D` (because firing time ≈ `D / (damage_rate × bots)`, and the bot count cancels).
More simultaneous bots → more damage/second and proportionally more fuel/second → the job finishes **faster**
for the **same total fuel**. Committing more bots does not inherently cost more fuel; it costs more *bots* and
front-loads the burn.

**Why the old `2 Intel/bot/s` needs recalibration.** Under "1 damage/bot/s", a 92-defense target costs
`0.2 × 92 = 18.4` Intel total at the new rate — affordable from 15 starting Intel plus income. At the old
`2 Intel/bot/s` it would cost `2 × 92 = 184` Intel for the same kill, roughly **10×** a plausible early
budget. Hence the drop to ~0.2 as the opening candidate.

### 5.1 Fuel starvation

When fuel is insufficient:
- **stop or throttle firing** by one explicitly documented rule (pick one and state it in code comments; e.g.
  "fire only as many active bots as current fuel/s supports");
- **hold additional bots at their sources**;
- **keep assignments active**;
- show a clear **"waiting for fuel"** state;
- **continue resource production and the global clock.**

For the initial continuous-operation test, fuel-empty means **wait**, not auto-retreat. Do **not** reintroduce
the old 10-second starvation timeout — it was designed for the discarded one-shot-force model. Net Watch
pressure (§8) is what makes prolonged waiting consequential; validate that before adding any new failure
timer. Dispatched bots still have finite work capacity, so waiting cannot generate unlimited damage.

---

## 6. Internal objectives  [PROPOSED]

The player directs the break-in; assigned buildings supply its execution. After choosing an objective, assault
is **continuous** — no repeated "pulse" clicks are required to keep firing. Assignments supply the chosen
objective automatically; they do not independently pick routes or override the player's internal decisions.

**One consequential choice to test first** (test-fixture values):

| Path | Work | Time @10 active bots | Fuel |
|---|---|---|---|
| **Direct** | required node 22 + CORE 70 = **92 defense** | ≈ 9.2 s | ≈ 18.4 Intel |
| **Utility first** | required node 22 + utility node 10 (+3 s activation) → CORE 70 **reduced to 50** = **82 defense** + activation | ≈ 11.2 s | ≈ 16.4 Intel |

So "utility first" trades **more time** for **less fuel and less total work** — a real decision whose best
answer should change with how much time/defensive exposure you can afford (see §8).

---

## 7. Reach, ownership & defense  [mix]

- **Target legality** [IMPLEMENTED]: an enemy host must have an **owned neighbor**.
- **Source eligibility** [PARTIAL]: a source needs an **owned path** to an owned neighbor of the target. *(The
  prototype gates by owned-connectivity today, but as per-strike eligibility, not as a persistent assignment.)*
- **CORE capture grants host ownership** [IMPLEMENTED for the single-breach path]. Capturing an **ordinary**
  internal node does **not** by itself expand city territory — only the CORE does. *(The prototype currently
  only resolves ownership on CORE capture, consistent with this.)*
- **Resident bots auto-defend their own building** and are consumed through defense. They do **not** move
  between buildings. [PROPOSED — no defense exists in the prototype yet.]
- **Every owned building has modest base resistance**; exact value provisional. [PROPOSED]
- **Victory:** capture the **HUB** — not every building. [IMPLEMENTED]
- **Defeat:** Net Watch retakes your **last owned building**. [PROPOSED — no defeat condition exists yet.]

---

## 8. Global clock, Net Watch & attention  [PROPOSED]

- **Production and Net Watch timers keep running during internal combat.** *(The prototype already keeps
  production/income running while you're inside — Net Watch does not exist yet.)*
- **Incoming threats stay visible from inside** the target.
- **Explicit pause freezes combat, production, and enemy timers together.**
- Start with **one warned counterattack**: a readable target, arrival time, and strength.
- Persistent assignments are what make this tractable — the player shouldn't need to babysit every source to
  keep operations fed.

---

## 9. Retreat & recovery  [PROPOSED]

Retreating ends the **entire** target operation:
- stops its contributing assignments,
- loses remaining dispatched bots,
- **preserves** unspent global fuel,
- **preserves** discovered information.

For the baseline test, **unfinished internal damage resets** after retreat. Test *persistent* internal damage
separately — repeated cheap incursions that chip a target down over many retreats could become a dominant
degenerate strategy.

---

## 10. Provisional values & worked examples

All values are opening-test candidates, **not** final balance.

| Value | Candidate | Status |
|---|---|---|
| Damage per active bot | 1 defense / s | [PROPOSED] |
| Fuel per active bot | 0.2 Intel / s | [PROPOSED] (prototype uses a different parallel-drain formula) |
| Firing allowance | 10 s/bot → 10 damage/bot | [PROPOSED] |
| Starting rig bots | 10 | [IMPLEMENTED] |
| Starting Intel | 15 | [IMPLEMENTED] |
| Intel income | 0.6 / owned host / s | [IMPLEMENTED] |
| Bot production | +1 / 5 s per war building (cap 80) | [IMPLEMENTED] — replenishment pacing **unvalidated** |
| War building cost | 25 Intel | [IMPLEMENTED] — investment pacing **unvalidated** |
| Host defence (global) | 20 (outer) / 40 (inner) / 240 (HUB), by ring | [IMPLEMENTED] |
| Internal node defence | entry 0, mid `16 + 6·k`, CORE 70 | [IMPLEMENTED] (chain depth 3/4/6 by ring) |

**Worked example — fuel independence.** A 92-defense target with the proposed model costs `0.2 × 92 = 18.4`
Intel total, whether you bring 10 bots (≈9.2 s) or fewer over more time. Over ~9.2 s a lone starting rig
supplies `15 + 0.6 × 1 host × 9.2 ≈ 20.52` Intel — enough. Ten bots at 10 damage each (100 capacity) covers
the 92.

**Worked example — the internal choice.** See §6: Direct ≈ 9.2 s / 18.4 Intel; Utility-first ≈ 11.2 s /
16.4 Intel. (Test-fixture figures.)

---

## 11. Implemented vs. proposed — at a glance

The sandbox prototype (`scripts/botnet_proto.gd`, "v2") was rewritten to implement this spec. A headless logic
check confirms the economy matches the fixtures exactly (DIRECT spends 18.40 Intel, UTILITY 16.40, demand
gating commits ~9.2 bots not the whole stockpile, Net Watch repel/loss both resolve). These are logic checks,
**not** playtests.

**Implemented now (this model):**
- Fixed 5×3 grid, HUB centre; **two** owned source rigs in a corner; ring layout; `SPACE` pauses everything.
- **Persistent per-building → target assignments** (§3): **multi-select** your war buildings (click to toggle),
  click a bordering enemy, choose Direct/Utility, **ATTACK**. Several buildings can feed one target. Attacks run
  **along the owned network route** (a disconnected building can't attack — no "from anywhere"). Bots are
  **consumed from the source nodes** (one-way). Unassigned buildings hold for self-defense; an explicit
  **🛡 Defend** button holds a selection home. (Defense is self-only — bots don't move between buildings.)
- **Demand-gated continuous dispatch + reinforcements** (§4): sources supply the operation only up to its
  remaining capacity need; new production flows in over time; nothing is dumped.
- **Bots-execute / resources-fuel** (§5): 1 damage + 0.2 Intel per active bot per second, 10-damage allowance
  per bot; damage needs both a bot and fuel; **fuel starvation → wait** (throttle, "waiting for fuel"), no
  timeout.
- **Internal objectives** (§6): Direct vs Utility-first (utility node, 3 s activation, −20 CORE), continuous
  assault (no pulse-clicking); shown in the operation inset.
- **Reach/ownership** (§7): target must border territory; source needs an owned path; **only CORE capture**
  grants the host; resident bots + base resistance defend; **victory** = HUB, **defeat** = lose last building.
- **Global clock + one warned Net Watch attack + re-arm** (§8): production, income, and the Net Watch timer
  run during internal viewing; the warning shows target, ETA, and strength.
- **Retreat** (§9) ends the operation, loses dispatched bots, keeps global fuel; internal damage resets.
- **Two deliberate steps — link, then commit.** (1) **Drag** from a war building onto a node to *link* it
  (enemy → attack link, connected friendly → defend link); nothing is sent, the link draws as a static line.
  Link several buildings onto one node. (2) Press **ATTACK** (or **DEFEND**) — only then do the bots start
  flowing. On ATTACK the needed bots are consumed from **all** linked sources (spread proportionally) and
  firing begins immediately (no timer); reinforcements flow as capacity drains. On DEFEND the linked
  buildings route bots to the friendly node to bolster its resident defence (this relaxes the old
  "bots never move between buildings" rule — intentional, per the drag-to-defend direction).
- Streams are drawn along the owned network route; a link/plan line is static, a committed flow animates.

**Still simplified / not yet built:**
- Each source is **one** production node (the `war` flag), not an aggregate of several (§3 note).
- Active bots use a **shared capacity pool** approximation, not per-bot individual allowances (faithful to the
  fixtures; edge cases with mixed-age reinforcements are approximate).
- **Explicit retarget** is "reassign the source" (works) rather than a dedicated control; **blocked-by-broken-
  route** only triggers on actual source loss, not on a severed relay mid-chain.
- Low-fuel still dispatches to in-operation idle (it gates only on `Intel > 0`); the exact "hold at source"
  rule (§5.1) and a **reserve / defend-only** policy are not built.
- Not ported into the real city; no fog/scan, no multiple currencies, no complex enemy AI (all deferred per §12).

---

## 12. Validation scenario & open tuning questions

**Minimum testable slice:**
- two owned source buildings,
- one frontier target,
- one meaningful internal choice (§6),
- one fuel resource (Intel),
- one warned Net Watch attack,
- a small HUB objective.

Keep existing production/building rates as baseline, but treat **replenishment and investment pacing as
unvalidated**. Keep **transit instant** at first (show delivery streams without distance delays). Defer
multiple simultaneous enemy operations, extra currencies, fog, and complex enemy AI until the assignment loop
reads clearly.

**What to watch for (hypotheses to check, not findings):**
- Do players understand **where their production is assigned**?
- Do they distinguish **resident vs. committed** bots?
- Do they **retarget for explainable strategic reasons**?
- Do they **deliberately keep local defense**?
- Do they understand **blocked-production / waiting-for-fuel** states?
- Do they make **different internal choices under different threats**?

**Degenerate pattern to guard against:** "assign everything toward the HUB and wait." If that dominates, fix it
by strengthening **competing priorities and consequences** (defense pressure, fuel scarcity, time cost) — not
by adding more clicks.

**Unresolved tuning questions:**
1. Exact firing-allowance, damage, and fuel rates (opening candidates only).
2. Base building resistance value.
3. Bot replenishment and war-building investment pacing.
4. Net Watch cadence/strength and how its warning reads.
5. Whether internal damage should persist across retreats (§9).
6. The one explicit fuel-throttle rule to use under starvation (§5.1).
7. Whether a reserve / defend-only policy is needed beyond "unassigned buildings defend."

---

## 13. Summary of changes

**What changed from the previous revision of this doc:**
- Replaced per-breach **force assembly** and the **"auto — all reachable fire"** proposal with
  **persistent per-building assignments** the player chooses and retargets (§3).
- Added a **demand-gated dispatch** rule (no stockpile dumping) and **reinforcements during an operation**,
  explicitly removing the old "no reinforcements" rule (§4).
- Reworked combat to **bots execute, resources fuel**: per-bot firing allowance, `0.2 Intel/bot/s` (down from
  `2`), and the "total fuel is independent of bot count" property, with the recalibration rationale (§5).
- Changed fuel-empty from a **10 s retreat timeout** to **waiting** (§5.1).
- Specified **internal objectives** (direct vs. utility-first) as the first consequential break-in choice (§6).
- Specified **defense, ownership, victory, defeat, the global clock, Net Watch, pause, and retreat/recovery**
  as proposed systems (§7–§9).
- Added an honest **implemented-vs-proposed** split (§11) and a **validation scenario** with open tuning
  questions (§12).

**Remaining provisional values:** all of §10 — especially damage (1/bot/s), fuel (0.2/bot/s), firing allowance
(10 s), base resistance (unset), and all pacing (bot production, Intel income, war cost).

**Difference from the current prototype:** the prototype still runs the *earlier* one-shot-force model (§11,
"Implemented"). None of §3–§9's proposed systems are built yet; this spec is the target to build toward once
the open questions in §12 are decided.
