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
godot --headless --path . --script tests/economy_test.gd     # income, caps, research, manufacture, security, capture
godot --headless --path . --script tests/botnet_help_test.gd # Help navigation + layout at 1280x720 and 1366x768
```
Use the console executable above on Windows. Each check exits nonzero on failure.
To capture the Help suite's rendered previews, omit `--headless` and append
`-- --capture`; images are written to `review/visual_help/`.
These checks cover scripted behavior and layout; human usability testing is still pending.

> The pre-redesign suites (assault, takeover, production-cost, usability, campaign,
> MP lockstep, …) tested the old bot-army mechanics and were removed in the 0.4.0
> research–manufacture–deliver redesign. Re-authoring MP-lockstep determinism and a
> campaign walkthrough against the new model is still open work.

The card deck is a pull-out drawer at the bottom. Pushed down (the default) it is one
40px strip: a red ATTACK tab, a blue DEFENCE tab, eight mini cards (all cards, both
banks) and a handle. Click a mini card to research / pause it; drag a held copy straight
onto the map to play it. A closed tab, the handle or `C` pulls the deck up to the four
detailed cards of that tab (effects, the research price as resource icons + a clock,
held copies, progress, and a quiet `Cancel` link in the status row while queued);
the open tab, the handle or `C` pushes it down again, the other tab switches banks.
Pulled up, the deck covers the bottom of the map instead of moving it. Dragging a big
card pushes the deck down for the drag and brings it back after the drop. A tab blinks
for 3 seconds when one of its cards finishes research. Eight cards share one research
queue. Drag a held ATTACK card onto a reachable foreign host, a DEFENCE card onto one
of your own hosts (including your rig). The sidebar always ends above the deck; scroll
inside a long sidebar to reach its remaining controls.

The idle right sidebar shows compact standings automatically; selecting a node replaces
it with node controls. Research and Board buttons/menus are removed. Help uses six
illustrated pages with examples; the tutorial colours its keywords like the things they
name (buildings in their card colour, ATTACK red, DEFENCE blue, your pieces green).

Winning: hold at least 51% of ALL buildings (rounded up) for 51 continuous seconds
(`HOLD_FRACTION`/`HOLD_SECS` in tuning.gd), or be the last botnet with its rig.

Fog of war (one rule for every botnet): a faction's real sight is
its own hosts and every host one street away from them (`_in_sight`/`_sight_set`); on top of
that every rig is visible as a landmark (`_visible_to`/`_visible_set`). A rig seen only through
fog is drawn and clickable, but nothing around it shows: rival packets, wires, worm jumps, card
pulses and the busy-street colour all follow real sight (`_flight_visible`, `_sighted_runs`).
Hosts seen before stay on the map as dim outlines without owner or bot count (`_seen`,
`_explored`, `_last_seen`); fogged hosts cannot be clicked. Territories: every visible owned
host claims a round patch (`TERR_RADIUS`); one botnet's patches melt into rounded areas
(gaps and waists filled by `TERR_SMOOTH`), the ground between rivals is split halfway between
their buildings, and borders are inset so two botnets' lines never touch (`_territory_shapes`,
recomputed only when sight or ownership changes).

Every standing building works whatever its bot count (0.1.5: losing bots no longer switches
slots off); only a card (DDOS), a running construction or the owner's pause stops one.

Building prices (`BUILD_COSTS` in buildings.gd), paid evenly over 10 s of funded work, the
full price needed in the bank to queue: Intel harvester 10 Intel, Bot farm 30 Intel, Crypto
miner 50 Intel, Credential harvester 50 Intel, Research lab 50 Intel + 25 Crypto. A short
resource slows a job (the scarcest one sets its pace); build cards show prices as icons.
Production costs are 1:1: Intel -> Credentials, Intel -> Crypto, Crypto -> Research.
Inputs belong to the host owner; funded output goes to the Phishing caster during theft
(the host shows PHISHED and its countdown). Unfunded or capped producers consume nothing.
Click an installed miner, credential harvester or lab to pause/resume; capacity remains
installed. Attacks and construction take priority over conversion spending; card research
spends before labs.

The AI botnets all play `_ai_think` (there is one AI and no difficulty setting).

Map layouts (New game → Layout; numbers in `town.gd`): **Spiral** (the default), **Elliptical**, **Ring**
and **Grid**. The three galaxies (`_place_galaxy`) fill a shape with about as many computers as the
same-size grid, each the best of `STAR_CANDIDATES` random spots and never closer than `STAR_SPACING`,
so spacing is even: a spiral has one arm per botnet winding out of a core with every rig at an arm's
tip; an elliptical galaxy is a wide disc, denser in the middle; a ring has an empty middle. The rigs
sit at even angles round the centre (you top-left), so every botnet starts alike, and computers far
from every rig (the core, the stretch between two rigs) are the rich, well-defended ones. A shape too
small for its computers grows and is filled again. Multiplayer takes the galaxy from the match seed
(`GALAXIES[seed % 3]`), so every screen builds the same one; the guided campaign stays on its grid.

The hidden network (`LINK_REACH`) is never drawn as such. A link a botnet has used — connected along
(`_do_wire`) or sent any packet over (`_schedule`) — becomes a road on its own map for the rest of the
match (`_roads`, `_establish`, drawn faintly under the wires); rivals' roads are never shown.

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

Attacking, on the target's panel: **Scan** reveals it quietly; **Attack** gives every connected source an
order to send a share of its bots (25/50/75/100 %, or 125/150 % overcharged: the whole garrison, each bot
hitting harder) at `ASSAULT_RATE`, its farms resting until the order is spent; a source connected while the
attack runs joins at the same share; **Stop** ends the orders (unsent bots stay home) and keeps the
connections, so Attack can be pressed again. (The plain stream, `["launch", t, "attack"]`, remains for the AI
and the protocol; the panel no longer offers it.) Every attacking bot is lost with `HOP_LOSS` (25 %) on each
link it crosses (`_loss_hop`, rolled on the simulation's seeded `rng`, so lockstep-safe): 75 % arrive from next
door, 42 % across three links, so a big garrison far from the front no longer wins alone. Reinforcements,
scans, Crypto and cards are never lost. Probes set `hop_loss = 0` to count exact landings.

Phishing steals output for 30/20/10 seconds across three foreign hosts. DDOS stops all
production and routing for 30/20/10/5/2 seconds across five foreign hosts. 0day captures
instantly with 75% probability, but only a host you have a connection into (a dormant
wire is enough); failure changes nothing. Supply chain removes buildings, jobs and
defenders while retaining ownership. A rig whose routing is cut can still play DEFENCE
cards on itself (CDN clears its DDOS) but cannot send cards anywhere else.

Each DEFENCE card spreads through up to five successive owned hosts and costs twice
its matching ATTACK card in each resource (research times unchanged): CDN/DDOS, Patch day/0day,
Incident response/Phishing, SCA/Supply chain. Card art lives in `assets/cards/schematic/`
(the four DEFENCE shields are flat pictograms in the same style as the attack art).
CDN clears DDOS (production and routing) on an affected host;
otherwise it doubles production for 10 seconds, still paying 1:1 inputs. Patch day blocks
0day and Supply chain for 30 seconds; Incident response clears Phishing without immunity;
SCA blocks Supply chain for 60 seconds. Boosts refresh rather than stacking above x2.

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
(selection, `PLAYER`, time of day, `randf()`): otherwise the screens drift apart. `tests/mp_lockstep_test.gd`
checks exactly that.

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
