# BOT selection usability review

Reviewed 11 October 2026. Decision: make standing bot-production orders predictable and possible in a few deliberate actions. **Recommend selecting production buildings, then commanding a destination once.** The current single-source attack is already short; its problems are hidden group membership, shared draft targets, poor cancellation scope, and scaling.

## Evidence baseline

- **Confirmed:** the final reviewed prototype has 405 lines, 30-bot capacity, regeneration, attrition, and real one-bot travelling packets. Owned nodes are the selectable production sources. The design's new section 0 supersedes its historical sections 1?13. Fuel, internal objectives, war-building construction, operations, and Retreat are absent from this version.
- **Confirmed:** 17 controlled cases passed in Godot 4.7.2 using a frozen copy of the production script and theme, actual GUI mouse input and buttons, and a 1280?720 SubViewport. All 17 states were rendered. Sources, ownership changes, and elapsed time were controlled fixtures; this is engine evidence, not a human playtest or a balance simulation.
- **Confirmed:** the production script changed repeatedly during the audit. Earlier evidence is retained but superseded. Final evidence: [source hashes](source_manifest_final.json), [frozen script](probe_project_final/scripts/botnet_proto.gd), [reviewed design](reviewed_design_final.md), [probe](probe_project_final/probe.gd), [results](probe_project_final/results.json), and [render log](probe_project_final/render_stdout.log). All source references below point to that frozen version.
- **Assumed:** desktop mouse is the initial target; a production building's aggregate output is the intended eventual command object. The prototype currently represents that object as one node. Both enemy attack and friendly reinforcement are common tasks.
- **Unknown:** audience familiarity with strategy controls, human error rates, discovery time, preferences between drag and click, and controller/touch requirements. Action budgets below are requirements, not measured player performance.
- Review artifacts were added; gameplay and design files were not edited by this review. Concurrent edits belong to other work.

Nine review domains were covered: interface/accessibility, audience/comprehension, attention, actions/agency, economy/consequences, space/navigation, theme/mental model, narrative consistency, and validation/scope. Puzzle/hint and multiplayer/community domains were excluded because they do not govern this interface. Combat balance, campaign pacing, city integration, and external genre comparisons were not evaluated.

## Current interaction and honest counts

1. Left-click an owned node toggles it into a cumulative source set. It does not replace earlier sources; clicking it again removes it.
2. Left-click an enemy sets one shared pending destination. A friendly click adds a source instead, so the same click sequence cannot order friendly reinforcement.
3. Dragging a source to a legal destination adds it to that cumulative set and replaces the shared destination. It does not make an independent order.
4. The distant ATTACK/DEFEND panel button commits all eligible sources to the shared destination. The source selection clears; the target remains.
5. Each committed source continuously dispatches along its owned route. Clear links clears the pending selection, while standing assignments continue.
6. Right-click a node clears its outgoing assignment and every incoming assignment. It preserves already travelling packets. There is no ownership restriction on this cancellation.

