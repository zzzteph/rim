# RIM — Gap Analysis vs. the Genre

*Synthesis of six parallel deep-dives (automation/factory, economy/city-builders,
hacking/cyberpunk, threat/defense, replayability/progression, game-feel/onboarding),
each grounded in real games. This is "what RIM is missing," deduplicated and ranked for a
solo project. Companion to `GAME_DESIGN.md` (v0.5.2).*

---

## The one-paragraph diagnosis

RIM has built the **hard half extraordinarily well**: a legible systems skeleton (discrete
packets on road-routed tunnels, coverage-based producers, per-node overload, Cycles-as-food
upkeep with recoverable starvation, a saturating market) and first-class accessibility.
What it is missing is everything that turns a *system* into a *game people finish and
replay* — and the six independent reports converged on the **same three missing layers**:

1. **A real, felt antagonist** (tension/stakes).
2. **A reason to keep going** (goals, progression, endgame, replay).
3. **Feel, legibility & fiction** (audio/juice, instruments to see the machine, a story and a
   hacker fantasy).

The most striking result: **5 of the 6 agents — even the ones not assigned to threat —
independently named "no real, telegraphed antagonist" as RIM's single biggest gap**, and
it is also RIM's own open design question #4. That is the clearest signal in the study.

---

## The convergent top gaps (ranked by cross-agent consensus × impact)

