# Rim — Design

A 2D cyberpunk automation game. You are an unseen operator building a botnet
across a city, from the slums ("the Rim") toward the corporate centre.
Inspired by *Knights and Merchants* (production chains, goods delivered to
consumers) and *Factorio* (belts, merging, bottlenecks, auto-generated maps).

Version scheme: `X.Y.Z`, starting `0.0.0`. Each digit is 0–9; on 10 it rolls
over (`0.0.9 → 0.1.0`, `0.9.9 → 1.0.0`).

---

## The game now (v0.7.4): two connected map scales

RIM is a 2D cyberpunk hacking/automation game with an unseen operator and **two connected map
scales** (SimCity/Constructor city presentation; Stellaris hierarchy/exploration). One New
Game / Continue experience, no walking avatar. Entry point: **New Game** (`scripts/netrun.gd`,
`scenes/netrun.tscn`). The city size is chosen on the menu (Small 10×10 / Medium 24×24 / Large
40×40; the grid unit is a **building lot**).

**Global city map.** A continuous architectural city of districts, streets and a 2.5-D skyline.
Each building is a "system" with links to other buildings. Buildings start **grey/unknown**;
**scanning a building reveals its links** to neighbours (discovered links are drawn, hidden ones
stay invisible). You expand along discovered links from buildings where you hold a foothold. Click
a reachable building to open its **local** network directly; Esc returns to the city (camera and
selection restored).

**Local building map.** A schematic component graph inside one building. It opens with **one entry
component**; scanning a revealed component discovers its direct neighbours (progressive discovery
at both scales, independent). Component types and install slots (brief §3):

| Component | Slots | Capacity | Affinity |
|---|--:|--:|---|
| IoT | 2 | 2 | Cycles |
| Web server | 4 | 4 | Cycles |
| File server | 4 | 4 | Intel |
| Database | 6 | 3 | Intel |
| PC | 6 | 4 | balanced (×0.5) |

**Control via attack cards.** Hacking a component spends resources through **technique cards** in
three research branches — **credentials / vulnerabilities / phishing**. A card applies only if the
target has the matching trait (login / software / human) and succeeds (deterministic) when its
power ≥ the target's relevant defence (password / software / awareness). Basic cards are free from
the start and beat easy Rim targets; tier-2 cards (Brute Force / Service Exploit / Targeted Phish)
are unlocked by spending **Research** (produced by an installed Research Lab program). Ineligible
or under-powered cards are refused with the reason and never charge. Capturing the **first**
component establishes a building **foothold** and a route to C2 — no program required to expand.
Capturing **every** component (including hidden ones) grants full control; the win check requires
all actual components, never just the visible subset.

**Programs & economy.** Install programs (the reused catalogue: Mirai/Poisoned Package/Cloud
Cryptojacker → Cycles; Phishing Kit/Scraper → Intel; Magecart → Crypto; Darknet Market Intel→Cash;
Mixer Crypto→Cash; Forge Intel+Cycles→Tools; Lab Intel+Cycles→Research) into a captured
component's slots — **several per component**. A producer matching the component's affinity runs at
100%, otherwise ×0.5. Output flows as **real packets** along the building route to C2; converters
consume banked inputs. Programs can be disabled/removed; undo-safe where applicable.

**Overload & recapture (risk).** Slots and supported capacity are different constraints. Active
program **load** above a component's **capacity** overloads it; sustained overload degrades its
**access integrity** (MVP: 7%/s per unit over capacity) until it hits 0 and the component is
**lost** (ownership drops, installed programs go dormant, the building loses that foothold).
Reducing load stops the damage and integrity recovers (4%/s). A lost component must be
**re-captured** with a card.

**Tuning defaults (MVP, documented — not settled numbers):** scan 2 Cycles; basic card power 3 /
tier-2 power 6; defences scale by organization so the Rim opens with basic cards and deeper orgs
need research; capacity load is per-component and separate from banked cost; dormant-on-loss
programs; deterministic previewed cards; bounded Cycles emergency trickle when stranded with no
income. All verified by `review/netrun_assertions.gd` (12 checks). Accessibility (text scale,
palette, reduced motion) flows from the shared `Settings` autoload; atomic validated save/load
persists both graphs, hidden+discovered identities, programs, research, resources and cameras.

