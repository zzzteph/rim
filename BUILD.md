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
godot --headless --path . --script tests/sim_smoke_test.gd   # 90 s four-faction match (3 AIs): no error, banks stay sane
godot --headless --path . --script tests/ai_test.gd          # AIs research, manufacture and capture ground (not idle)
godot --headless --path . --script tests/campaign_test.gd    # plays the 5-chapter guided campaign end to end
godot --headless --path . --script tests/botnet_help_test.gd # Help navigation + layout at 1280x720 and 1366x768
```
Use the console executable above on Windows. Each check exits nonzero on failure.
To capture the Help suite's rendered previews, omit `--headless` and append
`-- --capture`; images are written to `review/visual_help/`.
These checks cover scripted behavior and layout; human usability testing is still pending.

> The pre-redesign suites (assault, takeover, production-cost, usability, …) tested
> the old bot-army mechanics and were removed in the 0.4.0 research–manufacture–deliver
> redesign; the economy, AI and campaign suites above are their replacements.
> Re-authoring an MP-lockstep determinism suite for the new command set is still open work.

Economy (research–manufacture–deliver, 0.4.0). There are five resources (`RES` in
tuning.gd): **Bots**, **Intel**, **Crypto**, **Credentials**, **Research**. Resources are only
spendable once they reach your **main node** (your rig). The main node makes one of every
resource per second, delivered locally with no courier (`MAIN_INCOME`, `_tick_production`
step 1). Producers you build on other hosts emit output into a per-producer local buffer
(`BUFFER_CAP`); a **courier** then carries it home — one Bot per non-Bot unit, consumed on
arrival (`_tick_dispatch`/`_dispatch_for`/`_deliver`). New Bots deliver themselves. A main-node
**Bots reserve** (`BOT_RESERVE_CHOICES`) keeps couriers back for operations, and a **shipping
priority** biases which resource ships first. Each bank has a cap of `BASE_CAP[res]` plus
`CAP_PER_PRODUCER` for every producer of that resource you own (`_cap`); incoming shipments
reserve destination room (`incoming`).

Cards are **researched once, then manufactured**. A blueprint is learned in the single
research slot (`_do_research`/`_tick_research`, cost + time in `cards.gd` `RESEARCH`); five
recipes are known from the start (`KNOWN_START`: Recon, Breach, Phishing, Patch, Incident
response). A known recipe is manufactured into single-use copies in one of three
**manufacturing lanes** (`MANUFACTURE_LANES`, `_lane_*`/`_tick_manufacture`); each copy pays its
`make` cost up front and takes `make_time` seconds, and finished copies sit in a 12-slot ready
inventory (`READY_SLOTS`, `_ready_total`). A lane can **Repeat**. The deck drawer at the bottom
has a red ATTACK tab and a blue DEFENCE tab. Pushed down, its strip shows all fifteen recipes as
mini cards (click = research / pause, drag a held copy = play). Pulled up (a tab, the handle or
`C`), it shows four detailed cards of the open tab at a time; ← / → in the strip page through the
rest (`_deck_page`: ATTACK has three pages, DEFENCE two). Drag a ready copy onto the map to play
it, or launch from a host's panel. Drag a held ATTACK card onto a reachable foreign host, a DEFENCE
(support) card onto one of your own hosts (including your rig).

Hosts have a **security class** 1–3 (`SEC_BY_TYPE` by host type, `_security`): a capture card
only takes a host whose security is at or below the card's reach (`sec_max` — Breach 1,
Exploit 2, 0day 3). Installing a **Firewall** (`wall`) raises a host's security by one, to a
cap of `SEC_MAX` (3); a main node is pinned to `SEC_MAIN` (3). Security is public; Recon is
optional for capture and reveals installations, buffers and mission access for 30 s.

The idle right sidebar shows compact standings automatically; selecting a node replaces it
with node controls (installations, build palette, logistics on the main node). Help uses six
illustrated pages with examples; the tutorial colours its keywords like the things they name
(ATTACK red, DEFENCE blue, your pieces green).

Winning: hold at least 51% of ALL hosts (rounded up) for 51 continuous seconds
(`HOLD_FRACTION`/`HOLD_SECS` in tuning.gd), or be the last botnet with its rig.

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
(`PRODUCER_KINDS`: Intel, Bot, Crypto, Credential and Research-lab) turn an input bank
resource into an output resource at `rate` (input paid from the host **owner's** available
bank at `in_rate`); output goes to a local buffer and is couriered home, or straight to the
bank when the producer sits on the main node. A short input scales output down that tick;
a capped bank or full buffer makes a producer idle and burn no input. A **Firewall** (`wall`)
is not a producer: it raises the host's security (see above). Build jobs are paid evenly over
`BUILD_TIME` s of funded work with the full price (`BUILD_COSTS`) reserved to queue;
demolition takes `DEMOLISH_TIME` s. Click an installed producer to pause/resume; DDoS,
Supply-chain sabotage, a running construction or the owner's pause stops one
(`_producer_active`). During Phishing, a victim host's new producer output is diverted to the
caster (who still pays a courier home per stolen non-Bot unit).

The AI botnets all play `_ai_think` (one economic AI, no difficulty setting): it develops
producers, learns blueprints, manufactures known cards and uses them to capture, steal and
defend, under the same income, delivery, prices, lane/reserve limits and fog as a person.

Map layouts (New game → Layout; numbers in `town.gd`): **Spiral** (the default), **Elliptical**, **Ring**
and **Grid**. The three galaxies (`_place_galaxy`) fill a shape with about as many computers as the
same-size grid, each the best of `STAR_CANDIDATES` random spots and never closer than `STAR_SPACING`,
so spacing is even: a spiral has one arm per botnet winding out of a core with every rig at an arm's
tip; an elliptical galaxy is a wide disc, denser in the middle; a ring has an empty middle. The rigs
sit at even angles round the centre (you top-left), so every botnet starts alike, and computers far
from every rig (the core, the stretch between two rigs) are the rich, well-defended ones. A shape too
small for its computers grows and is filled again. Multiplayer takes the galaxy from the match seed
(`GALAXIES[seed % 3]`), so every screen builds the same one; the guided campaign stays on its grid.

The hidden network (`LINK_REACH`) is never drawn as such. A link a botnet has sent any packet
over (`_schedule` — a shipment, courier, or operation) becomes a road on its own map for the
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

Operations (cards do all the fighting; `cards.gd` `CARDS`, resolved in `_play_card` /
`_op_land` / `_tick_execs` / `_apply_support`). Playing an ATTACK card launches an **operation
flight** from your main node along a route through your own network to the target
(`_attack_route` / `_op_reachable` — you must own a path toward it). Capture and raid cards
then **execute** on arrival for the card's `exec` seconds before they resolve
(`_execs`); a lost route, a changed owner, or a defender's Patch can stop them mid-execution.
Support (DEFENCE) cards apply locally and instantly to one of your hosts.

The ten ATTACK/information recipes: **Recon** (reveal for 30 s), **Credential breach** (capture
a security-1 host), **Known exploit** (capture up to security 2), **Phishing** (divert a host's
new producer output to you for 24 s), **Packet siphon** (redirect up to six courier packets of
a chosen resource for 18 s), **Vault raid** (steal up to eight stored Crypto from a rival main
node), **DDoS** (stop a host's producers, income and dispatch for 18 s), **0day** (capture up to
security 3; longer on an active rival main node), **Worm** (chain up to three adjacent visible
security-1 hosts of one owner), **Supply-chain sabotage** (disable producers on the target and
up to two adjacent same-owner hosts for 20 s). The five DEFENCE/support recipes: **Patch**
(cancel the earliest hostile capture/raid executing on this host, else arm one interception
for 20 s), **Incident response** (clear Phishing, Packet siphon and sabotage here; undispatched
stolen output reverts), **Traffic filter** (clear a DDoS and block a new one for 12 s), **Courier
cover** (protect cargo this host emits from Packet siphon for 16 s), **Express route** (halve
delivery travel time for this host's shipments for 16 s). A main node whose routing is cut can
still play support on itself but cannot send attacks. Card art lives in
`assets/cards/schematic/`, mapped from each recipe's `fam` by `FAMILY_ART`.

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
(selection, `PLAYER`, time of day, `randf()`): otherwise the screens drift apart. (A lockstep
determinism suite for the new command set is still to be re-authored; see the tests note above.)

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
