# Claude prompt: make military commitment create strategic openings

Implement and validate a small combat prototype in RIM that tests whether a smaller network can win a local battle by concentrating its stored bots, and whether that commitment exposes it to counterattack.

This is the latest task. The economy patch is already in the working tree. Earlier proposals for paid regeneration, regeneration caps, upkeep, settling time, and supply-dependent production are background ideas, not instructions to combine into this prototype.

## Broader player goal: hacking and cyberpunk identity

The player also reports that the game does not sufficiently feel like hacking or cyberpunk. Read `HACKING_IDENTITY_BRIEF.md` alongside this prompt. The desired direction is discovering access, completing valuable operations, and making consequential choices about corporate power and the people in the city.

The finite-assault experiment below addresses local combat and commitment. Do not report it as solving the game's identity or overall progression. Keep that experiment isolated. In your final handoff, also provide the concrete next-prototype specification requested by the identity brief: one corporate data theft operation, temporary access distinct from ownership, extraction with readable defensive counterplay, and a visible city consequence. This additional deliverable is a design specification, not an instruction to bundle a new operation mode into the combat patch.

## Problem and desired experience

The player's report is that a small economic core supports endless expansion into full-farm hosts; once an opponent owns somewhat more territory, ordinary attacks make no progress. The reported 30% ownership is an observation, not a verified universal threshold.

Current mechanics help explain this:

- A farm produces one bot/s, while each host normally sends at most one bot/s. Sources can replace their departures and remain defended.
- Hostile bots trade one for one with defenders. Progress requires delivered attack rate to exceed local regeneration plus friendly reinforcement.
- More hosts provide more permanent sending channels. Stored bots often act like extra health rather than a force the player can deliberately mobilize.
- A slightly larger network can reinforce a threatened position without making a meaningful commitment elsewhere.

The target experience is: "I am smaller overall, but I can concentrate reserves to take an exposed position. If I overcommit, the opponent can punish the hosts that supplied my assault."

A larger empire should retain its earned advantage. Do not add a free bonus for being behind or promise that the smaller player wins equal play.

## Read first and preserve existing work

Inspect the working tree and applicable repository instructions. Preserve existing user changes.

The active game is `scenes/botnet_proto.tscn`, implemented in `scripts/botnet_proto.gd` with `scripts/botnet_cfg/*.gd`. Do not implement through legacy `data/economy.json`.

Currently farms cost 30 Crypto and harvesters add 15 Intel capacity. Preserve those values and the other economy/card rules for this experiment. Keep the unfinished Insane difficulty disabled in the UI.

Relevant areas include `_regen`, `_sim_step`, `_reserve_of`, `_bot_target`, `_auto_guards`, `_can_emit`, `_emit_due`, `_deliver`, `_capture`, the command handlers, and `_mp_hash`. Inspect their current implementation rather than relying on historical line numbers.

## Prototype: a finite assault order

Add an explicit Assault action alongside the existing continuous Attack/Scan/Guard behavior.

1. The player selects owned sources and a hostile target, and chooses how much of the currently available garrison to commit. Use a small, readable control with a clear default. Show the committed quantity and predicted defenders left.
2. At command acceptance, snapshot a finite integer quota per source. New regeneration, reinforcements, additional wires, or repeated button presses must not silently enlarge that order.
3. Launch committed bots faster than the ordinary stream, subject to the actual route and link capacities. Choose initial launch rate and commitment settings using a small executable model; label them provisional and document why they were selected.
4. Each successfully departing hostile bot still costs one source bot and one Intel. Stalled departures spend neither. Do not turn insufficient Intel into debt.
5. One outgoing order owns a source at a time. Attack, scan, guard, and assault must not independently spend the same garrison. Define replacement of an existing order explicitly.
6. When the quota is exhausted, stop. Continuing an ordinary stream or launching another assault requires an explicit order.
7. Cancel stops unsent departures; already departed packets continue under existing travel/arrival rules. Losing a source invalidates its remaining order.
8. Lost routes, blocked links, and insufficient Intel pause departures without accumulating a catch-up burst. UI feedback must explain the blocker.
9. When the target becomes friendly, stop unsent assault departures. Already travelling packets follow existing arrival rules. Completion/cancellation must not silently turn the assault into unlimited automatic guards.
10. Keep ordinary combat resolution, fog rules, Intel costs, and network travel semantics. Do not bypass shared bandwidth or teleport a whole garrison.

Important existing traps to inspect:

