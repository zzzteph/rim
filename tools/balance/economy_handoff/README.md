# Economy handoff verification model

**Latest Claude task:** [CLAUDE_PROMPT.md](CLAUDE_PROMPT.md) now requests a finite-assault prototype with measured source exposure and a 10-host-versus-12-host scenario. It replaces the earlier economy implementation prompt, archived in `CLAUDE_PROMPT_ECONOMY_HISTORY.md`. The economic models and military-cost addendum below remain background; do not combine their optional changes with the assault experiment.

**Player identity concern:** [HACKING_IDENTITY_BRIEF.md](HACKING_IDENTITY_BRIEF.md) adds a proposed hacking/cyberpunk direction: temporary access, a corporate data theft operation, defensive interruption, and consequences for people in the city. The active prompt requests a separate next-prototype specification. The combat experiment alone does not establish this identity.

**Earlier economy follow-up:** candidate A has been implemented in the working tree. [MILITARY_ECONOMY_ADDENDUM.md](MILITARY_ECONOMY_ADDENDUM.md) retains a separate military-cost proposal for background. Run `python tools/balance/economy_handoff/military_economy_probe.py` for its independent calculations: 13 checks pass across 12 economic and 18 combat scenarios. Its results are in `military_economy_results.json`; no gameplay or full matches are simulated. The original model below intentionally retains the pre-patch baseline and will report config drift against the now-modified game.

Start with [HANDOFF.md](HANDOFF.md) for the design and implementation plan. Give Claude [CLAUDE_PROMPT.md](CLAUDE_PROMPT.md) together with this directory. The selected first candidate is **30 Crypto per farm and +15 Intel capacity per harvester**. The earlier 10-Crypto suggestion is retained only as a comparison.

Run from the repository root:

```powershell
python tools/balance/economy_handoff/model.py
```

This standard-library-only Python tool reads current configuration values, checks them against the audited baseline in `parameters.json`, and writes deterministic forecasts to `results.json`. It also records SHA-256 fingerprints of the current working-tree files. These fingerprints do not imply that the files match Git HEAD.

Edit the variants, scenario parameters or sensitivity ranges in `parameters.json`, then rerun. For separate experiments use `--parameters your_parameters.json --output your_results.json`. If authoritative game values change, the script fails: review the model's fidelity before changing `config_expectations`.

## Model contract

This is a budget and affordability model, not a match simulator. It supplies three kinds of evidence:

1. Exact configuration arithmetic: capacity, source rates, resource conversions, proposed price escalation and card opportunity cost.
2. Continuous-rate projections: how many funded miners support a specified building cadence, with sensitivity to farm prices and Intel capacity.
3. A deterministic 0.1-second funding simulation: externally requested construction jobs share a single resource pool, require the full per-job quote to queue, reserve nothing, and pay proportionally over at least ten seconds of funded work. The simulation records completed, blocked and unfinished jobs, spending, stock and active liabilities. It checks conservation and nonnegative balances at every step.

The simulator's update order is request, affordability/queue, job funding, then averaged income for the interval. Runtime packets, routes, attack reserves, Intel/Crypto conversion contention, labs, card research, control stages and combat are not simulated. The live runtime spends on card research before construction and performs producer conversion after construction; consequently a construction bottleneck can reduce lab output. Lab budget tables describe maintaining a specified output, not a runtime guarantee that Research has priority.

Construction stress requests occur at t=0, then every 15/30/60 seconds for 300 seconds. Each requests three farms. There is no inferred capture rate or invented opponent. The baseline scenario receives 10 Intel/s available after other expenditure; candidate scenarios receive the average output of a single funded miner, starting with 30 Crypto. They illustrate affordability, not strategies with equal total investment.

The 60-second outage scenarios receive no new cash and start with 0/30/100/900 Crypto, no jobs and no farm liability. They do not remove bots or disable existing bot farms. Three-farm burst cases start with 0/30/90/100 Crypto and expose the difference between a queue admission check and funding the whole host. A 900-Crypto case checks whether a mature wallet can absorb the whole disruption.

The model compares the baseline, candidate A at 30 Crypto, a conditional 20-Crypto alternative, and the superseded 10-Crypto proposal. Optional harvester escalation is a separate static affordability calculation. The 10/20/30 opening and recovery comparisons use a specific one-miner build order, not a claim about an optimal opening or a minimum possible time. Packet-threshold estimates account for discrete packet amounts on one miner before travel; the repeated-construction simulation still uses averaged income.

