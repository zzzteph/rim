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
