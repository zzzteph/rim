# Claude instructions: make links and combined attacks understandable

Read the CURRENT `design/BOTNET_ATTACK_DESIGN.md` and `scripts/botnet_proto.gd`, then `review/botnet_clarity_2026-10-11/REVIEW.md`. The review includes 17 rendered GUI/state cases and 10 controlled runtime scenarios. Check for later changes before editing; preserve unrelated work.

The creator is struggling to understand what a link means, how to start an attack, and how to combine several sources. This is a prototype with an approximately ten-minute match target (8?12 minutes). Prioritize a readable, teachable command loop. Preserve the current intentional Intel/buildings, defender advantage, one-bot streams, and explicit Select ? Aim ? Commit model. Earlier review instructions to omit Intel no longer apply. Avoid changing to instant-click/drag attacks during this UI pass.

## Player model to make visible

- Network connection: an existing wire; the player is not drawing new network topology.
- Supply order: keep sending a source's bots to one final target.
- Route: existing connections used by a travelling bot.
- Preview: a proposed order; nothing has changed yet.
- Resident bots: the number stored at a node, also its health.
- Moving dots: dispatched bots, which act only at their final destination.

Combined attack means A?X AND B?X. Each source sends up to one bot/s, subject to stock, route, and Intel. It does not mean A?B?X: that reinforces B, whose own sending limit remains one/s. Passing through a node does not recruit its production. Sixty selected resident bots are not an immediate sixty-bot volley.

## 1. Repair the interaction and layout defects

- Reserve playable map space outside the panel. At 1280?720 the current panel covers Nodes 10 and 11, and actual clicks on Node 10 are intercepted. Every node hit area and label must remain visible/selectable at supported window sizes.
- Pin the primary preview and Attack/Reinforce action so they never require scrolling. Building and removal controls belong below the main command or in a separate/collapsed section. The reviewed retargeting state puts Attack below the visible scroll area.
- Finish command state transitions before refreshing the display. Currently commit leaves a stale ATTACK button after its pending target is cleared.
- Escape, right-click, and Clear cancel all pending target/focus state while preserving standing orders and airborne bots. Replacing the source set or recalling contributors must not inherit a stale pending target.
- Keep stock, ownership, action, selected membership, and waiting status live. A friendly target must not retain an ATTACK label that will reinforce it.

## 2. Show exactly what the next click means

Use clearly labelled stages: Choose sources ? Choose destination ? Preview ? Order running.

Show named source chips/count plus a visible Change sources action. If retaining the current behavior where selecting a source immediately makes subsequent node clicks choose a destination, prominently show ?Choose destination? and provide Change sources to return to source selection. Do not promise that ordinary clicks replace sources while the interface is in destination mode.

Make Shift-click to add/remove sources and empty-map box selection visible beside the source group. A valid drag aims only; the command button commits. Sources remain selected after commitment for fast retargeting.

Keep efficient paths:
- One source: source click + destination click + commit.
- Two sources: source click + Shift-click second + destination + commit.
- Spatial group: box-select + destination + commit.
- Retained-group retarget: new destination + commit.

After commitment, show ?Attack running: A + B ? X? and actual supply status. Do not leave the panel looking as though the player must press Attack again.

## 3. Explain and support combining attacks

The target view should show existing player contributors and any proposed additions separately. Adding C to A+B?X should clearly preview three contributing sources and preserve the two existing orders. Show which existing destination will be replaced if C was assigned elsewhere.

Provide Add sources / Retarget / Stop my supply through the existing command flow. Select my sources selects only currently player-owned contributors; list hostile attackers separately. The current contributor recall incorrectly includes enemy sources.

Show combined actual output, not just selected stock or reachability:
- selected and reachable sources;
- actual bots/s leaving toward this target;
- in-transit bots;
- per-source Sending / Waiting for Intel / Waiting for bots / No route;
- a simple target trend or expected-progress assessment.

