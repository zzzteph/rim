# Updated botnet prototype: gameplay and interaction review

11 October 2026. Decision: which corrections and small experiments make the current attrition prototype useful for testing production allocation, reinforcement, and territory pressure? This supplements the [selection review](../bot_selection_2026-10-11/REVIEW.md). [Combined Claude instructions](CLAUDE_INSTRUCTIONS.md).

## Evidence and scope

**Confirmed:** current section 0 is the active design; sections 1?13 are explicitly historical. Current code has 30-cap nodes, 1 bot/s regeneration, 1 bot/s dispatch as individual packets, owned-network routing, arrival-only attrition/reinforcement, HUB victory, and loss when no owned nodes remain. Friendly reinforcements become resident stock and can subsequently be dispatched; the historical no-staging/disposable-work-capacity constraints do not govern this model.

The latest update introduces three timing variables: SEND_RATE 1 bot/s, LINK_TIME 1 second/hop, and NODE_ROUTE_DELAY 0.25 seconds/intermediate node. The newest travel update makes packets cross links and visibly pause at intermediate nodes without entering their resident stock; the source and destination have no routing delay. The design and code now agree on these values and on enemy activation of continuous streams every six seconds. The earlier 2.5/s rate and obsolete ten-bot enemy-wave description were superseded during review; they are not current findings. Multiple activated enemy streams can coexist.

I read the complete updated document and script, reconciled three read-only review batches, and ran **12 controlled mechanics cases in Godot 4.7.2** against the final frozen 1/s production script. These call the real simulation functions with explicit fixtures; they are not GUI usability tests, ordinary play sessions, or balance simulations. Earlier selection evidence consists of 17 GUI/rendered cases on the preceding version; selection code remains unchanged in this snapshot. All 12 mechanics cases were run on the 1/s revision. A retained diagnostic tool also ran 32 controlled rate/stock/route cases to check the newest timing proposal.

Evidence: [source hashes](source_manifest_hops.json), [reviewed design](reviewed_design_hops.md), [frozen script](probe_project_hops/scripts/botnet_proto.gd), [mechanics probe](probe_project_hops/gameplay_probe.gd), [results](probe_project_hops/results.json). Gameplay and design files were not edited by this review.

**Assumed:** the desktop prototype should test where players allocate production, how far reinforcement must travel, and how much resident defense they expose. **Unknown:** novice comprehension, dominant strategy, appropriate match length, and whether 2.5/s is the right dispatch rate. No final balance verdict is supported.

Review domains: actions/agency, challenge/economy, space/pacing, interface/accessibility, audience/comprehension, attention, theme, narrative/world consistency, and production/validation. Puzzle/hint and social/multiplayer domains are excluded as irrelevant here. Campaign progression, city integration, presentation polish, monetization, and numerical balance tuning are outside this pass.

## Fix before interpreting playtests

### Critical: cancellation writes the opponent's orders

