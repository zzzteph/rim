# Botnet prototype v2 — headless validation (2026-10-11)

Mechanics probe for `scripts/botnet_proto.gd` after the v2 rewrite (generated town, three botnets in a
free-for-all, typed buildings with their own pictures, Cash race, link capacity, attention-gated local view, control stages, rate dial, rally point)
with the designer's two-verb control scheme (wire by drag, launch from the target's panel, guards that arm
themselves) and the cost-aware AI botnets.

- `probe.gd` — SceneTree script: 18 fixture cases on a fixed town seed plus three full 10 Hz matches as
  pacing readings. Calls the real simulation functions; not a usability test, not a balance verdict.
- `results.json` — the run recorded here.
- `shot.gd` + `captures/` — early rendered checks of the four panel states.
- `gallery.gd` + `gallery/` — the real scene rendered under Xvfb through 33 scripted states: towns from four
  seeds, selection, dormant wires and the launch pad, a launched two-stream attack with a busy link, the
  inspect diagnostics, a capture, the rally point, the rate dial, a guard arming when its building is
  damaged, Cash packets, the inside view with its slot board (build, replace in progress), an attack by NYX, a scripted match at one-minute intervals on two
  seeds, and the three endings. `gallery/00_contact_sheet.png` is an overview.

Run (Godot 4.7.2, from a project folder that contains `scripts/` and `scenes/`):

```
godot --headless --path <project> --script res://probe.gd
xvfb-run -a godot --path <project> --rendering-driver opengl3 --script res://gallery.gd
```
