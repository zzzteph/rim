# RIM / BOTNET — build & run instructions

A single-scene 2D strategy game made with **Godot 4.7.2** in **GDScript**. No external
dependencies, no addons, no C#. Everything is plain Godot. These instructions are written
to be handed to another developer or LLM so they can build, run, and ship the game.

---

## 1. What it is

- **Engine:** Godot **4.7.2** (stable). Renderer: **GL Compatibility** (OpenGL ES 3 / WebGL2),
  declared in `project.godot` (`config/features=("4.7", "GL Compatibility")`).
- **Language:** GDScript only.
- **Main scene:** `res://scenes/botnet_proto.tscn` (set as `run/main_scene` in `project.godot`).
  Its whole behaviour lives in `scripts/botnet_proto.gd`.
- **Tunables / content:** `scripts/botnet_cfg/*.gd` — factions, town, building types, buildings,
  cards, and all balance numbers. The main script reads them through aliases and never hard-codes
  values. **These are `const`s read at load time: after editing a cfg, restart the scene.**
- **Data:** `data/*.json` is bundled into exports (see the `include_filter` in `export_presets.cfg`).
- **Version:** `X.Y.Z`, kept identical in `GAME_VERSION` (`scripts/botnet_proto.gd`, sent with
  feedback) and `config/version` (`project.godot`). **Every update bumps it:** Z+1; when Z
  would reach 10 it wraps to 0 and Y+1; when Y would reach 10 it wraps to 0 and X+1
  (0.1.9 → 0.2.0, 0.9.9 → 1.0.0).
- **Fonts:** The interface bundles JetBrains Mono Regular/Bold with Noto Sans Symbols for
  circled digits and the queue pause mark. No installed system fonts are required. Source
  versions and hashes are recorded in `assets/fonts/README.md`; both SIL Open Font License
  files in that directory are included in the Windows and Web exports.

### Repo layout
```
project.godot                 # Godot project file; main scene = scenes/botnet_proto.tscn
export_presets.cfg            # "Windows Desktop" and "Web" export presets
scenes/botnet_proto.tscn      # the game (a Control running scripts/botnet_proto.gd)
scenes/menu.tscn              # legacy title scene (not the main scene; kept for reference)
scripts/botnet_proto.gd       # ALL game logic + UI (one big script)
scripts/botnet_cfg/*.gd       # factions.gd, town.gd, types.gd, buildings.gd, cards.gd, tuning.gd
data/*.json                   # bundled data
.github/workflows/web.yml     # CI: export to web + publish to GitHub Pages on push to main
```

---

## 2. Get Godot 4.7.2

Download the editor for your OS from the official builds:
`https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable`

You need two things to make **exports**:
1. The **editor** binary.
2. The matching **export templates** (`Godot_v4.7.2-stable_export_templates.tpz`), installed via
   the editor (*Editor → Manage Export Templates → Install from file*) or placed at:
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
   - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`

> On Windows there are two editor exes: the normal one and a `..._console.exe`. Use the
> **console** build when running headless so you see stdout (prints, test results).

---

## 3. Run it

### In the editor
Open `project.godot` in Godot 4.7.2 and press **F5** (Play). The game boots on the start menu.

### From the command line (desktop)
```bash
# Linux/macOS
godot --path . res://scenes/botnet_proto.tscn
# Windows (use the console build to see output)
"Godot_v4.7.2-stable_win64_console.exe" --path . res://scenes/botnet_proto.tscn
```

### Headless (for CI, parse-checks, automated tests, rendering)
```bash
# Parse-check / smoke-run: if the script has errors they print as "SCRIPT ERROR" / "Parse Error".
godot --headless --path . res://scenes/botnet_proto.tscn
```
The shutdown lines about leaked RIDs / "Unreferenced static string" / VariantPools are normal
engine-exit noise, **not** script errors. Only `SCRIPT ERROR` / `Parse Error` matter.

Run the automated mechanics and layout checks before exporting:
```bash
godot --headless --path . --script tests/economy_test.gd     # cycles, storage, stations, caps, research, Firewall sockets, capture
godot --headless --path . --script tests/theft_test.gd       # Phishing, Packet siphon, Vault raid: the loot reaches home
godot --headless --path . --script tests/conflict_test.gd    # Patch recovery, DDoS on a main node, inheritance, Sabotage on workers, loot last, Worm
godot --headless --path . --script tests/capture_test.gd     # deterministic capture: outcomes, timing, same-step order, Worm stages
godot --headless --path . --script tests/onboarding_test.gd  # first run: Learn and Skirmish open at once; menu is navigation only
godot --headless --path . --script tests/menu_test.gd        # menus: containment, equal insets, Help round trips, glyphs, seed-picked layout
godot --headless --path . --script tests/objective_test.gd   # the majority objective: one source, HUD lines, hold countdown and reset
godot --headless --path . --script tests/accounting_test.gd  # economic ledger: flows reconcile with banks, measured rates, losses
godot --headless --path . --script tests/diagnosis_test.gd   # host diagnoses: preview = real cycle, statuses, route home, panel order
godot --headless --path . --script tests/preview_test.gd     # target preview: legality, route/arrival, execution, fog-safe areas, dated Recon
godot --headless --path . --script tests/recon_test.gd       # no security levels; Recon 50%, attacks 50%/25%, seeded dice, counters first
godot --headless --path . --script tests/logistics_test.gd   # workers: supply round trip, conservation, sockets on arrival, held / lost packets
godot --headless --path . --script tests/workers_test.gd     # 2 workers per station, identities, replacement, capture, local use, escrow, fairness
godot --headless --path . --script tests/queue_test.gd       # the four-place FIFO queue: capacity, order, waiting head, full hand, pause, cancel
godot --headless --path . --script tests/fog_test.gd         # unscouted hosts reveal nothing; Recon reveals, expiry collapses; AI uses Recon
godot --headless --path . --script tests/host_panel_test.gd  # host panels: facts, slot rows, the slot chooser, socket seating, no launch controls, no stale controls
godot --headless --path . --script tests/cards_ui_test.gd    # cards strip and drawer, selection and launch, research bar, queue strip, + Queue
godot --headless --path . --script tests/forecast_test.gd    # income forecast vs a steady simulation; workers, routes, starvation, caps
godot --headless --path . --script tests/net_forecast_test.gd # the HUD's net: income less research, cards, building, upkeep vs the bank
godot --headless --path . --script tests/events_test.gd      # event history: priorities, one entry per condition, outcomes, strip, history
godot --headless --path . --script tests/sim_smoke_test.gd   # 90 s four-faction match (3 AIs): no error, banks stay sane
godot --headless --path . --script tests/ai_test.gd          # AIs research, manufacture and capture ground (not idle)
godot --headless --path . --script tests/ai_rules_test.gd    # AI turn-taking: cut-off projects, Research host (4+ slots), boxed-in research, retools
godot --headless --path . --script tests/campaign_test.gd    # plays Learn as one session: no rebuilds, no waits, resume