## Findings the model can support

- Phase A changes farm construction from 30 Intel to **30 Crypto** and changes each harvester's Intel capacity contribution from 50 to 15. Eight harvesters provide 220 capacity; ten provide 250.
- Crypto production costs one Intel per Crypto. The selected 30-Crypto price preserves the **30 upstream Intel** per farm. It adds miner infrastructure, slot and delivery requirements. The superseded 10-Crypto option is cheaper in material terms: one miner plus three farms costs 50 + 3*10 = 80 source Intel versus 90 for three baseline farms.
- One continuously funded ordinary outer miner produces 1/3 Crypto/s; a central ordinary miner produces 1/s; a central ERP miner produces 1.5/s. Corresponding Intel costs are the same rates. Credit arrival can be later than this ideal forecast.
- At 30 Crypto/farm, three farms per 15/30/60 seconds demand 6/3/1.5 Crypto/s. These are respectively eighteen/nine/five ordinary outer miners or four/two/one central ERP miners, before labs/cards or other cash spending. They are exogenous development rates, not simulated capture rates.
- A Supply card costs 40 Crypto directly plus 40 Research, which costs another 40 Crypto to produce. Its marginal Crypto opportunity cost equals **2.67 Phase A farms**, with existing infrastructure, versus eight farms at the superseded price. It also needs 30 Credentials, input Intel, production time and 35 seconds of card research. Research production and the card's research can overlap; their durations must not simply be summed.
- Three outer miners produce 1 Crypto/s. Maintaining a PC lab at 0.5 Research/s leaves 0.5 Crypto/s for farms: **one farm/minute**, compared with two without that research output. One outer miner cannot maintain that lab's full output without using a cash reserve.
- A bank of 30 Crypto can admit three 30-Crypto farm jobs because quotes are not reserved. With zero income they share that bank and none completes. A bank of 90 completes all three in ten seconds when uninterrupted. A player who queues just one farm could instead finish it using the 30 bank; the model's simultaneous three-job policy is explicit. Price times farm count is an eventual bill, not the immediate queue admission requirement.
- A one-miner opening with 50 starting Intel, uninterrupted construction, one ordinary miner and no competing spending takes approximately 10 + 90 + 10 = **110 seconds** to finish its first additional farm before delivery effects. Starting from zero Intel/Crypto and only the rig's Intel income adds 50 seconds for miner savings. Other build orders can be faster; pressure and competing spending can make them slower.
- Bounded optional harvester prices 20,25,30,35,40,45,50,50 total 295 Intel for the first eight. All remain below the base Intel capacity. A 10 × 1.5^n progression exceeds capacity on purchase nine when capacity gain is 15: price 256.289 vs capacity 220, using exact unrounded prices. A policy that rounds after every purchase can yield a different price and must be specified separately.
- Applying the current cap clamp with eight harvesters after a +15 change clips 400/500 Intel to 220, removing 180/280. The handoff should state whether the experiment starts fresh or applies any explicit migration policy.

## Validation and interpretation

`results.json` preserves inputs, source fingerprints, **16 hand-checkable cases**, fidelity markers, automatic invariant checks, variants, ordinary/boundary scenarios, sensitivity tables and limitations. All pass in the supplied run. The cases include three funding timesteps, zero income, shared quote affordability, explicit build duration, candidate prices and the exponential-price lockout. No randomness or external dependencies are used. The source markers are audit alarms, not proof that every future runtime edit remains compatible; a gameplay behavior change still requires a fidelity review.

Candidate A passes the material-cost-preservation check. The card-use guardrail and snowball outcome remain warnings requiring controlled matches. The model does not prove win rates, desirable match duration, comeback ability or that construction costs alone solve compounding. Free permanent bot output and uncapped Crypto remain in the proposal. No Godot gameplay tests or player sessions were run while preparing this bundle.

No game files are changed by this tool. Keep the full directory together so the implementation brief, editable model, provenance and results remain reproducible. For a standalone conversation, `HANDOFF.md` is self-contained and `CLAUDE_PROMPT.md` supplies the implementation request.
