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

Run the automated mechanics, pointer-input, and layout checks before exporting:
```bash
godot --headless --path . --script tests/botnet_usability_test.gd
godot --headless --path . --script tests/botnet_ui_edge_test.gd
godot --headless --path . --script tests/card_balance_probe.gd
godot --headless --path . --script tests/four_card_effect_test.gd
godot --headless --path . --script tests/production_cost_test.gd
godot --headless --path . --script tests/ai_card_smoke_test.gd
godot --headless --path . --script tests/botnet_help_test.gd
```
Use the console executable above on Windows. Each check exits nonzero on failure.
To capture the usability suite's rendered fixtures, omit `--headless` and append
`-- --capture`; results and screenshots are written to `review/implemented_ui/`.
These checks cover scripted behavior and layout; human usability testing is still pending.

The card deck is a pull-out drawer at the bottom. Pushed down (the default) it is one
40px strip: a red ATTACK tab, a blue DEFENCE tab, eight mini cards (all cards, both
banks) and a handle. Click a mini card to research / pause it; drag a held copy straight
onto the map to play it. A closed tab, the handle or `C` pulls the deck up to the four
detailed cards of that tab (effects, cost/time, held copies, progress, `x` to cancel);
the open tab, the handle or `C` pushes it down again, the other tab switches banks.
Pulled up, the deck covers the bottom of the map instead of moving it. Dragging a big
card pushes the deck down for the drag and brings it back after the drop. A tab blinks
for 3 seconds when one of its cards finishes research. Eight cards share one research
queue. Drag a held ATTACK card onto a reachable foreign host, a DEFENCE card onto one
of your own hosts (including your rig). The sidebar always ends above the deck; scroll
inside a long sidebar to reach its remaining controls.

The idle right sidebar shows compact standings automatically; selecting a node replaces
it with node controls. Research and Board buttons/menus are removed. Help uses six
illustrated pages with examples.

Production costs are 1:1: Intel -> Credentials, Intel -> Crypto, Crypto -> Research.
Inputs belong to the host owner; funded output goes to the Phishing caster during theft.
Unfunded or capped producers consume nothing. Click an installed market, credential
harvester or lab to pause/resume; capacity remains installed. Attacks and construction
take priority over conversion spending; card research spends before labs.

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

## 4. Export a build

Both presets live in `export_presets.cfg`.
They exclude design notes, review artifacts, tests, scratch files, and previous builds.

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
