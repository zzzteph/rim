# RIM — Game Design Document

*A document for a game designer / systems reviewer. It describes the current build
(v0.5.2) — mechanics, numbers, and open questions — so it can be evaluated. Exact
values are pulled from `scripts/main.gd` and may change between builds.*

---

## 1. Concept

**RIM is a 2D cyberpunk hacking/automation strategy game.** You are a hacker growing a
**botnet** across a procedurally generated neon "night city." You place hacking
structures in city districts and wire them back to a central **C2 (command & control)
server** with routed **tunnels** that carry discrete **data packets**. It is a
single-player, real-time (pausable) base-builder.

**Inspirations:** Knights & Merchants (production chains, servants-consume-food economy,
chunky UI), Factorio (automation, discrete items on belts, bottleneck-chasing), and
Constructor. The "belt" is a **tunnel**; the "item" is a **packet**; the "worker/food"
is **Cycles upkeep**.

**Design pillars:**
- **It is a GAME first** (fun over simulation fidelity). No unrecoverable states.
- **Accessibility (low vision) is a first-class requirement**, not an afterthought.
- Every structure and tech is a *flavor-level homage* to a real hacking concept
  (non-operational).

---

## 2. Goal & session shape

- **Win condition:** reach **1000 Cash**.
- **Starting state:** one C2 Server (3×3), **80 Cycles**, everything else 0, on the rim
  of a fixed **100×100** tile map. Fog of war hides most of the city.
- A session is a single map; there is currently **no persistent meta-progression**
  (save/load of the in-progress game exists).

---

## 3. Core loop

1. **Place a producer** on the matching district (ground colour = resource colour).
2. **Tunnel it back toward the C2** (data always flows to C2 by the shortest route).
3. Packets arrive at C2 and bank the resource.
4. **Convert** resources (e.g. Intel → Cash at a Darknet Market) and **spend** them to
   expand.
5. Manage **upkeep** (tunnels burn Cycles), **overload** (links/nodes have throughput
   caps), and **Trace** (heat).
6. Repeat, pushing into richer districts, until 1000 Cash.

The intended "Factorio moment" is watching discrete packets stream along your tunnels and
chasing the next bottleneck (a thin tunnel, an overloaded node, a starved converter).

---

## 4. Resources (6)

| Resource | Internal | Colour | Source | Used for |
|---|---|---|---|---|
| **Cycles** | compute | green | Mirai Dropper, Poisoned Package, Cloud Cryptojacker | build cost, **tunnel upkeep**, converter fuel, commands |
| **Intel** | data | blue | Phishing Kit, Scraper Botnet | sold for Cash, converted to Tools/Research |
| **Crypto** | crypto | orange | Magecart Skimmer | laundered to Cash at a Mixer |
| **Cash** | credits | yellow | Darknet Market (Intel→Cash), Crypto Mixer (Crypto→Cash) | **win metric**, cost of advanced structures & fat tunnels |
| **Tools** | tools | purple | Exploit Forge (Intel + Cycles) | breach ICE, DDoS Smokescreen |
| **Research** | research | cyan | Research Lab (Intel + Cycles) | unlock tech |

Cash is produced **only by conversion**, never mined — a deliberate "you must build a
supply chain" gate.

---

## 5. The map

- **100×100 tiles.** Buildings occupy 3×3 blocks with 1-tile **street** gutters between
  them (so there is a connected road grid).
- Partitioned into **districts** via a seeded Voronoi scheme; valuable districts cluster
  toward the centre, residential/undercity fill the rim.
- **Districts are colour-coded by the resource you can produce there:**
  - 🟢 **Cycles** — The Sprawl (residential), The Registry, Server Farms
  - 🔵 **Intel** — Glasshouse Row, The Feeds
  - 🟠 **Crypto** — The Exchange
  - cyan **The Spire** (endgame flavor), grey **The Undercity** (no producer)
- **Fog of war:** you can only build within your structures' vision radius. Pushing a
  **Proxy** (see §9) toward a district reveals and unlocks it.
- **ICE:** some districts carry an ICE tier; building there costs **Tools** to breach and
  spikes Trace (+8).

---

## 6. Structures

### Producers (place on matching-resource ground)

| Structure | Produces | Base rate | District(s) | Unlock | Cost |
|---|---|---|---|---|---|
| **Mirai Dropper** (nest) | Cycles | 1.0/s | residential **or any Cycles** | start | 10 Cy |
| **Poisoned Package** | Cycles | 3.0/s | any Cycles | tech *Supply-Chain* | 40 Cy, 10 In, 40 Cash |
| **Cloud Cryptojacker** | Cycles | 4.0/s | any Cycles | tech *Cloud* | 30 Cy, 10 In, 60 Cash |
| **Phishing Kit** (phish) | Intel | 1.0/s | any Intel | start | 12 Cy |
| **Scraper Botnet** | Intel | 1.5/s | any Intel | tech *Web-Scraping* | 15 Cy |
| **Magecart Skimmer** (salami) | Crypto | 1.0/s | any Crypto | start | 30 Cy, 20 In, 30 Cash |

