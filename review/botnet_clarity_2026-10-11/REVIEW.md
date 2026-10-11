# BOTNET clarity review: links, attacking, and combined supply

11 October 2026. **Judgment: the current interface is not sufficiently clear to evaluate the ten-minute gameplay loop.** This is supported by reproducible input/display defects, hidden attack constraints, and the user's direct report of confusion. Adding more instructions alone will not fix the covered map nodes or stale commands. The existing Select ? Aim ? Commit concept is viable; stabilize and explain it before changing bindings again.

[Claude instructions](CLAUDE_INSTRUCTIONS.md).

## What was reviewed

The complete current 747-line script and 136-line active design were reviewed, including the new Intel/building economy, defensive power 1.5, explicit commit button, and focus shading. These are current intentional additions, not the archived earlier fuel/interior model. Earlier reviews are historical evidence and must not dictate removal of these additions.

**Confirmed evidence:** 17 controlled GUI/state cases passed in Godot 4.7.2, with all 17 states rendered at the configured 1280?720 viewport. Real mouse events and panel buttons were used, with explicitly labelled controlled ownership, keyboard, and marquee fixtures. Ten additional runtime scenarios tested the mechanics that explain apparently ineffective commands. **Player evidence:** the creator reports struggling with the interface. **Unknown:** the prevalence of each misunderstanding among new players, final balance, and actual match duration. There was no new human playtest.

[Source hashes](source_manifest.json), [frozen script](probe_project/scripts/botnet_proto.gd), [reviewed design](reviewed_design.md), [UI probe](probe_project/ui_probe.gd), [UI results](probe_project/results.json), [scenario tool](probe_project/clarity_scenarios.gd), [scenario results](probe_project/scenario_results.json). Only review artifacts were added; the game and design were not changed by this review.

Nine review domains: interface/accessibility, audience/comprehension, attention, actions/agency, challenge/economy, space/pacing, concept/theme, world consistency, and production/validation. Puzzle/hint and multiplayer/community domains were excluded as irrelevant. Full simulation correctness, city integration, controller/touch, campaign progression, and final balance were not re-audited. The numeric scenarios diagnose current local thresholds and recovery, not a whole-match win probability.

## The explanation the player needs

**A network connection is an existing wire. A supply order tells a source where to keep sending its production. The route is the path those bots travel.** Removing an order does not remove a wire.

**To combine an attack, A and B must both have X as their destination.** Each sends up to one bot per second, so together they can deliver two bots per second if stock, reach, and Intel allow it. Passing through a node does not recruit that node's production.

```text
Two orders with the SAME final target:
A ? X, via whatever owned route is available
B ? X, via whatever owned route is available
Result: up to two attack streams arriving at X.

A ? B, followed by B ? X:
A reinforces B's stored bots. B still releases only one bot/s toward X.
This is not a two-stream attack on X.
```

Sixty resident bots across two selected nodes does not mean an immediate sixty-bot volley. A second Bot building increases regeneration; it does not increase that node's one-bot/s sending limit. This should be explained in the source/target preview, not left for the player to infer from tiny moving dots.

## Prioritized findings

### Critical: the panel blocks playable nodes and hides the main action