**Confirmed:** cancellation on either an enemy attacker or its friendly target clears the enemy attack assignment. It also clears incoming friendly support when stopping a source. [Code](probe_project_hops/scripts/botnet_proto.gd#L257); probe cases 03?04 plus the preceding selection evidence.

**Impact:** the player can halt enemy dispatch directly instead of countering it through production decisions. Source cancellation also changes more than the player may intend.

**Smallest intervention:** Stop supplying modifies only selected, currently player-owned sources' outgoing assignments. It preserves incoming orders and already dispatched packets. Replace the old unrestricted right-click cancel binding when adopting contextual destination commands. **Validate:** A attacks X, X attacks A, B reinforces A; stopping A leaves X?A and B?A intact, as well as all travelling packets.

### Major: timing changes with frame duration

**Confirmed:** emission sends at most one bot per frame. At the current 1/s rate over an eight-second well-stocked-source fixture, 60 Hz emits 8 bots, 10 Hz emits 7 at the floating-point boundary, and 0.5 Hz emits only 4. The two-second frames are deliberate hitch fixtures, not a claim about typical frame rates. At higher future sending rates the failure starts at smaller frame durations. A one-second process call also delivers the first newly emitted packet immediately, although its earliest valid arrival is 1-second departure + 1-second link travel = 2 seconds. The latest hop-phase update additionally discards elapsed time left after a link or routing phase: a two-hop packet remains undelivered after one 2.25-second call, but arrives after nine 0.25-second calls. Case 12 reproduces this newly introduced defect. [Emission](probe_project_hops/scripts/botnet_proto.gd#L156); cases 01?02 and 12.

**Impact:** lag or large simulation steps alter offensive strength and reinforcement timing, making apparent balance results unreliable.

**Smallest intervention:** account for every due departure, available stock, and each packet's actual departure time. Preserve individual packets and visible intermediate pauses. Carry unused elapsed time across every link and routing phase, including zero-delay routing; do not reset the clock and discard the remainder. Production, emission, AI cadence, and arrivals need a consistent timeline. **Validate:** the same timed orders at common frame rates and deliberate hitches produce equivalent outcomes within a declared small numerical tolerance; no arrival precedes its own departure plus route duration. A loop that emits more packets but gives every new packet the full frame's age is insufficient.

### Critical: arrival list order can award a false HUB victory

**Confirmed:** the flight list is processed in insertion order, not arrival-time order. In case 08 the HUB starts with one enemy bot. Enemy reinforcement is due at 0.1 seconds and player attack at 0.5 seconds. Both fall in the same step. Processing the later player attack first sets won=true; processing in chronological order leaves the HUB enemy-owned and produces no win. Final HUB stock and ownership are identical, but the victory flag differs. [Arrival processing](probe_project_hops/scripts/botnet_proto.gd#L171).

**Impact:** a terminal result can depend on storage order rather than the documented arrival rule. This can occur with ordinary frames whenever distinct arrivals fall within one frame; the probe amplifies the separation for clarity.

**Smallest intervention:** resolve arrivals chronologically and define equal-time handling independently of source/list order. Recommend treating truly simultaneous opposing arrivals as one target resolution before checking capture. **Validate:** reversing the stored flight list cannot change a result when arrival times are unchanged; earlier reinforcement prevents the false win.

### Major: simulation continues mutating the board after victory inside the same step

**Confirmed:** case 09 captures the HUB and then lets a later enemy packet retake it while won remains true. The process can still run enemy AI and a defeat check after a winning arrival. Orders can also be changed through input after terminal state. Reset controls are built only on panel refresh. [Delivery](probe_project_hops/scripts/botnet_proto.gd#L189), [process](probe_project_hops/scripts/botnet_proto.gd#L138).

**Smallest intervention:** document immediate HUB victory and immediate defeat on last-node loss at the chosen event boundary. Resolve any truly simultaneous group consistently, choose one terminal result, then stop further gameplay events and order mutations. Show result/Reset immediately. **Validate:** HUB capture followed by a later enemy arrival freezes at the valid win; last-node loss followed by a later player arrival freezes at defeat; a simultaneous event uses the declared tie rule; victory and defeat cannot both be active.

### Major: selection and panel state obscure what the command will do

**Confirmed from prior GUI evidence and unchanged code:** independent drags share a hidden destination, ordinary clicks accumulate sources, friendly click targeting fails, commit clears selection, panel stock/action labels become stale, and draft/committed routes look alike.

**Smallest intervention:** retain the previous recommendation: ordinary select/inspect; deliberate multi-select; one contextual destination command; retained groups; scoped stop; live stock/ownership/action; preview distinct from committed routes. Two clicks for a single source, marquee + destination for a spatial group, one command to retarget an existing group. Provide a left-button alternative. **Validate:** independent A?X then B?Y orders remain independent; both factions use the same targeting procedure; selected sources lost to the enemy become uncontrollable immediately.

## Rules to clarify and small improvements to test

These are current behaviors or design limitations, not all correctness bugs.

### Full-friendly supply wastes bots

**Confirmed:** sending one bot from a 30-bot source to a full 30-bot friendly node leaves source 29 and target 30. Sources keep sending despite the cap; probe case 05. At the current 1/s setting an unthreatened full source regenerates that bot before its next departure; the waste is lost output, not necessarily sustained stock depletion. Under incoming attack or faster dispatch it can also reduce defense. This follows the present cap/dispatch rules, so it is not an arithmetic bug.

**Hypothesis:** persistent reinforcement can send output that produces no useful defense, and can compete with local defense under incoming pressure. **Recommendation:** first show destination-full/overflow state. Then test one isolated alternative: hold future supply while a friendly target has no room after accounting for friendly packets already travelling there, retaining the assignment so it resumes when room opens. Do not recall or refund committed packets. Do not restore historical fuel or operation-demand systems. **Tradeoff:** waiting for room can make help arrive late against a new attack, especially over long routes; compare that response before adopting it. Existing full-node loss remains the baseline until this rule is intentionally changed.

### Enemy streams can become permanent support instead of adapting

**Confirmed:** after its destination becomes friendly, an enemy attacker remains assigned there. AI excludes assigned sources from new attacks. Case 06 leaves an enemy producer feeding a friendly node despite an available hostile neighbor. This is an AI limitation, not proof that the whole game is too easy.

**Recommendation:** on the existing AI decision cadence, reconsider orders whose attack target is now friendly or unreachable. A minimal enemy may release that completed attack and choose an adjacent hostile target; no global planner, new unit type, or economy advantage is needed. **Validate:** the source can resume useful frontier pressure rather than being permanently excluded merely because its assignment field is occupied. Keep player assignment lifecycle separate and explicit.

### Capture, loss, and routing need a short standing-order contract

**Confirmed:** player attackers continue feeding a captured target as reinforcement. Friendly reinforcement becomes attack if the destination is lost. Capturing a source clears that source's outgoing assignment. Route loss erases an order without a notice; restoration does not resume it. Existing packets keep faction, destination, and route and still arrive after relay loss. Case 07 verifies lost-relay completion and non-resumption; case 11 verifies that retargeting does not redirect old packets.

**Recommendation for this prototype:** keep ownership-sensitive arrival resolution and continuing target assignments, announce their changed action, and retain the simplicity that dispatched packets finish even after route/source changes. Route failure may clear future supply, but report that it stopped and requires reissue; retained blocked orders with automatic resumption can wait until a test shows they are needed. Explain that routing legality is checked for future departures. Do not call in-flight travel through a subsequently captured relay a bug if this is the declared simplification.

**Validate:** capture/loss with packets airborne, source loss, alternate owned route, only-relay loss/restoration, and exact-zero capture all match the documented outcomes. No new packet leaves via an illegal route. Already travelling packets never change faction or target merely because a source changed ownership.

### The strategic claim needs a narrower wording

?Whoever out-produces wins? and ?two producers beat one? are hypotheses conditioned on starting stock, travel time, dispatch capacity, target choice, and local delivered pressure. Global producer count does not guarantee that production reaches the decisive fight. The enemy starts with more nodes but activates sources gradually, so raw totals alone do not explain difficulty.

**Recommendation:** describe the intended skill as allocating timely supply while protecting the sources and routes that sustain it. Keep production/dispatch values provisional. Test whether local concentration, shorter support routes, or temporary defensive allocation changes outcomes before changing rates or adding systems. Do not automatically respond to an easy HUB rush by adding HUB health or a new currency.

## The new three-dial proposal: conditional acceptance

**Verdict:** accept 1/s sending as a prototype baseline **if concentrated support is the intended way to overcome regeneration**. Revise the expectation that merely sending bots will substantially drain an unthreatened full source. Whether this creates enjoyable decisions remains unknown. Keep the newest values for the correctness/UI pass; do not restore 2.5/s automatically.

The relevant option relationship is mixed: faster sending improves burst pressure but spends resident stock faster; shorter travel helps contextually with response and route length. The comparison is an isolated deterministic PvE fixture, not a ranking of whole-game strategies or an audience difficulty judgment.

For a source with no incoming effects, stock change below cap is approximately production minus actual dispatch. With production = sending = 1/s, the source replaces what it sends and oscillates around 29?30 when starting full. Against an idle regenerating target, one established stream adds approximately 1 damage/s against 1 recovery/s. Two streams add approximately 2 damage/s against 1 recovery/s. Once a source is itself attacked, outgoing supply does compete with its local recovery; the defensive opportunity cost has not disappeared.

The runtime sweep holds regeneration at 1/s, target starting stock at 20, source stock at 0 or 30, and sources at node 0 alone or nodes 0 and 5 together. Enemy AI is disabled to isolate the threshold. Runs last 60 seconds at 60 Hz; future supply stops on first capture. The following rows use full sources and the current 1-second link time:

| Sending rate | One-source capture | Two-source capture | Stock of an unthreatened attacking source after 10s (one-source case) | Interpretation |
|---|---|---|---|---|
| 1/s ? current | No capture within 60s | ~23.98s | ~29.00 | Concentration overcomes regeneration; sending alone barely draws down stock |
| 1.5/s ? diagnostic | ~42.98s | ~12.92s | ~24.33 | Slow stock-funded single-source pressure |
| 2/s ? diagnostic | ~22.50s | ~9.00s | ~20.48 | Clearer stock commitment and faster concentrated attack |
| 2.5/s ? previous reference | ~15.00s | ~7.40s | ~15.58 | More front-loaded stock commitment |

These capture times are diagnostic approximations from the current runtime, which still has the timing defects above; they are not accepted tuning targets. The checks avoid contested arrival-order cases. Do not tune around those defects: rerun after correction. At zero starting stock, one source failed to capture within 60 seconds for all four sending rates; production limited its sustained contribution. This verifies that a higher sending rate alone does not create extra bots. All 32 scenarios kept stock within 0?30.

Halving LINK_TIME from 1.0 to 0.5 at the current 1/s rate shortened the two-full-source capture from about 23.98s to 22.50s, but did not make the isolated one-source attack capture the target. That is the expected distinction: shorter travel changes when pressure arrives, while SEND_RATE changes how much can leave a stocked source per second.

**Clarify units before upgrades:** raise SEND_RATE to release faster; lower LINK_TIME or NODE_ROUTE_DELAY to move/route faster. The current NODE_ROUTE_DELAY is per-packet latency with unlimited concurrent passage, not a node throughput limit or queue. The latest visual motion now pauses at intermediate nodes, matching the updated rule; preserve that feedback. Intermediate transit never adds to the node's resident stock. Actual routing congestion would be a new mechanic. The two travel-delay parameters have similar global effects today; local route/node upgrades could distinguish them later. No upgrade tree is needed to test the current loop.

| Risk | Trigger | Impact | Smallest test |
|---|---|---|---|
| Players mistake a steady stream for progress | One source versus an idle regenerating target at 1/s | Long ineffective attacks | Show live target trend; ask players to predict whether capture will happen |
| Stock commitment is weaker than expected | Sending equals regeneration and source is unthreatened | Initial stock reserve is not spent | Compare 1/s baseline with 2/s only after correctness fixes |
| Faster sending upgrade seems ineffective | Source has little resident stock | Production still limits output | Show waiting-for-bots state; compare full versus empty source |
| Transit and routing upgrades seem identical | Both change only global travel latency | Redundant upgrade decisions | Keep them as debug parameters until local variation is tested |

[Retained diagnostic tool](probe_project_hops/balance_probe.gd), [32-case results](probe_project_hops/balance_results.json). Reproduce with:

```powershell
& 'C:/Users/steph/Downloads/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:/Users/steph/Documents/GitHub/rim/review/botnet_gameplay_2026-10-11/probe_project_hops' --script res://balance_probe.gd -- --rates=1,1.5,2,2.5 --seconds=60 --fps=60
```

The tool imports the frozen production script and applies rate/link-time overrides only in memory. It is retained for this ongoing parameter discussion, with scenario policy, limits, and machine-readable results. No gameplay constants were edited by this review. Model fidelity is checked through the actual simulation, conservation bounds, and the independent production-versus-dispatch boundary above; exact timestamps need revalidation after fixing the runtime.

## Prototype experiment and decision gate

First correct authority, timing/arrival order, terminal states, and selection feedback. Then use the existing grid or tiny fixtures for three short tasks:

1. Two player sources against one enemy source: predict which source drains, where packets go, and when to reinforce or retarget.
2. Repeat with a longer reinforcement route: observe whether the player anticipates delay and changes allocation.
3. Capture a node under a continuing stream, then threaten another source: observe whether the player understands the new reinforcement assignment and can redirect it with one command.

Use a small first round of representative players, record commands/corrections, unintended orders, source stock, arrivals, and explanations of capture/loss. Change only one rule at a time, especially the full-friendly hold experiment. Successful prototype evidence means players can explain why a node was lost and adapt their allocation with few actions; it does not establish final balance. If HUB rushing repeatedly wins without exposing meaningful pressure, test existing route layout or enemy activation choices before broadening the feature set.

## Documentation deliverable

Keep the active document short: player goal, current rules/values, controls, order lifecycle, enemy behavior, terminal resolution, known prototype simplifications, and a few test questions. Move sections 1?13 to a clearly named historical file, preserving them. Remove their old ?Locked constraints?/?Implemented now? statements from the active reading path. Preserve the latest correct enemy activation description. State that travel uses hop count and routing delay applies only at intermediate nodes (one hop 1 second, two hops 2.25 seconds). Describe reinforcement as adding reusable resident stock under the new attrition model. Record recommendations as changes from the baseline, not as pre-existing rules.