**Not in this slice (separate scope):** rival operators, campaigns, audio, storage subsystems,
local per-component transport detail, and the optional efficiency/reconnaissance/stability upgrade
families.

## Legacy prototype (off-menu): botnet placement game

> The sections below describe the original `main.tscn` placement game. It is kept
> for its mature systems (A* tunnels, packet economy, ICE Sweep antagonist,
> persistence, accessibility) but is not the current game.

## Core loop

1. Hacked homes produce **Compute**.
2. Compute (drawn from the Hub) feeds the **tunnels**.
3. Tunnels carry **Data** to consumers / the Hub.
4. Data is sold for **Credits**.
5. Credits (and Compute/Data) pay for new nodes and hacks.

## Map

- Auto-generated, fixed **100×100** tiles from a random seed.
- The map is a **night city partitioned into contiguous districts** (seeded
  Voronoi over a `GW×GH` grid of `COARSE`-tile cells) tiling the whole map — no
  floating islands. Valuable districts cluster toward the centre; the C2 starts
  in a residential district on the left Rim.
- Districts: **The Sprawl** (residential → Cycles), **Glasshouse Row** (offices →
  Intel), **The Feeds** (media → Intel, lit billboards), **The Registry** (supply
  chain → Cycles), **Server Farms** (low racks → Cycles), **The Exchange**
  (financial → Crypto, ICE 1), **The Spire** (megacorp core, tall towers, ICE 3
  landmark), **The Undercity** (slums filler). Each renders in its own neon
  palette and skyline height so you can read what you're hacking; boundaries +
  centroid labels are drawn, and the minimap paints the whole plan.
- Districts hold a **limited number of slots** for their node type (scaled to
  district size).
- Compute nodes obey a **minimum spacing** rule.
- Buildings occupy **multi-tile footprints** (C2 3×3, others 2×2). A tunnel
  attaches from a cell in the **one-cell ring just outside** each building's
  border (drawn with a short stub to the border, never into the footprint). Each
  cell can host only one tunnel, so several tunnels connect on **different
  sides** of a building; the router picks the attachment cells itself (any free
  ring cell to any free ring cell).

## Resources

Locked set (internal key in parens): **Cycles** (compute) — power; runs tunnels &
programs. **Intel** (data) — information; flows through tunnels, sold for Cash
(later: input to Tools). **Cash** (credits) — money; builds things, win condition.
Planned later: **Tools** (breach ICE), **Crypto** (launder → Cash), **Research**.

| Resource | Role |
|---|---|
| **Cycles** | Power. Feeds tunnel upkeep and pays build costs. |
| **Intel** | Information. Flows through tunnels; sold/converted to Cash. |
| **Cash** | Money for building; the win condition. |

Richer targets cost more, paid with lower-tier resources (a cost ladder).
Later tiers (Intel from The Spire) come post-MVP.

## Nodes (MVP)

Every structure is a **hacking homage** — a nod to something real from the net.
Internal keys in parentheses.

| Structure | Homage | Where | Produces / does |
|---|---|---|---|
| **C2 Server** (hub) | command & control | start | Storage + pays all tunnel upkeep. Only storage in MVP. |
| **Mirai Dropper** (nest) | the Mirai IoT botnet | The Sprawl (spacing) | CPU (1/s) |
| **Poisoned Package** (package) | typosquatted npm package / supply-chain compromise | **The Registry** slot | CPU (3/s) — the richer, gated CPU source |
| **Phishing Kit** (phish) | Emotet-style mail lure | Glasshouse Row slot | Data |
| **Magecart Skimmer** (salami) | checkout-page JS skimmer | The Exchange slot | Credits |
| **Darknet Market** (fence) | Silk Road stall | anywhere | Sells stored Data → Credits while linked to C2 |
| **Tor Relay** (relay) | onion hop on a pwned router | **patch a Mirai Dropper** | Patching **stops its CPU production**; it becomes a pure merge point / range extender. Never placed on empty ground. |

## Tunnels (MVP)

Only two types:

| Tunnel | Homage | Capacity | Upkeep/tile | Notes |
|---|---|---|---|---|
| **DNS Tunnel** (dns) | iodine — data in DNS queries | 3 | low | cheap, quiet branches |
| **Reverse Shell** (tcp) | fat pipe back to C2 | 10 | high | loud trunks after a merge |