**Confirmed:** at 1280?720 the panel occupies x16?420/y376?706. Node 10 at (170,400) and Node 11 at (405,400) lie inside it. An actual click on Node 10 is intercepted and does not inspect/aim it. [Screenshot](probe_project/captures/10_bottom_node_click_intercepted_by_panel.png), GUI case 10. Geometry: [panel](probe_project/scripts/botnet_proto.gd#L77), [map](probe_project/scripts/botnet_proto.gd#L98).

With an outgoing order, incoming support, and an unused building slot, the target action begins at y691 and extends below the scroll viewport's y698 limit. Its center is outside the visible viewport. Stop/remove/build controls precede it. [Screenshot](probe_project/captures/13_retarget_action_below_build_and_remove_controls.png), case 13.

**Consequence:** players cannot reliably act on visible map locations and may not find the command they just prepared. **Minimum remedy:** reserve a map rectangle outside the panel, and pin the primary command/preview above a separate or collapsed Buildings section. **Acceptance:** every node center/hit area and label is usable at target sizes; Attack/Reinforce never needs scrolling.

### Major: selecting sources and selecting a destination are hidden modes

**Confirmed:** after A is selected, a plain click on owned B aims reinforcement at B instead of selecting it. This remains true after an order because selection is retained. [Case 06](probe_project/captures/06_click_other_source_aims_reinforcement.png), [input](probe_project/scripts/botnet_proto.gd#L387). The document's promise that a normal source click replaces selection is false in this state.

**Consequence:** ?select A and B? can become ?make A supply B.? Inspecting another building can appear to prepare an unrelated command. **Minimum remedy:** show the active step persistently: Choose sources / Choose destination / Preview / Order running. Display named source chips and a visible Change sources action. Keep the present click-to-aim behavior only with an explicit destination-mode banner; Change sources returns to source selection. Do not promise ordinary click replacement while in destination mode. Shift-click and marquee remain deliberate source-group gestures. Clear an obsolete pending destination when the source set changes.

**Acceptance:** a player can identify who will send, what the next node click means, and how to select a different source without issuing an order. Current efficient paths remain available: one-source click + target + button; two-source click + Shift-click + target + button; marquee + target + button; retained-group retarget + button. Extra pointer correction or a scroll is not hidden from the action count.

### Major: the displayed command can cease to exist internally

**Confirmed:** committing refreshes the panel before clearing its pending target. The panel retains ATTACK while the map has left preview; another press has no pending target to act on. Escape clears sources but leaves the target/focus. Marquee and contributor recall can inherit an obsolete target. Panel stock and action do not refresh as normal simulation proceeds; a captured target still has an ATTACK button whose action is now reinforcement. [Cases 04](probe_project/captures/04_commit_leaves_stale_attack_button.png), [07](probe_project/captures/07_escape_keeps_pending_target_and_fog.png), [16](probe_project/captures/16_target_capture_keeps_wrong_action_label.png), [commit](probe_project/scripts/botnet_proto.gd#L406), [panel](probe_project/scripts/botnet_proto.gd#L525).

**Minimum remedy:** finish the state change before updating the display. After commit, show the actual running order and its contributors; the pending preview is gone. Escape/right-click/clear cancel all draft focus but preserve standing orders. Live labels reflect stock, ownership, costs, and waiting states without disrupting input focus. **Acceptance:** no stale no-op command, no residual aim after cancellation, and no action whose label disagrees with its current effect.

### Major: the interface explains reach but not whether the attack works

**Confirmed:** the preview gives selected stock and N/M reachable, but not actual stream rate, Intel requirement, damage, target regeneration, or why a source is waiting. At zero Intel, standing attack lines remain with no waiting-for-Intel message. [Case 11](probe_project/captures/11_zero_intel_orders_look_active_no_block_reason.png), [dispatch](probe_project/scripts/botnet_proto.gd#L242).

Current damage per bot is 1/1.5 = 2/3. For a stationary idle target, ignoring other flows:

| Target | Funded streams | Damage/s | Regeneration/s | Expected sustained effect |
|---|---:|---:|---:|---|
| Ordinary, one Bot building | 1 | 0.667 | 1 | Cannot overcome regeneration |
| Ordinary, one Bot building | 2 | 1.333 | 1 | Progresses slowly |
| Idle HUB, two Bot buildings | 3 | 2 | 2 | No sustained margin |
| Idle HUB, two Bot buildings | 4 | 2.667 | 2 | Progresses |

These are conditional thresholds, not universal required source counts. A target that is itself sending loses resident stock through that outgoing flow; reinforcements, source shortages, travel, or Intel starvation also change the result.

**Runtime evidence:** one funded stream failed to capture Node 1 during 120 seconds. Two with +2 Intel/s captured it in about 63.27 seconds. Three funded streams did not capture the idle HUB; four captured it in about 46.27 seconds. A serial A?B?X chain failed against Node 1, whereas direct common-target orders succeeded. An extra Bot building did not increase a single source's stream. These isolated scenarios disable enemy AI and are not full-match pacing results.

**Minimum remedy:** preview and running attack show selected/eligible sources separately from actual funded output, destination, Intel spend versus income, in-transit count, and a short progress assessment. Examples: Sending / Waiting for Intel / Waiting for bots / No route / Insufficient pressure. Say ?estimated while current rates hold? where predicting progress. Do not equate selected stock with committed force or legal reach with sufficient damage.

### Critical recovery defect: ordinary building choices can permanently stop all attacks

**Confirmed:** both starting nodes can fill their spare slots with non-Intel buildings. At zero Intel, no Intel income, and no remaining attack flights, no command can restore offensive supply: every slot is full and there is no building replacement/removal. The controlled recovery fixture sent zero bots and rejected attempts to add Intel buildings. [Building rule](probe_project/scripts/botnet_proto.gd#L215), scenario `full_slots_zero_intel_no_recovery`.

Without any Intel income, the default fifty Intel funded fifty departures in the two-source tests and failed even against the weakest idle frontier node; it subsequently recovered. Active enemy behavior can change that battle, so this does not prove all normal openings unwinnable.

**Recommendation:** make the secondary building slot recoverable in this prototype, with a visible replacement action that can restore Intel production. This is an intentional small rule change, separate from UI fixes. Avoid adding another currency or unlock to recover. Explain that capacity stores Intel but produces none. **Acceptance:** the exact full-slot/zero-income fixture can recover without restarting; the blocked attack points to the recovery action. Also demonstrate one real, AI-enabled opening that teaches combined attacks and can reach a first success.

### Major: counted contributors are not always player-owned or funded

**Confirmed:** Select contributors includes enemy-owned suppliers in the source selection. Command execution filters ownership, but displayed source count/stock becomes misleading. [Case 15](probe_project/captures/15_contributor_selection_includes_enemy_source.png), [recall](probe_project/scripts/botnet_proto.gd#L461).

With two player orders, zero Intel reserve, and income of one/s, the lower-index source sent all 120 packets in a 120-second fixture; the other sent none. A two-source assignment therefore looked combined but had only one source's effective output.

**Recommendation:** Select my sources filters ownership; list hostile attackers separately. Define a predictable scarce-Intel allocation policy, such as fair rotation, and disclose which sources are waiting. Fair allocation does not create more total damage: one Intel/s still funds at most one aggregate attack bot/s. **Acceptance:** selected, eligible, assigned, and actually sending counts cannot be confused; no enemy is selected as controllable and no silent index-based priority is presented as two full streams.

### Major visual confusion: line meaning and threat visibility conflict

**Confirmed:** enemy assault routes into a player node use the same green destination-based color as friendly reinforcement. Focus leaves all immediate neighbors of the target bright, including non-contributing enemies, while unrelated owned nodes and threats fade strongly. In case 14, an attack on owned Node 5 fades while aiming at Node 1. [Screenshot](probe_project/captures/14_aim_dims_attacked_owned_source.png), [drawing](probe_project/scripts/botnet_proto.gd#L628).

**Recommendation:** preserve the existing useful dashed preview, solid standing arrow, and moving packet distinction, but add a compact legend and consistent faction/action treatment. Highlight actual selected contributors and routes, not an unexplained set of bright neighbors. Owned nodes under attack and incoming hostile flows stay legible during focus. Call it Focus rather than Fog: it is not lost visibility or a connectivity rule. **Acceptance:** paused players can explain each line; hostile flows do not read as friendly support; planning one attack does not hide a second threat.

## Proposed compact command panel

Primary content stays fixed; building/removal details are secondary. Example for two sources aimed at an idle ordinary target with no Intel income:

```text
PREVIEW ? nothing sent yet
Sources: YOUR RIG + Node 5                 [Change sources]
Destination: Node 1 (enemy)               [Change target]

Combined capacity: 2 bots/s     In transit: 0
Expected pressure: 1.33/s       Target recovery: 1/s
Intel needed: 2/s               Income: 0/s
Intel reserve: 50 ? about 25 seconds at this net spending rate

[ Start attack from 2 sources ]           [Cancel preview]

Buildings / advanced source details       [expand]
```

After commitment: `ATTACK RUNNING ? 2 sources ? Node 1`, actual sending/hold status, target trend, and `Add sources / Retarget / Stop my supply`. Adding C previews the existing A+B contributors plus C and commits only the intended changes. Existing contributors continue; no individual bot selection or automatic all-map assignment is introduced. A source whose existing order would be replaced is named before commitment.

The precise layout is a proposal, not a rendered implementation. Avoid showing all diagnostic numbers permanently: preserve source names, output, status, and the primary action; detailed damage/regen arithmetic may expand below the simple assessment.

## Documentation and first-use explanation

Use six terms consistently: network connection, supply order, route, preview, bot in transit, resident bots/health. Rename Remove this link to Stop this source's supply, and Remove all links into it to Stop my supply to this target. These stop future departures only.

Fix current contradictions: the basic rules still say one attack bot removes one defender although combat now uses two-thirds; the single-stream-matches-regeneration claim is obsolete; plain-click replacement conflicts with aim mode; enemy Intel exemption conflicts with ?no economy advantage?; group retarget takes aim plus button, not one action. Keep the new intentional Intel/buildings/defender advantage and the explicit commit requirement.

First-use copy: ?Click your first source. Shift-click your second. Click an enemy. Press Start attack. Both sources now send toward that destination. Attacks need Intel; build Intel production to keep them supplied.? Demonstrate this in a solvable, funded opening and then let the player repeat independently. Teach the existing economy at the point it blocks the order. A long manual will not repair the UI hierarchy.

## Validation and scope

Minimum patch order: fix covered nodes and stale state; expose sources/destination/status; make combined output and Intel holds honest; provide Intel recovery; then test the ten-minute loop. Do not enlarge the feature set or silently rebalance damage to conceal command failures.

A first qualitative test can use five people unfamiliar with the prototype. Without coaching after the brief first-use prompt, ask them to: explain a wire versus an order; start one attack; add a second source to the same target; explain why weak/unfunded attacks do not progress; issue an independent third-source order; retarget the original group; stop one source without recalling packets; recover Intel production. Proposed gate: at least four of five complete the core command tasks and correctly predict affected sources; any repeated source/destination error triggers another UI iteration. This is a small diagnostic gate, not statistical proof.

Retain the agreed **approximately ten-minute match target (8?12 minutes)**. Record active decision time separately from confusion, Intel stalls, and futile attacks. Do not stretch play through hidden waiting to meet that target. A verified AI-enabled opening and one complete playthrough are still required before claiming match pacing is good.

Reproduce the retained scenario tool:

```powershell
& 'C:/Users/steph/Downloads/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:/Users/steph/Documents/GitHub/rim/review/botnet_clarity_2026-10-11/probe_project' --script res://clarity_scenarios.gd -- --seconds=120 --fps=60
```

The tool uses the actual frozen runtime with controlled ownership/building/Intel fixtures, records per-source departures and capture, checks stock bounds, and disables enemy AI to isolate these explanations. Re-run on updated rules before reusing numeric conclusions. No numerical rebalance is recommended in this review; correctness, recovery, and visibility are the first interventions.
