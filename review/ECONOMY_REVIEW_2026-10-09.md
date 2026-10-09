# RIM economy review — 9 October 2026

Reviewed `data/ECONOMY_GUIDE.md` (the requested `.mdd` appears to be a typo), `data/economy.json`, and their implementation in `scripts/econ.gd`, `scripts/building.gd`, `scripts/city.gd`, `scripts/menu.gd`, and `scripts/session.gd`. No economy settings or gameplay code were changed for this review.

**The strongest current incentive is to establish productive capacity in easy residential PCs. Corporate targets lack a distinct economic prize; Cash and Crypto have very little demand. Correctness and feedback issues also obscure the balance.** Establish resource purposes, corporate rewards, and reliable feedback before broadly increasing prices or reducing income.

This is a review of the current city/building mode, not the separate legacy `netrun.tscn` economy. Calculations below describe the inspected snapshot; proposed values are experiments, not measured optimal settings.

## Evidence and limits

- The existing `review/building_checks.tscn` suite passed: 90 generated interiors across six building configurations, plus the suite's economy checks; zero reported failures.
- Eight isolated checks against the actual `Econ` and building code confirmed capped-output input waste, converter ordering, starved-converter heat, disconnected storage/cooling behavior, disconnected alarm eligibility, a guaranteed cold production loadout, absent natural cooling, and stale heat text. The diagnostic scene is in ignored local scratch space, `.godot/economy_review/probe.tscn`.
- Some diagnostic checks deliberately force emission or alarm probability to 100% to establish eligibility or worst-case behavior. These are **not** claims that ordinary nodes always emit or alarm.
- The main building tests use abundant resources, disable several economy constraints, and force successful progress for the graph-solvability check. They establish mechanics, not player pacing or strategic balance. No full player-session simulation or human playtest was conducted.

## 1. Resource demand is incomplete

| Resource | Current flow and demand | Recommended purpose |
|---|---|---|
| Intel | Passive income and producers; pays for all actions and deployments; also feeds Market and Forge. | The frequently spent operational resource. Keep a recovery path when the player loses infrastructure. |
| Cash | Market and Mixer output. Its only current spending opportunity is the 10 Cash component of Credential Dumper deployment. | Finance durable upgrades, new tool research, contacts, and optional emergency services. |
| Credentials | Keyloggers/Dumpers; one spent per boosted login capture attempt. | Access preparation, potentially with targeted credentials obtained from story investigations. |
| Exploits | Forge consumes Intel; one spent per boosted software capture attempt. | A deliberately valuable way to tackle protected software; make the input cost or effect competitive. |
| Crypto | Mining output; only consumed by Mixer to make Cash. | An alternative source of useful Cash. Its value depends on fixing Cash demand first. |

Ten Cash requires 20 seconds of a fully supplied Market or 12.5 seconds of a fully supplied Mixer. The Market also consumes 20 Intel to make those ten Cash, excluding its 15 Intel deployment cost. A Mixer needs an additional Crypto source or existing stock.

One Dumper costs 35 Intel + 10 Cash and produces 0.2 Credentials/s. Three Keyloggers cost 45 Intel and produce 0.24/s. The Dumper retains a real advantage: it uses one slot instead of three. However, easy access to more residential slots weakens the value of that compression. This is not strict domination in every situation.

**Recommended first expansion:** add a small, visible Cash-funded progression ladder with consequential purchases. Keep some optional repeatable demand, such as buying a specific lead or arranging emergency cleanup. Avoid introducing compulsory upkeep everywhere before establishing whether managing a large network is enjoyable.

## 2. Corporate difficulty needs corporate rewards

For a fresh, already detected target with success probability `p`, independent retries, and no consumable, expected profile-plus-capture spending is:

`3 / p + 8 / p = 11 / p Intel`.