- Every tunnel draws Compute upkeep from the Hub's pool (background).
- Upkeep is **per tile**; each tunnel has a **max length** — longer routes need
  **Relays** in between.
- A hungry tunnel (not enough Compute) **slows down** proportionally; nothing is
  destroyed. Speed never drops below **25%**, so a starved network can always
  crawl its way back — no unrecoverable freeze. Game first.
- Tunnels run along grid cells at **90° and 45°** (K&M-style roads) and are
  **routed by A\*** around whatever is in the way — other tunnels and structures —
  with as few bends as possible (a small turn penalty keeps roads tidy). Each
  cell counts as one step, diagonal or not. Distance is shown to the player as
  **latency in packets** (`pkt`, one per cell) where **lower = faster**. The
  reach limit is `MAX_LEN` cells (10); latency + upkeep + cost are previewed live
  while routing (the preview shows the actual route, or why there is none), and
  every built tunnel is labelled with its latency. The grid draws a faint line at
  every tile (brighter every 5th) so tiles are countable by eye.
- A node or tunnel with **no path to the Hub** is drawn red / "offline" (a red
  ring on the node), and linking a dead-end branch warns you — production on an
  unconnected branch never arrives.
- **Tunnels cannot overlap**: a tunnel occupies its path cells exclusively; a new
  one may not share a cell with another tunnel or pass through a building, and a
  diagonal step may not cut between two occupied cells (so two diagonals can
  never cross in an X). Latency (`pkt`) = the number of cells the tunnel
  occupies, countable on the grid.
- **Packets ARE the data**: every unit a producer makes is one packet that
  physically travels the tunnels at `PACKET_SPEED` (slowed by starvation). The
  Hub only gains a resource when its packet arrives, so a longer route really is
  slower. An overloaded tunnel drops packets on entry per the loss formula above
  (a red X flashes where one is lost). A Data packet reaching a Fence turns into
  a Credits packet and carries on. Each packet has a distinct shape+colour —
  **Compute = green circle**, **Data = blue square**, **Credits = yellow diamond**
  (legend in the HUD); the HUD also counts packets in transit.
- Tunnels merge **only at a Relay or the Hub**, so every bottleneck is a visible
  point. (In code: the network is a tree rooted at the Hub; each production node
  or Relay has exactly one outgoing tunnel toward its parent; parents must be a
  Relay or the Hub, so branches merge only there.)

## Overload / packet loss

Per tunnel of capacity `C`, with `S` packets offered and `over = max(0, S - C)`:

    lossrate = clamp(over * 0.5 / C, 0, 1)
    delivered = S * (1 - lossrate)

- Slight overload delivers a little more than capacity (peak ~11.25 for C=10 at
  S=15).
- At **2×** capacity you get back exactly `C`.
- At **3×** capacity `lossrate = 1` — congestion collapse, nothing gets through.

## Delivery (Knights & Merchants style)

Goods go to the nearest consumer that needs them first; surplus goes to the Hub.
A **Fence**, while connected to the Hub, sells Data two ways: a Data packet
routed *through* it becomes a Credits packet on the spot, and it also pulls
stored Data from the Hub one packet at a time (`FENCE_RATE`/s) — the blue packet
travels Hub → Fence, is sold, and a Credits packet travels back to the Hub. It
also acts as a pass-through/merge point for routing.

## Goal (MVP)

Reach **1,000 Credits**. No threat/Trace yet — Trace is the first planned
post-MVP feature.

## Controls (MVP)

- Pan: WASD / arrow keys. Zoom: mouse wheel.
- Build bar: pick a node or tunnel type, then click the map. Invalid placement
  shows red.
- Tunnels: pick DNS/TCP, click child node, then click parent (Relay/Hub).
- Top bar: Compute, Data, Credits, upkeep, and goal progress.
- Right-click: cancel / remove.
- Visuals: dark background, neon shapes for nodes, moving dots for packets.

## MVP simplifications (to revisit)

These are deliberate first-cut shortcuts, faithful to the agreed rules but
simpler; noted here so they are not mistaken for the final design:

