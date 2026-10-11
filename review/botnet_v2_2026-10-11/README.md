# Botnet prototype v2 — headless validation (2026-10-11)

Mechanics probe for `scripts/botnet_proto.gd` after the v2 rewrite (generated town, three factions, Cash
race, link capacity, attention-gated local view, control stages, rate dial, rally point).

- `probe.gd` — SceneTree script: 13 fixture cases on a fixed town seed plus three full 10 Hz matches as
  pacing readings. Calls the real simulation functions; not a usability test, not a balance verdict.
- `results.json` — the run recorded here (13/13 pass).
- `shot.gd` + `captures/` — the real scene rendered under Xvfb: idle, order preview, running orders with a
  rally point, and the inside-a-building view.

Run (Godot 4.7.2, from a project folder that contains `scripts/` and `scenes/`):

```
godot --headless --path <project> --script res://probe.gd
xvfb-run -a godot --path <project> --rendering-driver opengl3 --script res://shot.gd
```