- `_auto_guards` can reactivate assigned friendly-target wires even if their live flag was cleared.
- `_do_wire` can automatically join sources to an ongoing attack.
- Several runtime and AI paths calculate production directly rather than exclusively through `_regen`.
- Scheduled packets retain their path/time; cutting a route does not currently erase packets already in flight.

Explicit finite-order state must remain finite across those transitions. Use the existing architecture where it fits; do not build a separate combat engine.

## Exposure is a requirement, not an assumption

A finite quota alone may not expose a source if its regeneration replaces every departing bot. Evaluate ordinary, fully farmed, ERP, and temporarily boosted sources, including congested routes and Intel shortages.

First test the finite assault with current regeneration. Measure actual minimum garrison and how long the source is vulnerable; do not present "bots committed" in the UI as evidence of real exposure.

If regeneration erases that risk, test one clearly separated variant:

**Pause local bot regeneration at a source while its assault remains active, including while its departures are blocked. Resume when the order completes, is cancelled, or becomes invalid.**

This is an explicit tradeoff of issuing that assault, not a global production nerf. Display the pause and preserve delivered reinforcements. Test cancellation/reissue and target-capture transitions so it does not become an exploitable toggle. Compare this variant to the simple finite quota and retain the smallest version that meets the commitment goal.

Do not introduce paid regeneration, empire upkeep, permanent regeneration caps, card nerfs, capture settling, or new supply rules in the same experiment. If neither assault variant works, report the failed mechanism rather than bundling unrelated balance changes.

## AI, controls, and multiplayer

- Make the action available through a straightforward existing selection/target flow. Show remaining quota, actual departures, source defenders, cancellation, and funding/route blockers.
- AI must use the same commands and information restrictions. It should consider a local assault and recognize exposed enemy origins without reading hidden state.
- Validate commands, ownership, available quotas, costs, cancellation, and transitions through the deterministic command path.
- Include new state in multiplayer synchronization/hash checks as needed.
- Update relevant help and descriptions. Follow the repository's gameplay version convention when producing a changed build.

## Verify before claiming success

Build a small reproducible model from the actual current rules. Include starting garrisons, generation, finite quotas, launch rate, Intel demand, travel, and shared link limits to the extent required by the claim. Clearly label approximations. Run baseline, ordinary, optimized, and boundary cases; select initial values from those results.

Add meaningful mechanics tests for:

- Exactly the accepted quota can depart; no extra bots from subsequent regeneration or repeated commands.
- No negative banks/garrisons, double spending, or duplicate orders.
- Zero and partial Intel, route interruption, link congestion, source loss, target capture, cancellation, and mode switching.
- No accidental auto-guard or wire-join continuation after a finite order.
- Actual source exposure with heavily farmed and boosted hosts.
- Existing attacks, scans, guards, cards, and multiplayer determinism still work.

Run appropriate existing Godot tests from `BUILD.md` and the new focused checks. Do not rewrite unrelated tests simply to make them pass.

## Decisive gameplay scenarios

Use reproducible prepared positions with **10 hosts versus 12**, both players following the same rules. Record map, host types, farms, garrisons, resources, routes, and commands. Test several layouts and swap sides to reveal map advantages.

1. **Local opportunity:** the larger player leaves a branch weakly supported. The smaller player can take a local objective through timed concentration.
2. **Counterattack:** the attacker commits too much. The defender can punish the assault's weakened origins.
3. **Sound defense:** the larger player concentrates appropriate defenders and guards. The smaller side is not guaranteed a breakthrough.
4. **Chokepoint:** shared route capacity limits the burst honestly and encourages choosing another approach.
5. **Repeated assault:** a player cannot make an effectively permanent faster stream without spending reserves, exposing origins, or allowing a rebuilding interval.

Compare the current game, simple finite assault, and the exposure variant if needed. Record target changes, source minimum garrison, exposure duration, bots and Intel spent, cancellations, recovery time, and the actual response available to the opponent.

One easy capture is not sufficient. Success means both concentration and counterattack become useful decisions. More expensive stalemates or a stronger permanent stream are failures.

## Deliver

Return the implemented prototype, chosen values and reasoning, model/test commands and results, scenario observations, and remaining limitations. Separate source-confirmed behavior, calculated predictions, automated runtime results, and actual player observations.

Conclude whether the prototype creates local opportunities and punishable commitments, or whether it failed that test. Do not claim that comeback balance or win rates are proven by a few scenarios. If you cannot run gameplay validation, state exactly what remains unverified.