- Build cost is paid instantly from the Hub stock. **Construction-over-time
  delivered through tunnels** is deferred.
- Tunnel upkeep and starvation are handled as one **global** Hub pool /
  slow-factor rather than per-branch.
- Tunnel load/loss is evaluated per tick from the tree (subtree production vs
  capacity) and applied to each packet as it enters a tunnel, rather than by
  measuring the packets already inside it.

## Zones & structures added (0.1.7–0.1.8)

- Zones: **The Registry** (supply chain → Poisoned Package, big Cycles),
  **The Feeds** (social/ad → Scraper Botnet, bulk Intel), **Server Farms**
  (cloud → Cloud Cryptojacker, heavy Cycles).
- **Intel collectors** (Phishing Kit, Scraper Botnet) show a coverage ring —
  they sweep an area (`INTEL_RANGE` tiles); place them to blanket the zone.
- Every structure/tunnel/resource uses one **shared glyph set** (`glyphs.gd`) so
  the map, the build list and the legend match: IoT device variety (camera /
  router / fridge / DVR), npm crate, server rack, envelope, leaked-list, card,
  market diamond, onion rings; packets are **bolt = Cycles, eye = Intel,
  coin = Cash**.

## Selection, removal, on/off, flow limit (0.1.8)

- Click a **structure or tunnel** to select it (pulsing highlight + info panel).
  Remove with the **Dismantle** button, the **Delete** key, or right-click to
  clear. Dismantling a tunnel detaches just that link.
- Each structure has an **Enable/Disable** toggle (stops production + upkeep,
  drawn dimmed with "OFF") and producers have an **output limit** (0–100% in 25%
  steps) — throttle a source to stop overloading its tunnel.
- **Overload is recoverable**: loss is capped (~85%), so an overloaded tunnel
  still carries ~15%; the tunnel shows `OVERLOAD -X%`, a top banner warns, and
  the info panel suggests the fix. All of enabled/limit state is saved.

## Progression pipeline (0.2.0)

The grass→armor depth, cyberspace edition. Five resources now flow:

```
Mirai/Package/Cryptojacker ─▶ Cycles (power; runs everything)
Phishing/Scraper ─▶ Intel ─┬─[Darknet Market]─▶ Cash
                           └─[Exploit Forge]──▶ Tools ─▶ breach ICE
Magecart Skimmer ─▶ Crypto ─[Crypto Mixer]────▶ Cash (the win)
```

- **Processors** (`CONV` table) pull a stored resource from C2, convert it, and
  send the product back as real packets: **Darknet Market** (Intel→Cash),
  **Exploit Forge** (Intel→Tools, burns Cycles), **Crypto Mixer** (Crypto→Cash).
- **ICE**: rich zones carry an ICE tier (The Exchange = tier 1). Building there
  **consumes Tools** to breach and spikes **Trace**. Deeper ICE zones later.
- **Trace** (0–100): rises from live **Reverse Shells** (loud) and breaches,
  cools over time. Above 80 ("hot") ICE throttles every tunnel 20% until it
  cools — pressure, not a dead end. Shown in the top bar and Stats.
- Packets: **Cycles = bolt, Intel = eye, Crypto = hexagon, Tools = key,
  Cash = coin.**

## Linking depth (0.2.2)

- **Protocols** (tunnel variety): **DNS** (cap 3, silent, cheap), **VPN** (cap 6,
  *cools* Trace), **Reverse Shell/TCP** (cap 10, loud), **HTTP/2 Flood** (cap 16,
  pricey), **Onion Route/Proxy** (cap 5, reaches **16 cells** vs 10, costs a
  Tool). Each has its own capacity, upkeep, max length and Trace noise.
- **C2 commands**: **Overclock** (spend Cycles → a structure runs at 2× for 20s,
  pulsing 2× ring) and **DDoS Smokescreen** (Cycles + Tools → Trace scrubbed to
  0). In the Build tab under C2 COMMANDS.
- **Topology bonus**: a **Tor Relay** aggregating several branches lifts its
  outgoing trunk capacity (+1 per extra branch, up to +4) — reward for merging.
- Trace now sums every live tunnel's protocol noise (VPN negative) minus decay,
  plus breach spikes.

