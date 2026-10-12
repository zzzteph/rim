# Botnet prototype v2 — headless validation (2026-10-12)

Mechanics probe for `scripts/botnet_proto.gd` (now the game's main scene). A generated town, three botnets in a
free-for-all under fog of war, typed buildings with their own pictures, four resources (Cash, Credentials,
Research, Intel), link capacity, a slot board right in the panel (builds paid in Intel and left to run, several
per building), control stages, a rate dial, scanning (the first scout reveals), the six-family card system with
one reach, attack equal to defence, capture emptying the inside, and a majority-hold win with no clock —
validated with the designer's two-verb control scheme (wire by drag, launch from the target's panel, guards that
arm themselves) and two AI botnets that play under the same fog and the same reaction delay as the player.

- `all_cards.png` — every card face as the research tab draws them: six families (credential, phishing,
  1-day, 0-day, supply-chain, denial of service), the single card above its worm.
- `probe.gd` — SceneTree script: **46 fixture cases** on fixed town seeds, plus three full 10 Hz matches as
  pacing readings. Cases 27–41 cover the fog-bound AI (a twin test that perturbs only hidden fields, the public
  prior, scout-then-strike, visibility of others' flows, scan memory, the lawful counter-attack, limits,
  retaking, idle scouting, choking the leader, learned edges, worm value, a pacing guard, a UI twin test);
  42–46 cover the win and the build model (majority-hold, a supply-chain steal, a denial of service, the AI
  building unattended and paying Intel, player-memory symmetry); 06, 10 and 17 cover unattended multi-slot
  jobs paid in Intel, capture emptying the inside, and the slot board. Calls the real simulation functions; not
  a usability test, not a balance verdict.
- `results.json` — the run recorded here (46 cases, 0 fails).
- `shot.gd` + `captures/` — early rendered checks of the four panel states.
- `gallery.gd` + `gallery/` — the real scene rendered under Xvfb through **47 scripted states**: towns from four
  seeds; selection; dormant wires and the launch pad; a quiet scan and the revealed launch pad; a launched
  two-stream attack with a busy link; the inspect diagnostics; a capture; the rate dial; a guard arming when
  its building is damaged; Cash packets; the slot board in the panel (a build job running, slots full, a
  replace clearing then building); the research tab (the catalogue as card faces, a running queue, paused, a
  hand of cards); the leaderboard tab; a target's panel with the hand to drag from; a card packet in flight; a
  credential stuffing wiping defenders; a phishing halving them; a worm flying downtown and its chain; a DoS
  and a supply-chain steal side by side; the effect labels on the map; a building under attack and its board
  while attacked; paused; a scripted match at one-minute intervals on two seeds; and the three endings (you
  hold the majority, NYX holds it, you lose your last building). `gallery/00_contact_sheet.png` is an overview.

Run (Godot 4.7.2, from a project folder that contains `scripts/` and `scenes/`):

```
godot --headless --path <project> --script res://probe.gd
xvfb-run -a godot --path <project> --rendering-driver opengl3 --script res://gallery.gd
```
