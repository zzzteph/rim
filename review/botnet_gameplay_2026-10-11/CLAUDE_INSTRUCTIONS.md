# Claude instructions: improve the botnet prototype's controls and gameplay reliability

Read `design/BOTNET_ATTACK_DESIGN.md`, `scripts/botnet_proto.gd`, `review/botnet_gameplay_2026-10-11/REVIEW.md`, and the preceding `review/bot_selection_2026-10-11/REVIEW.md`. Recheck the current files because they are being edited concurrently. Preserve unrelated changes.

This is a small gameplay prototype. Prove that assigning production, defending sources, and responding to travel delays creates understandable decisions. Current section 0 supersedes the historical sections 1?13. Preserve the simple attrition model: capacity 30, regeneration, single-bot streams, source depletion, faction-owned routing, effects only on arrival, HUB victory, and defeat when the last owned node is lost. The latest reviewed settings are SEND_RATE 1 bot/s, LINK_TIME 1 second/hop, and NODE_ROUTE_DELAY 0.25 seconds/intermediate node. Travel is now hop by hop: source and target add no routing delay, intermediate nodes visibly pause transit without storing the bots; one hop takes 1 second and two hops take 2.25 seconds. Preserve that current baseline initially and keep the values provisional. Do not add fuel, interior objectives, construction, new currencies, progression, unit types, or city integration.

## 1. Correct mechanics before tuning difficulty

- **Cancellation authority:** the current cancel function can stop enemy streams. Player commands may modify only currently player-owned sources. Stop supplying clears selected sources' future outgoing orders only. Incoming friendly support, incoming enemy attacks, and packets already travelling must continue.
- **Consistent time:** the current emitter sends at most one bot per frame and ages newly emitted packets by the entire frame. Resolve all due departures up to available stock and respect each bot's departure time. No arrival may precede departure plus route duration. The latest hop-phase implementation also discards remaining elapsed time when crossing a link or ending a node pause. Carry that time through all due phase transitions, including zero-delay routing; preserve visible intermediate pauses. Ensure production, emission, AI cadence, and movement use consistent elapsed time. Preserve visually distinct one-bot packets.
- **Arrival chronology:** process arrivals by actual arrival time, not flight-list order. An earlier reinforcement must affect a later attack even when both occur within one frame. Define deterministic equal-time resolution independent of source-array order; recommended policy is to resolve truly simultaneous opposing arrivals together at each target before checking capture.
- **Terminal states:** apply HUB victory/last-node defeat at the documented event boundary. Once a result is established, stop further simulation and order changes and display result/Reset immediately. Never allow both win and loss. A later arrival in the same frame must not mutate the board after a valid terminal event.

These are reproducible correctness problems, not requests for balance changes. The mechanics review contains 12 controlled engine cases, including a false HUB victory caused by arrival ordering.

## 2. Make building assignments take a few deliberate actions

The player commands a building's aggregate bot output. The prototype represents each producer as one node; do not add per-bot or per-internal-node selection.

- Left-click selects/inspects one owned source, replacing previous selection. Clicking it again keeps it selected. Inspection issues no order.
- Shift-click and empty-map marquee deliberately create a visible source group.
- Selected source(s) + right-click destination commits a persistent order: enemy = Attack; friendly = Reinforce. Replace the old right-click cancellation binding. No selected source means no order.
- Optional direct source-to-destination drag previews while held and commits on valid release. Dragging a selected group member commands that visibly indicated group; dragging an unselected source commands only it. A?X followed by B?Y must leave independent orders.
- Keep the source group selected after an order. Retargeting requires one new destination command.
- Add Keep bots here / Stop supplying for selected owned sources, with the scope defined above.
- Provide a visible left-button alternative: select ? Assign destination ? destination click. Escape cancels this draft only. Controls must be keyboard-focusable.
- Show legal destinations, the affected source group, assignments being replaced, and any excluded sources before commitment. Invalid input leaves existing orders intact and explains why it failed. Mixed eligibility reports participating stock and excluded members accurately.

This intentionally replaces section 0's mandatory drag/link + separate ATTACK/DEFEND button. The explicit right-click destination or valid drag release is the commitment gesture. Update the controls text accordingly.

Budgets: single source ?2 clicks or one drag; spatial group = marquee + destination; selected-group retarget = one command; source-scoped stop = select + Stop; left-button alternative = three clicks. Arbitrary scattered subsets still require initial selection. Never meet the budget by automatically assigning all owned buildings.

## 3. Make ongoing orders and lifecycle visible

- Keep stock, ownership, action, source eligibility, and selected membership live. A captured friendly target cannot still display an ATTACK action that actually reinforces it.
- Show current destination/action in source inspection; show contributors when inspecting a destination. A Select contributors action may recall them without individually finding each source.
- Distinguish selection, dashed preview, committed route, and actual travelling bots. Label resident stock separately from in-transit bots. Preserve correct pause behavior.
- Preserve player standing-target behavior for this patch: capture changes incoming attacks into reinforcement; losing a destination changes supply into attack. Announce the transition. Capturing/losing a source clears that source's old outgoing order and immediately changes command authority.
- Retargeting changes future departures only. Already dispatched bots keep their faction, destination, and route and finish even after source/relay ownership changes. Document this as a prototype simplification.
- If no owned route remains, stop future dispatch and visibly report the stopped order. For this prototype, retaining the current cleared-order behavior is sufficient; state that restoring the route requires reissue. Use an alternate owned route if one exists. Do not silently add auto-resumption.
- End-state Reset must appear without an unrelated map click.