Learn (0.6.9): lesson 4's rival steps say who acted (“NYX (red) …”), never pause, and point at a host to act on (the
“station_spot” role: the relay while it has a free slot, else your nearest host with one; `_camp_fill` names it). In
open play the banner shrinks after `CAMP_OPEN_BANNER_SECS` to a `CAMP_STRIP_H` line with the goal instead of vanishing.
godot --headless --path . --script tests/mp_lockstep_test.gd # two screens, same command stream: identical every turn
godot --headless --path . --script tests/text_fit_test.gd    # every text fits with a margin; no overlaps; whole sentences
godot --headless --path . --script tests/botnet_help_test.gd # Help navigation + layout at 1280x720 and 1366x768
```
Use the console executable above on Windows. Each check exits nonzero on failure.
To capture the Help suite's rendered previews, omit `--headless` and append
`-- --capture`; images are written to `review/visual_help/`.
These checks cover scripted behavior and layout; human usability testing is still pending. The Milestone A
tasks for 5–8 first-time players, with how to run and record them, are in **`docs/PLAYTEST.md`**.

> The pre-redesign suites (assault, takeover, production-cost, usability, …) tested
> the old bot-army mechanics and were removed in the 0.4.0 research–manufacture–deliver
> redesign; the economy, AI, campaign and lockstep suites above are their replacements.

Design reference: **`docs/DESIGN.md`** describes the whole game as it runs (match flow, map, economy
formulas, logistics, every card, defence, winning, the AI, multiplayer, the interface, derived numbers and
leftover config); `docs/design.html` is the same document as a styled page, and `docs/rim_constants.json`
holds every constant. All three are generated, so they never drift from the numbers in the game:

```
godot --headless --path . --script res://docs/tools/dump_constants.gd   # refresh rim_constants.json
python3 docs/tools/build_design.py                                     # rebuild design.html and DESIGN.md (needs pandoc)
```

Prices and constants come from `scripts/botnet_cfg/`; the text describing behaviour lives in
`docs/tools/design.body.html` and the card tables in `docs/tools/build_design.py`, and is kept true to the
code by hand: change a rule, update its description there and rebuild.

Economy (research–manufacture–deliver; 0.6.2 rates). There are four resources (`RES` in
tuning.gd): **Intel**, **Crypto**, **Credentials**, **Research**. Resources are only
spendable once they reach your **main node** (your rig). The main node itself only trickles one of
every resource every 6 s (`MAIN_INCOME`, 10 a minute), so a network that builds nothing stalls: the economy is
what you build. Every held host runs one **production cycle** every `PROD_CYCLE` (6) s on its own
phase (`_tick_production` → `_run_cycle`). Every producer makes **1 unit a cycle** of its own resource
(10 a minute; the host type's multiplier scales it; 0.6.18: the flow doubled from 12 s cycles, measured so workers are rarely free — the smart scripted player's workers idle 3% of the time instead of 31%, with the same pace — and every price, bank cap, start stock, store and theft haul doubled with it) with **no input** (0.6.12: the Crypto miner, Credential harvester
and Research lab are producers like the Intel harvester; their `use` is empty and `CONVERT_ORDER` only keeps the
code path for a future converter). Each Firewall eats its 1 Intel of upkeep: on a remote host from this cycle's own
Intel harvest first, which never takes storage room, then from what is stored there (0.6.14, `_cycle_split`, the one
rule `_run_cycle`, `_cycle_preview` and the plans share). A remote host keeps what it made in a
**storage** of `STORE_CAP` (20) units, all resources together (`hosts[i].store`, by beneficiary); a storage that
cannot hold a whole cycle gives every producer the same share (`_cycle_share`, from `_store_room`: never the room held
for cargo on its way), and full storage stops them. An export's last whole unit also takes the crumbs such a shared
cycle leaves when the host's plan spares them and the bank has room (`_amount`, the request's exact `max`, lowered by
every pickup of the same pass like `qty`, 0.6.15); a phished host's plan counts the thief's harvest only past your own
stock there, so your Intel keeps its Firewall's upkeep (as `_cycle_split`); a Vault raid caps the claims on what it
took (`_cap_claims`); crumbs of a
material nothing on the host makes any more leave on their own once the host is not short of room. Production uses only what has **arrived** on the host. Each bank has a
cap of `BASE_CAP[res]` plus `CAP_PER_PRODUCER` for every producer of that resource you own (`_cap`);
anything on its way reserves its room at the destination (`incoming` for a bank, `hosts[i].inbound` for a
host's storage), so nothing is credited early and nothing overfills.

Workers and logistics (0.6.2, the `LOGISTICS` block in botnet_proto.gd). There is no Bots bank. Every finished,
operational **Bot station** provides exactly `WORKERS_PER_STATION` (2) reusable **workers** with stable ids
(`workers`, `hosts[i].teams` per station slot and installation generation); the main node starts with its station's
two. A worker carries `WORKER_CARRY` (1) unit per leg and is never consumed by a delivery. A worker lost while its
station survives (cargo lost on a cut route) is replaced after `WORKER_REPLACE` (5) s of operation
(`_tick_teams`); a demolished or replaced station's workers **retire** after the leg they are on; **capture**
destroys every worker of the captured host's stations, including those away (`_kill_home_workers`), and the former
owner gets one event ("Host 7 lost to NYX — 2 station workers destroyed."). States: available, collecting,
carrying, blocked, heading home (`_worker_state`; 0.6.16: "available" means free wherever the worker is).

Demand is automatic (`_host_plan`, `_open_requests`). Installations use what is on their host first; a host asks
only for its Firewalls' upkeep for the next cycle (after the Intel it makes itself) and the bills of its construction
(the converter-bundle and `plan_rr` paths stay for a future converter). What is not
needed for the next cycle is **surplus** and goes to the main node. **Workers go where they are needed, from
wherever they are** (0.6.16, `_tick_logistics` → `_dispatch`, event-driven with a 0.25 s fallback): a job moves one
unit from a **source** to a **destination** (`_start_haul`). A project's material or a Firewall's upkeep comes from
the nearest place that can spare it — your bank at the main node, a host's spare stock (its plan's `export`), your
own salvage — **straight to the site** (`_best_delivery`: the source and free worker that get a unit there soonest,
`_nearest_worker`, `_leg_time`); a host's surplus, your salvage and stolen goods go to your bank (`_best_haul`). A
worker first travels empty to the source (`trip` "fetch", the unit claimed there: `claim`/`pclaim`, or taken from
the bank at once and put back if the job is dropped), then carries it (`trip` "carry", `_set_off_loaded`); it is
free where it delivers (`workers[wid].base`) and takes its next job from there, so a delivery to a site is usually
followed by that host's own surplus home. With nothing it can do, a worker away from the main node heads home
(`trip` "home"). New stations' workers start working where their station is. **Building comes strictly first**
(0.6.16): every free worker serves construction and upkeep while any of it can go — a Firewall's upkeep first (and,
when its host's full storage leaves no room for it, that host's surplus as urgently: `room` demands), then Bot
stations, then projects in the order given; what the main node's projects wait for that is neither in the bank nor
coming (`_build_lack`) is brought home from the hosts as building too. Then, of the same class, the surplus where a
free worker already stands (0.6.18: `_best_haul` ranks it before tightness, so a worker freed at a host carries that
host's output on instead of walking empty to the next host in turn), then the surplus of the hosts about to fill
up (`_tight_now`: its next cycle and its Firewalls' incoming upkeep would not fit, counting what workers are already
on their way to collect), the hosts in turn (`_served`, `_served_res`); stolen goods last (`_pick_rank`,
`_pick_request`). A worker that leaves a host for the main node to fetch supplies takes a unit of that host's
surplus along (0.6.18, `_ride_along`). A host that does not make all its upkeep asks for the next cycle plus `UPKEEP_KEEP` - 1 (1) more
cycles of what it lacks, in whole units beyond the next cycle, and keeps one cycle more than that, which only a nearer
host's surplus Intel fills: such a surplus goes to a Firewall host no farther from it than the main node instead of
home (`_best_haul`'s top-up). A host's surplus waits for a worker already on its way there rather than drawing
a second worker (`_arriving`: a loaded one, or, 0.6.18, one still going to a pickup whose unit goes there); a source that cannot give a whole unit is used only when none can, and then at least
`PART_MIN` (0.25) of one. Room for a Firewall's upkeep in a full storage is made as urgently as the upkeep, by only as
many workers as it needs.
`_build_owed` is the bank stock the projects the workers can reach still need (a cut-off or DDoSed site holds none);
supplies to production only get `_supply_budget` (the rest, in whole units). A collection **claims** its unit (`claim`) and the
destination holds room for what is coming (`inbound`), so two workers never take the same last unit or the same last
room. Supplies leave the bank with their worker. There is no Refill or any other supply setting: input supply is
automatic, in the background.

> **Interpretations (0.6.2):** a worker lost on a cut route with its station still standing is replaced after 5 s;
> a station whose host has no route to the main node keeps its workers waiting there (they count as "on their way",
> not free); cancelling a project during its work leaves the unworked share of its materials at the site as salvage
> (workers take it home), never back in the bank at once; every fourth assignment is a host-turn for fairness (0.6.10: while something is being built, a turn to keep production going).

Movement (`_advance_flights`, every step). Every packet — workers and every card — moves hop by hop
(`hop_i`) and is checked whenever it leaves a host: that host must still be its owner's (else it is lost
there) and not under DDoS (else it waits), and the next host must be the owner's and up, or be the
packet's end (`_end_ok`: an attack may end on a rival host; a defence card, a returning card and a worker
bound for one of your hosts need it still yours). Neutral and rival hosts are never relays (`_travel_route`,
`_attack_route`). Held packets (`blocked`, `at`) re-route every 0.5 s (`_tick_blocked`); a card held
`CARD_GIVE_UP` (20) s, or whose target is gone, turns home and is a ready copy again on arrival
(`_card_back`). **Defence cards travel too**: they leave the main node and act, or load a Firewall socket,
only on arrival (`_support_arrive`); one aimed at the main node lands at once. A card that will load holds
its socket while it travels (`socket_res`), so competing deliveries never overbook a Firewall.

Economic accounting (Milestone A). Every bank movement goes through `_add_bank` (income, or loss to the
cap) or `_spend` (spending), each with a **cause** — trickle, production, delivered, stolen, returned,
refunds, buildings, manufacturing, research, supply, converters, upkeep; cargo whose route breaks and
storage drained by a Packet siphon are recorded as lost (`cargo`, `siphoned`), and each delivery also
records its source host (`from:<host>`). `_ledger_add` keeps 1-s buckets over the last `LEDGER_SECS` (30) s
per botnet; `_econ_rates(fac, res)` turns them into per-minute received/spent/lost rates by cause, and
`_incoming_eta` reports cargo on the road. These measured rates are shown only as **historical** (the Economy
overview and tooltips say "Historical, last 30 s"). The ledger is presentation only: it is not part of the
lockstep fingerprint (`_mp_hash`).

Income forecast (round B). The income forecast is what will reach the
main node's bank per minute with the network as it stands (`_forecast`, recomputed every 0.5 s or after any
command); since 0.6.17 the HUD shows it net of what the bank pays out (below). It is worked out from the network, never extrapolated from early ledger events: the main node's
trickle and buildings (with their bank inputs), then each host whose output is yours (`_fc_cycle`: its active
producers, inputs made there or supplied by workers from a shared budget — plenty while the bank holds
a buffer, else what the main node itself brings in — Firewall upkeep), limited by its route
home, by your workers' trips dealt as the dispatcher deals them (`_fc_split`: supplies and Firewall upkeep strictly
first, then the hosts' trips even out; short of workers, they make as many trips a minute as their time allows;
0.6.18: Intel a host gives a neighbouring Firewall rides that host's own trips, shared by every host that may give it
in proportion to the Intel each one's trips move, and the worker who brings it carries the Firewall host's output
home — one leg, not a round trip), by its storage's room for supplies
(`_fc_accepts`: when its plan is limited, only the share of one cycle's inputs the plan funds — 0.6.8), and by the
bank's room. A Firewall on a host you phish eats your Intel once the owner's stock there is gone; nothing comes from
a phished host whose storage is full of the owner's stock ("storage full at …"), nor from any host while your main
node is under DDoS. "Not enough workers" names each material the shortage cuts, even to nothing, and never one it
frees (0.6.8). The full-bank test is once per material, not per host (it walks every host's producers). A host the trips cannot keep up with
stays full, so it makes only what leaves, every producer the same share (`_fc_throttled` scales them together).
The tooltip and the Economy overview name the sources and what holds the forecast back ("not enough
workers", "no route home from …", "your bank is full"), and each bank's tooltip says how much is stored at hosts, in
transit (`_where_is`).

Net forecast (0.6.17). The HUD's second line under each material is ONE signed number a minute: the income forecast
less what the bank pays out in the next minute, as things stand (`_forecast` returns `use: {res: {what: units}}`, `net`
and `full` beside `rate`). `_bank_use(fac)` (it only reads) adds research while it runs and is not paused (it pays as it
progresses: `_research_cost` × the part of the next minute it still runs / `_research_time`), the card queue while it
runs and is not paused (each copy pays its `_recipe_cost` once, when it starts: the price of every copy that starts
within the next minute — not the copy being made, already paid, and none while a full Ready inventory keeps it from
starting — so one Recon counts 8 Intel, not 8 over its 3 s), building (`_build_owed`: what the projects still need from
the bank, all of it within the next minute; a project the workers cannot reach holds nothing) and the main node's
Firewalls' upkeep; `_forecast_now` adds what the bank sends to remote hosts (a Firewall's upkeep on a host that does not
make enough Intel), as far as the workers' trips bring it. A full bank takes in again only what is used from it that the
main node's own income (trickle and buildings) does not refill: then a remote host's output of it is counted; while the
main node covers the use, remote output waits on its host and clogs it, as with a full bank nothing uses. It shows
"full" only while its income keeps up with what is used (`full`: what is not used is lost), else the negative net. `_hud_rate` shows "+N/min" (green), "−N/min" (red, a minus
sign) or "0/min" (dim); `_forecast_lines` (the tooltip, and the Economy overview under each bank's "net …" heading)
lists the income and its sources, each use in the next minute ("Used per minute: research 14, card queue 48, …"), the net, what
holds the income back, and when the net is negative whether the bank is empty or runs empty within the minute. `tests/net_forecast_test.gd` checks the
net against the next 60 s of play with research and a card queue running (each bank within 20%) and with one Recon, the
next-minute rules (a paid copy, three of four 26 s copies, a nearly full Ready inventory, research with 10 s left), a
network that uses nothing (net = income, 120 s), each use on its own (paused research and queue, a full Ready inventory,
a project, an unreachable one, main-node and supplied Firewalls), full banks (also a full Intel bank a main-node Firewall
uses while a remote host's Intel clogs its storage), the HUD's sign and colour, the tooltip's order and the overview. The **Workers** column is the worker population, not an income:
"Workers N" over "B busy · F free" (or "· K blocked"). `tests/forecast_test.gd` checks the forecast against 120 s of
steady play and against no workers (including hosts whose Firewall runs only on supplied upkeep), a cut route, upkeep
supplied or starved, a full bank, a File server whose storage cannot hold a whole cycle (its producers share the room), a phished host with a
Firewall and one with a full storage, and a main node under DDoS, and, with two workers for six hosts, each material
within 30% of what arrives.

Host panels (0.6.3; since reworked around the slot chooser). Your host's panel is its name, then **its facts**
(`HostInfo`, `HOST_INFO_H` 58 px, from `_host_info_view`: type and owner, slots used/total, its storage as resource icons
with their amounts and x/10 — at your main node its bank — and the Firewall: on with n/m cards loaded, OFF, being built,
or none), then **one full-width row per slot** (`SlotBox`, `SLOT_H` 56 px, from `_slot_view`): a building's picture and
name, its state on the right (`SLOT_STATES`: off under DDoS or Sabotage, phished, bank or storage full, a station's
missing workers or its workers held by Sabotage, a Firewall OFF), and as icons with numbers what it makes or uses every cycle on this host (`_flow_items`:
+1.5 Intel on a Server, a Firewall's -1 Intel, a station's +2 workers) next to the stock of that resource here
(`_stock_items`; at the main node, the bank); a project shows its state, its materials here of its bill as icons
(n/m), a progress bar and a red cancel button; an empty slot is dashed and reads "Empty slot — click to build". A
finished Firewall's row has a small picture and its three sockets across the second line, so every row keeps one
height. A **click on a slot opens the chooser** (`_open_chooser`; `_chooser` is UI state the simulation never reads) in
place of the facts and the rows: a title with Close (and Cancel project on a running project, Remove on a built slot),
then every building (`BuildOption`, `OPTION_H` 54 px, from `_option_view`): picture, name, what it makes or uses as
icons, one short line on what it is for (`BUILD_WHAT`), its price as resource icons with the build time (amounts the
bank cannot pay now in red with "Not enough in bank" — still orderable, since ordering is free and workers bring the
materials), the building already there marked "Installed here". A pick sends the build command for THAT slot
(`_choose_build` → `_cmd(["build", host, slot, kind])`, replacing what is there: demolish, then build) and closes the
chooser; Close, Esc, a click on the map or elsewhere in the sidebar (not in the 4 px between two of its rows: a near
miss), another selection or the card drawer close it too. There is no palette and no
dragging of buildings. Everything fits without scrolling at 1280×720 and 1366×768, under Learn's banner as well
(`tests/text_fit_test.gd`).
Hover notes (`_wrapped_tooltip`) measure their wrapped height before they are shown and set their lines at the text
font's own height (the symbols fallback makes the theme font's lines 28 px at 13 px), so Godot places them fully on
screen; `TooltipPanel` in `assets/ui_theme.tres` gives them an opaque bordered panel. Selecting your host closes the card drawer, and
opening the drawer closes the build menu; however one host of yours becomes the selection (a capture, a Learn step,
a shift-click, a Logs entry), `_refresh_panel` closes the drawer too (0.6.5). A selected host a rival takes turns into
an inspection (if you still see it) without moving your view; a host you inspect that you capture becomes your
selection in the same refresh, and an inspection the fog drops leaves the narrower sidebar without sliding the map
(0.6.8: `_refresh_panel` treats every change the sim makes to the sidebar like a prune), and the drawer's state is part of the panel's context only
while the build menu shows, so opening it keeps your place in the Logs or the Economy view.
A slot row's tooltip (`_slot_tip`) says what it is, what it is doing and the host's first two problems from
`_host_diag`; a right click on a row still demolishes (nothing can be paused). The facts' tooltip (`_host_info_tip`)
gives the type's multipliers and the storage in words; a chooser row's (`_option_tip`) the materials and what replacing
costs. Learn's build steps cue an empty slot of the step's host first, then the building in that slot's chooser
(`_camp_build_ctrls`).
No card is sent or launched from a host panel: cards go through the card UI and drag and drop. A foreign host's
panel shows only its owner and "Unknown host — send Recon to inspect." until a fresh Recon adds its type, slots,
storage and Firewall cards; when the Recon goes stale it says "Recon expired". In every finished Firewall's row a
`SocketList` shows its 3 socket positions side by side: empty, a card on its way (with its arrival time), loaded (by
name and art), or off. Sockets are positional (`hosts[i].sockets`: "" empty, a recipe, or "@recipe#flight" held for a card
on its way) and seated on the finished Firewalls in slot order, 3 each (`_wall_seat`): a card loads into the first
empty position from the left; a card that fires leaves its position empty; a Firewall that is demolished or
replaced takes its own 3 positions and their cards away when the work starts (`_seat_out`), and one that is
finished gets 3 empty positions at its seat (`_seat_in`), so every card stays in the Firewall it was loaded into.
`tests/host_panel_test.gd` covers this and the slot chooser (opens on a click, lists every building, orders into that
slot, replaces, cancels, closes on Esc, the map, another selection; none on rival or neutral hosts; the lockstep
fingerprint unchanged by it), and checks that no control outlives its context.

Host diagnoses and route inspection (Milestone A). `_cycle_preview(i)` works the next cycle out exactly
as `_run_cycle` will, on copies (`_pv_add`/`_pv_take`), so "Next cycle in 2.4 s: …" shows feasible output;
`tests/diagnosis_test.gd` checks the preview against the real
cycle. `_host_diag(i)` names the status from the first problem (under DDoS, sabotaged, phished, no route,
starved, blocked, waiting for workers, Firewall off, building, idle; else operating) with a cause and a
fix. `_route_eta` reports hops, travel and the queueing a packet leaving now would meet, without reserving link
capacity; `_host_delivered` reads the ledger's per-host "from" entries. On the map the selected host's links you
can see, its route home (green, chevrons pointing home) and a tag with hops and time are drawn; a host with no
route home rings its cut-off segment (`_cut_off`) in red. None of this changes the simulation.

Target preview (Milestone A). `_target_preview(fac, card, host)` says, before anything is spent: whether the card can
launch and why not (`_can_play`), the chance (`_chance_line`: 50% scouted or 25% unscouted, with the Recon's age; 50% for a Recon itself), the route from the main node with arrival time
and queueing, the execution time and what stops it, the hosts an area or chain effect would hit as far as the player
can see (`_preview_nearest`, `_preview_chain` — never hosts out of sight), the Worm's next stage (`_worm_next`),
public defences (an armed Patch, a Filter) and the last Recon snapshot with its age (`_known_defences`; loaded
sockets are never read live). While a card is dragged over a host the preview follows the cursor
(`_paint_drag_preview`). The card is used only on launch.

Event history (Milestone A). `events` is one persistent queue for this screen's player, newest first, in three
priorities (`EV_CRIT` needs you now, `EV_ACT` worth acting on, `EV_INFO` news). `_tick_events` polls every 0.5 s
for lasting conditions — a rival intrusion on your host (critical on the main node), DDoS / Sabotage / Phishing /
Siphon on your hosts, a Firewall without Intel, hosts cut off from the main node, a rival holding the majority,
no workers at all, research that cannot pay — and keeps ONE entry per condition that updates while
live and then ends (it stays in the history as news). One-off news comes from hooks: `_op_outcome` via
`_event_outcome` (your operations' results and attacks on you, ending their intrusion entry), `_fire_socket`,
blueprints learned, copies made, lost cargo; the same news within 10 s counts up on one entry. Nothing is drawn over
the map: a **Logs** button at the top-left under the HUD (`logs_button`) counts the entries that are new since you
last looked ("Logs · 3 new", red while something critical is new or live) and opens the Events view (`H` too), where
a click finds an entry's host. The history keeps 80 entries, is cleared with the match
(`_gen`, with the economic ledger and `op_outcomes`), and is not part of the lockstep fingerprint.

Cards are **researched once, then manufactured**. A blueprint is learned in the single
research slot (`_do_research`/`_tick_research`, cost + time in `cards.gd` `RESEARCH`); five
recipes are known from the start (`KNOWN_START`: Recon, Breach, Phishing, Patch, Incident
response). A known recipe is manufactured into single-use copies through **one FIFO queue** of at most
`QUEUE_SIZE` (4) entries, the copy being made included (`mq`, `_mq_add`/`_mq_remove`/`_tick_manufacture`). Only
the head is made; it pays its `make` cost when it starts, from main-node stock no worker has claimed, and takes
`make_time` seconds. A head that cannot start says why ("Needs 9 Intel at Main rig · 2 on the way", "Ready inventory
full — use a card") and nothing overtakes it. While the head is unpaid and the queue runs, its price is held back
from research and from supplies (`_supply_budget` via `_head_owed`), so research no longer takes the bank unit by
unit before a copy can start (0.6.12) — unless the Ready inventory is full and the copy could not start anyway
(0.6.14). Research also leaves alone what the projects still need (`_research_hold`: `_build_owed`, a remote site's
only while you have workers), so construction goes first for it too; the research bar names what the bank lacks
apart from what it keeps, and for whom ("Intel is kept for your Recon copy and your construction"). Prices by role (0.6.12, same totals): infrastructure (Bot
station, Lab, Firewall) and blueprints are paid mainly in Crypto, cards and the harvesters mainly in Intel. Removing a waiting entry is free; cancelling the paid head refunds its
unworked share. The queue pauses separately (`queue_pause`). Finished copies sit in a 12-slot ready inventory
(`READY_SLOTS`, `_ready_total`, which also counts the copy being made and cards in flight that may return). The AI
uses the same queue.

The cards area (0.6.1). At the bottom an always-visible **strip** shows the queue's four places (`QueueChip`: the
head making / paused / waiting with what it lacks as icons / done, then the waiting copies; x removes one; an empty
place opens the recipes) and a separate Pause button, then the cards you hold as fixed-size `ReadyChip`s (they are never
shrunk: what does not fit goes behind "+n"), and on the right a three-bar button (`C`) that opens the **drawer**.
The drawer keeps usable cards apart from recipes: **Ready** (`ReadyTile`s, paged, with Packet siphon's resource
choice), **Attack recipes** and **Defence recipes** (four recipe cards a page, each with an explicit **+ Queue**
button and "2 queued · 1 ready"; the card body only explains; recipes are never dragged) and **Research**. A ready card is dragged onto a host, or clicked to select it
(`_armed`: the drawer closes, valid targets are framed, the preview follows the cursor) and then launched with a
click on a host (`_launch_armed`); Esc, right-click or a click on empty map unselects it, and the selection survives
opening and closing the drawer. **Research** is a button beside Economy and Menu in the top bar (`R`): its label is
the active research's state ("Research 45%", "Paused 45%", "Stalled 45%", or "Research +n" open blueprints); the
research view names it with its progress and time left (`_research_status_line`), shows the selected blueprint's
price, time and action above the tree (`ResearchInfo`, `_research_action`), and draws the selection (a cyan band
and outline) apart from hover (a lighter fill) and the states (known: family colour; researching: white with a
bar; paused: amber; stalled: red; open: violet; locked: grey). While research runs, a **research bar** under the HUD
(`ResearchBar`, `_research_bar_state`) shows the project's name, track, progress, active / paused / stalled (and
what is missing) and the work left; with nothing running there is no bar. `tests/cards_ui_test.gd` covers
empty and crowded inventories, paging, selection and launch, research states, the research bar and the queue strip.

There are **no security levels**: any card may target any foreign host; a host's type decides only its slots
and production multipliers. Capture cards differ by price and execution time (`exec`, and `exec_rig` on a held
main node — Breach 15/30 s, Known exploit 9/20 s, 0day 5/12 s, each Worm stage 9/20 s). **Recon** reveals
installations, storage and Firewall cards for 45 s, but itself gets through only `RECON_CHANCE` (0.5) of the time
(a miss shows nothing and only its sender hears of it). Every other attack card succeeds at `SCOUTED_CHANCE` (0.5)
with fresh Recon of the host (`_recon_fresh(fac, t, at)`, judged when the operation resolves, voided by a change
of owner) and `UNSCOUTED_CHANCE` (0.25) without (`_op_chance`); defence cards on your own hosts always work.
`_op_roll` draws once per resolved operation from `sim_rng` (seeded from the map in `_gen`, part of `_mp_hash`),
only when the chance is below 1, and only after counters, a void target and the route have been decided.
`rolls_always_hit` (tests only) forces every draw to succeed while still taking it, for suites about effects.

The idle right sidebar shows compact standings automatically; selecting a node replaces it
with the host's panel (its facts and its slots; a click on a slot chooses its building). Help uses six
illustrated pages with examples; the tutorial colours its keywords like the things they name
(ATTACK red, DEFENCE blue, your pieces green).

Winning: hold at least 51% of ALL hosts (rounded up) for 51 continuous seconds
(`HOLD_FRACTION`/`HOLD_SECS` in tuning.gd), or be the last botnet with its rig. `_objective()` is the one
source for these numbers: the HUD (always visible, after the five banks), the standings and the win
check read it. A botnet whose rig is taken is eliminated (`_check_rigs` → `_eliminate(fac, captor)`); 0.6.13: its
captor **inherits** its other hosts with their finished buildings (a new ownership generation: jobs, storage, sockets,
workers, claims, inbound cargo and effects are cleared; the heir's Bot stations staff themselves at once, `_sync_teams`),
so taking a main node is worth a whole network. With no living captor its hosts turn neutral and empty, as before.

Fog of war (one rule for every botnet): a faction's real sight is
its own hosts and every host one street away from them (`_in_sight`/`_sight_set`); on top of
that every rig is visible as a landmark (`_visible_to`/`_visible_set`). A rig seen only through
fog is drawn and clickable, but nothing around it shows: rival packets, wires, worm jumps, card
pulses and the busy-street colour all follow real sight (`_flight_visible`, `_sighted_runs`).
Hosts seen before stay on the map as dim outlines without owner or current contents (`_seen`,
`_explored`, `_last_seen`); fogged hosts cannot be clicked. Territories: every visible owned
host claims a round patch (`TERR_RADIUS`); one botnet's patches melt into rounded areas
(gaps and waists filled by `TERR_SMOOTH`), the ground between rivals is split halfway between
their buildings, and borders are inset so two botnets' lines never touch (`_territory_shapes`,
recomputed only when sight or ownership changes).

Installations (`BUILD_KINDS` in buildings.gd) go in a host's slots. Producers
(`PRODUCER_KINDS`): the **Intel harvester**, **Crypto miner**, **Credential harvester** and **Research
lab** each make 1 unit of their resource a cycle from nothing (0.6.12: no producer has an input; a storage
that cannot hold a whole cycle is shared among them in proportion, `_cycle_share`); the **Bot station** provides
2 reusable workers. Host type multipliers scale output (`_tmult`). A **Firewall** (`wall`) is not a producer: each
one gives the host `FIREWALL_SOCKETS` (3) **sockets** for defence cards and eats 1 Intel a cycle
from its host's storage (`fw_on`; without Intel it switches off and its cards wait). A Patch,
Incident response, Traffic filter or Cargo cover sent to a host with a free socket is loaded on
arrival instead of spent, unless its attack is already there (`_apply_support`, `_trigger_now`); it then
fires on its own when its trigger hits (`_fire_socket`, `SOCKET_TRIGGER`: an intrusion starting
for Patch via `_start_exec`, Phishing/siphon/sabotage landing for Response, a DDoS landing for
Filter, a siphon grabbing this host's cargo for Cover). Express route cannot be loaded. **Construction is
supplied before work**: ordering is free; the project's bill (`BUILD_COSTS`) goes into an **escrow** at its site
(separate from the 20-unit storage, so a 32-unit Bot station fits any host), first from what the host has spare, the
rest carried by workers one unit a leg; only then do its `BUILD_TIME` s of work run (`_tick_jobs`). Replacing an
installation demolishes it (`DEMOLISH_TIME` s) while the materials travel. Nothing can be paused (0.6.9: neither a
project nor a producer); cancel leaves the delivered (unworked) materials at the site as salvage; capture destroys them;
a Vault raid can steal unconsumed escrow, and the project's shortage reopens. DDoS, Supply-chain sabotage or a
running construction stops a producer (`_producer_active`); Sabotage also keeps the Bot-station workers of the hosts it
hits from setting out (`_worker_state` "blocked"; a leg already under way finishes). During Phishing (180 s), a
victim host's new output is stored there for the caster, whose workers collect it; the host's own
workers stay the owner's. Vault-raid loot and siphoned cargo (a Packet siphon lasts 60 s) also wait on the host
(`hosts[i].loot`) for the thief's workers, who collect them last; a pile has its own claims (`pclaim`, `_pile_free`,
apart from the storage's `claim` / `_store_free`), so one unit never draws every free worker and a pile pickup never
takes what the host's storage keeps for its Firewall. When a thief is eliminated its siphons stop and what
its Phishing diverted goes back to the host's owner at once (0.6.14).

The AI botnets all play `_ai_think` (one economic AI, no difficulty setting): it gives every
host a self-feeding layout (`_ai_plan`: a Bot station first, then an Intel harvester and its
converters; a Lab host with a Miner beside it; one Firewall once the network is worth guarding),
retools a producer whose bank overflows (`_ai_rebalance`), learns blueprints, manufactures known cards and uses them to capture, steal and
defend, under the same income, workers, delivery, prices, four-place queue and fog (it presses only hosts its
own Recon saw) as a person.

Map layouts (numbers in `town.gd`): **Spiral**, **Elliptical**, **Ring** and **Grid**. There is no layout option:
`_layout_for_seed` picks one from the seed in `_gen`, so a seed always rebuilds the same layout and map
(`_opt_shape` remains an internal fixture for tests and Learn). The three galaxies (`_place_galaxy`) fill a shape with about as many computers as the
same-size grid, each the best of `STAR_CANDIDATES` random spots and never closer than `STAR_SPACING`,
so spacing is even: a spiral has one arm per botnet winding out of a core with every rig at an arm's
tip; an elliptical galaxy is a wide disc, denser in the middle; a ring has an empty middle. The rigs
sit at even angles round the centre (you top-left), so every botnet starts alike, and computers far
from every rig (the core, the stretch between two rigs) are the rich, well-defended ones. A shape too
small for its computers grows and is filled again. Multiplayer takes the galaxy from the match seed
(`GALAXIES[seed % 3]`), so every screen builds the same one; the guided campaign stays on its grid.

The hidden network (`LINK_REACH`) is never drawn as such. A link a botnet has sent any packet
over (`_schedule` — a shipment, worker, or operation) becomes a road on its own map for the
rest of the match (`_roads`, `_establish`, drawn faintly under the wires); rivals' roads are
never shown. There are no manual connections to make in this model.

Performance rules (0.1.3–0.1.4): the simulation runs in fixed `SIM_DT` = 1/30 s steps
(`_sim_step`); `_process` only feeds it real time and decides what to repaint, with packets drawn
`_sim_acc` ahead so they glide. Frames are capped by `_pace_frames`: 60 fps while playing, 30 with
the menu open or the window in the background.

The map is painted by five `MapLayer` children (`MAP_PARTS`, bottom to top): `ground` (territories,
streets, wires), `packets`, `nodes` (buildings), `over` (card packets, pulses, focus / drag guides)
and `mask` (screen-space masks). Each is painted by `_paint_<part>` into `_cv`; map drawing code
calls `_cv.draw_*`, never a bare `draw_*`. Godot keeps a layer's drawing until it is repainted:
`ground`/`nodes`/`over`/`mask` and the HUD repaint when `_view_key()` changes (pan, zoom, hover,
selection, deck, …) and every `MAP_REFRESH` s while the match runs; `packets` repaints every frame
only while something moves, `over` only while something in it animates (`_over_fast`). Anything
new the map shows must either come from the simulation (refreshed MAP_REFRESH-ly) or be part of
`_view_key()`. `queue_redraw()` on the game still repaints every layer.

Text in custom `_draw` code goes through `_text` / `_text_w` (a shaped-text cache), never
`draw_string` / `get_string_size` directly: Godot's own font cache keeps only 64 strings and one
frame draws more, so it re-shaped everything every frame. Inside `_sim_step`, `_route` results
are memoised from `_auto_guards` to `_tick_production` (`_route_memo`), where no owner or route cut
changes. A change that must not alter the rules should leave a fixed-seed match identical, step for
step.

Text must fit, with a margin, and never overlap (`tests/text_fit_test.gd` checks it at 1280×720 and
1366×768). Wrapped text is measured and drawn as a shaped `TextParagraph` (`_para`, `_text_lines`,
`_text_height`): the UI font's symbol fallback reports a 25 px line at 12 px while a shaped line is
~17 px, so `Font.get_height()` must not be used to count or place lines. A card face shows its
one-line `lead` and then only the **whole** `rules` sentences that fit (`_card_blurb`); the full text
is the card's hover tooltip, so keep each rules sentence short (about two card lines). Map names are
placed after every building by `_place_names`: the first free spot of eight round the building, clear
of other names, pictograms and warning lines, in priority order (selected, hovered, campaign hosts,
main nodes, yours, others); a minor name with no free spot shows on hover instead. The sidebar
content sits in `panel_gutter`, 6 px clear of its scrollbar; your host's rows fill its width, and a foreign host's
slots size from `PANEL_W` (`_palette_card_w`).

Operations (cards do all the fighting; `cards.gd` `CARDS`, resolved in `_play_card` /
`_op_land` / `_tick_execs` / `_apply_support`). Playing an ATTACK card launches an **operation
flight** from your main node along a route through your own network to the target
(`_attack_route` / `_op_reachable` — you must own a path toward it). Capture and raid cards
then **execute** on arrival for the card's `exec` seconds before they resolve
(`_execs`). An intrusion resolves in exactly one outcome,
recorded by `_op_outcome` in `op_outcomes` with its own message for both sides: **countered** (a Patch: by
hand, armed, or loaded in a Firewall), **owner changed** (the target's ownership generation moved first, so
a host is never captured twice from one generation), **route failed** (no path from the attacker's main
node when it ends), **missed** (the draw failed: 50% scouted, 25% unscouted), **raided** (Vault raid) or **captured**.
Intrusions resolve earliest end first, equal end times by operation id
(launch order), and a turn's commands — a manual Patch included — apply before that turn's steps. A Worm
captures its target, then runs one more stage on the nearest visible linked host of the same original owner
(its own draw; 0.6.13: if the first stage had fresh Recon, the second host counts as scouted, `_mark_scanned`); a
stopped stage ends the chain. **Patch recovery** (0.6.13): a Patch that stops an intrusion — by hand, armed or from a
Firewall socket — leaves its host recovering for 30 s (`_patch_recover`, `patch_recover_until`, in `_mp_hash`; public: the host's
effects, a "NO PATCH" map label and the attack preview show it to everyone who sees the host, 0.6.14): no Patch can be played there meanwhile, one on its way goes back to the hand, and one
already loaded in the Firewall still fires and restarts the window. While its main node is under DDoS a botnet can
play no card at all (`_can_play`), so a DDoS on the rig opens a window for a capture. Phishing and Siphon land as: a loaded Response
first, then the draw, then the effect; DDoS and Sabotage draw once for the operation, then each host's own
Filter/Response answers.
Support (DEFENCE) cards apply locally and instantly to one of your hosts.

The ten ATTACK/information recipes: **Recon**, **Credential breach**, **Known exploit**,
**Phishing**, **Packet siphon**, **Vault raid**, **DDoS**, **0day**, **Worm** and **Supply-chain
sabotage**; the five DEFENCE/support recipes: **Patch**, **Incident response**, **Traffic filter**,
**Cargo cover** and **Express route**. Their numbers live in `cards.gd`; each card's face and
hover tooltip say what it does (`lead`, `rules`). A main node whose routing is cut can
still play support on itself but cannot send attacks. Card art lives in
`assets/cards/schematic/`: every recipe has its own picture (`FAMILY_ART`, by `fam`); five of them
(vault, worm, siphon, cover, express) are drawn by `assets/cards/schematic/make_art.py` in the style of
the hand-made ones — run it, then import (`godot --headless --path . --import`).

To run a one-off test or render, add a tiny scene whose script instantiates the game and inspects
it, e.g.:
```gdscript
extends Node
func _ready():
    await get_tree().process_frame
    var P = load("res://scenes/botnet_proto.tscn").instantiate()
    get_tree().root.add_child(P)
    await get_tree().process_frame
    # drive P directly (public vars/methods), then save a PNG for visual checks:
    await RenderingServer.frame_post_draw
    get_tree().root.get_texture().get_image().save_png("res://shot.png")
    get_tree().quit()