Evidence: [input and selection](probe_project_final/scripts/botnet_proto.gd#L209), [cancellation](probe_project_final/scripts/botnet_proto.gd#L243), [commit](probe_project_final/scripts/botnet_proto.gd#L261), [panel](probe_project_final/scripts/botnet_proto.gd#L293).

Counts start with clean selection and existing producers; exclude optional pause, corrections, discovery, and pointer travel. A drag is one sustained gesture, not one click. The ten-source scenarios use explicit ownership fixtures, not a claim that the opening contains ten sources.

| Task | Current minimum | Recommended target |
|---|---|---|
| One source attacks enemy | 1 drag + button = 2 gestures; or 3 clicks | Source click + destination right-click = 2 clicks; optional 1 drag |
| One source reinforces friendly | 1 drag + DEFEND = 2 gestures; ordinary click-target flow fails | Same 2-click command; optional 1 drag |
| Ten sources to one destination | 10 drags + button = 11 gestures; or 12 clicks | 1 marquee + destination command = 2 gestures when spatially selectable |
| Retarget the same ten sources | Reselect all ten, then target and commit | 1 destination command with group retained |
| Ten independent source?target orders | 10 ? (drag + button) = 20 gestures | 10 independent direct drags |
| Stop one source with incoming reinforcement | 1 right-click also removes incoming support | Select source + Keep bots here = 2 clicks, only outgoing stopped |

Arbitrary scattered subsets still require deliberate initial selection; marquee cannot make every possible subset a two-action task. Group recall or contributor selection can reduce repeated selection later. Do not meet the budget by auto-assigning the entire map.

## Priority findings

### Major: a second drag silently changes the first source's destination

**Confirmed observation:** drag node 0?1, then node 5?6. Both sources enter one set with target 6; ATTACK assigns both to 6. [Before commit](probe_project_final/captures/04_two_drags_share_target.png), [after commit](probe_project_final/captures/05_both_sources_second_target.png). The toast names only the last source, while the panel reports two.

**Mechanism and impact:** a line-drawing gesture suggests an individual relationship. The data model instead treats it as adding to a group while overwriting a global destination. This can drain a building for a different fight than intended; adding another confirmation does not repair the meaning.

**Smallest intervention:** make drag an explicit immediate order. If the dragged source belongs to a visibly selected group, command that group; otherwise command only that source. Ordinary selection replaces the group; Shift-click deliberately adds/removes. **Validate:** A?X then B?Y leaves two independent assignments, and players correctly predict which sources a group drag affects.

### Major: group selection grows accidentally and must be repeated after every order

**Confirmed observation:** normal clicks accumulate/toggle sources, commit clears all of them, and no marquee or contributor recall exists. [Ten-source plan](probe_project_final/captures/10_ten_source_plan.png).

**Mechanism and impact:** checking a source changes the draft; previously selected sources are easy to forget. Retargeting repeats source assembly, scaling effort with territory rather than strategic decisions.

**Smallest intervention:** left-click replaces selection and shows the source's existing order. Shift-click and empty-map marquee create explicit groups. Keep the group selected after issuing a command. **Validate:** inspecting a building changes no assignment; a selected ten-source group retargets with one destination command. Add Select contributors only if repeated target inspection still requires source hunting.

### Major: attack and reinforcement use different click rules

**Confirmed observation:** click source 0 then friendly 5 produces two sources and no destination. Enemy clicking sets a destination. Dragging provides friendly targeting, then still needs the panel button. [Evidence](probe_project_final/captures/06_friendly_click_is_source.png).

**Mechanism and impact:** ownership changes what a target click means. Defense under time pressure therefore requires a different learned procedure and extra pointer travel.

**Smallest intervention:** selected source(s) + explicit destination command works for both factions: enemy = Attack; friendly = Reinforce. Suggested desktop binding is right-click destination, replacing the existing cancellation binding. Provide select ? Assign destination ? left-click destination as a visible alternative. **Validate:** both tasks work through the same sequence with no hidden draft sources.

### Major: cancellation removes more than the player may intend, including enemy attacks

**Confirmed observation:** with A?enemy and B?A, right-click A removes both assignments, while travelling packets survive. [Evidence](probe_project_final/captures/08_right_source_cancels_incoming.png). In the final rewrite, enemy AI also uses assignments: right-clicking an enemy node removes its attack assignment despite the node being unowned. [Probe case 17](probe_project_final/captures/17_right_click_enemy_stops_enemy.png).

**Mechanism and impact:** a source-level stop also dismantles its defensive supply. Applying the same write to an enemy's assignment creates an unintended way to stop enemy dispatch, rather than merely manage the player's sources. Player misunderstanding is an inference; the state changes are confirmed.

**Smallest intervention:** Keep bots here / Stop supplying affects only selected owned sources' future outgoing dispatch. Preserve incoming reinforcement and travelling packets. Remove unrestricted enemy assignment cancellation. Clearing selection means selection only. **Validate:** stopping A leaves B?A and all packets intact; targeting or inspecting an enemy never changes enemy orders.

### Major: the panel is stale when stock or ownership changes

**Confirmed observation:** after regeneration, a target has 21 bots while the panel still says 20. A draft ATTACK button remains after capture makes the target friendly; pressing it would use the current friendly semantics. [Stale stock](probe_project_final/captures/03_panel_target_count_stale.png), [wrong action label](probe_project_final/captures/13_draft_label_wrong_after_capture.png). The process updates the HUD and map, not the panel's values.

**Mechanism and impact:** the label and underlying command can disagree exactly when the player must decide where production goes. An order acknowledgement alone cannot fix the pre-command information.

**Smallest intervention:** keep selection summary, destination ownership, action, and stock live, without disrupting keyboard focus. **Validate:** capture and regeneration update visible values and action before the next input. Human testers can predict the command's current effect.

### Major: planned arrows and committed supply orders look the same

**Confirmed observation:** both use the same route-line drawing function. Moving packets now represent real deliveries, and correctly freeze during pause; preserve that improvement. [Drawing](probe_project_final/scripts/botnet_proto.gd#L339).

**Mechanism and impact:** a static bright arrow alone cannot say whether the command is a preview, committed but waiting, or supplying. Source inspection also fails to name its standing destination.

**Smallest intervention:** dashed preview versus solid committed route, clear source-selection outline, destination/action label, and real moving packets only for dispatched bots. Use shape/text as well as color. Show resident stock and current outgoing destination; show eligible destinations when sources are selected. **Validate:** testers distinguish selected, planned, assigned, and travelling states with simulation paused.

### Major: capture silently changes attack into reinforcement

**Confirmed observation:** after a target flips, incoming source assignments remain and become friendly reinforcement. The captured node's own outgoing assignment is cleared, but its contributors continue supplying it. [Delivery rule](probe_project_final/scripts/botnet_proto.gd#L174), [case 12](probe_project_final/captures/12_capture_keeps_order_as_defend.png).

**Mechanism and impact:** sources can remain committed after the player's attack has succeeded; deliveries cap at 30, so later arrivals to a full target do not increase stock. Whether this is a desirable strategic policy is unknown, not a proven balance defect.

**Smallest intervention:** preserve the current policy for the usability patch and announce it: ?Captured Node 1; 2 sources now reinforce it.? Show current contributors and offer source-scoped Stop supplying or retarget. Alternatively, stop future supply on capture only after an explicit design decision; do not silently change the rule. **Validate:** players predict the next bot's destination after capture and can change it without reselecting every contributor.

### Minor: invalid and partial orders lack useful explanations; keyboard access is disabled

**Confirmed observation:** an unreachable drag silently does nothing. In a mixed selection the panel counts 40 resident bots across two sources but only one is eligible; commit changes one assignment and clears both selected sources. Buttons use FOCUS_NONE. [Mixed eligibility](probe_project_final/captures/15_mixed_eligibility.png), [partial commit](probe_project_final/captures/16_silent_partial_commit.png), [button focus](probe_project_final/scripts/botnet_proto.gd#L287).

**Mechanism and impact:** players must infer which source failed and why; the stock total overstates participating stock. Drag dependence and unfocusable buttons obstruct equivalent input paths.

**Smallest intervention:** show eligible source count and their stock separately from excluded sources; explain exclusions (?No owned route?, ?Destination is the source?). A partial commit must name affected/excluded members and retain their visible selection. Provide a focusable left-button target-picking alternative and Escape to cancel its draft. **Validate:** mixed selection produces understandable results, and the command can be completed without dragging or right-clicking.

## Proposed interaction contract

The player controls **where each building's aggregate bot production goes**. Several selected buildings can supply one destination; each source has one standing assignment. Network connectivity is an eligibility constraint, not something the player must redraw per command. Bots leave automatically under the existing dispatch rules; retargeting affects future dispatch only.

- **Left-click source:** select/inspect that source, replacing previous selection. Reclick keeps it selected. Inspection issues no command.
- **Shift-click / empty-map marquee:** deliberately modify/select the visible owned-source group. Starting a drag on a node orders; starting on empty map selects.
- **Right-click destination:** command the selected group immediately, enemy Attack / friendly Reinforce. With no selected sources, issue no order. Explicitly replace old right-click cancellation.
- **Optional drag source?destination:** preview while held; release on a valid destination commits. Drag a selected group member to command the indicated group; drag an unselected source to command only it. No mandatory distant button afterward.
- **Retarget:** keep selected group after commit; one new destination command changes its future supply.
- **Keep bots here:** stop only selected owned sources' future outgoing supply. Incoming support and travelling packets continue.
- **Left-button alternative:** select ? Assign destination ? destination click, with explicit cursor/state and Escape to cancel that draft. Inspection of a friendly destination must not implicitly add it as a source in this mode.
- **Order visibility:** name current destination/action in the source inspector, show contributor counts at the destination, and separate draft from standing orders. Optional Select contributors recalls the target's current sources.
- **Preview:** show which source orders would be overwritten, eligible/excluded membership, and reachable destinations. Invalid release retains existing orders and explains why it failed.

The prototype's physical nodes stand in for future buildings. When buildings contain multiple production nodes, the global command should aggregate that building's eligible output rather than introduce per-internal-node clicks. Do not add an internal-node selection step to the basic command.

## Tradeoffs and smallest useful experiment

Direct commitment removes confirmation friction but can dispatch bots after an accidental release. Test destination highlighting, group-count preview, and a modest drag threshold first. Correction changes future assignments; do not label it Undo if already dispatched bots cannot return. Compare a second variant with a nearby confirmation: marquee ? target ? local Confirm, three gestures for a group. The current link-per-source + distant button flow is the baseline. Keep bot values, routes, AI, and victory rules identical across variants.

The recommended first slice is ordinary source selection, contextual enemy/friendly destination command, retained selection, scoped Stop supplying, and live order feedback. Add marquee to test ten-source scaling, and the visible left-button alternative to remove drag/right-click dependence. Group hotkeys, reserve sliders, split percentages, presets, and new economy rules are unnecessary for this decision.

Run a qualitative first round with 5?8 representative players, using the same fixed starting states and counterbalanced variants. Test: one attack; one reinforcement; independent A?X then B?Y; ten-source group attack and retarget; inspecting without changing an order; stopping A while B reinforces A; a mixed reachable/unreachable selection; and explaining where the next bot goes after capture. Start with unguided discovery, then measure learned use separately.

Record clicks, drags, and keyboard actions separately; also task time, corrections, unintended sources/targets, and prediction of future dispatch. Pass criteria: learned single-source order ?2 clicks or one drag; spatial group ?2 gestures; selected-group retarget one command; scoped stop preserves incoming orders and packets in every scripted case. For a small qualitative round, require at least 4 of the first 5 participants to complete the core tasks without instruction after discovery, and stop to revise any repeated wrong-source command or stop-scope misunderstanding. These are proposed decision thresholds, not established usability results or statistical proof.

## Documentation cleanup

The new section 0 correctly marks the attrition model as current and sections 1?13 as historical. Keep that distinction. Remove the remaining section-0 `ENEMY_SEND 10` statement: the reviewed script now activates persistent enemy one-bot streams and has no ENEMY_SEND constant. Add the new selection/order contract and explicit capture/cancellation semantics to the current section; archive historical ?Implemented now? headings so they cannot be mistaken for current behavior. Do not implement historical fuel, internal objectives, demand gating, or Retreat as part of this usability work.

[Claude-ready handoff](CLAUDE_PROMPT.md) contains the proposed behavior and acceptance cases.