At current values, each attack bot removes 2/3 defender. One funded 1/s stream cannot overcome an idle ordinary node's 1/s regeneration. Two can progress slowly. An idle HUB regenerates 2/s, so three streams only match it and four can progress. These are conditional examples: outgoing target supply, incoming reinforcement, shortages, and travel change the result. Do not hard-code ?two sources always win.?

A second Bot building increases resident regeneration, not the one-bot/s dispatch limit. State that directly on the build action.

## 4. Make Intel blocking visible and recoverable

Preview Intel spend/s, income/s, and reserve. If income is below projected spend, show an approximate reserve duration under current rates. At zero Intel show ?Waiting for Intel? beside the affected order and the recovery action; keep the standing order visible.

The reviewed two-order/one-Intel-per-second fixture funded one source for all 120 departures and the other for zero. Define a predictable allocation policy, such as fair rotation, and disclose actual funded output. Fair sharing must not imply extra aggregate throughput: one Intel/s funds at most one attack bot/s.

Fix the permanent recovery trap: both starting spare slots can be filled without Intel production; after Intel runs out, there is no way to restore offense. For this prototype, make the secondary building slot replaceable through an explicit action, so Intel production can be restored without restarting. Treat this as a small documented rule change. Capacity stores Intel; it does not generate it.

Provide one teachable, AI-enabled opening in which the player can fund a combined attack and achieve a first success. Do not rely on a hidden economic prerequisite or silently grant resources after a failure. If a starting-resource/building adjustment is needed, report it separately from UI changes.

## 5. Give line styles one meaning each

Keep thin network wires, dashed uncommitted previews, solid directional orders, and moving dispatched bots. Add a compact legend. Distinguish faction and action consistently: an enemy attack into a player node must not look like green friendly reinforcement.

Rename ?Remove this link? to ?Stop this source's supply.? Rename target-wide removal to ?Stop my supply to this target.? These actions stop future departures only; wires, incoming enemy attacks, other friendly support, and travelling bots remain as appropriate to the explicitly named scope.

Highlight actual sources/routes/target. Do not imply every bright neighboring node contributes. During focus, keep attacked owned nodes and hostile incoming flows legible. Call the effect Focus, not Fog.

## 6. Teach the loop briefly and validate it

First-use prompt:
?Click your first source. Shift-click your second. Click an enemy. Press Start attack. Both sources now send toward it. Attacks spend Intel; Intel production keeps them supplied.?

Place the explanation beside the relevant controls and show a solvable first task. Avoid a long tutorial wall or hiding buildings that are required to recover Intel.

Acceptance cases:
- Every node is selectable and the primary command is visible without scrolling.
- A+B?X starts only after commit; both actual streams are visible when funded.
- Adding C preserves A+B, while an independent D?Y order changes only D.
- A?B?X is not labelled as two attack streams toward X.
- Retarget affects future departures only; stopping one source preserves other orders and airborne bots.
- Escape clears preview/focus; commit leaves no stale command; ownership changes update action labels.
- Enemy contributors never enter the controllable selection.
- Weak pressure and missing Intel produce different, understandable explanations.
- Full slots plus zero Intel can recover through a visible action.
- One complete AI-enabled playthrough demonstrates a feasible path toward the HUB.

Use brief novice testing after engine checks. Ask players to explain wires versus orders, combine two sources, add a third, identify why an attack stalls, and stop/retarget correctly. Record corrections and confusion separately from combat waiting. Aim for roughly ten minutes per complete match, without padding it with stalls.

Update the active design to match the new controls and actual damage/economy. Fix its conflicting one-damage and one-stream-matches-regeneration claims, source replacement description, enemy economic symmetry claim, and retarget action count. Keep history archived.

Report what changed, actual action counts, tests, and remaining player-test questions. Prioritize these clarity and recovery fixes before adding more systems or rebalancing combat.
