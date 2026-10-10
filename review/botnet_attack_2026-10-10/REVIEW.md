# Design review: RIM botnet attack loop

Reviewed 10 October 2026. Review object: the current [BOTNET_ATTACK_DESIGN.md](../../design/BOTNET_ATTACK_DESIGN.md), including the new §2a fuel and automatic-selection proposals. This focused document report updates the interpretation of those proposals in the earlier whole-project review. No gameplay or design files were changed.

## Decision at stake

**Adopt the direction, but specify its commitment and consumption rules before implementing the full loop.** Bots dealing damage while consuming operation fuel is a clearer relationship than the prototype's independent, additive damage pools. Automatic collection of eligible war-hosts is also a good default. Neither choice yet establishes how many bots should be dispatched, how long each lasts, or what meaningful decisions take place inside the host.

The compelling player promise is to weaponize a city's infrastructure: conquered hosts produce disposable attack capacity, ownership opens new frontiers, and committing that capacity exposes home territory. Preserve stationary hosts, data streams, local resident defense, one-way bots, and internal combat. Avoid expanding this into movable armies or forward staging.

## Evidence baseline

- **Confirmed document rules:** hosts are stationary; bots are one-way consumables; targets must border owned territory; attack and defense share bots; combat happens internally. The new fuel model and automatic contributors are proposed and explicitly unimplemented.
- **Confirmed current prototype:** [combat](../../scripts/botnet_proto.gd#L179) drains up to 6 bots/s and 3 Intel/s independently and adds their damage. [Breach](../../scripts/botnet_proto.gd#L202) empties selected resident bot stocks into a committed force and precommits Intel. [Internal generation](../../scripts/botnet_proto.gd#L134) creates straight chains. Production continues during internal combat; new global Intel does not refill the precommitted internal Intel pool.
- **Calculated:** current prototype baseline cases and a conditional fuel model were executed. The latter is a bound on the new proposal, not a faithful simulator of an agreed lifecycle. [Results, assumptions, and source hashes](fuel_checks.json) are retained.
- **Assumed only for numerical illustrations:** each engaged bot deals 1 defense damage/s; fuel burns at 2 Intel per bot-second. Damage per second is not specified in the proposal. Current `BOT_DMG = 1` means damage per consumed bot and cannot be imported as a per-second rate without a new rule.
- **Unknown:** bot lifetime/work capacity, engagement cap, exact consumption timing, reinforcement, starvation/restart rules, global clock and pause behavior, target audience, desired session length, and representative player comprehension or engagement.
- **Reported anecdote:** the old node-clicking loop was tedious to playtesters. The document does not include the sample, protocol, observations, or build needed to establish the cause or prove that live fuel solves it.

The Game Design Review skill was applied comprehensively across nine domains: experience/audience; concept/theme/emotion; actions/rules/agency; challenge/progression/economy; space/pacing; attention/guidance; interface/accessibility; narrative/world; production/validation. Three read-only review batches were reconciled. Dedicated puzzle/deduction analysis was excluded because no deduction or hint system is specified; multiplayer/community analysis was excluded because this loop specifies a single-player opponent. These exclusions do not waive basic rule comprehension or responsible validation. The Game Balance Analysis skill supplied the numeric checks.

## Priority findings

### 1. Major: bot consumption is still missing its governing rule

**Observation:** [LOCKED principles](../../design/BOTNET_ATTACK_DESIGN.md#L30) require one-way consumables, while [§2a A](../../design/BOTNET_ATTACK_DESIGN.md#L56) and question 2b reopen persistence. Saying that burning fuel uses a bot up does not define how much work one bot performs.

**Mechanism and impact:** deployment, active firepower, and remaining ammunition are different quantities. A bot lasting one second and one lasting ten seconds have tenfold different total capacity at the same damage/s. An indefinitely surviving deployed bot could eventually conquer through trickling income. The latter would undermine the throughput premise even if it never returns home.

**Recommendation:** retain the locked one-way rule. Define a bot's finite firing lifetime or damage/work allowance, when resident stock is deducted, how active bots expire, and whether unfueled bots expire or wait. Define whether newly produced bots may reinforce an existing operation; no reinforcement is the simpler first test. Dispatched bots never return, while undispatched resident stock remains available for defense.

**Tradeoff:** a finite work allowance creates predictable ammunition costs; a clock-based lifetime makes starvation more dangerous. Choose one primary consumption rule instead of layering both without a clear purpose.

**Validation:** trace one success, one under-fueled attempt, and one early retreat. Players should predict what was committed, what remains at home, and whether waiting can still save the operation. Do not balance the 2 Intel/s working value before this contract exists.

### 2. Major: automatic source selection must be separated from automatic maximum commitment

**Observation:** [§2a B](../../design/BOTNET_ATTACK_DESIGN.md#L65) removes host picking and says defense is the only reason to hold hosts back. But every dispatched bot is irrecoverable, so preserving ammunition for the next attack already matters without Net Watch.

**Mechanism and impact:** auto-emptying every reachable host can waste surplus bots on easy targets. Growing the botnet could increase losses without increasing reward. Auto-selecting sources reduces administration; deciding the quantity sent remains a strategic commitment.

**Recommendation:** auto-collect eligible contributors, then apply a visible operation budget or reserve policy. Keep one simple control rather than compulsory individual host toggles. Selecting a target previews the operation; pressing **BREACH** commits it. Preview contributors, dispatched bots, resident stock left behind, burn rate, and known requirements. Uncertain information should be marked as uncertain.

**Tradeoff:** one commitment decision adds a little interface work. Host-by-host selection scales that work with empire size; unrestricted automatic dispatch sacrifices predictability.

**Validation:** compare the same easy target with small and large resident stockpiles. Extra production should provide useful options rather than accidentally magnifying losses. Test whether players distinguish inspecting a target from launching an irreversible operation.

### 3. Major: linear fuel drain buys speed, not an inherent total-fuel penalty

Let `H` be target defense, `E` concurrently engaged bots, `d` damage per bot-second, and `f` fuel per bot-second. With constant engagement, adequate fuel, no attrition, and no overkill:

```text
damage rate = E × d
fuel burn rate = E × f
completion time = H / (E × d)
total fuel = H × f / d
```

**Calculated implication:** doubling engagement halves time and doubles instantaneous burn; total fuel stays constant. Live income, attrition, overkill, and limited lifetimes can change the practical result. With live income, slower assaults may need less fuel in reserve because they earn more while fighting; that is a time tradeoff, not improved damage-per-fuel efficiency.

**Recommendation:** describe the main choice as **completion speed versus committed bots, local reserves, and available fuel throughput**. Make speed useful through one readable warning/response window. Do not add an artificial nonlinear fuel tax merely to manufacture a second tradeoff.

**Tradeoff:** pressure makes speed matter but can turn a thoughtful strategy game into a reaction test if warnings are too short or pause/inspection is unsupported.

**Validation:** resolve identical targets with smaller and larger strikes, first without pressure and then with one warned response. Compare total fuel, completion time, bots irreversibly committed, and defense left at home.

### 4. Major: keeping the old economy rates may make the new fuel model mostly waiting

**Observation:** [§4](../../design/BOTNET_ATTACK_DESIGN.md#L106) retains the old prototype's 15 starting Intel in source and 0.6 Intel/s per host, while the proposal suggests approximately 2 Intel per engaged bot-second.

**Conditional calculation:** at illustrative `d = 1`, the first outer target's 92 defense needs 184 Intel. With 15 starting Intel and 0.6/s income, even an ideal lossless assault needs at least `(184 − 15) / 0.6 = 281.67 seconds` from that resource state to obtain sufficient fuel. This is a fuel-conservation lower bound; unspecified bot expiry or discrete restart rules may make the attempt slower or impossible. It is not a prediction for the eventual integrated economy.

A hypothetical 20-bot strike burns 40 Intel/s. At those stock/income values its initial 15 Intel lasts about `15 / (40 − 0.6) = 0.381 seconds`. A bar that empties almost immediately is unlikely to provide a useful decision window; whether it feels confusing or tense requires a playtest.

**Recommendation:** tune damage, fuel per bot-second, bot work capacity, income, and opening stock together against a declared first-assault duration. Retune the new model instead of carrying the old rate table over unchanged.

**A concrete test candidate, not final balance:** if the objective is an approximately ten-second first assault, assume ten engaged bots, `d = 1`, no bot expires before ten firing seconds, and lower `f` from 2 to **0.2 Intel per bot-second**. The 92-defense target then takes 9.2 ideal seconds and 18.4 Intel. Starting with 15 and earning 0.6/s supplies 20.52 Intel over that interval, avoiding fuel stalls in the conditional model. This is a 90% reduction in the working fuel rate, offered to expose the scale of the mismatch. It does not validate the lifecycle, defense, war-building investment, or player experience. Increasing opening stock instead is possible, but also requires checking sustainable income after the first capture.

**Validation:** a novice should complete the first reasonably prepared operation without an unannounced starvation trap. Test a sufficient and an intentionally insufficient loadout, then inspect replenishment time for the second conquest.

### 5. Major: starvation and the two-map clock have incompatible or missing contracts

**Observation:** [§2a](../../design/BOTNET_ATTACK_DESIGN.md#L58) allows waiting for fuel income; [the process diagram](../../design/BOTNET_ATTACK_DESIGN.md#L90) says out of fuel/bots means retreat. Shared defense is locked, but the opponent and lose condition are absent.

**Mechanism and impact:** indefinite safe waiting can remove the need to prepare sufficient reserves. Conversely, continued bot expiry or offscreen attacks can punish a player who cannot see or interrupt the consequence. The reserve decision cannot be validated without specifying what happens at home while the player is inside another host.

**Recommendation:** define empty-fuel behavior, restart, bot expiry, world-clock progression, pause, and retreat outcomes. For a first strategy test, permit readable planning time and display a warned incoming attack in the internal view. Use one announced response rather than many simultaneous interruptions. If starvation can wait indefinitely, test whether the player simply stays inside until the target is conquered; do not assume this creates tension.

**Tradeoff:** forgiving stalls support recovery; finite expiry or enemy pressure supports preparation. Excessively punitive starvation makes live fuel an execution trap.

**Validation:** deliberately underfuel an attack while one clear global warning is active. Observe whether players can explain the available choices and attribute the outcome to their commitment rather than unseen events.

### 6. Major: resource stakes do not make a straight chain tactical

**Observation:** [§3](../../design/BOTNET_ATTACK_DESIGN.md#L96) calls internal play tactics; the current topology has one legal next node. Proposed input alternatives change click frequency or planning style, not the consequence set.

**Mechanism and impact:** a falling bar can create suspense, but mandatory successive clicks may repeat the old busywork. Tactical decisions require an alternative that changes the outcome under different circumstances.

**Recommendation:** keep continuous assault after selecting a meaningful action. Test one internal choice, such as disabling an alarm before the CORE versus rushing it while accepting a warned response. Match the compared scenarios' approximate difficulty and duration. Do not add pulse clicks solely to make the player busier.

**Tradeoff:** a branch adds learning and tuning overhead; one clear choice is sufficient to test the claim. Large internal graphs risk making every conquest laborious.

**Validation:** present the same host under different fuel/threat conditions. Players should sometimes change their approach and explain which consequence caused the change. If behavior remains identical, the internal tactical promise is still unproven.

### 7. Major: source reach and resident defense need an explicit spatial rule

**Observation:** targets must touch territory, but wording alternates between hosts "that can reach" and everything "wired to" the target. Current [_eligible](../../scripts/botnet_proto.gd#L124) gathers war-hosts through connected owned territory adjacent to the target. This differs from allowing only directly adjacent war-hosts. Question 3 leaves non-war-host defense open.

**Recommendation:** state the source-routing rule separately from target legality. Connected owned-territory routing is consistent with no staging and avoids forcing every frontier host to become a war building. Resident bots should defend locally and automatically; every host can have modest base resistance to provide a response window. Define what happens when Net Watch cuts the owned route during an operation.

**Tradeoff:** routing through all owned territory weakens offense's need for forward placement, while resident defense preserves local value. Transit should be added only if it creates a consequential placement/response decision. Its delay alone is not a benefit.

**Validation:** compare a rear war-host and a frontier war-host under one known enemy threat. Players should understand which can contribute, which resident bots defend, and what territory loss disconnects.

## Numeric comparison

The actual straight-chain damage budgets are **92 outer**, **120 inner**, and **194 HUB**. The global displayed defenses **20 / 40 / 240** do not determine the prototype's internal damage budget. The current document now correctly lists 3/4/6 internal nodes and CORE defense 70; the old broad review's criticism of the previous node table is superseded.

| Conditional fuel case: outer target, `d = 1`, `f = 2` | Ideal completion time with adequate fuel | Total fuel, excluding income/overkill | Burn rate |
|---|---:|---:|---:|
| 5 concurrently engaged bots | 18.4 s | 184 Intel | 10 Intel/s |
| 10 concurrently engaged bots | 9.2 s | 184 Intel | 20 Intel/s |
| 20 concurrently engaged bots | 4.6 s | 184 Intel | 40 Intel/s |

These rows require enough finite bot work capacity to sustain the displayed engagement. They do not endorse persistent bots. With only ten bots committed, their combined capacity is `10 × d × firing_lifetime`; for `d = 1`, a one-second lifetime supplies only 10 damage, while ten seconds supplies 100. Lifetimes and damage allowances are therefore essential inputs.

| Sensitivity: outer target, fuel burn 2 per bot-second | Total fuel requirement | Minimum firing lifetime with ten committed bots |
|---|---:|---:|
| `d = 0.5` damage per bot-second | 368 Intel | 18.4 s |
| `d = 1` | 184 Intel | 9.2 s |
| `d = 2` | 92 Intel | 4.6 s |
| `d = 4` | 46 Intel | 2.3 s |

**Old prototype only:** ten bots plus 15 Intel supply at most 47.5 damage and fail against the first outer target in the isolated 60 Hz model. One bot plus 78.6 Intel can defeat the HUB in about 25.73 seconds because the old formula allows Intel-only damage after bots expire. These are reasons to replace or retune that model; they are not defects demonstrated in the newly proposed fuel system. The document explicitly acknowledges that distinction, but its claim that a fresh rig can crack a soft host still needs a resource/time qualification.

## Answers to all open questions

| Question | Recommendation | Condition or tradeoff |
|---|---|---|
| 1. Internal combat feel | Continuous assault for a selected action, with one consequential internal choice. | Discrete pulses only if pulse timing changes a meaningful outcome; otherwise they add repeated input. Preplanning can be tested later once there are real alternatives to plan. |
| 2. Host selection | Automatically gather eligible contributors; separate gathering from dispatched quantity. | Add one operation budget/reserve policy and a commitment preview before considering individual host control. |
| 2b. Spent or persistent bots | Keep spent, one-way bots as already locked. | Define finite work/lifetime and starvation. Persistent bots would reopen the throughput premise rather than merely tune it. |
| 3. Defense | Resident bots auto-defend and are consumed; modest host base resistance provides warning/reaction time. | Define last-foothold defeat and recovery. No-war hosts should be vulnerable without necessarily vanishing instantly. |
| 4. Transit | Keep instant breach for the first contract test. | Test 1–2 s/hop later only if forward placement or threatened-route timing changes decisions; avoid adding travel as empty delay. |
| 5. Resources | Begin the test with bots plus one fuel; retain Intel/Credentials/Exploits as candidate differentiated operation inputs. | Scan is an information action, not simply another damage flavor. Add a resource only when it supports a distinct choice. Resolve Cash versus Crypto's distinct sinks before committing to all five. |
| 6. Escalation | Escalate through tougher or differently structured targets, readable Net Watch pressure, and a HUB combining learned decisions. | Do not begin with a blanket conquest-price surcharge. Larger health alone can extend waiting rather than increase challenge. |
| 7. Failure | Committed bots stay lost; preserve learned information. Test limited persistent damage separately. | Fully persistent damage can make cheap repeated chip attacks dominant; fully resetting everything can punish exploration. No survivor refund is needed under the locked premise. |

## Smallest next experiment

Use **two owned war-hosts, one frontier target with one consequential internal choice, one fuel resource, one warned Net Watch attack, and a small HUB goal**. This fits the intended fantasy without needing the real city renderer, full resource set, fog, or transit.

Before testing, specify the irreversible commitment point, finite bot work allowance, starvation/restart behavior, source routing, resident reserve, clock/pause, CORE ownership effect, and exact loss condition. Explain CITY OVERLOAD's purpose in one sentence if the fiction is tested.

For a first qualitative comparison, recruit 5–8 people from the intended audience once that audience is chosen. This sample can expose recurrent confusion and decision explanations; it cannot establish population preference. Include non-color state cues, accessible inspection time, and keyboard access in a representative interface test.

Observe first-assault preparation, commitment prediction, reasons for route/force choices, response to the warning, starvation recovery, and whether the player can explain the result. Compare:

1. Automatic contributors with unrestricted commitment versus an automatic budget/reserve policy.
2. A matched straight chain versus one meaningful internal choice.
3. Small versus large strikes under the same warned response.

**Decision rules:** retain automation if players correctly predict commitment and intentionally preserve reserves; retain the branch if changing circumstances changes decisions for explainable reasons. If the chain and branch produce only waiting and the same mandatory actions, redesign the internal consequence before adding content. Retune fuel if reasonably prepared novices suffer immediate, unexplained stalls. Never interpret winning alone as proof of tactical depth or comprehension.

## Verification and limits

An ephemeral Python verifier was executed through shell standard input, importing the existing retained baseline combat function. No temporary script or scratch file was written, so no scratch cleanup remains. It checked a hand-known two-second/20-fuel case, zero engaged bots, zero fuel with no income, recovery from live income, and fuel-stock conservation. It swept engagement caps 1/5/10/20/40, targets 92/120/194, damage rates 0.5/1/2/4, and adequate versus insufficient starting fuel. The additional `f = 0.2` test candidate uses the same formulas and was separately executed. Numerical evidence and inspected-file hashes are retained in [fuel_checks.json](fuel_checks.json).

The conditional simulator assumes a constant engagement cap, no attrition, fractional duty cycling when income is insufficient, no overkill, no node-click delay, no transit, and no opponent. Its income-limited completion times are optimistic bounds, not valid complete combat predictions. Finite bot consumption must be added after its rule is chosen. No engine run, rendered interface assessment, or human playtest was performed.
