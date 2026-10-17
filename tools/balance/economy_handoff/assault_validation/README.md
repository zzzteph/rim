# Finite assault: validation

These files test the finite-assault prototype requested in `../CLAUDE_PROMPT.md`. None of them is part of the game build.

| File | What it is |
|---|---|
| `../assault_model.py` | Fixed-step flow model used to choose the provisional values. It writes `../assault_model_results.json`. Calculated predictions only. |
| `assault_scenarios.gd` | The five decisive 10-host vs 12-host scenarios on the real simulation. Results are in `assault_scenarios_results.json`; `summarize.py` produces `assault_scenarios_summary.txt`. |
| `ai_usage.gd` | AI-only Small matches that count Normal AI assault orders and record how each match ends. |
| `../../../../tests/assault_test.gd` | Mechanics suite: 51 checks covering quotas, Intel, routes, streets, transitions, exposure and AI. |

Commands, run from the repository root:

```
python tools/balance/economy_handoff/assault_model.py
godot --headless --path . --script tests/assault_test.gd
godot --headless --path . --script tools/balance/economy_handoff/assault_validation/assault_scenarios.gd -- --out out.json
python tools/balance/economy_handoff/assault_validation/summarize.py out.json
```

## Scenario setup

- **Maps:** Small 6×4 layouts, seeds 5, 11 and 23. Each layout is played twice, with the sides swapped.
- **Territories:** side A has 10 hosts and side B has 12. Both grow breadth-first from their own rig.
- **Development:** every host has 2 farms, 1 harvester and a full garrison. Each bank starts with 150 Intel.
- **Players:** AIs are frozen. Both sides issue scripted commands through `_apply_cmd`, under identical rules.
- **Scripted responses:** these read exact garrisons, which is an upper bound on what a player could see.

**Modes:**

- **current:** streams only, as in the game before the prototype.
- **finite:** assault orders with farms still regenerating.
- **exposure:** assault orders with the source's farms resting while the order stands. This is the shipped default.