| Target/security | Profile/capture chance | Expected Intel | Slots | Intel per slot |
|---|---:|---:|---:|---:|
| Residential PC, “None to speak of” | 87.3% | 12.60 | 6 | 2.10 |
| Core, Corporate ICE | 41.6% | 26.44 | 8 | 3.31 |
| Core, Black ICE | 24.7% | 44.53 | 8 | 5.57 |
| Core, Lethal black ICE | 15.6% | 70.51 | 8 | 8.81 |

Sources: `building.gd` `NODE`, `SEC_DIFF`, `TYPE_MOD`, `_chance`, `_profile`, `_take`. These figures exclude discovery, any prerequisite captures, deployment, travel/click time, and heat losses. A scan can reveal multiple neighbors, so assigning a fixed discovery charge to every node would be misleading.

The lethal core costs 5.60 times as much in these target actions for 1.33 times the slots. PCs and cores accept the same program categories; installed tools have the same output regardless of building security or industry. Entering another building is currently free and grants its entry firewall.

There is nuance: deployment capital reduces the disparity. A guaranteed cold PC with four Harvesters and two Cloaks costs 220 Intel to equip and makes 6.4 Intel/s. A guaranteed cold core with five Harvesters and three Cloaks costs 285 and makes 8/s. Including the target action costs above, their simple gross capital-recovery times are approximately 36.3 and 44.4 seconds, respectively. These assume immediate deployment and continuous useful output, exclude path costs and passive income, and are not actual new-game completion times. Large sites also concentrate more nodes behind one entry.

**Recommendation:** give corporate objectives exclusive value: a research unlock, a contract payout, a unique dataset, a connection to another company, or a story consequence. Tie the reward to recovering evidence or achieving a specific objective, rather than paying a repeatable bounty every time the same node is recaptured. Preserve useful residential footholds while making corporate infiltration the route to advancement.

For the requested corporate stories, an email chain could reveal a contractor's credentials, identify the server holding evidence, then enable a decision to sell, expose, or return that evidence. Each route can have different Cash, access, or reputation effects. These are proposed mechanics; they do not exist in the reviewed economy.

Also inspect network topology before promising a fixed infiltration depth: `_generate()` selects any shallower parent, including the entry firewall. A core can therefore attach directly to entry. Decide whether that shortcut is desirable variety or should be constrained for important objectives.

## 3. Production compounds faster than the stockpile supports

Scraper's direct deployment payback is `10 / 0.6 = 16.7 seconds`; Harvester's is `45 / 1.6 = 28.1 seconds`. Both exclude access, cooling, cap waste, and time spent assembling the installation. Tier 2 is cosmetic today, so advanced equipment has no research requirement.

The cold four-Harvester PC produces 6.4 Intel/s, or 7.4 including baseline income. With no spending or converters, the default 100 Intel cap fills from empty in **13.5 seconds**. Additional infrastructure quickly produces overflow rather than useful income. Faster production then encourages constant spending, storage deployment, or ignoring the economy once it is abundant.

One scalar cap also treats unlike resources as equivalent. A cap of 100 Intel covers only 12.5 base capture attempts before other costs; 100 Credentials supports 100 boosted attempts; manufacturing 100 Exploits consumes 1,000 Intel. Their appropriate buffers need not match.

**Recommendation:** support resource-specific caps, then tune by desired uninterrupted play time and major purchase size. For example, 30–60 seconds of buffer at 7.4 Intel/s requires roughly 222–444 Intel. That is a pacing experiment, not a proposed universal starting cap. Storage should create planning options, rather than requiring a player reading an email to check the HUD every few seconds.

Keep passive recovery income initially. Setting it to zero, as the guide permits, can leave a bankrupt player with no producers and no means to pay for recovery.

## 4. Heat has a sharp safe-loadout boundary

All current emitters add at most one heat per second; each Cloak removes two. Thus a node with `N` emitters and `C` Cloaks cannot gain heat when `N <= 2C`, regardless of their noise probabilities. Four Harvesters plus two Cloaks on a PC are guaranteed cold. The worst-case diagnostic forced all Harvesters to emit every second for 600 seconds and confirmed this.

