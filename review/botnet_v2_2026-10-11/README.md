# Botnet prototype v2 — headless validation (2026-10-11)

Mechanics probe for `scripts/botnet_proto.gd` after the v2 rewrite (generated town, three botnets in a
free-for-all, typed buildings with their own pictures, Cash race, link capacity, attention-gated local view, control stages, rate dial, rally point,
scanning, and the card system: Credentials and Research, a research tab, single and worm cards with linked or any reach, type resistances)
with the designer's two-verb control scheme (wire by drag, launch from the target's panel, guards that arm
themselves) and the cost-aware AI botnets.

- `all_cards.png` — every card face, LINKED row and ANY row, as the research tab draws them.
- `probe.gd` — SceneTree script: 26 fixture cases on a fixed town seed plus three full 10 Hz matches as
  pacing readings. Calls the real simulation functions; not a usability test, not a balance verdict.
- `results.json` — the run recorded here.
- `shot.gd` + `captures/` — early rendered checks of the four panel states.
- `gallery.gd` + `gallery/` — the real scene rendered under Xvfb through 48 scripted states: towns from four
  seeds, selection, dormant wires and the launch pad, a quiet scan and the revealed launch pad, a launched two-stream attack with a busy link, the
  inspect diagnostics, a capture, the rally point, the rate dial, a guard arming when its building is
  damaged, Cash packets, the inside view with its slot board (build, replace in progress), the research tab
  (the catalogue as card faces, LINKED and ANY, a running queue, paused, a hand of cards), a target's panel with
  the hand to drag from, a card packet in flight, a credential stuffing, a phishing, a worm flying downtown and
  its chain, the effect labels on the map, an attack by NYX, a scripted match at one-minute intervals on two
  seeds, and the three endings. `gallery/00_contact_sheet.png` is an overview.

Run (Godot 4.7.2, from a project folder that contains `scripts/` and `scenes/`):

```
godot --headless --path <project> --script res://probe.gd
xvfb-run -a godot --path <project> --rendering-driver opengl3 --script res://gallery.gd
```
