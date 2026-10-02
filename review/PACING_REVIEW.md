# RIM: speed and progression review

Reviewed 2 October 2026. Documentation only; no gameplay changes were made for this follow-up.

The current project identifies itself as **0.5.7**. The original [120-item review](GAME_REVIEW.md) used the earlier 0.5.6 snapshot. This addendum inspects the current production rules rather than treating that snapshot as the latest build. Initial inspected `scripts/main.gd` SHA-256: `1C79DD4A8166D6F12641BE456625ACD6DC0E252BB9D7851374E5500A76D843EF`. The live source changed during documentation; the pacing constants, clock, contracts and victory rules were rechecked against the subsequent source (`20425E6245FFC706EEBBD4EA109C4B3568E663008441416B294A3EC5FD2F569F`) and the relevant rules and line references remained the same. This review did not edit game code.

## Assessment

Your concern is supported by the progression rules. RIM currently has the structure of a short network-economy scenario: establish a working income route, scale it, and accumulate 1000 Cash. It has several advanced systems, but the victory condition does not require the player to graduate from the opening economy to a more capable operation.

That can make progress feel very fast even when the simulation clock is running normally. It can also produce the opposite experience on an inefficient opening: a long wait while doing essentially the same task. Both outcomes come from the small number of required economic stages.

These are code-backed findings and analytical examples, not measured completion times from representative human playtests. No full-run timing claim is made here. The game-design specialist reviewed this diagnosis and the proposed progression structure alongside the earlier simulation and UX reviews.

## What “speed” means here

| Layer | Current evidence | Design implication |
|---|---|---|
| Simulation clock | `_process(delta)` accumulates elapsed time and advances in 0.1-second steps. Production multiplies its rates by `dt`. | Ten simulation ticks per second do not mean 10× speed. Higher frame rate should not increase economic production. |
| Player speed control | Pause is present; the inspected scripts expose no simulation fast-forward multiplier or speed selector. | The compressed progression is already possible at the ordinary clock rate. Any future 2× or 3× control needs separate balancing. |
| Local feedback | Packets travel at 60 pixels/second; a tile is 24 pixels. A ten-tile route takes roughly four seconds plus endpoint geometry, before starvation slowdown. | Transfers are deliberately quick. Slowing packet animation alone does not create a deeper economy; a pipeline can still maintain throughput. |
| Deployment | A paid structure is inserted immediately, with no construction queue. Research unlocks immediately when RP is spent. | The whole build budget can be deployed quickly, including while paused. Instant placement can remain enjoyable, provided obtaining and supplying advanced capacity creates meaningful work. |
| Progression | Victory checks the current Cash balance against 1000. | Advanced research, Tools production, Crypto laundering, protected expansion, and a developed backbone can all be skipped. |

Evidence: [clock](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1330), [production](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1517), [packet speed](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:15), [deployment](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1225), [research](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1045), [victory](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1567).

## Why the journey compresses

1. **The opening chain is also an endgame solution.** Cycles support an Intel collector, and a Market converts Intel to Cash. The tools needed for this route are available from the start. Additional technology can make it more effective, but is not required for victory.
2. **Research has little depth.** Six of seven technologies have no technology prerequisite. The only dependency is Exploit Development before HTTP/2. Buying upgrades can become a list of purchases rather than a sequence of new production problems.
3. **The research workload is small.** All seven technologies together cost 115 RP. A continuously supplied Lab consumes at 0.5 units/second, so its ideal processing workload is 230 seconds, or 3 minutes 50 seconds. Real delivery losses, input supply, fuel, startup and transport increase this. Nevertheless, the underlying workload is measured in minutes, before contract rewards reduce it further.
4. **Contracts can pay for existing possession.** Stock contracts check the current stockpile and do not consume it on completion. A Cycles contract asks for 20–50 units; the game starts with 80. Where the random offer permits, the player can receive 50–125 Cash and 5 RP without creating an additional delivery. A Cash-possession contract awards 14 RP. Research can therefore advance without operating a Lab. Offer randomness and a full board prevent treating these rewards as guaranteed continuous income.
5. **Cash investment competes with the finish line.** Advanced infrastructure spends the same balance needed to win. Near 1000 Cash, keeping the opening network running may be a better short-term choice than exploring a new capability. This discourages the late investment that should make the ending satisfying.
6. **Location changes the economic tempo substantially.** Coverage multiplies producer output between 0.5× and 2.5× before overclocking and other limits. That is a fivefold gross-output range. Actual returns also depend on route length, upkeep and loss; sparse coverage can make a layout unprofitable while a dense opening compounds quickly. A universal price increase would punish those cases differently.
7. **Threat adds interruptions without guaranteeing a new economic stage.** Sweeps, quarantines and blackouts can demand attention, but victory can still come from restoring the same short income chain. More attacks alone would lengthen recovery and repeat familiar work.