### ① A telegraphed antagonist — the "ICE Sweep"  ★ highest-signal item
*Named by: hacking, threat (its #1 recommendation), economy, replayability, automation — and GDD open-Q#4.*

RIM's `Trace` is currently an invisible scalar (>80 → ×0.8 throttle, then decays) — pressure
with no actor, no telegraph, no stakes, and fully stall-able. Every exemplar (Uplink's trace
tracker, Factorio pollution→evolution, RimWorld's warned-and-staged raids, TD wave previews,
Plague Inc detection) says the fix has a specific **shape** that also satisfies RIM's pillars
(game-first, pause-safe, no unrecoverable states):

- **Make Trace spatial.** Loud tunnels (Reverse Shell/HTTP) emit a noise field into their
  district; VPN/DNS stay quiet.
- **Dispatch a visible tracer** when a district's noise crosses a threshold: it **walks your
  tunnel tree hop-by-hop toward C2** on an **accelerating countdown** ("TRACE INBOUND — 0:45
  to C2"), drawn in **red along the exact tunnels it will take** (reuse the existing
  selection route-highlight), re-pathing live when you reroute.
- **Counterplay you already own:** go quiet (swap to VPN/DNS), **reroute** to add hops/Proxies
  (slower trace — rewards the Proxy backbone), place **countermeasure nodes**
  (Honeypot/Tarpit/Scrubber — a new Cash sink + "build a defense" fantasy), **sever/disable
  the targeted branch** to break the trail, or **DDoS Smokescreen** (already exists — now it
  *saves a run*).
- **Recoverable by construction (anti-"They Are Billions"):** a tracer reaching a node
  **quarantines** it (temporary offline, recoverable); reaching C2 causes a **telegraphed timed
  blackout** (production pauses), **never destruction**. C2 is indestructible.
- **The driver (so it can't be idled out):** add a slow, **non-decaying Notoriety** (Factorio
  "evolution" / RimWorld "wealth") that rises with botnet size + Cash + lifetime and sets
  sweep **strength/depth**. You can lower sweep *frequency* by going quiet, but not sweep
  *strength* — a real clock toward the finish, auto-tuning difficulty.

This reuses RIM's tunnel tree, A* routing, route-highlight, dismantle/disable, DDoS, and fog.
**It is the single biggest game-maker and the most on-theme (the trace literally walks the
wires).** *Impact: very high · Effort: medium–high.*

### ② A reason to keep going — Contracts + staged objectives to The Spire + post-win scaling
*Named by: economy, hacking, replayability, automation — and GDD open-Q#7.*

The game ends flatly at 1000 Cash, routing nearly every run through the same Intel→Market
pump and leaving The Spire, Crypto, Tools, Research and ICE under-used. Three stacking fixes,
all mostly **data + timer + UI** (no new simulation):

- **A Contract Board** (Hacknet/Uplink/Against-the-Storm "orders") in the C2 Console:
  time-boxed jobs with a **named client**, a **target district/structure**, a **reward**
  (Cash + tech/rep), and a **complication** (e.g. *"[AZEVEDO SYNDICATE] Exfil 50 Intel from
  Glasshouse Row in 4:00 — the Row is running ICE-2 this week."*). Gives Cash a *purpose*,
  points expansion at specific districts, and creates **spiky, diversified demand** that
  rewards running multiple chains. Pause-safe (frozen on pause), fully recoverable (failure
  just forfeits the reward).
- **Staged objectives + a reputation track to The Spire** — promote the existing `→ Next`
  signpost into an explicit milestone chain (100 Cash → breach first ICE → reveal the Spire →
  …) and make the **final contract the Spire heist**, so there's always a next target.
- **Alternate win conditions** that each force a different economy: *Total Control* (hold an
  ICE-3 Spire district → activates Tools/ICE), *Kingpin* (launder N Crypto → forces the Mixer
  line), *Blackout* (complete the tech tree → forces Research). Win-checks over systems that
  already exist.
- **Post-win: an infinite Cash/pressure ladder + a run-summary scorecard** (time-to-win, peak
  Cash/s, peak Trace, nodes, packets delivered) so a win mints a "beat this."

*Impact: very high · Effort: contracts & staged goals low–medium; alt-wins medium.*

### ③ The legibility layer — alerts + graphs + tooltips + bottleneck finder
*Named by: automation (#1), economy (#8), game-feel (#3/#4/#5) — mostly surfacing data RIM already computes.*

RIM *manufactures* bottlenecks (overload, starvation, offline) but gives almost no instruments
to **see, diagnose, and systematically beat** them — and this becomes *essential* the moment
②/⑤ add complexity. Nearly all of it is surfacing existing state:

- **A persistent, click-to-jump alerts strip** (Factorio-style): OVERLOADED / STARVED
  (`slow_factor < 1`) / OFFLINE (no path to C2) / Trace-hot / idle converter — glyph + text,
  click pans to the problem. The detection already exists for the banner/info-panel. **Cheap.**
- **Stats-tab graphs over time**: store the net-rate samples you **already take at 1 Hz** in a
  ring buffer and draw production/consumption sparklines + Cash-vs-goal. Visualizes the
  invisible market-saturation curve and answers your own balance questions. **Cheap.**
- **Hover tooltips on everything** (resources, ▲/✓/✕ symbols, coverage, Trace, upkeep, build
  entries) — the lowest-effort learnability win here — plus, as depth, a **Codex tab** reusing
  `glyphs.gd` + the homage flavor. **Tooltips are the single cheapest learnability win.**
- **A "biggest bottleneck" chip** in the collapsed dashboard ("Darknet Market starved for
  Intel" / "VPN trunk at 180% cap").

*Impact: high · Effort: low–medium (cheap wins).*

### ④ The game is silent — audio + juice
*Named by: game-feel (its #1 and #3).*

A grep confirms **zero audio code**. The core-loop's most-repeated, most-rewarding moment
(a packet banking at C2) happens in total silence with no visual punch.

- **SFX subset (cheap, enormous):** a delivery chime at C2 **pitch-varied per resource** (also
  a **third accessibility channel** — you *hear* which resource banked), plus build/tunnel/sell
  sounds and **distinct** overload/starved/offline alarms. Wire a bus-per-category to
  volume/mute sliders in the existing `Settings` autoload.
- **Juice the ~5 meaningful moments** (not every tick): a counter scale-pop + glow on delivery,
  a coin-burst at the Market sale, a power-on ring on build/route-lock, a real win crescendo —
  **all routed through the existing `reduced_motion` gate** so it stays accessible.

*Impact: high · Effort: low–medium (SFX subset + delivery pop are cheap wins).*

### ⑤ Economic depth — a demand side + intermediate goods
*Named by: economy (its keystone #1/#2); automation touches it via ratios.*

RIM's economy is one step deep (producer → one-step converter → Cash) with **no consumer** but
tunnel upkeep. Every K&M/Anno/Settlers/ATS economy runs on *demand pulling you into deeper
chains and new territory*:

- **A demand side:** the botnet itself is the "population" — C2 gains **ranks** (kiddie →
  operator → syndicate → kingpin), each **demanding an ongoing resource basket** to grow
  (sustain X Research/s + a Tools buffer + Y Cash). Unmet demand stalls growth (caps nodes /
  shrinks vision), never kills. This is the Anno tier-engine in cyberpunk: each tier forces a
  *new* resource, a *new* district, a *new* chain. (The Contract Board in ② is the cheaper
  first taste of "external demand.")
- **Intermediate goods + two-input recipes** on the existing packet/tunnel engine: Intel →
  *Credential Cracker* → **Credentials** → *Forge* takes **Credentials + Tools** → **Exploit
  Kits** (worth far more Cash). Delivers the genre's signature "recipe composition" pleasure
  and gives richer districts a reason to exist.
- **Allocation layer** (K&M/Workers&Resources): **finite C2 storage** (overproduction backs up)
  + **distribution sliders** (of banked Intel, X% → Market, Y% → Forge, Z% → Lab) — turns
  parallel dumps into a budget you apportion.

*Impact: high (deepest economic uplift) · Effort: medium (ranks/recipes) — higher than ①–④.*

### ⑥ A replay engine — Ascension tiers + seeds + archetypes + score
*Named by: replayability (its #1/#2/#4/#6); automation (endgame scaling).*

Winning currently produces nothing and the next run is identical. The roguelite answer respects
RIM's "no power-creep between runs" pillar by unlocking **options, not power**:

- **Stacking difficulty unlocked by winning** (Slay the Spire *Ascension*): each win mints a
  harder tier built from existing constants (higher goal, hotter ICE, steeper saturation,
  slower Trace decay) — the canonical thousand-hour-tail mechanism; the ICE Sweep (①) is the
  natural high-tier content.
- **Seed entry/share + a Daily City** — the generator is already seeded and the seed is even
  shown in Stats; just expose/copy/enter it. **Cheap.**
- **City archetypes + modifiers** (ONI world traits): bias the existing Voronoi weights into
  *Fortress / Sprawl / Finance-Hub / Rolling-Blackouts* cities so no two want the same opening.
- **A run-summary score + par medals** (shared with ②) and **constraint achievements** ("win on
  DNS only", "under 20 min") as replay prompts / horizontal-unlock currency.

*Impact: high (longevity) · Effort: Ascension & archetypes medium; seed-expose & score cheap.*

---

## Honorable mentions (worthwhile, lower priority / higher effort)
- **Per-node modules + a permanent overclock slider** (Factorio modules / Satisfactory
  overclock) — productivity/efficiency/stealth/throughput implants turn the flat tech tree into
  build-defining choices and a lategame sink. *(automation #3; med/med.)*
- **Blueprints / copy-config / cluster-stamp** — scale without hand-tedium. *(automation #5; med/med-high.)*
- **Conditional/smart routing** — threshold auto-throttle, tunnel filters/priority, conditional
  routing (the circuit-network depth layer). *(automation #6; high value, high complexity.)*
- **Narrative & fantasy skin:** a handler who messages the C2 console at milestones + a
  SHODAN-style antagonist voice as Trace climbs; named fictional megacorps that own rich
  structures and serve as contract clients/victims; a diegetic "C2 terminal" reskin; an
  Exapunks-style in-world zine as the tutorial. *(hacking #3/#4/#7; mostly text/data, low–med.)*
- **Discovery by probing** — a quiet-vs-loud Scan action over fog (NITE Team 4). *(hacking #6.)*
- **Real external-actor market / contested territory / "construction delivered through tunnels".**

---

## Recommended build order (for a solo project)

**Phase A — Cheap wins that raise quality *now* and make everything else teachable** (days, mostly surfacing existing data):
hover tooltips · alerts strip · net-rate sparklines · SFX subset + delivery juice · run-summary
score · seed expose/share · Settings → tabs (Accessibility/Audio/Gameplay/Controls) ·
the gated first-run tutorial (rides on `_next_step()`).

**Phase B — The headline: tension.** The telegraphed **ICE Sweep** antagonist + the
**Notoriety/evolution** driver (gap ①). This is the single biggest step-change in how the game
*feels*.

**Phase C — Goals & replay.** The **Contract Board** + **staged objectives / alternate wins to
The Spire** + **Ascension tiers** + **city archetypes** (gaps ② & ⑥). Turns a one-and-done
sandbox into a campaign with a tail.

**Phase D — Economic depth.** **Demand-side ranks** + **intermediate goods** + **allocation
(storage/sliders)** + the **production dashboard** (gap ⑤). The deepest, most expensive layer —
do it last, on top of the legibility tools from Phase A.

**The throughline:** RIM is already computing or sampling almost everything the Phase-A/C
features need (net-rate samples, overload/starvation/offline states, `_next_step()` state,
reduced-motion gating, the glyph set, a seeded generator, the tunnel tree + A* + route-highlight
for the sweep). Most of the near-term value is **surfacing and dramatizing what's already there**,
not building new simulation — which is why so much of it is cheap.