All producer output is **× coverage** (see §7) and **× output-limit** (player-set 0–100%)
and **×2 while Overclocked**.

### Converters (place anywhere in vision; pull input from C2, send product back)

| Converter | Reaction | Rate | Fuel | Unlock |
|---|---|---|---|---|
| **Darknet Market** (fence) | Intel → Cash | 3.0/s + pass-through | — | start |
| **Crypto Mixer** | Crypto → Cash | 2.0/s | — | tech *Laundering* |
| **Exploit Forge** | Intel → Tools | 0.6/s | 3 Cycles each | tech *Exploits* |
| **Research Lab** | Intel → Research | 0.5/s | 2 Cycles each | start |

The Darknet Market has a special **pass-through**: an Intel packet routed *through* a
Market on its way to C2 is sold on the spot — this is the main Cash pump (and the subject
of the market-saturation rule, §10).

### Infrastructure

- **C2 Server (hub):** the sink; all packets end here. Unlimited throughput.
- **Proxy** (relay): see §9.
- **Tunnels:** see §8.

---

## 7. Coverage-based production  *(new in 0.5.x)*

A hack's output scales with **how many distinct city buildings it sweeps** within
`COVERAGE_RADIUS = 4` tiles.

`output multiplier = clamp(buildings_covered / 5, 0.5, 2.5)`