Evidence: [starting tools and technology costs](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:32), [build costs](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:73), [coverage](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1409), [contracts](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1659), [claim behavior](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1730), [threat and win checks](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1556).

## How quickly can the current Cash objective accumulate?

The Market price is `clamp(1 - Cash / 2000, 0.3, 1)`. Before the 1000-Cash goal, that price declines from 1 to 0.5; the floor does not apply yet.

Let `q` be a constant effective sales rate arriving as Cash, measured in units/second **before the price discount but after delivery losses**. Approximate the steady income phase by:

```text
dCash/dt = q × (1 - Cash/2000)
time from 0 to 1000 Cash = 2000 × ln(2) / q seconds
```

| Effective sales rate | Approximate earning time to 1000 Cash |
|---:|---:|
| 0.5 units/second | 46.2 minutes |
| 1 unit/second | 23.1 minutes |
| 2 units/second | 11.6 minutes |
| 3 units/second | 7.7 minutes |
| 6 units/second | 3.9 minutes |

These examples assume a functioning, continuously supplied network, a starting Cash balance of zero, and no spending, contract income, threat penalties or changing throughput. They exclude setup and planning. Price is assigned during conversion rather than exactly at final arrival, so the continuous model is an approximation. Higher rates require sufficient producers, power and transport, and potentially multiple Markets; the table does not demonstrate a legal six-units/second opening.

The useful conclusion is that a small Cash target can be exhausted quickly by a scaled network. Increasing it alone would extend the same earning phase. [Pricing evidence](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1105).

## Lessons from the reference games

The reference games are useful for their progression structure, rather than as universal session-length benchmarks. Scenario, player experience, difficulty and speed settings all affect completion time.

Factorio's developers describe how alternative research paths and science requirements gave players time to use intermediate upgrades. That is directly relevant to RIM: an upgrade needs a useful operating period before its successor arrives. This is a historical design rationale from 2018, not a claim about current average Factorio completion times. [Factorio, Friday Facts #275](https://www.factorio.com/blog/post/fff-275).

Constructor's official description includes houses and factories, competing property operations, tenant demands and disruptive characters. Those interacting demands give the player more to manage than a single accumulating balance. RIM could adopt that pressure through clients, district demands and competing operators without copying its setting. [System 3, Constructor](https://system3.com/product/constructor/).

Your K&M example identifies another useful direction: growth that needs an operating supply network before the next expansion can happen. A RIM equivalent could be delivered deployment parts, specialist operator capacity and district access. Those are proposed adaptations, not verified claims about K&M's completion time.

## Proposed pacing target

For the first substantial standard scenario, use **90–120 minutes of unpaused simulation at 1×** as an initial design and playtest hypothesis for a competent player. It is not a measured current duration or a promise that the present content can support two hours.

If a future 3× control advances every simulation system consistently, that represents approximately 30–40 minutes of unpaused wall time, plus paused planning and time spent playing at slower speeds. New players may need considerably more time. A longer campaign should earn its duration through distinct missions and new economic problems.

| Proposed format | Initial duration hypothesis | Purpose |
|---|---|---|
| Guided introduction | 10–20 minutes | Learn one recoverable production route and read the bottleneck feedback. |
| Short operation | 20–40 minutes | A focused layout or defense problem with a deliberately narrow objective. |
| Standard operation | 90–120 minutes at 1× | Develop from a small intrusion into a sustained city-scale network. |
| Sandbox | Open-ended | Build and optimize with configurable pressure and voluntary milestones. |

These are proposed formats and targets, not claims that these four modes are currently implemented.

## Give the standard operation five stages