## Vision / fog of war (0.2.3)

- Every structure reveals a radius of the city (`VISION`; C2 big, relays extend
  reach). The map outside coverage is **fogged** — you can only build where you
  have vision, so expansion means pushing coverage toward new districts. Your own
  structures/tunnels always draw on top of fog.

## Tunnels (0.2.3 changes)

- Max length is now **255 cells** — distance is limited by **packet loss**
  (`TUNNEL_LOSS` per cell; Proxy/HTTP travel best), upkeep per cell, and latency,
  not a hard cap. Overload loss stacks on top.
- A* pathfinding is bounded (20k expansions) for long routes.
- **Mouse panning**: middle-drag or right-drag moves the map (a right *click*
  without dragging still cancels/clears). WASD still works.
- Clicking a tunnel now uses a forgiving proximity hit-test (fixes the "can't
  click the tunnel" bug). Also fixed: all newer structures/tunnels were
  unbuildable because the click router only knew the original types.
- Build list: bigger entries, **3D neon-block icons** matching the map, grouped
  sections with separators.

## Research tech tree (0.3.0)

- New resource **Research** (RP), produced by the **Research Lab** (Intel +
  Cycles → Research). Spend RP in the **Tech tab** to unlock facilities.
- Tree: Supply-Chain Attacks → Poisoned Package, Cloud Cryptojacking → Cryptojacker,
  Crypto Laundering → Mixer, Exploit Development → Forge, Onion Routing → Proxy,
  HTTP/2 Flooding → HTTP (needs Exploit Development). Base tools (Mirai, Phishing,
  Skimmer, Market, Lab, Relay, DNS/VPN/Reverse Shell) are available from start;
  locked tools are greyed in the build list until researched.

## More network/placement (0.3.0)

- **Per-tunnel consumption** (#5): a processor can't pull faster than its tunnel's
  capacity.
- **Building-only placement** (#2/#3): structures must sit on city building blocks
  (majority of footprint), not empty streets/plazas — plus vision + district.
- **4 lanes per cell** (#7): up to 4 tunnels share a cell, drawn as offset
  parallel lanes.
- **Building glow scales with height** — taller/richer buildings glow more,
  signalling how much they can yield.

## 0.3.1 — UI fixes, districts, city life

- **Info panel rebuilt** with explicit anchoring (fixes buttons not clicking and
  the panel overlapping the map): Dismantle / Disable / Output ± pinned
  bottom-right, labels set to ignore mouse, `clip_contents` on.
- **Build menu sub-tabs**: Hacks / Proc / Links / Cmds categories within the
  Build tab (locked tools still greyed by research).
- **More, smaller districts** scattered across the map (more Voronoi seeds) so
  resources are never far.
- **Tor Relay** purpose clarified + bigger vision (15): the merge point that
  aggregates thin links into a fat trunk (+capacity per branch) and scouts ahead.
- **City is alive** (XCOM-Apocalypse vibe): tall towers get **setback tiers +
  antennas with blinking warning lights**, **twinkling windows**, scrolling
  billboards in The Feeds, and **data motes drifting along the avenues**.
- Buildings have **varied silhouettes** by height/district (towers vs low racks).

## 0.3.3 — real-looking background city

- The **map's background buildings** are now real 3D structures (`_bg_building`):
  stacked setback tiers, shaded front/right/top faces, sparse lit windows, and a
  **rooftop per district** (`DIST_STYLE`) — residential domes, office flats, bank
  crowns (Exchange), server vents (Farms), media billboards (Feeds), the Spire's
  command spire, slum awnings. The whole skyline reads like a night city.
- Detail scales with zoom: full buildings up close, shaded tiers at mid zoom,
  flat lit footprints when zoomed far (keeps it fast).

## 0.3.2 — real cyberspace buildings & resource-coloured ground

- **District ground colour now matches the resource** you can place there:
  **green = Cycles** (Sprawl / Registry / Farms), **blue = Intel** (Glasshouse /
  Feeds), **orange = Crypto** (Exchange), cyan = Spire, grey = Undercity. So the
  ground tells you where each producer goes.
- **Structures are real-looking cyberspace buildings** (`STRUCT` table +
  `_prism`/`_roof`): stacked setback **tiers**, shaded front/right/top faces,
  **lit twinkling window grids**, and a **distinct rooftop per type** — C2 command
  spire with rotating ring, office towers (Phishing), bank crown (Skimmer),
  server vents (Cryptojacker), broadcast mast (Scraper/Relay), research dome
  (Lab), ziggurat (Package), chimney (Forge), tank (Mixer), market awning (Fence).

## 0.5.0–0.5.4 — Fixed panel, placement, proxy, coverage, antagonist & gap-analysis pass

- **0.5.0** fixed-width side panel (plain Panel + clip_text on buttons; never PanelContainer/
  clip_contents — those resize it or break button clicks); Mirai Dropper builds on any Cycles
  (green) ground; vision circle around every structure; keyboard shortcuts (Del/E/O/−/+).
- **0.5.1** **Proxy node** — convert any producer into a low-upkeep (×0.4) router that stops
  producing, extends reach and merges links (renamed from Tor Relay); cursor shows mode
  (crosshair building / hand clickable).
- **0.5.2** **coverage-based production** (output ×0.5–2.5 by nearby city buildings covered);
  **overload fix** — only real over-capacity reads "OVERLOADED"; a long link's normal bleed now
  reads "−% (distance)"; Esc cancels the armed tool.
- **0.5.3** **ICE Sweep antagonist** — when Trace/Notoriety build, a telegraphed tracer walks
  your tunnels toward C2 on an accelerating countdown (red path + marker + warning banner),
  **quarantining** nodes (recoverable) and only **blacking out** C2 (−25 Cash, ~4s pause), never
  destroying. Counter by going quiet, rerouting, **dismantling the node it's on**, or DDoS. A
  non-decaying Notoriety drives escalation so you can't idle it out. Win screen shows a run
  scorecard (time / peak Cash-s / packets / peak Trace / nodes).
- **0.5.4** clickable **alerts strip** (overloaded / offline / starved / Trace-critical → jump to
  the problem); **hover tooltips** on build entries.
- Design docs added: `GAME_DESIGN.md` (full GDD) and `GAP_ANALYSIS.md` (6-agent genre gap study).

## 0.4.8 — Left-panel UI, edge-pan & route highlight

- **Selection info moved to the LEFT panel (#6):** clicking a structure/tunnel now
  shows its details + **Dismantle / Disable / ⚡ Overclock / Output −/+** in the left
  panel, and the **bottom panel is removed entirely**. This also fixes the bug where
  those buttons weren't clickable in the old bottom bar.
- **Cmds sub-tab removed (#4):** Overclock is now a context action on a selected
  producer; DDoS Smokescreen moved to the Stats tab; Cancel is right-click.
- **Edge-pan (#3):** push the mouse to a screen edge to scroll the map — no clicking.
- **Route highlight (#7):** selecting a structure highlights its whole packet route
  back to C2 in yellow.

*Next:* the Tech list doesn't fit the panel (#1/#2) — moving it to a dedicated tree
view; and clarifying the routing model (#5).

## 0.4.7 — Mesh connections, overload, collapsing dashboard & more perf

- **Connect any node to any node (#1/#4):** a tunnel can now lead to *any* structure,
  not just the C2 / a Relay / a Market. You can chain producers together (IOT → IOT →
  C2) and fan many links into one node; data always flows on toward C2 (shortest tree
  path). Loops are prevented — you can't link into your own downstream.
- **Per-node overload (#5):** every node has a throughput ceiling (C2 ∞, Relay 20,
  converters 12, producers 6 pkt/s) and, past 4 incoming links, starts to choke. A node
  carrying more than it can relay drops the excess (congestion loss, shown as
  ▲ OVERLOAD on the tunnel). Build Relays / fatter tunnels to carry big fan-ins.
- **Auto-collapsing dashboard (#2):** the bottom panel shrinks to a slim bar showing the
  live "→ Next" step when nothing is selected (reclaiming the map), and expands on
  select / tool-arm. Body text no longer overflows the action buttons.
- **Performance (#6):** the tunnel-route A* preview is cached (was a full search every
  frame while dragging a link); the fog/vision list is cached (rebuilt only when nodes
  change); packets force cheap dots above 220 in flight.

*Note:* each node still has a single uplink (its outgoing tunnel), so "many connections"
means many **incoming** links aggregated toward C2. Strict road routing can occasionally
fail to connect very tightly-packed nodes — space them out or route through a Relay.

## 0.4.6 — Roads, mouse control & UI fixes

- **Tunnels follow the streets (#3):** routing is now orthogonal and runs only on
  street/open cells, so links trace the road grid and turn at 90° instead of cutting
  straight through buildings.
- **Mouse map control:** left-click-drag now pans the map (click without dragging
  still selects/places); middle- and right-drag still pan too.
- **Fixed-width side panel:** the control panel is a fixed Panel now, so switching
  Build/Tech/Stats/Menu no longer resizes it.
- **Solid top bar:** the resource bar is opaque (was semi-transparent) and now also
  backs the resource-icon / net-rate line.
- **Bigger text** across the UI for readability.
- **Minimap performance:** the static district grid is baked to a texture and the
  minimap only repaints when the camera or node set changes (was 400 draws/frame).

*In progress:* the mesh connection system (#1/#4/#5 — connect any node to any node,
many links, per-node overload/congestion) is a routing-core rewrite being built next;
road routing above is the shared foundation.

## 0.4.4 — Placement by resource/colour (bug fix)

- **Producers now place on any district of their resource/colour, not one exact
  district.** Previously a Phishing Kit could *only* go in Glasshouse Row even though
  The Feeds is also Intel/blue (and The Feeds' only producer, the Scraper, is
  research-locked) — so blue ground that looked buildable was refused. Now any Intel
  producer sits on any Intel (blue) ground, any Cycles producer on any Cycles ground,
  etc. District slot capacity counts all same-resource producers. Clearer error naming
  the valid districts.

## 0.4.3 — Economic tension (Phase 2 of the panel roadmap)

Kills the old "spam one producer into one Darknet Market and watch Cash climb"
dominant strategy and gives Cash a reason to exist:

- **Diminishing Darknet Market returns:** a market saturates as you bank Cash —
  the sale price per Intel is `clamp(1 − Cash/2000, 0.3, 1.0)`, so it's 1:1 at the
  start, ½ by the 1000-Cash goal, floored at 0.3. The sprint slows near the line,
  reinvesting Cash (which lowers your balance) keeps prices high, and diversifying
  into Crypto → Mixer becomes worthwhile. Applies to both the Market pass-through
  sale and the Mixer.
- **Cash sinks on advanced structures:** Poisoned Package +40, Cloud Cryptojacker
  +60, Magecart Skimmer +30, Exploit Forge +30, Crypto Mixer +50 Cash — so Cash is
  a currency you spend to grow, not just a score you watch.
- **Phishing vs Scraper is now a real choice:** Phishing Kit is a cheap early
  starter (20 → **12 Cycles**), the tech-gated Scraper Botnet is denser but noisier
  (2.0 → **1.5 Intel/s**).
- **Live signpost:** the C2 Console shows a context "→ Next:" step that advances with
  your state (build a Phishing Kit → build a Darknet Market → route Intel → scale /
  diversify), so the core loop is always in front of you.
- Removed dead constants (`FENCE_CONV`, `FENCE_RATE`, `TRACE_PER_TCP`).

**Still queued:** Phase 3 antagonist (telegraphed, pause-safe ICE "sweeps" driven by
Trace; graded Trace penalty; staged tier-gated objectives ending at The Spire), plus
per-instance scaling build cost, deeper UI relayout, and colour-blind structure/minimap palettes.

## 0.4.2 — Readability, Accessibility & Performance pass (10-agent review)

Driven by a fleet of specialist review agents (player-review research for
Factorio / K&M / hacking games + code audits for UX, accessibility, performance,
onboarding, visual readability and economy). This release lands the low-risk,
high-consensus items:

- **Performance (the lag fix):** the static night-city (grid + background
  buildings + district edges) is now **baked once into a dedicated layer** instead
  of being re-drawn every frame, and background buildings were simplified to a
  single shaded prism. Placed structures gained **zoom LOD** — the creep tendrils,
  orbiting dots and lit window grids are skipped when zoomed out.
- **Accessible packets:** resource packets are now drawn as **distinct shape
  pictograms** (bolt = Cycles, eye = Intel, coin = Cash, hexagon = Crypto, …) so
  identity never rides on colour alone; the Matrix glyph flicker was calmed (5→2.5 Hz).
- **Figure-ground:** your structures now get a **dark knockout moat** and an
  **always-on neon keyline**, tunnels get a **dark casing**, and the city backdrop
  is **dimmed a little for everyone** (more under High Contrast) so your botnet
  stands out against the neon city.
- **Accessibility polish:** High Contrast now also **thickens tunnels and enlarges
  packets**; **Text size** reaches **200%** and now scales in-world labels (tunnels,
  districts, tags); the last un-gated animations (window twinkle, tendrils, the
  packet-loss flash) now respect **Reduced motion**.
- **Onboarding:** the idle **C2 Console** now explains the core loop — *Cash is sold,
  not mined: steal Intel → tunnel to C2 → sell at a Darknet Market*; the **Scraper
  Botnet** is now unlockable via a new "Web-Scraping Botnet" tech (was a dead,
  never-buildable list entry); the Magecart Skimmer is recoloured to match its Crypto output.

**Queued for next pass:** economy tension (diminishing Darknet Market returns,
scaling build cost, Cash sinks, graded Trace), deeper UI relayout (de-stacked HUD
rows, armed-tool state, collapsible info panel), colour-blind structure/minimap
palette, vision-list caching and A* preview throttling.

## 0.4.0 — Accessibility & Clarity (Phase 1 of the panel roadmap)

- **Settings · Accessibility** menu (Menu tab + pause overlay), persisted to
  `user://rim_settings.json` via the `Settings` autoload: **Reduced motion**
  (stops matrix rain, twinkle, tendrils, motes, rotating/blinking roofs, pulses →
  packets become dots), **Colour-blind palette** (Okabe–Ito for all six resources
  and tunnel health), **High contrast** (dims the city backdrop, thickens
  structure edges), **Text size** (100/125/150%), **Packet style** (Code/Dots).
- **Status by symbol, not colour alone**: tunnel health labels now read ✓ / ▲
  OVERLOAD / ✕ CONGESTED alongside the colour.
- **Net-rate HUD**: a second line shows Cycles/Intel/Cash **net ±/s** plus **ETA**
  to the Cash goal (sampled each second).
- **Pause-to-plan**: you can build, link and inspect while paused (sim frozen).
- **Undo** (Ctrl+Z): reverts the last place / tunnel / patch / dismantle and
  refunds, up to 20 steps.

## Interface (Knights & Merchants-style)

- **Left control panel**: a minimap (click/drag to move the camera) above three
  tabs — **Build** (the hack list with colour chips, the two tunnels, Cancel),
  **Stats** (botnet status: resources, structures, tunnels, packets in transit,
  upkeep/feed, map seed) and **Menu** (save, load, main menu, quit).
- **Bottom info panel**: describes whatever is relevant — the selected structure
  (homage, zone, footprint, output, tunnel out and latency, online/offline, a
  **Dismantle** button), the active tool (homage + live cost/latency hint), or
  a hovered hack. Status line underneath.
- **Top bar**: CPU, Data, Credits, packets in transit, upkeep & feed, goal
  progress, packet legend.
- Left-click with no tool **selects** a structure; right-click cancels / clears.
  **Esc** pauses and opens the menu overlay. Reaching the goal shows a victory
  overlay (keep playing or return to the menu).

## Menu, save & load

- The game starts at a **main menu**: New Game (fresh seed → generated map),
  Continue (enabled when a save exists), Quit.
- **Save/Load** writes `user://rim_save.json`: seed, zones, every structure (with
  tunnel endpoints), resources, packets in flight, camera. Loading restores the
  exact state. Available from the Menu tab and the Esc overlay.

## Visual style

Cyberspace, not a home lab: a dark grid with neon zones. Structures are
**holograms** — a pulsing ground glow, a wireframe prism with a translucent top
face and a sweeping scanline, and a vector glyph for the kind (C2 data-core
rings with rotating ticks and light columns, Mirai camera lens, npm crate,
phishing hook, payment card, market diamond, Tor onion rings). Tunnels attach at
ground level; packets are glowing shapes on the wires. The window starts
maximized and the interface uses large type.