This can be an intentional exchange of slots for safety. Increasing `noise` alone cannot make that particular loadout dangerous: its maximum emission already equals its cooling. The guide's suggested noise tuning therefore cannot address every safe build.

Without cooling, heat accumulates permanently. A lone Harvester reaches 50 heat after an expected 90.9 seconds and 100 after 181.8 seconds if earlier minute alarms are ignored. A lone quiet Data Vault reaches those thresholds after 625 and 1,250 seconds. Quiet means delayed trouble, not indefinite safety. Empty warm nodes also retain their heat.

For a node staying at or above 50 but below 100, ten minute rolls give a `1 - 0.95^10 = 40.1%` chance of at least one alarm. Across 20 such nodes, a single minute boundary gives a `1 - 0.95^20 = 64.2%` chance that at least one alarms, assuming independent rolls. A large warm network can become a maintenance burden.

Five burns multiply action price by 1.5 and unboosted probability by 0.75, so the expected price of a still-required action doubles where probability clamps do not intervene. This is a relative probability reduction: 64% becomes 48%, not 39%. Profiling and enumeration survive alarms, so the whole recovery cost is not simply twice the initial infiltration cost.

**Recommendation:** explicitly support a safe, slower configuration and a faster, risky configuration. Add program pause controls, readable cooling forecasts, and an idle cooling policy. If alarms remain destructive, warn reliably and consider a shutdown/trace grace stage before a complete wipe. Include pause/time controls for reading long story archives; production and alarms currently continue while the city/building screen is active.

## 5. Freshly manufactured Exploits often lose the Intel comparison

Forge spends 1 Intel/s to make 0.1 Exploits/s: **10 Intel per Exploit**, before the Forge's installation, slot, or cooling costs.

With fresh unburned capture chance `p` and a manufactured Exploit spent on every attempt:

- Plain capture costs `8 / p` Intel in expectation.
- Boosted capture costs `18 / min(p + 0.3, 0.99)` Intel in expectation.

In the relevant unsaturated range, boosting saves Intel only when `p < 0.24`.

| Core security | Plain expected Intel | Including manufactured Exploits |
|---|---:|---:|
| Corporate ICE | 19.23 | 25.14 |
| Black ICE | 32.39 | 32.91 |
| Lethal black ICE | 51.28 | 39.47 |

These are capture-only costs. Profile costs are unchanged. Boosting can still save clicks and reduce variance; stockpiled surplus Exploits have a different opportunity cost. Burn penalties also change the break-even point. Credentials need a separate analysis because their producers do not consume Intel per unit.

**Concrete isolated tuning experiment:** reduce Forge input from 1.0 to 0.4 Intel/s while retaining output at 0.1/s. An Exploit then costs four Intel to manufacture; the corresponding fresh-node break-even becomes `p < 0.60`. Alternatively, give Exploits a stronger or distinct tactical effect. Test one of these changes at a time after fixing converter waste.

## 6. Random retries produce friction without much counterplay

Network scan, endpoint profile, and capture each roll independently and spend Intel on failure. Consumables boost capture only. At 15.6% capture probability, 18.3% of attempts sequences still have no success after ten tries. Reaching at least 95% cumulative success requires 18 attempts, costing up to 144 Intel for that capture alone. A 95% cumulative success threshold is not a hard guarantee.

There is no action-generated heat charge in `_net_scan`, `_profile`, or `_take`; heat comes from installed tools. Consequently, a difficult empty target mainly tests the player's Intel supply and willingness to retry.

**Recommendation:** make discovery deterministic at a known cost, or retain progress on failed discovery. Reserve meaningful uncertainty for intrusion, with preparation or accumulated progress improving the odds. Measure long failure streaks, not just average capture time. Raising prices across all three retry gates would amplify frustration without adding decisions.

## 7. Correctness and feedback fixes to do first