```
Run with `godot --path . res://that_scene.tscn` (omit `--headless` when you need a rendered PNG).

---

## 3b. Multiplayer

Up to 3 people play one match; there is no AI in multiplayer. **Menu → Multiplayer**: set your name, join
an open public lobby, create a public or private lobby (private ones are joined by their 5-letter code). In the
lobby the host picks 2 or 3 players, the map size and public/private; everybody can chat; when every player
presses Ready a 5-second countdown starts the match (any change cancels it). A player who leaves or
disconnects mid-match leaves an idle botnet behind; the others play on.

How it works (deterministic lockstep, see `server/PROTOCOL.md`): every screen runs the same simulation from
the same seed in fixed 1/30 s steps (`_sim_step`). Only **commands** travel: every state change a person makes
goes through `_cmd([...])`, which in single player applies at once (`_apply_cmd` → `_do_*`) and in
multiplayer is queued and sent for turn `T + delay` (`_mp_begin_turn`). A turn is 3 steps; a screen may only
simulate turn `T` when every player still in the match has sent it (`_mp_advance` / `_mp_ready`), and every
screen applies the commands of a turn at its first step, faction by faction. `PLAYER` is the faction **this
screen** plays (1–3); rules that differ for people and AIs ask `_is_human(fac)` (`humans`). Every 30 turns the
screens exchange a state fingerprint (`_mp_hash`) and the server reports a desync. Anything that changes the
match from the UI must go through `_cmd`, and nothing in `_sim_step` may depend on the local screen
(selection, `PLAYER`, time of day, `randf()`): otherwise the screens drift apart.
`tests/mp_lockstep_test.gd` checks exactly that: two screens playing different factions get the
same scripted stream of every command verb (plus malformed ones) and must match every turn.

