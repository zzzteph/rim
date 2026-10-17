# Candidate A validation harness

Paired experiments for HANDOFF.md §7. Not part of the game build.

## Setup

Three project copies, identical except for the economy constants:

| Copy | Bot farm | Intel limit per harvester |
|---|---|---|
| `base` | 30 Intel | +50 |
| `cand` (candidate A) | 30 Crypto | +15 |
| `c20` (conditional fallback) | 20 Crypto | +15 |

All three run the same game code, including the Crypto-aware Normal and Insane AI. Make a copy by duplicating the repository and editing `scripts/botnet_cfg/buildings.gd` (`BUILD_COSTS.bot`) and `scripts/botnet_cfg/tuning.gd` (`INTEL_CAP_PER_BUILD`).

## Matches

- Map: Small 6×4, seeds 7, 19 and 43. The human seat is vacated, as in `tests/ai_insane_test.gd`.
- Players: three Normal AI botnets. Faction 2 (NYX) is the policy player. It keeps the Normal AI's attack, defence and scan logic, but its construction decisions come from the policy through `ai_build_hook`. Factions 3 and 4 are unmodified Normal AIs.
- Length: matches stop at the first win or at 900 s.

Policies (none of them uses cards):

- **original:** harvesters go into the start slots. Every capture is filled with Bot farms whenever the bank minus job debts covers the price. More harvesters are added while Intel income is below 8/s. It never builds a miner.
- **adapted:** the original plan, plus a miner whenever miner capacity with a route home is below max(1/3, 2.5 farms' worth of Crypto per capture over the last 120 s). Miners go on the richest host with a route home. Miners are paused while free Crypto exceeds three farms, and resumed below one and a half.
- **adapted_late:** adapted, but no miner until after the first capture.

Under `base`, the farm costs no Crypto, so the miner rules never fire and all three policies give identical results.

## Fixtures

Economy only; AIs frozen.

- **Opening:** normal start, no grants. Either a miner on the best start slot, or one harvester then a miner. The farm is ordered the moment it is affordable.
- **Recovery:** only the rig is left, with 1 farm and 3 empty slots, empty banks and no miners. Either direct (miner, then farm) or optimised (harvester, miner, farm).
- **Synthetic midgame:** identical in every ruleset. The rig plus the 5 nearest ordinary hosts carry farms and harvesters; the 2 richest also carry a miner. 3 fresh empty captures give 9 empty slots.
  - **Prepared:** 150 Intel and 0 Crypto, or Intel at the ruleset's own cap. Records farms standing after 30, 60, 120 and 180 s.
  - **Interruption:** a Crypto bank of 0, 30, 100 or 900. Every miner is paused for 60 s, with up to three farm jobs.
  - **Card alternative:** 150 Intel and 60 Crypto. A neutral neighbour becomes a rival fortress (3 farms, 90 bots). Card path: credential harvester, lab, Supply research, play the card, attack. Farm path: farms, then attack at 60 s.

## Running it

```
godot --headless --path <copy> --script econ_experiment.gd -- --mode match --seed 7 --policy adapted --out m.json
godot --headless --path <copy> --script econ_experiment.gd -- --mode fixtures --seed 7 --out f.json
python analyze.py <dir with the json files>
```

`results/` holds the JSON from the runs reported to the user, plus `analysis.txt`.