## 4. Respect the latest three timing variables

At SEND_RATE = PROD_RATE = 1/s, an unthreatened full source remains around 29?30 bots while sending. One steady stream only matches an idle target's regeneration; the reviewed one-source fixture did not capture within 60 seconds. Two sources captured its 20-stock target in about 24.0 seconds. This can support deliberate concentration, but do not promise that sending alone substantially empties the source. Local defensive cost still emerges when the source is attacked.

Keep 1/s as the current baseline. After correctness fixes, compare 2/s as one separate tuning experiment if meaningful stock expenditure is desired; do not silently restore an older rate. The retained balance probe has 32 cases across sending rates, initial stocks, and link delays. Its current-runtime times are diagnostic, not final balance targets; rerun after timing fixes.

State each parameter's role and direction: increasing SEND_RATE releases faster; reducing LINK_TIME or NODE_ROUTE_DELAY lowers travel delay. NODE_ROUTE_DELAY currently adds latency to every packet and does not limit concurrent throughput or create a queue. Keep this simple model. Upgrades, congestion, and an upgrade tree are future work. Bots passing through a node must never add to its resident stock. Treat local allocation and delivered pressure as the skill to test, rather than a universal claim that the side with more total nodes wins.

## 5. Keep gameplay improvements small and explicit

**Minimal AI improvement:** on its existing decision cadence, reassess enemy orders whose hostile target became friendly or unreachable. A completed attacker must not stay excluded forever just because it is now feeding a friendly full node. It can release that order and choose a valid adjacent hostile target. Keep the current simple enemy; no global planner or new advantages.

**Full-friendly reinforcement experiment:** currently excess arrivals disappear at cap while sources keep dispatching. At 1/s regeneration can replace that expenditure in an unthreatened source; do not claim persistent stock depletion from this alone. This is current behavior, not an arithmetic bug. Show it clearly first. Recommend testing one separate rule: hold future friendly supply when there is no room after accounting for already travelling friendly bots; retain the order and resume when room opens. Keep dispatched packets unchanged. Compare the cost of delayed response when a full node comes under attack, especially on longer routes. Label this as an intentional experimental rule change; do not mix it into correctness fixes or restore the historical fuel/operation-demand model.

Treat ?two producers beat one? as a testable scenario, not a universal promise. Delivered pressure, travel time, starting stock, and exposed sources matter. Keep numerical tuning separate until the corrected prototype can be played reliably.

## 6. Validate the actual player loop

Use focused engine checks and a short manual pass. At minimum:

1. Independent A?X and B?Y orders remain independent; a group retargets in one command; enemy and friendly destination commands follow the same flow.
2. With A?X, enemy X?A, and friendly B?A, stopping A changes only A's outgoing order and preserves all travelling packets.
3. Equivalent elapsed time and orders at common frame rates plus deliberate hitches produce equivalent emission/arrival outcomes within a small stated numerical tolerance.
4. Earlier enemy reinforcement prevents a later HUB capture when appropriate; reversing the stored flight list does not change the result.
5. HUB capture followed by later enemy arrival, last-node loss followed by later player arrival, and truly simultaneous arrivals follow the documented terminal rule.
6. Capture/loss with bots airborne, lost/restored relay, alternate route, exact-zero capture, and source ownership changes match the declared lifecycle.
7. Full-friendly supply follows whichever baseline/experimental policy is explicitly selected; no packet is duplicated, recalled, or refunded.
8. Enemy AI can retarget a completed attack; pause freezes production, packets, and enemy timing; result controls appear immediately.

For a small player test, use two sources versus one, repeat with longer reinforcement travel, then add pressure immediately after capture. Observe whether players can predict the next bot's destination, explain a node loss, and adapt with few actions. Record action counts, wrong-source orders, corrections, and decisions. Do not claim final balance or improved novice usability from automated checks alone.

## 7. Replace the active document with a concise current specification

Preserve sections 1?13 in a clearly labelled historical archive. Keep the active document focused on current goal, rules, provisional values, controls, standing-order lifecycle, AI behavior, terminal resolution, prototype simplifications, and validation questions. Preserve the latest correct enemy description: it activates persistent single-bot streams every ENEMY_CADENCE. State the current hop-based travel formula clearly, counting routing delay only at intermediate nodes. Clarify that friendly arrivals become resident stock that can subsequently be dispatched under the attrition model.

Implement in small reviewable stages: mechanics correctness; selection and feedback; minimal enemy retargeting; then separately evaluate full-friendly supply and the sending-rate tradeoff, one change at a time. Report what changed, checks performed, actual action counts, and remaining design questions. Keep the prototype small.