So a sparse spot ≈ ×0.5–0.8, a typical spot ≈ ×1.0, a dense district ≈ ×1.5–2.5. This
makes **placement matter** (find dense blocks) and gives producers a reason to spread.
Shown on the structure as a coverage ring and in its info panel ("Covers N buildings →
×M.M output").

---

## 8. The network: mesh, tunnels, routing, overload, upkeep

### Topology — a mesh that drains to C2
- You draw a **single out-link per node**, but a node may receive **many** in-links, so it
  can act as a junction. You can link **any node to any other node** (not just to C2).
- Data always flows **to the C2 along the shortest routed path**; loops are prevented.
- Links **follow the roads**: routing is orthogonal and only on street/open cells, so
  tunnels trace the grid and turn at 90° instead of cutting through buildings.

### Tunnel types

| Tunnel | Capacity (pkt/s) | Upkeep (Cy/tile/s) | Loss/tile | Trace/s | Unlock |
|---|---|---|---|---|---|
| **DNS Tunnel** | 3 | 0.05 | 1.5% | 0 (silent) | start |
| **VPN Tunnel** | 6 | 0.12 | 1.2% | **−0.25 (cools)** | start |
| **Reverse Shell** (tcp) | 10 | 0.20 | 1.0% | +0.4 (loud) | start |
| **HTTP/2 Flood** | 16 | 0.30 | 0.6% | +0.2 | tech *HTTP/2* |
| **Onion Route** (proxy\*) | 5 | 0.28 | 0.4% | +0.1 | tech *Onion* |

\* *Naming caveat: this tunnel's internal key is `proxy`, which collides with the Proxy
node name — a known cleanup item.*

### Upkeep & starvation
- Each live tunnel burns `length × upkeep` Cycles/s from the global pool.
- If Cycles can't cover it, **`slow_factor`** scales everything down but **never below
  0.25** — a starved network crawls but always recovers (no death spiral). This is the
  K&M "food" analogue.

### Loss model (two separate things — important)
1. **Distance loss** (normal): `length × loss_per_tile`. Long links bleed packets; this is
   expected and shown as "−X% (distance)".
2. **Overload** (a problem): when the **offered load** through a node's out-link exceeds
   its **capacity**, excess packets are dropped and it's flagged **OVERLOADED**.
   `capacity = min(tunnel capacity, node throughput)`, reduced further past 4 in-links.

### Per-node throughput (`NODE_CAP`)
C2 ∞ · Proxy 20 · converters 12 · producers 6 pkt/s. Past **4 in-links** a node's capacity
is cut (−12% per extra link, floor 40%) — so over-wiring one node chokes it, and you build
**Proxies / fatter tunnels** to carry big fan-ins.

---

## 9. The Proxy node  *(new in 0.5.x — the "router")*

Select **Proxy** and click **any producer** to convert it. A Proxy:
- **Stops producing** (minimum CPU use),
- Forwards packets toward C2 at **40% tunnel upkeep** (minimum upkeep),
- **Sees far** (vision 15 vs ~6–8) to push reach into new districts,
- **Merges** many thin links into one fat trunk (throughput 20, +1 per aggregated branch).

Intended use: drop a cheap Mirai Dropper where you need reach, convert it to a Proxy, and
run a cheap backbone toward distant districts.

---

## 10. Economy & tension

- **Diminishing market returns (market saturation):** Cash paid per Intel sold =
  `clamp(1 − Cash/2000, 0.3, 1.0)`. 1:1 at the start, ½ at the 1000 goal, floored at 0.3.
  Spending Cash (which lowers your balance) keeps your sale price high, so reinvestment is
  rewarded and diversifying into Crypto→Mixer becomes worthwhile near the finish.
- **Cash sinks:** advanced structures cost Cash (Package 40, Botfarm 60, Mixer 50, Forge
  30, Skimmer 30) and fat tunnels cost Cash (VPN/TCP 10, HTTP 25, Onion 15). So Cash is a
  currency you spend to grow, not only a score.
- **Early choice:** Phishing Kit (cheap, 1.0 Intel/s, start) vs Scraper Botnet (denser
  1.5/s but tech-gated & noisier).

---

## 11. Progression — tech tree

Research (from a Lab) unlocks facilities. Current techs (cost in Research Points):
*Web-Scraping (10)→Scraper*, *Supply-Chain (10)→Package*, *Cloud (15)→Botfarm*,
*Laundering (15)→Mixer*, *Exploits (20)→Forge*, *Onion (20)→Onion Route*,
*HTTP/2 (25, needs Exploits)→HTTP tunnel*. Mostly a flat tier with one dependency.
*(A graphical tech-tree view is planned; it's currently a list.)*

---

## 12. Threat — Trace (heat)

- Each live tunnel adds its **noise** to Trace/s (VPN cools, Reverse Shell/HTTP are loud);
  Trace decays at 1.2/s. Breaching ICE spikes +8.
- Above **80 Trace**, ICE throttles the whole botnet ×0.8.
- **DDoS Smokescreen** command (40 Cycles, 1 Tool) resets Trace to 0.
- *This is deliberately mild right now. A telegraphed, pause-safe ICE "sweep" antagonist
  is the planned Phase 3 and does not yet exist.*

---

## 13. Commands & controls

- **Overclock** (20 Cycles): doubles a structure's output for 20s.
- **DDoS Smokescreen** (40 Cycles, 1 Tool): Trace → 0.
- **Output limit** (−/+): throttle a producer 0–100% to avoid overloading a thin link.
- **Pause-to-plan:** build/inspect while paused (sim frozen).
- **Controls:** left-drag or edge-scroll to pan, wheel to zoom, left-click to select/place,
  right-click or **Esc** to cancel, **Ctrl+Z** undo. Selected structure: **Del** dismantle,
  **E** disable, **O** overclock, **−/+** output. Cursor shows mode (crosshair = building,
  hand = clickable).

---

## 14. Accessibility (first-class)

Settings (persisted): **Reduced motion**, **Colour-blind palette** (Okabe–Ito),
**High contrast**, **Text size up to 200%**, **Packet style** (code/dots). Plus:
packets are **shape-coded** (bolt/eye/coin/hexagon/…) so identity never rides on colour
alone; tunnel health shows **symbols** (✓ / ▲ / ✕); structures get a dark knockout + neon
keyline + vision circle for figure-ground; animation is gated by reduced-motion.

---

## 15. Current balance snapshot (for quick evaluation)

- Start 80 Cycles; win 1000 Cash. Tick 10 Hz. Starvation floor 25%.
- Producer rates (×coverage 0.5–2.5): nest 1, phish 1, salami 1, scraper 1.5, package 3,
  botfarm 4 per second.
- Converters: fence 3 + pass-through, mixer 2, forge 0.6 (+3 Cy), lab 0.5 (+2 Cy) per s.
- Tunnels (cap / upkeep / loss / trace) in §8. Node caps in §8.
- Market price `clamp(1 − Cash/2000, 0.3, 1.0)`.

---

## 16. Known issues & open design questions (reviewer, please weigh in)

**Open questions for a designer:**
1. **Is coverage-based output the right lever, or does it over-reward "hunt the dense
   block" busywork?** Should it be range-based sweep instead?
2. **Dominant strategy:** pre-0.4.3 it was "spam Scraper + one Market." Market saturation +
   cash sinks were added to break it — does a clearly dominant line still exist?
3. **Node overload metrics** (6/s producers, 20/s proxy, −12%/link past 4) — readable? Fun,
   or fiddly?
4. **Threat is too soft.** What should the ICE antagonist feel like (telegraphed sweep vs
   steady pressure vs economic)? It must stay pause-safe and recoverable.
5. **Single out-link per node** (mesh-to-C2) vs true multi-path load-balancing — worth the
   complexity?
6. **Onboarding:** is "Cash is sold, not mined → Intel → Market" discoverable enough from
   the live "→ Next" signpost, or does it need a tutorial?
7. **Session length / endgame:** 1000 Cash with no meta-progression — right scope, or does
   it need staged objectives ending at The Spire?

**Known cleanup items:** tunnel key `proxy` vs the Proxy node name collision; tech is a list
not a tree; coverage count can be swingy by seed.

---

## 17. Tech / platform

Godot 4.7.2 (GDScript, GL Compatibility renderer), Windows build in `build/rim.exe`.
~2000-line `main.gd` (sim, A* routing, rendering), `ui.gd` (K&M-style panel). Static city
is baked once; see `DESIGN.md` for the per-version changelog.