| Share of the progression journey | Stage | Required new capability |
|---|---|---|
| First 10% | Bootstrap | Stabilize Cycles, collect Intel, make the first sale, and retain a recovery reserve. |
| Next 20% | District operation | Expand into a useful cluster and resolve a genuine supply or transport bottleneck. |
| Next 25% | Specialization | Choose a bulk-throughput, stealth or laundering approach and demonstrate its benefit in operation. |
| Next 25% | Metropolitan network | Support multiple district demands and a backbone while handling predictable, recoverable pressure. |
| Final 20% | Major extraction | Supply a protected Spire or other final target and maintain a demanding route until the operation succeeds. |

The percentages describe a desired distribution of meaningful progress, not timers that forcibly lock the player out. A strong player can reach stages earlier. Branches should provide equivalent ways to satisfy capabilities; requiring every technology would reduce strategic choice.

For example, a final operation might require a delivered quantity of Tools, a sustained Intel flow, adequate Cycles reserve and a successful extraction. A stealth network and a bulk network could satisfy it differently. Cash funds the preparation, while completing the operation determines victory. Exact quantities should come from network throughput tests and playtests.

Each stage should let the player **build, operate, discover a limitation, improve, and enjoy the improvement**. Completing an upgrade should change the next decision, rather than simply shorten the wait for the same counter.

## Recommended solutions, in order

1. **Resolve the economy and persistence defects in the main review before balancing duration.** Routing, OFF behavior, soft capacities, save/load state and recoverability affect the rates being tuned. An exploit or an impossible opening can distort pacing data.
2. **Separate operational victory from banked Cash.** Replace the standard operation's sole balance check with capability milestones and a supplied final objective. Keep a 1000-Cash sprint as a short scenario if desired.
3. **Make recurring contracts represent new work.** Use goods actually delivered, production accumulated since acceptance, or a sustained operating requirement. Treat possession checks as one-time milestones. Define the delivery/consumption rule in the contract UI and allow unsuitable offers to be declined. Reward actual effort and test reward share of income and RP.
4. **Add research tiers with continuing economic demand.** Early RP teaches the system. Later advances should require a new supply arrangement or specialized research input. Preserve alternative branches. Tune later workloads against effective delivered output, rather than adding another flat RP price to the same cheap process.
5. **Make advanced deployment an economic project.** Manufactured parts, delivered supplies or a limited installation team can give infrastructure an opportunity cost. Retain responsive placement previews and early deployment. A generic delay on every building would add waiting without necessarily adding a decision.
6. **Give districts and clients ongoing needs.** Require simultaneous service, reliability or differing resource mixes. Expansion should introduce a new allocation problem, with a visible payoff and a way to recover from shortages.
7. **Tune investment returns across the full chain.** Include producer output, coverage, upkeep, research, route loss, conversion, Cash expenditure and recovery reserves. Avoid tuning all prices from the best dense-city opening. The expected remaining scenario must be long enough for a useful upgrade to repay its cost.
8. **Provide deliberate speed and planning controls after progression works.** Proposed controls: pause, 1×, 2× and 3×, with readable status and optional auto-pause on urgent threats or starvation. Timers, contracts, packet movement and threats should advance consistently. Faster play should remain usable with keyboard controls and reduced motion.

## What to measure before choosing final numbers

Run a small formative playtest with new and experienced players across several dense and sparse starts. Include a direct-Cash strategy, a technology-investment strategy and a contract-heavy strategy. A small pilot reveals problems; it does not establish statistically reliable completion-time averages.

Record simulation time and wall time separately, plus paused time and selected speed. Track first stable Cycles income, first sale, first useful research deployment, district milestones, major reinvestments, recovery events and victory. Record Cash and RP earned through contracts separately from production.

Look for periods where the player is waiting for a balance with no useful alternative action, upgrades that are never used, repeated rewards for unchanged stock, and stages skipped by the shortest strategy. Ask players whether they understood the bottleneck and whether the improvement felt worthwhile. Fast execution should remain a reward for mastery; repeated idle accumulation should trigger a redesign of the next demand.

Do not accept a longer average duration by itself as proof of improvement. A successful revision should produce a longer sequence of understandable, rewarding decisions while preserving quick feedback from each action.
