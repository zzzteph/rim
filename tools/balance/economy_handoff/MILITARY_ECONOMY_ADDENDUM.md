# Next experiment: an economy that supports a fighting army

**Priority update:** the latest implementation request is the finite-assault experiment in [CLAUDE_PROMPT.md](CLAUDE_PROMPT.md). This paid-regeneration/cap proposal remains a separate design option; do not implement it alongside the assault prototype.

**Status:** proposal following the user's report that a few resource producers still support an expanding empire of full-farm hosts. This is about economic infrastructure, **not** stockpiling Supply chain attack cards. No card nerf follows from this report.

The current working tree already contains candidate A's 30-Crypto farm price and +15 Intel capacity per harvester. Preserve that work. The earlier `HANDOFF.md` describes that first experiment; it does not resolve the new report.

## Diagnosis

Changing the purchase currency adds a construction pipeline. It does not create a cost for operating the military: completed farms still regenerate bots for free. Once a small economy covers desired construction, additional income has little military purpose beyond more construction and cards.

There is a separate combat threshold. A four-farm ordinary host regenerates four bots/s; a five-farm ERP regenerates 7.5/s. Normal AI concentrates at most four sending hosts, each normally sending one bot/s. Without a card, outward defender drain, or some other disruption, those isolated targets cannot lose their garrison to four arriving bots/s. Increasing prices does not change that inequality.

**Revised vision:** holding quiet territory is affordable, but sustaining a larger fighting force requires more economic output. A stronghold buys time; holding it against concentrated attackers requires reinforcements or a tactical response.

## Exact test candidates

Test the two rules separately and then together. They address different failures.

### R: Pay for actual bot regeneration

- Every new bot regenerated outside the rig costs **0.25 Crypto**: one Crypto per four bots, paid proportionally with fractional production.
- A working owned rig receives an allowance of up to **2 bots/s of free regeneration**, limited by its active farms and their actual output. This preserves its starting two-farm output; it creates no bots when there is no working farm and does not bypass DDOS.
- Production above the rig allowance also costs 0.25 Crypto per bot.
- Charge only for actual bots added below the host's storage limit. A full garrison consumes nothing. Existing bots do not disappear when funds run out.
- If Crypto is insufficient, scale paid regeneration proportionally across eligible farms/hosts. No negative balances or processing-order advantage.
- Add a faction-wide **Pause paid bot regeneration** control, with the free rig allowance still operating. This makes saving for construction or cards an explicit choice.
- Keep farm purchase price at 30 Crypto for these initial tests. Track the combined construction/replacement burden; do not quietly lower prices to hide a failed recovery test.
- For the first implementation, preserve existing research/construction spending order; allocate paid regeneration from Crypto remaining after card research and construction, before lab conversion. Make the timing change explicit and test it. Calculate all hosts' demand before allocating funds.
- The rig allowance applies to its farm output, not a separate passive source. A faction without a working rig is already eliminated under the existing rules.

**Opening change:** the initial PC's regeneration becomes paid, although its initial 30 bots remain. This can slow the opening before the first miner. The rig allowance prevents complete production lockout but does not prove the opening remains fun. Run normal-start and failed-offensive tests; reject or retune if economic waiting dominates.

This makes the cost scale with **actual fighting and replacement**, not with the count of idle owned hosts. A few miners may reasonably support a quiet empire. The goal is to stop them supporting an arbitrarily large simultaneous replacement demand.

### G: Cap permanent regeneration at 2 bots/s per owned host

Use:

`potential_regen = min(2, active_farms * base_bot_rate * host_bot_multiplier) * temporary_production_multiplier`

- Apply the cap after host multipliers and before a temporary CDN boost.
- Keep current bot storage: 30 times the number of built farms, with a minimum of 30 on an owned host.
- Keep neutral security regeneration unchanged.
- Keep normal per-source sending rate at 1 bot/s.
- The initial rig's two farms still produce 2/s, and a one-farm ERP still produces 1.5/s. Additional farms beyond the local rate limit buy storage, not unlimited regeneration. Show this honestly in building previews and descriptions.
- When combined with R, charge only for the funded production actually delivered after the cap and temporary modifiers. CDN increases paid demand as well as potential output; it does not create extra free allowance.

Normal AI must try feasible source counts up to its existing four-source maximum instead of always selecting the smallest count giving positive damage. At 2 regeneration/s, three sources need 150 seconds to wear down a 150-bot ERP, beyond the existing 120-second siege budget. Four need 75 seconds before travel. Update both runtime regeneration and enemy estimates, including visible temporary boosts. Preserve fog restrictions.