The connection and lobby state live in `scripts/botnet_net.gd` (one WebSocket). Players always use the one
official server, `wss://network.thenakedcat.games/ws`: Multiplayer connects to it by itself and keeps retrying
while the menu is open; when it cannot be reached the lobby list says "Server unavailable". For development
only, the launch argument `-- --server=ws://localhost:8787/ws` points a build at a local server. The server (Node.js, `server/`) only runs lobbies, chat, the ready
countdown and relays turns, and it also serves the web game at `/`. `.github/workflows/server.yml` tests it,
exports the Web preset into `server/public/` and publishes the Docker image `ghcr.io/zzzteph/rim-lobby`
(`:latest`, `:sha-<commit>`) to GHCR; the VPS runs it with `docker run`, bound to `127.0.0.1:8787` behind its
reverse proxy — see `server/README.md`. So `https://network.thenakedcat.games` is the game: open it and play,
single player or online (the web game served there connects back to the same server; the game and server
versions always match). The GitHub Pages copy (`web.yml`) still works and uses the official server.

## 4. Export a build

Both presets live in `export_presets.cfg`.
They exclude design notes, review artifacts, tests, scratch files, and previous builds.

### Startup branding

The loading artwork is `assets/branding/boot_splash.png` (1280×720 PNG), with an editable
vector source in `assets/branding/boot_splash.svg`. Replace the PNG with
new title art or a gameplay screenshot to change both the desktop boot screen and the Web
download screen. The image fits within the window without cropping; its background is
`#0d0f17`, set in `project.godot`. No extra startup delay is added.