| Priority | Confirmed behavior | Proposed change |
|---|---|---|
| P0 | At 100 Cash, Market still consumes 1 Intel/s, cancelling passive recovery income while discarding its output. HUD still reports +0.5 Cash/s. | Limit converters by useful output capacity as well as input; offer pause controls. Distinguish potential, actual, and discarded output in feedback. |
| P0 | With zero Intel and only +1/s passive income, `[market, forge]` produces Cash only, while `[forge, market]` produces Exploits only. | Allocate scarce inputs by explicit player priority or a predictable shared allocation rule, instead of incidental installation/iteration order. |
| P0 | The selected heat panel remains at 0% after live heat is synchronized to 80%. | Refresh heat text and map warning indicators during simulation. Refresh boost availability when resources cross its threshold. The stale text was reproduced; boost-button behavior follows the same source refresh limitation. |
| P0 | The current city/building state persists only in session memory. Menu Continue opens the older `netrun.tscn` flow. | Add save/load and a correct resume route for this mode before tuning a long progression curve. |
| P1 | A starved Forge still emits heat. Capped producers remain noisy. | Define whether idle tools remain active; if they stop work automatically, stop their associated activity heat too. Communicate the policy. |
| P1 | Disconnected storage still raises global capacity; disconnected Cloaks cannot cool; disconnected warm nodes still roll minute alarms. | Define connected output, local autonomous operation, accessible storage, and alarm behavior explicitly. Retaining offline storage can be intentional; the current combination needs clear rules and feedback. |
| P1 | Captures and network scans can proceed from a controlled island without a route to entry, while production requires that route. | Decide whether remote operation requires an uplink and apply the chosen rule consistently. |
| P1 | Losing/uninstalling storage reduces capacity; the next clamp discards stock above the new cap. | Make this loss visible before voluntary removal; choose and explain the intended alarm-loss policy. |

For a standalone converter, the useful-work fraction is bounded by available input and by `output_headroom / (output_rate * dt)`. Multiple converters and same-tick consumers require a shared production/allocation policy; adding an isolated headroom check alone does not resolve ordering effects.

## 8. Improve the tuning contract

The guide's claim that every economic number is in JSON is inaccurate. Base security chances, node-type chance modifiers, probability bounds, node capacities, and accepted program categories remain in `building.gd`. These materially determine economic returns. The guide also suggests lowering base odds even though those values are outside the JSON file.

Move the parameters that designers actually need into a documented configuration, or narrow the claim. Explain relative burn penalties, cap overflow, offline behavior, and the fact that advanced tiers currently do not unlock anything.

Add semantic validation when loading: known resource/category keys, nonnegative costs/rates, noise and probabilities in range, positive useful capacities, and coherent `warn_at <= alarm_at <= max`. Valid JSON syntax alone cannot establish a valid economy. The current loader's three-tool fallback is visible but substantially changes progression; report invalid fields precisely rather than silently accepting malformed values.

## Recommended implementation order and success measures

1. Fix conversion, UI refresh, and save/resume; settle inactivity and connectivity rules. These changes make later measurements trustworthy.
2. Build one complete progression path: residential foothold → useful Cash purchase → corporate evidence objective → valuable reward. Connect the new corporate stories to these objectives where appropriate.
3. Tune resource buffers, advanced-tool access, Forge economics, and safe/risky heat loadouts against that path.
4. Run realistic seeded sessions for at least a residential expansion strategy, a Crypto/Cash strategy, and a corporate investigation strategy. Include time spent reading and navigating.

Track time to first producer and first corporate objective; Intel earned/spent/discarded; Cash earning and spending over time; useful output per captured node; and alarms/recovery time. Compare median and unlucky-tail outcomes. Watch whether corporate objectives remain worthwhile when players know the efficient residential strategy. Set target session length before choosing final numbers.

The reviewed `economy.json` SHA-256 is `53d0d252c8d3b3094bdc97b228e482ba7be4b39e022d64326122343457d0b3ea`.