## Predictions to check

The accompanying `military_economy_probe.py` verifies these rate relationships. They are not full-match forecasts.

### Economic demand at R's candidate price

All examples below concern paid regeneration outside the rig. Ordinary outer-city miners produce one third Crypto/s and need matching Intel input.

| Actual replacement output | Crypto consumed/s | Ordinary outer miners needed, before cards/labs |
|---:|---:|---:|
| 4 bots/s | 1 | 3 |
| 8 bots/s | 2 | 6 |
| 12 bots/s | 3 | 9 |
| 20 bots/s | 5 | 15 |

Six ordinary outer miners can fund eight replacement bots/s, not unlimited regeneration. With one fully supplied ordinary lab consuming 0.5 Crypto/s, six such miners leave funding for six bots/s. Six ordinary downtown miners produce 6 Crypto/s and can fund 24 paid bots/s; six downtown ERP miners produce 9 Crypto/s and can fund 36. Geography is deliberately valuable, so do not present the outer-city numbers as universal.

A 100-Crypto reserve can buy 400 replacement bots before new income, construction, or research. The reserve still matters; this rule is not an instant shutdown mechanic. Miner attacks affect future replenishment after the wallet is consumed.

### Isolated strongholds at G's candidate cap

Assume four continuously arriving attacking bots/s, full funding, no guards, no outward defender flow, no cards, and full Crypto funding if R is also active. Ignore travel and packet timing.

| Target | Current regeneration | Proposed regeneration | Current depletion time | Proposed depletion time |
|---|---:|---:|---:|---:|
| Ordinary host, 3 farms / 90 bots | 3/s | 2/s | 90 s | 45 s |
| Ordinary host, 4 farms / 120 bots | 4/s | 2/s | No progress | 60 s |
| ERP, 5 farms / 150 bots | 7.5/s | 2/s | No progress | 75 s |

Formula: `garrison / (attack_arrivals - regeneration - reinforcement + outward_drain)` when the denominator is positive.

One guard sending one bot/s increases the capped ERP example to 150 seconds. Two guards can stop four attackers. That defense commits other hosts and routes; it is valid counterplay. Do not promise that a supported host is always capturable. Four hostile streams also spend four Intel/s: the 75-second example costs 300 Intel over time.

The previously suggested gentle diminishing-return curve would still give a five-farm ERP 3.375 bots/s and a 240-second depletion time against four sources. It is too weak for this particular four-source threshold.

## Validation and decision

Use four versions on the same fixed maps and normal starts: current implemented economy, R only, G only, and R+G. First run deterministic local funding/combat fixtures; then replay the user's strategy using a fixed small resource core and full-farm captures. Include an adapted opponent that funds and concentrates attacks correctly.

Required mechanical cases:

- Empty/full garrison; zero/partial/sufficient Crypto; paused paid output; no farms; DDOS; CDN; rig allowance; shared funding independent of host order.
- No payment for output lost at the bot cap. No deletion of existing bots. No double charge on reinforcements or hostile departures.
- Initial PC and rig behavior explicitly covered. Preserve attacks' existing Intel cost.
- Runtime `_regen`, `_sim_step`, AI estimates, UI rates, and tests agree; a helper-only change must not leave the simulation using the old uncapped formula.
- AI budgets construction, card research, and replacement separately and establishes miners from a zero-Crypto start. Multiplayer remains deterministic.

Accept R only if expanded simultaneous fighting causes measurable replacement spending and recurring economic choices, while the player can still save for a card and recover. If a six-producer setup still covers all relevant demand, report its location, delivered rate, reserve, lab/card spending, and actual replacement rate before raising the price. Sweep **0.15 / 0.25 / 0.5 Crypto per bot** using the same workload; do not claim that any rate solves the strategy before playtesting.

Accept G only if an unsupported full-farm host can be worn down by properly funded concentration and the AI actually attempts feasible attacks. Extra storage should still buy meaningful time; guards and temporary cards should still help.

Do not use longer matches or a defeated broken AI as the success metric. The desired result is that the player must choose which fronts to fund, which captures to develop, and which strongholds to reinforce. A permanently idle empire needing little spending is not a failure of this design.

## Claude instruction

Preserve the already implemented economy changes. Treat this as the next experiment, not a request to rerun candidate A. Implement R and G as independently testable candidates, with the mechanics and AI/UI work above. Report baseline, R-only, G-only, and combined outcomes; keep only supported changes. Do not change Supply cards, add empire upkeep, or introduce capture settling as part of this experiment.