The app mark's editable source is `assets/branding/icon.svg`. Keep `icon.png` (256×256)
and `icon.ico` (16, 24, 32, 48, 64, 128, 256 pixels) in that directory in sync after editing it.
The PNG supplies the project/window icon and Web favicon; the ICO supplies Windows taskbar,
executable, and console wrapper icons. The default Web shell exports the splash and favicon
beside `index.html`, so host the whole exported directory. Re-export after replacing assets.

### Desktop (Windows)
```bash
mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/rim.exe
```

### Web (HTML5)
```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```
The web build **must be served over HTTP(S)** — opening `index.html` from `file://` will not work.
Quick local serve:
```bash
cd build/web && python3 -m http.server 8080   # then open http://localhost:8080
```
The game uses GL Compatibility and the Web preset ships with `thread_support=false`, so it runs on
plain static hosting (no special COOP/COEP headers required).

---

## 5. Continuous deployment (web)

`.github/workflows/web.yml` builds the Web export and publishes it to **GitHub Pages** on every
push to `main` (and on manual `workflow_dispatch`).

One-time setup in the GitHub repo:
- **Settings → Pages → Build and deployment → Source: "GitHub Actions".**

After the first successful run the game is live at `https://<user>.github.io/<repo>/`.
If you change the Godot version, bump `GODOT_VERSION` in the workflow (it downloads that exact
editor + export templates from `godotengine/godot-builds` releases, so the version must be
published there).

---

## 6. Gotchas / conventions

- **One script, one scene.** Nearly everything is in `scripts/botnet_proto.gd`. Inner `class`es at
  the bottom (HudBar, CardFace, SlotBox, BuildCard, HelpGlyph, …) are the custom-drawn widgets.
- **Config is read once at load.** Editing `scripts/botnet_cfg/*.gd` needs a scene restart to take
  effect (they are `const`s).
- **GDScript 4 lambdas** capturing a loop variable must bind it via a default argument, e.g.
  `b.pressed.connect(func(i = idx): ...)`, otherwise every callback sees the final value.
- **Dictionary field access is `Variant`** — annotate explicitly (`var h: Dictionary = hosts[i]`)
  when the inferred type would fail (`Cannot infer type`).
- **No history-writing git on behalf of a tool** — commits/pushes are the maintainer's to make.
