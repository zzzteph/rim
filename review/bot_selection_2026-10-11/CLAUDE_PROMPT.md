# Claude instructions: make bot-production orders predictable and fast

Read `scripts/botnet_proto.gd`, section 0 of `design/BOTNET_ATTACK_DESIGN.md`, and `review/bot_selection_2026-10-11/REVIEW.md`. The review's final snapshot is the 405-line one-bot-stream attrition prototype, recorded in `source_manifest_final.json`. Recheck source changes before editing. Sections 1?13 of the design are historical and explicitly superseded.

Improve selection and assignment usability. Preserve current bot production/capacity, attrition, transit, route ownership, enemy AI, and victory/defeat rules. Preserve unrelated working-tree changes. Do not bring back fuel, internal objectives, construction, operation machinery, or Retreat from historical sections. The review provides controlled engine evidence, not player testing.

## Player-facing contract

?Select these production buildings and tell them where their output goes.? The building's aggregate output supplies the destination automatically afterward. Players choose contributors deliberately; never automatically assign every reachable building. In this prototype a map node represents a producer. Future multiple internal production nodes must not require extra clicks for the global assignment.

1. Ordinary left-click selects/inspects one source and replaces previous selection. Reclick keeps it selected. Inspection must not issue or prepare a hidden reassignment to an old target.
2. Shift-click deliberately adds/removes source members. Empty-map marquee selects owned sources; show membership and count clearly. Starting a drag on a source is distinct from starting selection on empty space.
3. Selected source(s) + right-click a valid destination issues a standing order: enemy = Attack; friendly = Reinforce. Explicitly replace the current right-click cancellation binding rather than attach both meanings to it. With no selected sources, right-click issues no order.
4. Optional source?destination drag shows a preview and commits on valid release. A dragged selected-group member commands that visibly indicated group; a dragged unselected source commands only itself. A?X then B?Y leaves those independent assignments intact. Invalid release changes no assignments and explains why it failed.
5. Explicit destination commands require no extra distant ATTACK/DEFEND button. Show destination, action, and affected group before commitment, and acknowledge afterward. Keep the source group selected so one destination command retargets it.
6. Provide a visible left-button-only alternative: select sources ? Assign destination ? left-click a friendly or enemy destination. Show explicit target-picking mode; Escape cancels its draft without cancelling standing orders. Make equivalent controls keyboard-focusable.
7. Keep bots here / Stop supplying affects only selected OWNED sources' future outgoing dispatch. Preserve incoming reinforcement, resident stock, and all travelling packets. Remove the current ability to right-click an enemy and cancel the enemy's own AI dispatch assignment. Clearing selection only clears selection; replace ambiguous Clear links wording.
8. Source inspection shows its live resident stock and current standing destination/action. Destination inspection shows current contributors. Add Select contributors if needed to recall them without individually hunting sources again. It must never include enemy-controlled contributors in player commands.
9. Keep panel stock, ownership, and action live. A target becoming friendly must not leave a button labelled ATTACK that performs reinforcement. Distinguish selected source, dashed pending preview, solid standing route, and actual travelling packets using text/shape as well as color. Preserve real packet motion and its correct pause behavior.
10. Highlight reachable destinations when sources are selected. Preview eligible/excluded sources, participating stock, and which existing source orders will be overwritten. Mixed eligibility must disclose exactly which members change and which do not; retain visible membership. Explain unreachable/self-target/not-owned cases. Never count an excluded source's stock as participating.
11. Preserve current capture behavior for this usability patch: incoming attack assignments become friendly reinforcement. Explicitly notify the transition and show contributors, e.g. ?Captured Node 1; 2 sources now reinforce it.? Stop-on-capture is an alternative design decision, not an implicit bug fix. Document the chosen policy.
12. Retarget/stop changes future dispatch only. Do not promise an Undo that recalls travelling bots. Avoid adding reserve sliders, split ratios, group presets, or new economy systems before the basic interaction is validated.

## Action budgets

- Single-source command: two clicks (select + destination command), or one direct drag.
- Spatially selectable group: one marquee + one destination command.
- Already selected group retarget: one destination command.
- Stop an unselected source: source click + Keep bots here.
- Left-button alternative for one source: three clicks.
- Ten independent source?target orders: ten direct drags, without ten additional confirmations.

These counts exclude discovery, corrections, optional pause, and pointer travel. Arbitrary scattered subsets require initial deliberate selection; do not disguise that cost or replace it with automatic whole-map assignment. If direct commitment causes accidental losses, compare a nearby Confirm variant: marquee + target + Confirm, three gestures per group.

## Required acceptance cases

Verify through actual GUI input and rendered state as well as assignment data:

- A?X then B?Y produces independent orders; no source is silently redirected by a later drag.
- Clicking B after A selects B alone; Shift-click creates a visible group; reclicking a selected source does not deselect it.
- Enemy Attack and friendly Reinforce use the same destination-command sequence.
- Ten selected sources can be assigned as a group and retargeted without selecting ten again.
- With A?X and B?A, stopping A preserves B?A and all travelling packets.
- Enemy inspection/targeting/invalid inputs do not write enemy-owned assignments.
- Clear selection and Escape cancel drafts only; standing supply continues.
- Regeneration and ownership changes update panel stock and action before another input.
- Capture preserves and clearly announces the documented transition to reinforcement.
- Invalid drag leaves existing orders intact and provides a reason; mixed eligibility identifies participants and exclusions accurately.
- Preview, standing routes, and travelling bots remain visually distinguishable while paused.
- The visible left-button alternative can complete both destination types; controls support keyboard focus.

Use the frozen review probe/results as reproducible evidence of the old defects, not as a demand to preserve the old input contract. Report behavior changed, checks performed, action counts, and remaining human-test questions. Do not claim improved novice usability without player evidence.

## Current design documentation

Update the current section 0 with the selection/assignment contract, source-only stop semantics, retained selection, and capture policy. Remove its obsolete ENEMY_SEND 10 reference: current enemies activate one-bot persistent streams. Preserve historical material in a clearly labelled archive; do not mix its fuel/internal-objective rules into the current usability implementation.
