# RIM game, UX and performance audit — 100 findings

Reviewed on 3 October 2026. **44 bugs and 56 improvements** are prioritized below. Bug findings identify incorrect existing behaviour; improvements identify proposed design, usability or optimization changes. Runtime verification, source confirmation and proposals are marked separately. This is not a claim of 100 reproduced bugs.

Specialist agents covered simulation, game design, HUD/Stats/alerts, map/minimap, build/research/jobs, menus/settings/modals and inspector. The root reviewer ran the rendered playthrough, rendering benchmarks and consolidation. A separate agent reviewed classification, duplicates and evidence limits before publication. No production code was edited by this audit.

The workspace began at v0.6.4 and advanced through v0.6.5 to declared **v0.6.7** during concurrent work. The final reviewed snapshot is source_latest, with a production-hash manifest. New pre-game accessibility, contract Decline/resource filtering, rerouting, operational states and effective capacity are credited; implemented recommendations were removed. Simulation/HUD probes and the 50-check regression suite ran again, other UI/map/design claims were source-rechecked, and fresh threat/victory/menu screens were rendered. Stage filenames containing v066 refer to the final capture stage; its project declares v0.6.7.

## What was played and measured

The actual rendered opening used input events and verified mouse position: New Game (seed 1321476956), choose/deploy a legal Mirai, connect DNS to C2, let packets arrive for 12 real seconds, select/disable/enable the producer, open every sidebar tab, save/load, change text size through the real Settings buttons and exercise pause/accessibility displays. That opening used starting resources and produced 11 delivered packets at the 12-second checkpoint. It did not complete a full campaign.

A separate Netrun prototype and its menu entry appeared after the frozen source_latest cutoff. The100 selected findings cover the existing main game and shared interface represented by that snapshot. The prototype is not included in played evidence, and the discovery proposal should be coordinated with its ongoing implementation.

Screenshots 01–20 are this legal opening/UI session. Screenshots 25–29 use explicitly controlled threat/victory/UI states; fresh final-version captures are in screenshots_latest. Corruption, packet-rerouting and economy probes use isolated fixtures. Dense network and 3000-packet tests are synthetic stress scenarios, not legal economic playthroughs.

The previous regression suite passed **50 assertions with 0 failures** on the baseline and again on the final snapshot. Already-fixed older issues were not counted. New probes produced separate evidence; no shipping-build FPS claim is made.

Measured environment: Godot 4.7.2, OpenGL Compatibility, 1280×720, AMD Ryzen 5 5600H, NVIDIA RTX 3060 Laptop GPU. Render probes use fixed camera, VSync off, main._process disabled to remove external mouse/edge-pan interference, with world clock/redraw and 10Hz simulation ticks driven by the harness; UI runs normally. Frame intervals are local rendering/UI measurements. Headless microbench timings are CPU work only. Each dense fixture has the same camera before/after. Reported frame medians use 60 or 80 observations; they are short local samples.

| Fixture | Result | Meaning |
| --- | --- | --- |
| Opening, paused | 2595 draw calls;11.99ms median frame interval | Retained world commands still render when no world redraw is requested |
| Synthetic50/150/400 nodes, motion on | 30.89/86.15/119.89ms median | Local dynamic-render scaling; not a campaign FPS estimate |
| Synthetic400 nodes, reduced motion | 35.97ms median;8094 draw calls | Command regeneration drops; dense retained geometry remains costly |
| Synthetic400-node simulation | ~13ms per0.1s tick | CPU tick budget and catch-up deserve attention |
| Synthetic400-node fog rebuild | 40.25ms mean | Node-set changes can spike synchronous work |
| Synthetic3000 packets, winding route | 9.235ms mean movement;13.647ms p95 | Repeated segment lookup scales with traffic |
| Distant A* route preview | 6.41ms mean per search | Remaining synchronous hover work after existing heap/cache improvements |

See [performance_results.json](performance_results.json), [render_results.json](render_results.json), [playthrough.json](playthrough.json), [final simulation results](probes/simulation_v066_results.json), [final HUD results](probes/hud_v066_results.json) and [final regression results](probes/t99_v066_results.json). Discarded harness attempts are named discarded_* and are excluded from conclusions.

## What to fix first

1. Protect saved runs: make restore atomic, validate graph/numeric/schema state, preserve the valid backup and refresh the restored world. Fix blocking modal focus so keyboard actions cannot run behind Settings/pause dialogs.
2. Make every existing screen usable at 100–200%: flowing palette cards, readable full tab names, responsive HUD rows, separate threat/alert space, and victory actions reachable by keyboard and pointer.
3. Correct the network feedback players depend on: both packet directions after rerouting, contract deliveries counted from actual events, traffic based on active production, consistent roof hit targets and fresh route previews.
4. Profile one optimization at a time against the retained fixtures: batch/cull the static city, cache host and route geometry, reduce unchanged UI work, then address fog and packet lookup. Preserve visual readability and compare equivalent scenes.
5. Establish the smallest discovery base once the existing loop is reliable, coordinating with the new Netrun prototype: scan -> reveal -> hack -> persistence -> optional payload -> scan further. Use 3–5 connected hosts grouped into 1–2 organizations. Persistence itself extends scanning; a payload is a separate production choice. Keep host interiors unknown until scanned.

The most useful interface changes are a short sustainable-Cycles checklist; host/resource/operating-cost details before committing; costs and deficits on cards; inspector actions above flavour text; active/claimable jobs above offers; alerts that select the actual failing tunnel or threatened branch; and a minimap showing access, selection and network health.

## Count and coverage

| Area | Findings |
| --- | --- |
| Build, research and jobs | 14 |
| Game design | 13 |
| HUD, Stats and alerts | 18 |
| Map and minimap | 14 |
| Menus and inspector | 13 |
| Rendering and performance | 12 |
| Simulation and saves | 16 |

| Evidence class | Findings |
| --- | --- |
| proposal | 32 |
| source_confirmed | 21 |
| verified_runtime | 47 |

P1 means first tranche because it risks runs, blocks interaction, prevents readable critical feedback or addresses the dominant experience/performance issue. P2 improves correctness or normal play. P3 is polish or a balance experiment. Design P1s are proposals, not emergency defects. EffortS/M/L is relative implementation size, not an estimate in days.

Each item includes reproduction/context, impact, a concrete change and a check for completion. Related candidates were merged; 27 lower-priority, implemented or merged records are retained in [ADDITIONAL_CANDIDATES.json](ADDITIONAL_CANDIDATES.json), outside the 100-item count. Frozen source links preserve exact evidence even if the working tree changes again.

## The 100-item backlog

<a id="rim-001"></a>
### RIM-001 · A structurally malformed save can erase the live run while reporting success

**P1 · bug · verified_runtime · effort M** — Save integrity

**Evidence:** Controlled corruption fixture: node.path=[[1]] passes _validate_save. load_game returns true and 'Game loaded.' after _apply_save raises an index error and leaves only node 1. Evidence: probes/corrupt_save.log; simulation_project/corrupt_save_results.json. Validator accepts version='999.0' and researched=['invalid_tech']; _is_unlocked later indexes TECH[t] without a guard. Evidence: simulation_results save_unknown_version/save_unknown_research. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** In an isolated copy, save a valid two-node run, replace a path point with [1], then Load. Related unvalidated required tunnel/packet/contract fields also pass the validator.

**Player impact:** Loading a parseable but damaged save changes live state before failure; the success message conceals lost structures.

**Change:** Validate every field and nested collection that _apply_save or simulation consumes; build a complete temporary restored state and commit it only after all coercion and invariants succeed. Declare supported save-schema versions, migrate known older versions and validate researched IDs before committing a temporary restored state.

**Done when:** Malformed vector paths, missing required fields and wrong collection types are refused; the existing run remains byte-equivalent and Load returns false. Unsupported schemas and unknown researched IDs produce a clear error rather than a later lookup failure; supported legacy schemas migrate correctly.

**Source:** [source_latest/scripts/main.gd:2935](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2935) · specialist key `SIM01`

<a id="rim-002"></a>
### RIM-002 · Saved network topology, identities and numeric state are insufficiently validated

**P1 · bug · verified_runtime · effort M** — Saved network integrity

**Evidence:** Controlled schema fixtures all return an empty validation error for hub→child→hub cycles, duplicate node.id and a connected node.tunnel='invalid'. Runtime consequences follow unchecked recursion/dictionary access in _calc_subtree and upkeep. Evidence: simulation_results save_cycle/save_duplicate_id/save_unknown_tunnel. A fixture with next_id=1, camera zoom=0 and compute=-100 is accepted with no validation error; _apply_save assigns these values directly. Evidence: simulation_results save_invalid_ranges. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Mutate a valid serialized fixture's parent graph, node IDs or tunnel key; call _validate_save. These are synthetic damaged saves, not a legal-play topology.

**Player impact:** An accepted save can overwrite the hub, recurse indefinitely, or fail the first simulation tick.

**Change:** Require unique matching node IDs/keys, one root hub, valid parents, acyclic parent chains, valid tunnel/path state for every link, and valid packet-route references. Require finite bounded numeric values, a next_id above all existing IDs, valid camera zoom, footprint bounds and sizes, and valid output/timer/lane values.

**Done when:** Each invalid graph is rejected without applying it; a valid disconnected branch remains loadable. Reject colliding next_id, zero/invalid zoom and impossible numeric state before application; normal generated saves remain valid.

**Source:** [source_latest/scripts/main.gd:2946](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2946) · specialist key `SIM02`

<a id="rim-003"></a>
### RIM-003 · Saving over a parseable invalid file destroys the last-good backup

**P1 · bug · verified_runtime · effort S** — Save backup rotation

**Evidence:** Controlled file fixture: create two valid saves, replace current save with {"version":"0.6.4"}, then Save. _read_valid_save(backup) changes from non-null to null. Rotation checks only JSON dictionary parsing, not _validate_save. Evidence: simulation_results invalid_backup_rotation. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Use isolated save paths; create a valid backup, corrupt current save with valid JSON lacking game state, then save the active run.

**Player impact:** The only recoverable previous run is replaced by semantically unusable data, so a later failed/corrupt current save has no recovery path.

**Change:** Rotate the current file only when the same full validator used for loading accepts it; preserve the previous backup otherwise.

**Done when:** After saving over parseable invalid JSON, the previous backup remains valid and unchanged; ordinary valid rotation still works.

**Source:** [source_latest/scripts/main.gd:2877](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2877) · specialist key `SIM05`

<a id="rim-004"></a>
### RIM-004 · Keyboard focus escapes blocking modals and activates background controls

**P1 · bug · verified_runtime · effort M** — Modal input

**Evidence:** _grab_modal_focus assigns only the initial button. Actual Tab events in controls_probe move Settings Off→Off→Off→Code→100%→Close→Build→Tech→Stats. Enter press/release then changes ui.tab tostats while settings_visible remains true. No focus containment or background-control guard exists. Final source recheck: In-game modal focus helper still assigns the first button without forward/backward trapping. New menu-side modal also only assigns initial focus. Baseline actual key-event evidence remains qualified v064.

**Reproduce/context:** Open Settings, press Tab six times, then activate a background tab; repeat focus traversal around pause/win boundaries.

**Player impact:** A blocking modal permits hidden/background UI actions, undermining input isolation and potentially exposing Load/Quit controls through keyboard traversal.

**Change:** Trap forward/backward focus within the topmost modal and prevent background UI actions while it is open.

**Done when:** Tab/Shift+Tab wrap within Settings, Pause and Victory, including nested Settings; Enter/Space never activates controls behind the modal.

**Source:** [source_latest/scripts/ui.gd:530](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:530) · specialist key `UI-CONTROLS-05`

<a id="rim-005"></a>
### RIM-005 · Enlarged victory results push both exit actions below the viewport

**P1 · bug · verified_runtime · effort M** — Victory modal layout

**Evidence:** At200% and1280×720 the actual victory panel extends to y891; Main Menu starts y822 and ends y883. At1024×600 the configured stretch gives logical1280×750 but the panel still ends906;1366×768 gives the same1280×720 logical overflow. Settings and Pause fit in these checks, so this is one victory-content overflow finding. Results are in controls_probe_results.json modal_sizes. Final source recheck: Victory layout is unchanged: fixed centered offset, wrapping large scorecard and no bounded scroll/action footer. The baseline 200% overflow reproduction remains relevant; new reroute/contract UI does not alter this modal.

**Reproduce/context:** Reach the Cash goal with Text Size200%, including a scorecard with multi-digit statistics.

**Player impact:** Keep Playing and Main Menu are outside the visible viewport; the modal offers no scrolling path to those controls.

**Change:** Constrain the victory panel to the viewport, place results in an internal scroll area and retain visible action controls; center based on final size.

**Done when:** At all supported text scales and tested aspect ratios, the entire action area is visible and focusable; long scorecards can be read without pushing actions offscreen.

**Source:** [source_latest/scripts/ui.gd:653](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:653) · specialist key `UI-CONTROLS-07`

<a id="rim-006"></a>
### RIM-006 · Scaled palette labels overlap neighbouring tool buttons

**P1 · bug · verified_runtime · effort M** — Build palette

**Evidence:** At 1280×720 / 150% text, button remains 52px high while its child content is 69px; Poisoned Package child is350px wide inside284px button. At200%, child grows90px high/440px wide. Confirmed in panels_project/panel_probe_results.json and screenshots/15_build_200.png. Child HBox/VBox does not propagate minimum size to the Button and neither label wraps. Final source recheck: Fixed52px button and non-wrapping name/cost child labels unchanged. Baseline overlap geometry remains baseline evidence, source-rechecked v066.

**Reproduce/context:** Set Text Size to150% or200%, close Settings, open Build, inspect Hacks or Links.

**Player impact:** Names/costs collide and get clipped; the drawn text no longer corresponds cleanly to the hit targets.

**Change:** Make the tool row a container-sized button or propagate child minimum height; wrap or split name/cost within the available width.

**Done when:** At100/125/150/200% every visible tool name and cost occupies its own row, with no sibling overlap or horizontal truncation; the complete row remains clickable and scrollable.

**Source:** [source_latest/scripts/ui.gd:571](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:571) · specialist key `UI-PANELS-01`

<a id="rim-007"></a>
### RIM-007 · The compact header still clips at 200% and removes Feed from the HUD

**P1 · bug · verified_runtime · effort M** — HUD layout

**Evidence:** Reverified on imported source_v065 at 1280×720: the 200% compact header needs 1005 px but has 956 px, clipping its final fields; the legend spans x=600–1399. Compact fallback is implemented, but omits Feed entirely and rounds upkeep to whole numbers. Baseline v0.6.4 geometry is retained separately. Evidence: probes/hud_v065_results.json scaled_hud. Fresh visual verification: screenshots_v065/26_alerts_200.png. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Set Text size to 200% at 1280×720; inspect the compact resource/health header and legend. Larger stockpile digit counts also force compact mode.

**Player impact:** Accessibility scaling still removes information, and compact mode hides network feed even when the network is starving.

**Change:** Use responsive resource chips or wrapped rows with reserved health space. Keep Feed and meaningful upkeep precision when compacting; make overflow information explicitly reachable.

**Done when:** At 100–200% and 1280×720, all six resources and trace/feed/goal/upkeep remain readable or available through obvious overflow controls, without clipping or losing health fields.

**Source:** [source_latest/scripts/ui.gd:847](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:847) · specialist key `HUD01`

<a id="rim-008"></a>
### RIM-008 · Critical sweep headlines and alert buttons occupy overlapping screen space

**P1 · bug · verified_runtime · effort S** — Warnings and alerts

**Evidence:** Controlled sweep+overload UI fixture: headline boundsy66–90 with actual text325px wide; overload buttonx924,y70,w340,h30 intersects the headline's text bounds. Evidence: probes/hud_v065_results.json warn_alert; fresh visual verification: screenshots_v065/25_alerts_100.png and screenshots_v065/26_alerts_200.png. Final HUD rerun measured expanded countermeasure headline988px at100% (previous325px); the overlap persists and is stronger. Evidence: probes/hud_v066_results.json and screenshots_latest/25_alerts_100.png. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Have a sweep active while an overloaded/offline/critical alert is also visible.

**Player impact:** Threat countdown text competes with actionable alerts during the short reaction window.

**Change:** Reserve distinct layout rows for the headline and alert stack, with measured text bounds and scaling-aware spacing.

**Done when:** At100% and200%, simultaneous sweep, overload, offline, starved and trace alerts have no text/button overlap and the countdown remains legible.

**Source:** [source_latest/scripts/ui.gd:287](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:287) · specialist key `HUD03`

<a id="rim-009"></a>
### RIM-009 · Loading another city seed leaves the old baked city visible

**P1 · bug · verified_runtime · effort S** — World rendering / save restore

**Evidence:** Rendered load probe changed seed 1321476956 to 7654321; 302 of 400 district cells changed, but _city_layer emitted zero draw notifications. The minimap correctly changed seed. Screenshots21/22 show before/after;23 is a manual invalidation control. Evidence: render_results.json different_seed_load.

**Reproduce/context:** Run probes/render_benchmark.gd in the isolated copy, or load a valid save with a different seed while gameplay is already open.

**Player impact:** The visible city no longer represents terrain, legal placement and routing used by the restored simulation.

**Change:** Invalidate the baked city after generating the restored city; coordinate all terrain, fog and minimap caches through a world revision.

**Done when:** Loading each of two different seeds refreshes the city layer once and visible terrain agrees with placement/routing descriptors.

**Source:** [source_latest/scripts/main.gd:2973](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2973) · specialist key `PERF01`

<a id="rim-010"></a>
### RIM-010 · A baked city still submits thousands of retained draw calls

**P1 · improvement · verified_runtime · effort L** — Performance / static world

**Evidence:** At1280x720, the fixed opening view had2595 draw calls even when paused and the world emitted zero redraws. Median paused frame interval was11.99ms on this RTX3060 laptop. This is local renderer evidence, not shipping-build FPS; render_results.json paused_build.

**Reproduce/context:** Run the fixed-camera rendered benchmark; compare paused opening draw calls and frame intervals after chunking/batching.

**Player impact:** Redraw gating reduces CPU command regeneration but the renderer still submits the retained city commands on every frame.

**Change:** Partition the backdrop into cullable chunks and compare a texture/mesh batch for static roofs, windows and streets. Preserve crisp zoom and palette changes.

**Done when:** The same paused view has substantially fewer draw calls and lower frame intervals, with seed/palette refresh and terrain fidelity intact.

**Source:** [source_latest/scripts/city_layer.gd:7](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/city_layer.gd:7) · specialist key `PERF03`

<a id="rim-011"></a>
### RIM-011 · Dense structures need cached geometry and detail levels

**P1 · improvement · verified_runtime · effort L** — Performance / dynamic world

**Evidence:** Synthetic50/150/400-node fixed-camera scenes measured median running frame intervals30.89/86.15/119.89ms and3667/6682/8130 draw calls. At400, reduced motion measured35.97ms; pausing35.58ms. Fixtures are unlinked zero-output nodes and establish rendering scaling, not an attainable campaign benchmark.

**Reproduce/context:** Run the three dense rendered fixtures with identical camera, viewport and motion setting.

**Player impact:** Animated geometry and dense retained commands can make network expansion hard to interact with.

**Change:** Cache static host prisms/windows and animate a smaller overlay. Cull and reduce fine details at distance; prioritize selected/threatened hosts and keep silhouettes legible.

**Done when:** Compare50/150/400 fixtures before/after with identical composition; reduce median/p95 cost while selected hosts, packets and threats stay readable.

**Source:** [source_latest/scripts/main.gd:2373](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2373) · specialist key `PERF04`

<a id="rim-012"></a>
### RIM-012 · Add a small discover-and-compromise loop before automation

**P1 · improvement · proposal · effort M** — Hacker fantasy / core loop

**Evidence:** _handle_click routes tools directly to placement, and _try_place_node pays resources and creates an owned node immediately. Unowned map blocks have no host discovery or compromise state. The accepted discovery direction is future work, not a missing implemented requirement. This observation concerns the existing main game mode in the frozen snapshot. A separate Netrun prototype appeared after the cutoff and was not inspected or played in this review; check that work before implementing the proposal. Final source recheck: Placement still instantly creates an owned producer; discovery/acquisition states remain a proposal.

**Reproduce/context:** Source walkthrough: choose a producer, click valid ground, then draw its tunnel; no target assessment occurs.

**Player impact:** The player's main decision reads as building a producer rather than gaining access to a hostile endpoint.

**Change:** Build the smallest accepted base: start on one persistent host in a visible city with unknown contents. Scan graph-adjacent hosts; reveal host type, security and compatible payloads. Hack one eligible host and gain persistence. Install an existing producer/processor as a payload on that host; its output supplies information/resources. Persistence, rather than installing a payload, enables the next adjacent scan. Group several hosts into one named organization. Prototype3-5 hosts and1-2 organizations before extending the economy.

**Done when:** A fresh run completes scan -> reveal -> hack -> persistence -> optional payload -> scan further in five minutes. Unknown host interiors stay hidden; nonadjacent targets cannot be scanned; a newly persistent empty host can reveal its neighbours. Organization membership is legible, and acquisition/production have separate states.

**Source:** [source_latest/scripts/main.gd:1408](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1408) · specialist key `D-HOST-DISCOVERY`

<a id="rim-013"></a>
### RIM-013 · Teach a sustainable Cycles backbone before expanding Intel sales

**P1 · improvement · source_confirmed · effort S** — Onboarding / economy

**Evidence:** _next_step asks for a Phishing Kit before checking any Cycles source. has_producer includes Intel producers, so its later producer check cannot teach Cycles sustainability. Tunnels deduct upkeep from the starting 80 Cycles. Final source recheck: The new post-build recovery-reserve forecast does not change _next_step: opening guidance still asks for Intel before testing sustainable Cycles income.

**Reproduce/context:** Start with only C2: evaluate _next_step, then add a linked Phishing Kit and Market without a compute producer.

**Player impact:** A new player is directed into an unsustainable network before being taught the economy that keeps packets moving.

**Change:** Add a compact first-steps sequence that checks connected Cycles income and upkeep before requesting the Intel-to-Market chain.

**Done when:** Fresh-start guidance requests a productive linked Cycles host; once sustained, it advances to Intel and Cash, and returns to recovery advice if Cycles income stops.

**Source:** [source_latest/scripts/main.gd:1283](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1283) · specialist key `D-OPENING-CYCLES`

<a id="rim-014"></a>
### RIM-014 · Save rotation ignores copy and deletion failures before removing the current file

**P2 · bug · source_confirmed · effort M** — Save durability

**Evidence:** save_game removes an existing backup, ignores the return from copy_absolute, removes the current save, then attempts rename_absolute. Only the final rename is checked. No OS I/O-failure injection was performed. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Source review; relevant situations are a locked file, denied backup write or a filesystem error during rotation.

**Player impact:** A failed backup copy can discard both the old backup and current save before the new file is installed.

**Change:** Check each filesystem result, preserve at least one valid old file until replacement succeeds, and report the failed stage. Use a checked replace/rename strategy appropriate to the platform.

**Done when:** Injected copy/replace failures return false and leave a valid loadable current or backup file; success is reported only after final replacement is readable.

**Source:** [source_latest/scripts/main.gd:2879](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2879) · specialist key `SIM06`

<a id="rim-015"></a>
### RIM-015 · Save/load changes node iteration order and therefore deterministic threat selection

**P2 · bug · verified_runtime · effort M** — Save continuity

**Evidence:** Controlled valid roundtrip: nodes inserted [1,2,10], equal-depth sweep targets2 before save; JSON.stringify sorts object keys, load rebuilds nodes [1,10,2], next sweep targets10. RNG restoration alone does not preserve behavior. Evidence: simulation_results saved_iteration_order. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Compare _launch_sweep before and after a JSON save/load roundtrip of two equally deep branches with IDs2 and10.

**Player impact:** Continuing changes target tie-breaking and the order in which random packet-loss draws are assigned to producers.

**Change:** Use stable numeric node ordering in order-sensitive simulation loops or serialize/restore explicit ordering; specify deterministic sweep tie-breaking.

**Done when:** Identical state plus identical RNG resumes the same packet-loss assignments and next sweep target across save/load.

**Source:** [source_latest/scripts/main.gd:2855](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2855) · specialist key `SIM07`

<a id="rim-016"></a>
### RIM-016 · Outbound processor-input packets can follow an obsolete rerouted chain

**P2 · bug · verified_runtime · effort M** — Packet routing

**Evidence:** Controlled topology fixture: C2→node2→Forge3 input route[2,3]; reroute Forge3 to C2 while packet is on edge2. Packet survives with idx=1, route[2,3] although Forge3.parent=1. Stale-hop check only checks dir==1. Evidence: simulation_results stale_downward_route. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Start a conversion input travelling outward, dismantle/reroute the downstream processor link before input reaches the junction, then let it cross the next hop.

**Player impact:** Input can jump onto a link whose live start is elsewhere, producing resources through a physically impossible route.

**Change:** Validate adjacency in both directions and invalidate packets whenever any stored edge's endpoints no longer match the route snapshot.

**Done when:** Upbound and downbound packets are canceled on changed route adjacency; unchanged packets still arrive exactly once.

**Source:** [source_latest/scripts/main.gd:994](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:994) · specialist key `SIM08`

<a id="rim-017"></a>
### RIM-017 · Delivery contracts count net wallet changes, allowing refunds to satisfy deliveries

**P2 · bug · verified_runtime · effort M** — Contract accounting

**Evidence:** Legal-placement path with a controlled valid Cycles20 offer: place two valid Mirai, accept at60 Cycles, undo both, job completes with progress20 and packets_delivered=0. A separate controlled Intel fixture records20 delivered then spends5: progress15, not20. Evidence: simulation_results legal_placement_refund_contract/consumed_deliveries_contract. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Accept a Cycles delivery job after spending20 on undoable buildings; undo them. Alternatively deliver required Intel while a Market/Lab consumes some before completion.

**Player impact:** Rewards can be earned without delivery, while productive consumption prevents real deliveries from satisfying the advertised objective.

**Change:** Track per-resource cumulative C2 deliveries and snapshot that counter on acceptance; exclude refunds and emergency grants. If retained stock is intentional, rename the objective and still exclude refunds explicitly.

**Done when:** Refunding buildings does not advance delivery progress;20 genuine delivered units complete a20-unit job even when subsequently consumed.

**Source:** [source_latest/scripts/main.gd:2044](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2044) · specialist key `SIM09`

<a id="rim-018"></a>
### RIM-018 · Fuel-starved processors still contribute full traffic and overload other branches

**P2 · bug · verified_runtime · effort S** — Throughput accounting

**Evidence:** Controlled Forge fixture has100 Intel,0 Cycles: _node_traffic reports1.2 packets/s, but a simulation tick spawns0 processor input packets. Traffic predicate checks input only; production also requires fuel. Evidence: simulation_results converter_no_fuel. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Run a connected Forge/Lab with stocked Intel but insufficient Cycles; inspect offered subtree traffic on a shared trunk.

**Player impact:** Nonexistent work adds overload loss to genuine producers and gives misleading bottleneck diagnostics.

**Change:** Use the same operational/input/fuel predicate for offered processor traffic and actual conversion scheduling, or derive load from real emitted traffic.

**Done when:** A processor unable to afford fuel injects0 offered conversion load and cannot make a shared trunk appear overloaded.

**Source:** [source_latest/scripts/main.gd:1923](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1923) · specialist key `SIM10`

<a id="rim-019"></a>
### RIM-019 · A connected Cycles producer at zero output suppresses emergency recovery

**P2 · bug · verified_runtime · effort S** — Recovery economy

**Evidence:** Controlled connected Mirai fixture with cap_rate=0 and compute=0 reports production{compute:0}, has_income=true, reserve=false and compute remains0. _has_cycle_income checks type/on but not effective production. Evidence: simulation_results zero_output_emergency. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Set the output limit of the only connected Cycles producer to0%, deplete Cycles and tick the simulation.

**Player impact:** The emergency reserve's stated no-income condition is false despite zero production, and paid rebuilding actions remain blocked.

**Change:** Test effective positive Cycles production when deciding whether emergency supply is unnecessary; explain the zero-output reason when a manual setting disables income.

**Done when:** At0% effective output and no other Cycles income, the reserve reaches the intended bootstrap floor; restoring positive production ends reserve behavior correctly.

**Source:** [source_latest/scripts/main.gd:1730](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1730) · specialist key `SIM12`

<a id="rim-020"></a>
### RIM-020 · Disabling a forwarding structure silences its live tunnel without stopping transit

**P2 · bug · verified_runtime · effort S** — Trace and routing

**Evidence:** Controlled trunk fixture: disabled node2 still has operational TCP path and forwards an enabled Phishing child; upkeep0.5 remains charged, but trace10 decays to9.88 with no TCP noise. Noise predicate requires source-node on, unlike forwarding. Evidence: simulation_results disabled_tunnel_noise. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Place a producer/forwarder on a loud trunk, connect active child producers through it, then Disable the trunk's source structure.

**Player impact:** A functioning loud tunnel becomes free of noise merely by disabling unrelated local production; this undermines protocol/counterplay choices.

**Change:** Define noise by active tunnel/transit state rather than local producer on/off; if quiet empty links are intended, distinguish idle from actively forwarding.

**Done when:** A disabled local producer forwarding packets through TCP still contributes the documented TCP noise; truly inactive links follow an explicit quiet rule.

**Source:** [source_latest/scripts/main.gd:1878](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1878) · specialist key `SIM13`

<a id="rim-021"></a>
### RIM-021 · A footprint can enter a guarded district while paying the unguarded origin's breach cost

**P2 · bug · verified_runtime · effort S** — District security

**Evidence:** Controlled vision-position fixture on generated seed12345: Fence origin(75,9) hasICE0, center(76,10) hasICE1; placement succeeds and pays0 Tools. Both validation/payment use origin while ownership uses center elsewhere. Evidence: simulation_results footprint_ice_bypass. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Place a2×2 structure across a district boundary with its origin on unguarded ground and center in a guarded district. Fixture moved C2 only to isolate reachability; not presented as a completed legal expansion.

**Player impact:** Border positioning bypasses security costs for a structure owned by guarded territory.

**Change:** Choose one ownership/security anchor consistently for display, validation and payment, or charge the maximum ICE of occupied districts if that is the intended rule.

**Done when:** Every boundary orientation charges the agreed district/security rule, including affordability checks and exact Undo refund.

**Source:** [source_latest/scripts/main.gd:1369](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1369) · specialist key `SIM14`

<a id="rim-022"></a>
### RIM-022 · Mirai consumes shared Cycles district slots but bypasses their placement limit

**P2 · bug · verified_runtime · effort S** — District capacity

**Evidence:** Controlled district fixture with Registry cap2 legally passes _placement_error for3 spaced Mirai; _slots_left then returns-1. Mirai is counted by _slots_left but its placement branch omits the limit. Evidence: simulation_results nest_slot_bypass. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Fill a Cycles district using Mirai. This probe uses a controlled2-slot district to isolate the rule, not a naturally generated whole-map district.

**Player impact:** The same district-capacity indicator applies inconsistently and can show negative slots; Mirai can occupy beyond the cap while other Cycles payloads are blocked.

**Change:** Apply the same capacity rule to all slot-consuming Cycles producers, or explicitly exempt Mirai from both occupancy counting and the displayed limit.

**Done when:** No producer counted toward slots can make slots negative; exempt types are consistently excluded from both counting and validation.

**Source:** [source_latest/scripts/main.gd:1344](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1344) · specialist key `SIM15`

<a id="rim-023"></a>
### RIM-023 · DDoS is advertised as quarantine recovery but leaves quarantine timers unchanged

**P2 · bug · verified_runtime · effort S** — Threat counteraction

**Evidence:** Controlled fixture: successful40-Cycle/1-Tool scrub sets trace0 but leaves quarantine5 unchanged. Inspector explicitly says 'wait it out or DDoS' for quarantine. Evidence: simulation_results scrub_retains_quarantine. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Use DDoS after a sweep has already quarantined a host; observe its remaining quarantine and connectivity.

**Player impact:** Players spend scarce Tools expecting immediate branch recovery that the action does not perform.

**Change:** Choose the rule explicitly: clear quarantine on successful DDoS if it is a recovery action, or change inspector/action copy to say it only stops future tracing and current quarantine must expire. Expose the recovery command beside quarantine/trace alerts, with cost, cooldown and affordability, rather than relying on discovery inside Stats.

**Done when:** Action results match its preview and inspector guidance; quarantine recovery or retained timers are unambiguous. A quarantined player can find the command and predict its actual effect and cost before using it.

**Source:** [source_latest/scripts/main.gd:2790](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2790) · specialist key `SIM16`

<a id="rim-024"></a>
### RIM-024 · Main menu ignores the persisted text-size setting

**P2 · bug · verified_runtime · effort S** — Startup accessibility

**Evidence:** With Settings.text_scale=2.0 before instantiating menu.tscn, the real menu still reports New Game/Continue/Quit font16, subtitle14 and version11. menu.gd applies fixed overrides and never reads text_scale. Captured in panels_project/controls_probe_results.json menu. Final source recheck: Startup/menu controls retain fixed fonts. Only the new preview labels read Settings.text_scale; do not claim all new accessibility-preview text ignores scaling.

**Reproduce/context:** Set Text Size to200% in a game, return to Main Menu or restart with that setting persisted.

**Player impact:** Navigation returns to small text precisely for players who selected enlarged text.

**Change:** Apply the persisted text scale to startup controls and adapt the centered menu layout to the resulting dimensions.

**Done when:** Startup and return-to-menu controls honor100/125/150/175/200% consistently; every action remains visible and operable.

**Source:** [source_latest/scripts/menu.gd:165](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/menu.gd:165) · specialist key `UI-CONTROLS-01`

<a id="rim-025"></a>
### RIM-025 · Closing a nested modal loses keyboard focus instead of restoring its opener

**P2 · bug · verified_runtime · effort S** — Modal navigation

**Evidence:** _close_settings hides the overlay and restores paused state only. When Settings is opened over Pause then closed, controls_probe records nested_settings_closed_focus.path='null'; the Pause overlay remains open without restoring its Settings button or another meaningful focus target. Final source recheck: Closing Settings restores paused state but no focus. New menu._close_settings also only hides its panel. Baseline nested Pause/Settings focus evidence is unchanged logic.

**Reproduce/context:** Open Pause, keyboard-activate Settings, then Close/Esc the Settings panel.

**Player impact:** Keyboard users lose their location after returning to the parent menu.

**Change:** Track the opening control or a modal focus stack and restore a valid visible target when each modal closes.

**Done when:** Close and Esc return focus to the corresponding visible opener for nested Settings, Menu-tab Settings and Victory dismissal; invalid openers fall back predictably.

**Source:** [source_latest/scripts/ui.gd:516](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:516) · specialist key `UI-CONTROLS-06`

<a id="rim-026"></a>
### RIM-026 · Primary navigation tab names are truncated at large text sizes

**P2 · bug · verified_runtime · effort M** — Sidebar navigation

**Evidence:** Five tabs share284px regardless of font scale. At200% screenshots14_menu_200.png and17_jobs_200.png show Bu/Te/St/Jo/Me rather than full names; clip_text is enabled globally and no tooltip or accessible full-label fallback is assigned. This differs from palette-child overlap in UI-PANELS-01. Final source recheck: Primary tabs retain fixed shared sidebar width and scaling plus clipping; no responsive layout/full-label help added.

**Reproduce/context:** Set Text Size200%, close Settings and read the five primary sidebar tabs.

**Player impact:** The navigation destinations become ambiguous abbreviations generated by clipping.

**Change:** Use a responsive tab arrangement, wrap/stack labels or combine stable icons with full accessible names and visible destination help.

**Done when:** Each destination is identifiable at every text scale without guessing clipped text; focus and selected-tab feedback stay clear.

**Source:** [source_latest/scripts/ui.gd:138](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:138) · specialist key `UI-CONTROLS-08`

<a id="rim-027"></a>
### RIM-027 · Same-type tunnel endpoints have indistinguishable inspector names

**P2 · bug · verified_runtime · effort S** — Tunnel endpoint identity

**Evidence:** main._node_name returns the type name and the tunnel inspector concatenates those names. With a controlled two-node same-type UI fixture, controls_probe records 'Links Mirai Dropper → Mirai Dropper'. No instance ID, location or jump action identifies source versus parent. Final source recheck: Links still use _node_name for both ends and return type-level names. Keep controlled two-node fixture wording, not a claim of current legal-play reenactment.

**Reproduce/context:** Connect one Mirai Dropper to another and select that tunnel.

**Player impact:** The inspector cannot identify which actual structures the selected link connects, especially in a large network.

**Change:** Include stable instance IDs/names or coordinates for both endpoints and allow selecting/jumping to each endpoint.

**Done when:** Any two same-type endpoints have distinct readable identities; the displayed direction can be matched to the actual source and parent.

**Source:** [source_latest/scripts/ui.gd:1033](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:1033) · specialist key `UI-CONTROLS-20`

<a id="rim-028"></a>
### RIM-028 · HTTP/2's required technology is clipped even at default text size

**P2 · bug · verified_runtime · effort S** — Tech panel

**Evidence:** At100% the Locked—needs Exploit Development button text measures345px inside a260px-wide button; clip_text is true and tooltip_text is empty. Probe panel_probe_results.json research[http2] captures width/text. Final source recheck: Prerequisite is still a long clipped button string, with no wrapping reason label or tooltip added. Baseline font measurement remains qualified.

**Reproduce/context:** Start a new game, open Tech, scroll to HTTP/2 Flooding and read its disabled button.

**Player impact:** The prerequisite name is truncated and has no alternate complete tooltip or separate label.

**Change:** Put the prerequisite in a wrapping card label and keep the disabled button short; expose the full reason through accessible help.

**Done when:** Exploit Development is fully readable at100/125/150/200% without horizontal clipping or reliance on guesswork.

**Source:** [source_latest/scripts/ui.gd:935](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:935) · specialist key `UI-PANELS-11`

<a id="rim-029"></a>
### RIM-029 · Contract board rebuild destroys keyboard focus after accepting a job

**P2 · bug · verified_runtime · effort M** — Jobs interaction

**Evidence:** _rebuild_jobs queue_frees every existing child whenever _contracts_ver changes. In the probe an Accept button had focus; main.accept_contract triggered a rebuild, old card became invalid and gui_get_focus_owner became null. Final source recheck: Whole-card queue_free/rebuild logic remains. New unaccepted cards wrap Accept/Decline in a row, so the baseline helper's fixed get_child(3) Button assumption cannot be replayed unchanged; focus-loss cause is source-confirmed current.

**Reproduce/context:** Keyboard-focus an Accept button, activate it and continue navigating the board. Also observe focus when a different contract completes.

**Player impact:** Keyboard navigation loses its position because all cards are replaced for a single state change.

**Change:** Update cards by contract ID or restore focus to the corresponding surviving card/action after rebuild.

**Done when:** Accept, completion, claim and arrival preserve a meaningful focus target; an unrelated card changing state never clears the currently focused card.

**Source:** [source_latest/scripts/ui.gd:729](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:729) · specialist key `UI-PANELS-15`

<a id="rim-030"></a>
### RIM-030 · Linked-structure contract text omits which nodes qualify

**P2 · bug · source_confirmed · effort S** — Jobs objective description

**Evidence:** Jobs displays c.desc verbatim as Add N linked structures (main.gd:1947), but _contract_raw main.gd:1965 excludes the hub and every node with relay=true. A linked Proxy or a producer converted to Proxy therefore does not count, despite being a linked structure. Final source recheck: Displayed 'Add N linked structures' is unchanged and main.gd:2051 still excludes relay=true. Precise reproduction should link a newly converted unlinked Proxy during an accepted job.

**Reproduce/context:** Accept an Add N linked structures job, convert an unlinked producer to Proxy, then link it. Compare the visible connection with unchanged job progress; converting an already-counted producer alone is not the add-structure reproduction.

**Player impact:** The literal objective promises progress for a central network structure that the evaluator excludes.

**Change:** Name the qualifying set explicitly, for example Add N linked producers/processors (Proxies excluded), or align the evaluator with the intended broad objective.

**Done when:** The objective describes exactly the node categories counted; converting an eligible node explains any progress reduction.

**Source:** [source_latest/scripts/ui.gd:751](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:751) · specialist key `UI-PANELS-16`

<a id="rim-031"></a>
### RIM-031 · The net-rate line physically overlaps the resource legend

**P2 · bug · verified_runtime · effort S** — HUD layout

**Evidence:** Controlled rates fixture at100%: net-rate rectx312,y42,w409 and legend rectx600,y42,w519 intersect. Text is 'Cycles -99.9/s Intel +1000.0/s Cash +150.0/s ETA0:06'. Evidence: probes/hud_v065_results.json rates_legend. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Run a productive mixed network, or use the controlled three-rate fixture; both net rates and legend use fixed positions on the same row.

**Player impact:** Income and resource identity text become unreadable precisely when the economy is busy.

**Change:** Lay out rates and legend in a shared responsive container, separate rows or collapsible sections rather than independent fixed positions.

**Done when:** All displayed rates, ETA and legend remain non-overlapping for large positive/negative rates at every text scale.

**Source:** [source_latest/scripts/ui.gd:297](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:297) · specialist key `HUD02`

<a id="rim-032"></a>
### RIM-032 · The Stats resource inventory omits Research

**P2 · bug · verified_runtime · effort S** — Stats inventory

**Evidence:** Controlled fixture with77 Research: stats_label lists Cycles,Intel,Crypto,Tools,Cash but no Research. Header contains77 Research. Evidence: probes/hud_v065_results.json stats_research and screenshot10_stats.png. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Earn Research through contracts/Lab, then open Stats.

**Player impact:** The supposedly comprehensive inventory excludes the resource needed for technology decisions.

**Change:** Add Research using the same inventory presentation and precision policy as other resources.

**Done when:** Stats shows all six resource balances and matches the HUD after research spending, rewards and loading.

**Source:** [source_latest/scripts/ui.gd:945](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:945) · specialist key `HUD04`

<a id="rim-033"></a>
### RIM-033 · An overload alert selects the structure instead of its diagnostic tunnel

**P2 · bug · verified_runtime · effort S** — Alert selection

**Evidence:** Controlled overloaded-edge fixture: _jump_alert('overload') sets selected_id=2, selected_tunnel=-1. The tunnel inspector contains offered/cap/loss diagnostics; the selected producer inspector does not show that edge detail. Evidence: probes/hud_v065_results.json overload_jump. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Click an OVERLOADED tunnel alert.

**Player impact:** The alert moves to the location but opens the less useful inspector, requiring another precise map click to understand the issue.

**Change:** Select the overloaded tunnel or open an explicit throughput diagnostic section for that edge. Provide contextual upgrade/reroute actions and show the expected capacity/cost change from the selected diagnostic tunnel.

**Done when:** One alert click opens the affected link's capacity/offered/loss information and keeps coherent selection state.

**Source:** [source_latest/scripts/ui.gd:821](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:821) · specialist key `HUD11`

<a id="rim-034"></a>
### RIM-034 · Quarantined intact branches are labeled OFFLINE / unlinked in aggregate alerts

**P2 · bug · verified_runtime · effort S** — Alert cause labeling

**Evidence:** Controlled intact linked node with quarantine=5 is excluded from _connected; the alert text is '1 structure(s) OFFLINE / unlinked'. The inspector has a distinct quarantine state but the aggregate alert collapses causes. Evidence: probes/hud_v065_results.json quarantine_alert. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Allow ICE to quarantine a connected host without cutting its link.

**Player impact:** The prominent alert suggests a wiring problem even though the physical branch remains intact and recovery is time-based.

**Change:** Separate quarantined and unlinked counts, or describe the mixed alert as inactive and reveal cause per target.

**Done when:** An ICE-quarantined branch is visibly distinguished from a missing link in both the aggregate alert and inspector.

**Source:** [source_latest/scripts/ui.gd:887](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:887) · specialist key `HUD12`

<a id="rim-035"></a>
### RIM-035 · String-based message detection loses repeated and same-frame action results

**P2 · bug · verified_runtime · effort S** — Action feedback

**Evidence:** Reverified v0.6.5: emit the same failed placement, wait 3.7 s, emit again; _msg_t stays 0 and status remains Hover hint. In a second controlled case, assign two results before one UI update; history contains only the second. The new queue stores observed strings but cannot recover undetected events. Evidence: probes/hud_v065_results.json repeated_same_message/same_frame_history. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Repeat an identical invalid action after feedback expires, or produce two independent results within one render frame.

**Player impact:** Repeated input appears ignored, and earlier same-frame rewards/failures vanish before entering the new history.

**Change:** Emit action results as explicit events with unique IDs rather than watching a shared string; enqueue each event at its source.

**Done when:** Every action result is captured, including identical consecutive failures and two events in one frame; history and visible feedback preserve both.

**Source:** [source_latest/scripts/ui.gd:982](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:982) · specialist key `HUD15`

<a id="rim-036"></a>
### RIM-036 · The severity queue can delay urgent blackout warnings behind routine messages

**P2 · bug · verified_runtime · effort M** — Message priority

**Evidence:** v0.6.5 classifies severity and varies color/duration, but uses FIFO pop_front. A controlled 10-routine-message fixture queues BLACKOUT last, giving a 22 s wait before its 3.6 s display. After 100 more messages, the pending queue grows to 110 while history is bounded at 12. Evidence: probes/hud_v065_results.json warning_fifo/queue_bound. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Make several rapidly changing routine selections/results, then receive an ICE blackout or another critical error.

**Player impact:** Urgent information can arrive after the four-second blackout has already finished, while old routine feedback continues.

**Change:** Preempt or prioritize urgent operational events; coalesce routine repeats and bound the pending queue by count/age. Preserve readable acknowledgements without replaying obsolete actions.

**Done when:** A newly received critical warning displays immediately; routine backlog remains bounded and does not delay time-critical information.

**Source:** [source_latest/scripts/ui.gd:992](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:992) · specialist key `HUD16`

<a id="rim-037"></a>
### RIM-037 · Planning pause has no persistent visible indicator after its status message expires

**P2 · bug · verified_runtime · effort S** — Simulation state

**Evidence:** Controlled planning pause fixture: paused=true, pause_overlay.visible=false; after3.1s status='Hover hint' and header has noPaused marker. Evidence: probes/hud_v065_results.json planning_pause. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Use planning pause, then hover a host or wait for the status timer.

**Player impact:** Players can mistake a deliberately paused simulation for stalled production or broken input.

**Change:** Show a persistent PAUSED/planning badge with a clear Resume action while keeping the map interactive.

**Done when:** Planning pause remains visibly indicated until resumed, independent of tool hints or action messages; opening/closing menus preserves the badge correctly.

**Source:** [source_latest/scripts/ui.gd:969](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:969) · specialist key `HUD18`

<a id="rim-038"></a>
### RIM-038 · Loading a run preserves queued messages from the discarded timeline

**P2 · bug · verified_runtime · effort S** — Load feedback lifecycle

**Evidence:** A controlled v0.6.5 UI fixture queues old reward/expired messages, applies a valid saved state via the same _apply_save path used by Load, then reports Game loaded. The old reward still displays, with old expiry and Game loaded pending behind it. _apply_save clears Main transients but not UI message state. Evidence: probes/hud_v065_results.json load_message_timeline. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Queue rapid action results, then successfully Load another saved run before the message queue drains. The fixture drives _apply_save directly to isolate message lifecycle.

**Player impact:** A restored run shows obsolete rewards/failures from a timeline that no longer exists, and Load success itself may be delayed.

**Change:** Reset pending/current UI messages and align history with the successful load boundary; immediately surface the load/recovery result. Preserve messages when Load is refused.

**Done when:** After a successful Load, no discarded-timeline event is shown as current; success/recovery displays immediately, while failed Load leaves live-state feedback intact.

**Source:** [source_latest/scripts/ui.gd:986](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:986) · specialist key `HUD20`

<a id="rim-039"></a>
### RIM-039 · Armed tunnel and Proxy tools still miss visible tower roofs

**P2 · bug · verified_runtime · effort S** — Map interaction / hit targets

**Evidence:** The isolated headless probe finds C2 at roof point (74,20) through _node_at_silhouette, while _node_at(cell(3,0)) returns -1 and an armed tunnel reports 'Click a node.' Default selection has the B48 silhouette fix; tunnel and Proxy tools still use footprint-only hit tests. main/minimap hashes match the later source_v065 snapshot. Final source recheck: _try_tunnel and _try_convert_relay still call _node_at(cell); the new rerouting path also uses the same footprint target policy. Prior headless roof-hit proof remains applicable.

**Reproduce/context:** Use map_project/map_probe.gd, or arm a source tunnel and click the elevated part of C2 outside its ground footprint. Proxy conversion has the same footprint-only target path.

**Player impact:** A target that visibly responds to inspection becomes unclickable during the operation requiring it, especially on tall structures.

**Change:** Resolve a single visible-node target for inspect, tunnel endpoints and Proxy conversion, keeping ground-footprint placement rules separate.

**Done when:** Roof and footprint clicks choose the same visible frontmost node in all three modes; clicking empty ground still performs no node operation.

**Source:** [source_latest/scripts/main.gd:1461](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1461) · specialist key `MAP01`

<a id="rim-040"></a>
### RIM-040 · Undo can leave a stationary route preview showing an obsolete route

**P2 · bug · verified_runtime · effort S** — Route preview / cache invalidation

**Evidence:** map_probe_results.json records a cached valid 12-cell route to a second Mirai at (13,4). After Undo removes that target, pending source and pointer key stay unchanged; cached preview still says valid/12 while a fresh calculation returns blocked/INF. Cache keys contain only cell, pending source and tool. Final source recheck: Cache key still uses only cell, pending source and tool. Undo target removal/restore still does not invalidate this cache; new reroute Undo also clears only _pl_cache.

**Reproduce/context:** Run map_project/map_probe.gd, or preview a route while planning-paused and undo another node/tunnel affecting that route without moving the pointer.

**Player impact:** The planning display can retain a nonexistent path or incorrect route cost until the player moves the mouse.

**Change:** Include a topology revision in the preview cache key or invalidate it on every placement, removal, restore and reroute.

**Done when:** With a stationary pointer, Undo/redo-equivalent restores, dismantling and route changes refresh validity, geometry and cost before the next click.

**Source:** [source_latest/scripts/main.gd:763](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:763) · specialist key `MAP02`

<a id="rim-041"></a>
### RIM-041 · Empty-cell route endpoints can display OK but cannot be committed

**P2 · bug · source_confirmed · effort S** — Route preview / endpoint validity

**Evidence:** _preview_route falls back to _find_path_to_cell for an empty hovered cell and returns blocked=false when geometry is routable. _update_hint displays [OK], but _try_tunnel rejects every endpoint without a node. Final source recheck: Empty-cell fallback can still return blocked=false and OK while commit requires an existing node.

**Reproduce/context:** Arm a source, hover a reachable empty street and observe its white route/OK hint; clicking that same cell reports 'Click a node.' This is source-grounded, not a recorded physical click.

**Player impact:** The preview signals a complete valid operation at points where the actual action is unavailable.

**Change:** Distinguish 'route can reach here' from 'valid endpoint'; highlight commit-ready node targets and show 'choose a node' on empty endpoints.

**Done when:** Only an eligible distinct node target is marked ready to commit; exploratory geometry may remain visible with a clearly incomplete state.

**Source:** [source_latest/scripts/main.gd:742](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:742) · specialist key `MAP03`

<a id="rim-042"></a>
### RIM-042 · Proxy tunnel previews overstate upkeep by 2.5 times

**P2 · bug · verified_runtime · effort S** — Route preview / economic accuracy

**Evidence:** The isolated probe uses an actual one-cell route from a converted Proxy: _update_hint predicts 0.05 Cycles/s for DNS, while committing and ticking computes 0.02 Cycles/s. Preview multiplies length by protocol upkeep without the Proxy's 0.4 factor. Final source recheck: Tunnel preview still uses length*UPKEEP; actual Proxy source upkeep still applies 0.4. Post-build reserve forecast is in the structure branch only.

**Reproduce/context:** Run map_project/map_probe.gd, or preview and build a route from a converted Proxy and compare the preview estimate with the network upkeep change.

**Player impact:** Players overestimate the cost of the infrastructure intended to make expansion economical.

**Change:** Use one shared effective-upkeep calculation in the preview and simulation.

**Done when:** Every protocol preview matches actual incremental upkeep for both ordinary sources and converted Proxies to displayed precision.

**Source:** [source_latest/scripts/main.gd:1031](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1031) · specialist key `MAP04`

<a id="rim-043"></a>
### RIM-043 · The top HUD can trigger unintended upward edge-panning

**P2 · bug · source_confirmed · effort S** — Camera / UI interaction boundary

**Evidence:** Edge-pan checks mp.x>=300 and mp.y<=22 regardless of whether the pointer is over the resource HUD. That HUD covers the map's top 64 pixels, so pointing at the top resource row can move the camera. Final source recheck: Edge-pan still triggers y<=22 when x>=300, including the top HUD.

**Reproduce/context:** Move the pointer into the resource bar's first 22 pixels to the right of the left panel and wait while no modal is open.

**Player impact:** Reading resources can move the map and disrupt the placement or inspection context.

**Change:** Define edge-pan zones on the unobscured map rectangle and suppress them while interacting with HUD controls; allow edge-pan to be disabled.

**Done when:** Hovering any HUD element leaves the camera still; pointer movement to a real map-edge pan zone scrolls as documented.

**Source:** [source_latest/scripts/main.gd:1551](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1551) · specialist key `MAP07`

<a id="rim-044"></a>
### RIM-044 · Minimap view rectangle includes world hidden behind the UI

**P2 · bug · source_confirmed · effort S** — Minimap / camera footprint

**Evidence:** The view rectangle uses the full viewport width/height, although the left 300 pixels and top HUD hide world content. The actual opening layout is 1280x720 with a 300-pixel panel and 64-pixel top bar. Final source recheck: Minimap outline still uses the full viewport, including the covered left panel and top HUD.

**Reproduce/context:** At a middle-map camera position, compare the outlined minimap area with the world that is actually visible outside the left panel and HUD.

**Player impact:** The overview claims areas are in view when they are covered by controls, making click-to-pan and boundary inspection less precise.

**Change:** Calculate the world bounds of the unobscured map rectangle and use them for the minimap view indicator and centring policy.

**Done when:** Each corner of the minimap view outline corresponds to a visible map corner, including after resize and zoom.

**Source:** [source_latest/scripts/minimap.gd:64](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/minimap.gd:64) · specialist key `MAP09`

<a id="rim-045"></a>
### RIM-045 · ICE tracers cut across buildings instead of following their real tunnels

**P2 · bug · source_confirmed · effort S** — Threat visuals / route correctness

**Evidence:** Normal links use _edge_pts routed polylines, but the ICE warning draws straight node-centre lines and interpolates its moving marker between centres. The sweep's counterplay checks the actual parent links. Final source recheck: Threat warning lines and tracer still interpolate directly between node centres rather than _edge_pts.

**Reproduce/context:** Trigger a sweep on a branch whose tunnel takes a street detour; the threat overlay uses the direct chord instead of the routed street path.

**Player impact:** The visual threat appears on a different part of the map from the session the player needs to cut or reroute.

**Change:** Draw the warning and position the tracer using the swept edge's existing route polyline, while preserving pause-safe hop timing.

**Done when:** At every hop the threat marker and warning line lie on the same visible tunnel as packet traffic, including detours and parallel lanes.

**Source:** [source_latest/scripts/main.gd:2139](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2139) · specialist key `MAP12`

<a id="rim-046"></a>
### RIM-046 · Short-link labels are covered by the structures they describe

**P2 · bug · verified_runtime · effort S** — On-map labels / figure-ground

**Evidence:** Screenshots 05_first_link.png and 06_selected_producer.png show the one-cell DNS label running beneath the overlapping C2/Mirai silhouettes. Labels are drawn at the polyline midpoint before structures are painted, with no collision placement or backing. Final source recheck: Link labels still paint before structures at the route midpoint with no collision handling/backing. Prior short-link screenshot evidence remains mechanically relevant.

**Reproduce/context:** Follow the recorded legal opening: Mirai at [2,5] linked to C2 [2,2]; inspect the route label in screenshots 05 and 06.

**Player impact:** The first working link's latency/health annotation is difficult to read even at the default scale, undermining the feedback meant to teach routing.

**Change:** Move short-link annotations to a non-overlapping badge or selected-link callout with a dark backing; avoid labelling every crowded edge simultaneously.

**Done when:** The recorded opening's full link label remains legible over both roofs, and a dense network does not create overlapping unreadable labels.

**Source:** [source_latest/scripts/main.gd:2139](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2139) · specialist key `MAP13`

<a id="rim-047"></a>
### RIM-047 · Fog blocks and legal placement disagree at vision boundaries

**P2 · bug · source_confirmed · effort M** — Map fog / placement feedback

**Evidence:** Fog marks a whole 4x4 block visible from one centre-cell test, while placement checks every footprint cell with exact radius distance. Around a radius-16 C2 at (2.5,2.5), a fog-visible block can include cells beyond that radius, and a dark block can include legal cells. Final source recheck: Fog still marks whole 4x4 blocks from one centre-cell test while placement checks every footprint cell against exact radius.

**Reproduce/context:** Source-derived boundary example: block x16..19/y0..3 tests centre (18.5,2.5) as visible, although its x19 cell centres are outside the radius. Move a producer preview across such a boundary.

**Player impact:** Illuminated terrain can reject placement for being outside vision, and actionable boundary cells can appear unavailable.

**Change:** Use a consistent cell-level accessibility mask for fog/placement or explicitly display the exact build-reach boundary over coarse atmospheric fog.

**Done when:** A player can determine whether the entire preview footprint is within access from the map cue; no fully legal footprint is visually marked unavailable.

**Source:** [source_latest/scripts/main.gd:807](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:807) · specialist key `MAP14`

<a id="rim-048"></a>
### RIM-048 · Same-seed restores can leave minimap host markers at old positions

**P2 · bug · verified_runtime · effort S** — Minimap / save restore

**Evidence:** Controlled rendered cache-invalidation probe restored a same-seed state with equal node count/camera but synthetically moved C2 to(18,18); minimap emitted zero draw notifications. C2 does not ordinarily move. Its key covers seed/count/relay count/camera, not node identity or positions. The legal analogous scenario is same-count saves with different producer positions; that exact legal roundtrip was not recorded. Evidence: render_results.json same_seed_node_move_load.

**Reproduce/context:** Restore two same-seed states with equal node and relay counts but different positions, keeping camera and zoom unchanged.

**Player impact:** Players navigate toward markers belonging to the discarded run.

**Change:** Invalidate on restore and include a node-position/topology revision in minimap state tracking.

**Done when:** Same-count replacement, Undo and save restore repaint markers immediately without needing a camera move.

**Source:** [source_latest/scripts/minimap.gd:32](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/minimap.gd:32) · specialist key `PERF02`

<a id="rim-049"></a>
### RIM-049 · Advertised capacity behaves as a soft loss parameter rather than a throughput ceiling

**P2 · improvement · proposal · effort M** — Capacity model

**Evidence:** Measured controlled fixture: DNS cap3, offered4, distance loss0.03 produces modeled delivered3.2133/s. At extreme overload the0.9 loss ceiling lets arbitrarily large offered load exceed capacity. This is an observed model choice, not a proven design-intent bug. Evidence: simulation_results capacity_soft_ceiling. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Compare _edge.cap and _edge.delivered on an overloaded DNS trunk. Prior acceptance checks did not require a hard cap.

**Player impact:** Players cannot infer what a3-packet/s link can actually carry; node throughput ceilings cease to be ceilings.

**Change:** Either enforce an actual delivery/admission ceiling with queue/drop behavior, or explicitly call the displayed value a soft bandwidth/loss rating and teach that model.

**Done when:** For a hard-cap design, sustained delivery never exceeds declared capacity; for a soft model, inspector and help text clearly state the nonlinear rule.

**Source:** [source_latest/scripts/main.gd:1826](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1826) · specialist key `SIM11`

<a id="rim-050"></a>
### RIM-050 · Prevent or explain Overclock spending on currently unavailable producers

**P2 · improvement · verified_runtime · effort S** — Command availability

**Evidence:** Controlled fixtures: disabled Mirai and disconnected Mirai both spend20 Cycles and receive boost_t20; disabled production is{}, disconnected chain is[]. Evidence: simulation_results disabled_overclock/offline_overclock. Spending on an unavailable target is verified, but requiring a live target or queuing a boost is a design choice, not an established forbidden operation. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Select a disabled or offline producer and press Overclock; the timer runs while it cannot deliver additional production.

**Player impact:** A contextual action consumes scarce starting resources despite no current benefit, with no confirmation of a queued strategy.

**Change:** Gate the command on operational positive-output state or explicitly offer a queued boost that begins when the host is online. Show the reason when unavailable.

**Done when:** Disabled/offline/0%-output targets cannot silently spend20 Cycles on an expiring unusable boost; operational targets retain the existing behavior.

**Source:** [source_latest/scripts/main.gd:2778](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2778) · specialist key `SIM17`

<a id="rim-051"></a>
### RIM-051 · Exit and Load actions replace unsaved progress without a save decision

**P2 · improvement · proposal · effort M** — In-game Menu and Pause

**Evidence:** Menu buttons call go_main_menu, quit_game and load_game directly; go_main_menu/quit_game switch/exit immediately and no autosave or dirty-run decision is implemented. This proposal concerns the user flow, separate from save format/validation defects. Final source recheck: Menu/Pause exits and Load still call session replacement directly, with no unsaved decision. Startup preference persistence is separate from run saving.

**Reproduce/context:** Change the network after the last manual save, then choose Main Menu, Quit or Load Game from the Menu/Pause UI.

**Player impact:** A single menu action can discard the player's latest network changes without revealing that outcome.

**Change:** Track unsaved progress and offer Save/Discard/Cancel before destructive session replacement; keep the flow concise when the run is already saved.

**Done when:** A dirty run can be saved or retained before exit/load; Cancel restores the same run and focus, while an already-saved run exits without redundant prompts.

**Source:** [source_latest/scripts/ui.gd:228](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:228) · specialist key `UI-CONTROLS-09`

<a id="rim-052"></a>
### RIM-052 · Inspector actions sit after long flavour text and technical details

**P2 · improvement · proposal · effort M** — Selection inspector layout

**Evidence:** info_body precedes every action and begins with d.homage; critical Status is appended near its end. In the200% probe the body ends y1335, first action starts1341 and rate controls start1542 inside a scroll viewport ending667. Actions remain scrollable, but require traversing the entire prose block. This is separate from the global status-line height finding. Final source recheck: Long inspector body still precedes all controls and status remains near the bottom. New Reroute adds another below-body action; do not reuse old action pixel coordinates as freshly measured v066 geometry.

**Reproduce/context:** Select a producer at200% text and attempt to quickly disable it or reduce output during a network problem.

**Player impact:** Time-sensitive controls and operational status are far below descriptive prose.

**Change:** Put state and main operational controls near the top or in a bounded persistent action area; move flavour/extended metrics into a secondary section.

**Done when:** Disable/output actions and current status are quickly reachable from the initial inspector position at all scales; full descriptive details remain available.

**Source:** [source_latest/scripts/ui.gd:338](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:338) · specialist key `UI-CONTROLS-13`

<a id="rim-053"></a>
### RIM-053 · Overclock lacks cost, duration and remaining-boost context

**P2 · improvement · proposal · effort S** — Inspector Overclock

**Evidence:** The action label is only ⚡ Overclock(O), with empty tooltip. main.gd defines20 Cycles/20 seconds and sets boost_t, but inspector shows no remaining duration or active boost label; probe boost_time20 is visible only as a doubled Produces value. Functional disabled/offline overclock guards are owned by the simulation audit. Final source recheck: Overclock still has only its short label and no cost/duration/remaining boost preview. Canonical operational-state text does not add that context.

**Reproduce/context:** Select a producer, inspect Overclock before using it, then return to that producer during its20-second boost.

**Player impact:** Players spend a resource without a preview and cannot tell when the temporary effect will end or whether another press is useful.

**Change:** Display the cost and effect duration before activation, then show boost state/countdown and current affordability.

**Done when:** The control explains20 Cycles→2× output for20s and shows remaining boost time; a resource shortage has an explicit reason.

**Source:** [source_latest/scripts/ui.gd:361](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:361) · specialist key `UI-CONTROLS-14`

<a id="rim-054"></a>
### RIM-054 · The inspector lacks actual throughput and delivery rates

**P2 · improvement · proposal · effort M** — Inspector operational telemetry

**Evidence:** Baseline inspector reports nominal generation/processor recipe values rather than measured delivery. The final snapshot adds operational-state labels and effective tunnel admission capacity; those improvements are credited. Actual per-host throughput, deliveries and losses still require inference from packet motion and stock changes. Baseline UI evidence is controlled; current persistence is source-rechecked.

**Reproduce/context:** Inspect a disabled producer or a connected processor with no Intel/fuel, then compare the displayed rate with actual traffic.

**Player impact:** Players cannot judge what a disabled node could recover or why an apparently rated processor is idle.

**Change:** Separate rated capacity, current production/processing, delivered throughput and a concise idle/limited reason; retain capacity information while disabled.

**Done when:** An idle processor identifies the limiting input/fuel/route; a disabled producer retains rated capacity while current output is0; delivery loss is not presented as raw production.

**Source:** [source_latest/scripts/ui.gd:1070](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:1070) · specialist key `UI-CONTROLS-16`

<a id="rim-055"></a>
### RIM-055 · Tunnel latency uses packet units for a route-length count

**P2 · improvement · proposal · effort M** — Tunnel inspector metrics

**Evidence:** The inspector labels _edge_len as Latency:N pkt, but main.gd:735–737 returns path.size(), a cell count. Packet motion depends on PACKET_SPEED/slow_factor, so this count does not directly communicate elapsed delivery time. Final source recheck: Latency still labels _edge_len/path-size as pkt. Effective admission-capacity improvement is a separate metric and must be credited.

**Reproduce/context:** Inspect a short and long tunnel and try to infer when a packet will reach the parent from the displayed latency.

**Player impact:** The central timing metric has an unclear unit and cannot be readily related to travel time.

**Change:** Label route length in cells/tiles and provide an estimated travel time in seconds using the actual path/speed, with variable slowdown qualified.

**Done when:** Every displayed metric has a coherent unit; players can compare route length and approximate link travel time without interpreting 'packet latency'.

**Source:** [source_latest/scripts/ui.gd:1032](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:1032) · specialist key `UI-CONTROLS-17`

<a id="rim-056"></a>
### RIM-056 · Dismantle does not preview the affected branch or refund outcome

**P2 · improvement · proposal · effort M** — Inspector Dismantle

**Evidence:** The button is labelled Dismantle(Del) with no impact tooltip. main._remove_node removes the selected node and detaches incoming children; dismantling does not call _refund, while Ctrl+Z restores the removed topology. Final source recheck: Dismantle still lacks branch/refund/undo impact preview. Reroute now exists as an alternative operational action; do not imply removal is the sole available change.

**Reproduce/context:** Select a relay/processor with incoming branches and inspect Dismantle before activating it.

**Player impact:** Players cannot see how many structures lose their C2 route or whether build resources return before the action.

**Change:** Show affected direct/descendant nodes, resource outcome and undo availability near Dismantle; distinguish removing a node from removing its outbound tunnel.

**Done when:** Before removal the inspector explains the resulting disconnected branch and refund policy; the subsequent undo restores the described topology.

**Source:** [source_latest/scripts/ui.gd:343](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:343) · specialist key `UI-CONTROLS-19`

<a id="rim-057"></a>
### RIM-057 · Offer an immediate visible preview of palette tool details

**P2 · improvement · source_confirmed · effort S** — Build palette

**Evidence:** _on_hover updates hover_tool and _update_info builds the detailed body, but _process shows sel_scroll only for selection or current_tool, not hover_tool. Probe hovering nest records its homage/cost in info_body while inspector_visible=false. Standard delayed tooltip is still present; the separate immediate detail preview is the broken part. The existing delayed tooltip already exposes full help; this proposal improves presentation rather than claiming hover help is absent. Final source recheck: show_info still excludes hover_tool, but complete delayed tooltip remains. Retain as immediate-hover-preview improvement/dead-preview cleanup, not absence of hover help.

**Reproduce/context:** With no armed tool or selection, open Build and hover Mirai Dropper; inspect info_body and sel_scroll visibility.

**Player impact:** A player must wait for the tooltip; the existing immediate inspector-preview assignment is invisible while the build palette is open.

**Change:** Provide a visible compact hover preview that does not hide the hovered palette, or remove dead hover-inspector state and improve the tooltip intentionally.

**Done when:** Hover/focus any tool exposes its help without first arming it, and the palette remains available under the pointer.

**Source:** [source_latest/scripts/ui.gd:893](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:893) · specialist key `UI-PANELS-02`

<a id="rim-058"></a>
### RIM-058 · Locked tools do not name the research needed to unlock them

**P2 · improvement · proposal · effort S** — Build palette

**Evidence:** Tool tooltip is name+homage+cost; disabled state is based solely on _is_unlocked. No required technology is displayed or linked. For example Poisoned Package is disabled although the corresponding technology is named Supply-Chain Attacks. Final source recheck: Locked tool tooltip still lacks required technology; unlock-state processing unchanged.

**Reproduce/context:** Start a new game, hover locked Poisoned Package, then compare the Tech list.

**Player impact:** Players must infer a differently named technology before they can act.

**Change:** Add a readable Locked—requires <technology> line and a route to that research card; retain readable names and costs while locked.

**Done when:** Each locked tool identifies the exact technology and prerequisite chain; a player can navigate to the relevant card in one action.

**Source:** [source_latest/scripts/ui.gd:572](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:572) · specialist key `UI-PANELS-03`

<a id="rim-059"></a>
### RIM-059 · Build costs give no live affordability or resource shortfall

**P2 · improvement · proposal · effort S** — Build palette

**Evidence:** Palette cost labels are set once to _cost_str; _process refreshes unlock state only. An unlocked tool with insufficient Cash/Intel has the same palette presentation as an affordable one. Final source recheck: Palette costs remain static and show no per-resource affordability deficits. Armed-tool hint now forecasts Cycles after build and warns about recovery reserve; credit this and narrow the proposal to preselection palette/remaining resource shortages.

**Reproduce/context:** Research Cloud Cryptojacking, leave Cash below60, and compare its palette row before and after accumulating the required Cash.

**Player impact:** Placement failures are discovered after arming and selecting a map location.

**Change:** Show affordable/shortfall state beside each cost, while allowing intentional preview even when a resource is missing.

**Done when:** A missing resource is named with its deficit and updates as stock changes; research lock and resource shortage are visually/textually distinct.

**Source:** [source_latest/scripts/ui.gd:595](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:595) · specialist key `UI-PANELS-04`

<a id="rim-060"></a>
### RIM-060 · Palette does not expose production and processor operating recipes

**P2 · improvement · proposal · effort M** — Build palette

**Evidence:** Tool rows contain name and initial build cost only; tooltip contains homage. Actual producer rates and CONV input/output/fuel data in main.gd:21–37 appear only after selection of an installed structure. Final source recheck: Palette still shows name/cost and qualitative homage rather than production/processing recipes. New selected-state/effective-capacity text does not add pre-build recipe comparison.

**Reproduce/context:** Compare Mirai vsCloud Cryptojacker, or Intel Lab vsExploit Forge before constructing them.

**Player impact:** Players cannot evaluate expected yield or recurring fuel needs when making the build decision.

**Change:** Add a compact functional summary: output resource/rate for producers and input→output/rate plus fuel for processors, with coverage modifiers explicitly qualified.

**Done when:** Before arming a tool its base output or conversion recipe and recurring fuel are available in readable text, independently of icon colour.

**Source:** [source_latest/scripts/ui.gd:589](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:589) · specialist key `UI-PANELS-05`

<a id="rim-061"></a>
### RIM-061 · Tunnel options lack a comparable set of operating metrics

**P2 · improvement · proposal · effort M** — Links palette

**Evidence:** Links rows show build cost; tooltip uses qualitative homage such as small/cheap/silent or fast/loud. Numeric capacity, upkeep/tile, trace/s and distance loss are in main.gd:58–64 and are not provided together for comparison. Final source recheck: Links palette still lacks consistent numeric comparisons. Selected tunnel now shows protocol/effective capacity, but that does not populate palette capacity/upkeep/trace/loss comparison.

**Reproduce/context:** Open Build→Links and compare DNS Tunnel, VPN Tunnel and Reverse Shell before arming.

**Player impact:** Players choose tunnels by flavour and discover the actual cost/capacity consequences after deployment.

**Change:** Provide an aligned comparison or consistent tooltip fields for capacity, upkeep, trace and distance loss.

**Done when:** Each tunnel exposes the same units/fields; players can compare a cheap route, cooling route and high-capacity route without placing them.

**Source:** [source_latest/scripts/ui.gd:572](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:572) · specialist key `UI-PANELS-06`

<a id="rim-062"></a>
### RIM-062 · Custom palette buttons need explicit accessible names

**P2 · improvement · proposal · effort S** — Build accessibility

**Evidence:** _tool_entry creates a Button with empty text and places tool names in child Labels; no explicit accessibility name/description is set in this construction. The probe confirms every tool button_text is empty. This is a proposed accessibility hardening, not a claimed screen-reader runtime failure. Final source recheck: Custom tool Buttons still have empty own text and no explicit accessibility name; retain proposal status until platform announcement is tested.

**Reproduce/context:** Inspect a palette button's own label/accessibility metadata and test keyboard/screen-reader navigation on the supported platform.

**Player impact:** Accessible announcement of the custom row is dependent on engine child-text inference rather than an explicit contract.

**Change:** Assign the button an explicit accessible name and description containing its tool name, role, cost and lock reason, using the supported Godot accessibility API.

**Done when:** The platform screen reader announces a unique name, cost and availability for each tool; child labels do not cause duplicate announcements.

**Source:** [source_latest/scripts/ui.gd:570](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:570) · specialist key `UI-PANELS-09`

<a id="rim-063"></a>
### RIM-063 · Research cards do not identify the exact unlocked tool

**P2 · improvement · proposal · effort S** — Tech panel

**Evidence:** _tech_row shows t.name and t.desc but never renders t.unlocks. Several labels differ from the palette names, for example Onion Routing→Onion Route and Exploit Development→Exploit Forge. Final source recheck: Research rows still show name/desc/action without explicit unlocked palette names.

**Reproduce/context:** Read a Tech card and locate the tool it will enable in Build.

**Player impact:** Players cannot reliably connect research investment to a concrete action or build category.

**Change:** Render Unlocks: <tool name> with the matching glyph/category and optionally a jump action.

**Done when:** Every technology lists the exact current palette names it unlocks before purchase and after it is researched.

**Source:** [source_latest/scripts/ui.gd:606](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:606) · specialist key `UI-PANELS-10`

<a id="rim-064"></a>
### RIM-064 · Disabled research purchases lack a local balance and shortfall

**P2 · improvement · proposal · effort S** — Tech affordability

**Evidence:** When prerequisites are satisfied b.disabled depends on resources.research<t.cost, while text remains Research (<cost>RP). No local current balance, remaining amount or tooltip is set. Final source recheck: Eligible unaffordable research still shows cost only and disables the button without local current balance/deficit.

**Reproduce/context:** Open Tech with0RP, then with9RP, and compare an eligible10RP card.

**Player impact:** The player gets a disabled control without a clear local explanation of how close the unlock is.

**Change:** Add Research <current>/<required> and Need <deficit> messaging, plus a direct explanation of earning Research when the balance is zero. Show the Research price even when a prerequisite locks the card, alongside the named prerequisite and current balance.

**Done when:** At9/10RP a10RP card states1RP missing; at10RP it becomes actionable immediately, and prerequisite lock remains a distinct status. Prerequisite-locked cards expose their price, and insufficient-balance cards expose the precise deficit.

**Source:** [source_latest/scripts/ui.gd:938](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:938) · specialist key `UI-PANELS-13`

<a id="rim-065"></a>
### RIM-065 · Completed contracts have no notification outside the Jobs tab

**P2 · improvement · proposal · effort M** — Jobs feedback

**Evidence:** The Jobs tab label is static; completion feedback exists only in card status/Claim button. main.gd:1988–1990 marks done and changes version without setting message. Probe completion retained message='baseline' even though done=true. Final source recheck: Completed feedback remains inside Jobs; main marks done without emitting completion message, and tab has no badge. New Decline/filtering does not notify completion.

**Reproduce/context:** Accept a job, switch to Build/Tech, meet the objective and observe the navigation/status UI.

**Player impact:** Earned rewards can remain undiscovered and occupy contract slots while the player works elsewhere.

**Change:** Add a claimable-count badge and a concise completion event with a direct jump to the completed card.

**Done when:** Completion is signalled from any tab once per job; the badge remains until reward claim and opens the relevant claim action.

**Source:** [source_latest/scripts/ui.gd:910](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:910) · specialist key `UI-PANELS-17`

<a id="rim-066"></a>
### RIM-066 · Claimable and active jobs can be hidden below unopened offers

**P2 · improvement · proposal · effort M** — Jobs prioritization

**Evidence:** _rebuild_jobs iterates main.contracts in arrival order. Three cards are supported, but claimable/urgent state does not alter ordering or provide a view filter; at200% only a fraction of the first card is visible in screenshot17_jobs_200.png. Final source recheck: Card order remains main.contracts arrival order. Unwanted offers can now be declined; do not claim offers are irremovable. Claimable/active prioritization or badge grouping still absent.

**Reproduce/context:** Keep the first offer unaccepted, accept the third, complete it, then revisit Jobs at large text size.

**Player impact:** The most actionable work requires scrolling past untouched offers, compounding the absence of external completion feedback.

**Change:** Offer Claimable/Active/Offers grouping or a pinned claimable summary while preserving stable card focus and IDs. Show a consistent positive countdown until expiry, then an explicit expired state; add labelled urgency for near deadlines without relying on colour alone.

**Done when:** Claimable rewards and active deadlines are discoverable before unopened offers; changing state does not unexpectedly move keyboard focus. Accepted jobs are easy to locate, never display expired-looking zero while still active, and clearly distinguish urgent, expired and claimable states.

**Source:** [source_latest/scripts/ui.gd:740](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:740) · specialist key `UI-PANELS-20`

<a id="rim-067"></a>
### RIM-067 · Production rates for Crypto, Tools and Research are absent from the rate HUD

**P2 · improvement · proposal · effort M** — Economic telemetry

**Evidence:** v0.6.5 UI only loops rates overcompute,data,credits although resources/rates support all six keys. Controlled probe supplies Crypto12/s,Tools0.6/s,Research0.5/s and none appear in the net-rate text. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Run a skimmer, Forge or Research Lab and inspect the rate line.

**Player impact:** Players must watch stockpile increments to understand whether secondary resource chains are working.

**Change:** Make per-resource net rates available for every resource, using compact chips, tooltips or a Stats rates table to avoid expanding the crowded header.

**Done when:** A player can read Crypto,Tools andResearch net production without inferring it from changing totals; zero-rate treatment is consistent.

**Source:** [source_latest/scripts/ui.gd:953](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:953) · specialist key `HUD05`

<a id="rim-068"></a>
### RIM-068 · A one-second wallet change is presented as sustainable income and goal ETA

**P2 · improvement · proposal · effort M** — Economic estimation

**Evidence:** Main samples resources minus previous stock over~1s; the UI immediately converts Cash rate into ETA and _peak_cash_rate uses the same samples. Contract payouts, purchases, refunds and ICE losses are mixed with operating delivery. Source reviewed; no long-run ETA accuracy experiment claimed. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Claim a Cash reward or buy an expensive structure between samples, then inspect rate/ETA; compare with a steady resource-delivery network.

**Player impact:** A one-off payout can briefly imply a near-immediate victory; construction can make a healthy network appear to have negative production.

**Change:** Keep wallet-change feedback but estimate sustainable delivery/consumption rates separately with a short smoothed window and exclude capital/reward events from production ETA.

**Done when:** One-off transactions appear as transactions; production rate/ETA remains stable unless operational throughput changes, with an explicit insufficient-data state.

**Source:** [source_latest/scripts/main.gd:1592](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1592) · specialist key `HUD06`

<a id="rim-069"></a>
### RIM-069 · Stats reports stockpiles and counts without showing network operating efficiency

**P2 · improvement · proposal · effort M** — Network telemetry

**Evidence:** Stats shows Structures,Tunnels,In transit,Upkeep,Feed and stockpiles but no aggregate generated-versus-delivered rates, drops or net Cycles sustainability. Individual tunnel/inspector issues belong to the other UX agent. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Open Stats when the network is starved or overloaded and try to identify whether output covers upkeep.

**Player impact:** The network summary cannot distinguish an idle economy from a productive but lossy or uneconomic one.

**Change:** Add compact aggregate production, delivered throughput, dropped fraction and Cycles production/upkeep balance; keep detailed per-host diagnostics in the inspector.

**Done when:** Stats can answer whether the network is producing, delivering and sustaining upkeep using actual measured events.

**Source:** [source_latest/scripts/ui.gd:945](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:945) · specialist key `HUD09`

<a id="rim-070"></a>
### RIM-070 · Repeated alert clicks always select the first failing structure

**P2 · improvement · proposal · effort S** — Alert navigation

**Evidence:** Controlled fixture with two offline nodes: _jump_alert('offline') selects node 2 on both clicks. Source breaks on first matching node every time. Evidence: probes/hud_v065_results.json repeated_alert_jump. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Create multiple offline/overloaded branches and repeatedly click their count alert.

**Player impact:** An aggregate alert offers no efficient route to the second or later issue and repeatedly pulls the camera back to the same host.

**Change:** Cycle through matching targets or open a short issue list, preserving a stable ordering and count.

**Done when:** Every outstanding issue can be reached from its aggregate alert without manual searching; removed/repaired targets are skipped.

**Source:** [source_latest/scripts/ui.gd:803](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:803) · specialist key `HUD10`

<a id="rim-071"></a>
### RIM-071 · Starvation and critical-trace alerts lead to generic C2 text rather than a cause

**P2 · improvement · proposal · effort M** — Alert diagnostics

**Evidence:** _jump_alert falls back tohub_id forstarved/trace; the C2 inspector primarily contains flavor/zone information. It does not open a causal resource, noise or counteraction breakdown. Source-confirmed navigation. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Click Network STARVED or Trace CRITICAL.

**Player impact:** The advertised 'jump to the problem' action reaches C2 but leaves players to work out the remedy.

**Change:** Open a relevant diagnostic summary: Cycles balance/top upkeep routes for starvation, and noise sources/available counteractions for trace.

**Done when:** Each alert exposes at least one concrete cause and an available next action, with links to implicated branches.

**Source:** [source_latest/scripts/ui.gd:814](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:814) · specialist key `HUD13`

<a id="rim-072"></a>
### RIM-072 · Long passive guidance consumes much of the usable sidebar at large text sizes

**P2 · improvement · proposal · effort S** — Guidance layout

**Evidence:** Viewed screenshot18_stats_200.png; measured at200%: next-step status is250px high whileStats scroll area is235px. The status Label autowraps as an unbounded child outside scroll containers. Evidence: probes/hud_v065_results.json scaled_hud. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** At200% text, let the opening next-step guidance appear while Stats/Build/Tech is active.

**Player impact:** Passive tutorial text competes with the active interface and forces extra scrolling for routine controls.

**Change:** Keep a short next-action line with optional expandable detail, and cap passive guidance height without clipping actionable/error messages.

**Done when:** At supported text sizes, guidance leaves enough space for active content and can expand on request; full text remains accessible.

**Source:** [source_latest/scripts/ui.gd:389](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:389) · specialist key `HUD17`

<a id="rim-073"></a>
### RIM-073 · The sweep banner cannot take the player to the threatened branch

**P2 · improvement · proposal · effort S** — Threat navigation

**Evidence:** warn_banner uses MOUSE_FILTER_IGNORE and displays countdown/hops only; alert actions have no sweep kind. Camera can be elsewhere when a sweep starts. Actual tracer geometry is separately owned by the map agent. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Pan away from the current trace path when ICE announces a sweep.

**Player impact:** The reaction timer runs while the player searches for the attacked branch and relevant link.

**Change:** Make the sweep headline a navigation action that focuses the current threatened edge/path and exposes available counteractions.

**Done when:** One click/key action on the sweep warning finds the current trace path and explains the next threatened hop without disturbing unrelated topology.

**Source:** [source_latest/scripts/ui.gd:291](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:291) · specialist key `HUD19`

<a id="rim-074"></a>
### RIM-074 · Keep the pointed-at host stable when wheel-zooming

**P2 · improvement · source_confirmed · effort S** — Camera / zoom usability

**Evidence:** _zoom only changes camera.zoom and never adjusts camera.position. Therefore any world point away from the viewport centre moves away from the pointer during wheel zoom. Final source recheck: _zoom still changes scale without preserving the world point beneath the pointer.

**Reproduce/context:** Place the pointer over a host near a map edge and zoom several wheel steps; the zoom centre remains the camera centre.

**Player impact:** Inspecting or placing precisely requires repeated camera correction after changing scale.

**Change:** Anchor wheel zoom to the current pointer's world point, subject to sensible world bounds.

**Done when:** An in-bounds host remains beneath the pointer across zoom steps at all supported scales; keyboard or dedicated overview zoom remains predictable.

**Source:** [source_latest/scripts/main.gd:1186](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1186) · specialist key `MAP05`

<a id="rim-075"></a>
### RIM-075 · Bound camera travel and provide a quick return to C2

**P2 · improvement · source_confirmed · effort S** — Camera / navigation recovery

**Evidence:** Keyboard, edge and drag panning directly add/subtract camera.position without a map-bound clamp. The world is only 2400x2400 pixels; camera navigation can continue into entirely empty space. Final source recheck: Pan/drag/edge updates still have no world clamp and no dedicated return-to-C2 control is present.

**Reproduce/context:** Hold a pan key or edge-pan away from the map until its buildings leave view. This is a source-confirmed navigation possibility, not a performance conclusion from render-probe screenshots.

**Player impact:** A player can lose their network and spend time recovering instead of making routing decisions.

**Change:** Allow a small overscroll margin, clamp or softly stop beyond it, and add a visible/keybound return-to-C2 action.

**Done when:** Ordinary panning cannot leave the map unrecoverably offscreen, and one action reliably returns C2 to the usable map viewport at any zoom.

**Source:** [source_latest/scripts/main.gd:1551](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1551) · specialist key `MAP06`

<a id="rim-076"></a>
### RIM-076 · Show currently accessible territory on the minimap

**P2 · improvement · proposal · effort M** — Minimap / exploration and build reach

**Evidence:** The minimap bakes all district colours with no _vision_list or _vis_blocks overlay, while placement requires every footprint cell to be within vision. Startup screenshots show the whole resource map despite only a small usable neighbourhood. Final source recheck: Minimap texture still colours all districts without the current access/vision overlay.

**Reproduce/context:** At startup compare the fully coloured minimap with fog and legal placement reach around C2.

**Player impact:** Players can navigate toward resources on the overview without a cue that more access infrastructure is needed before acting there.

**Change:** Retain known district geography if desired, but add a clear current-access or discovered-area overlay using the same vision state as the world.

**Done when:** The overview distinguishes accessible and unavailable territory through redundant visual cues and updates after a new host or Proxy extends reach.

**Source:** [source_latest/scripts/minimap.gd:53](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/minimap.gd:53) · specialist key `MAP10`

<a id="rim-077"></a>
### RIM-077 · Use the minimap to locate network health and the current selection

**P2 · improvement · proposal · effort M** — Minimap / operational overview

**Evidence:** Every node is drawn as a fixed 3x3 resource-colour square. There is no disabled/offline/quarantined state, selected-node highlight, or active-sweep marker; screenshot 07's disabled producer is not distinguishable from an operational producer in the overview. Final source recheck: Canonical _op_state now exists for the inspector, but minimap markers still ignore it, selection and sweep position.

**Reproduce/context:** Compare screenshots 06_selected_producer.png and 07_disabled_producer.png at the minimap, then review the node-marker draw loop.

**Player impact:** When the network grows, players cannot use the overview to find the selected branch or locate a failure without moving the main camera.

**Change:** Add compact redundant status/selection markers and an ICE position cue; dirty redraw only when those states change.

**Done when:** Selection and disabled/offline/quarantined hosts can be distinguished without colour alone; active ICE can be located while its branch is offscreen.

**Source:** [source_latest/scripts/minimap.gd:64](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/minimap.gd:64) · specialist key `MAP11`

<a id="rim-078"></a>
### RIM-078 · Tunnel rendering repeatedly rebuilds stable route geometry

**P2 · improvement · source_confirmed · effort M** — Performance / routes

**Evidence:** _draw queries _path_bounds for each tunnel; that function loops the route cells, and _edge_pts recreates route polylines. Packet movement has a _polyline cache, but bounds and drawing do not share it. This is a source-confirmed avoidable cost; no isolated savings estimate is claimed.

**Reproduce/context:** Inspect draw work with long street routes while endpoints/topology remain fixed.

**Player impact:** Stable routes perform repeated allocation and cell traversal whenever ambient animation redraws the map.

**Change:** Cache bounds, rendered polyline and segment lengths together per topology revision; invalidate on reroute, removal and restore.

**Done when:** Repeated draws allocate no fresh stable-route geometry; topology changes update all caches before rendering or movement.

**Source:** [source_latest/scripts/main.gd:2129](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2129) · specialist key `PERF05`

<a id="rim-079"></a>
### RIM-079 · Packet movement repeatedly searches long polylines from their start

**P2 · improvement · verified_runtime · effort M** — Performance / packets

**Evidence:** CPU microbench using a synthetic winding120-cell/62-point path measured mean movement0.236ms at100 packets,2.715ms at1000 and9.235ms at3000(p95 13.647ms). _point_at_dist linearly searches segments and per-packet lookup repeats work. These counts are stress fixtures. Evidence: performance_results.json.

**Reproduce/context:** Run the packet movement microbench at100/1000/3000 packets on the same winding path.

**Player impact:** Packet work competes with simulation and rendering as traffic grows.

**Change:** Cache cumulative segment distances and use a remembered segment index or binary search; reuse positions for drawing, with explicit reverse-direction handling.

**Done when:** Movement is identical across bends and both directions, and the same packet fixture shows lower mean/p95 CPU time.

**Source:** [source_latest/scripts/main.gd:1013](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1013) · specialist key `PERF06`

<a id="rim-080"></a>
### RIM-080 · Full fog recomputation becomes a noticeable placement spike

**P2 · improvement · verified_runtime · effort M** — Performance / visibility

**Evidence:** Synthetic400-node CPU microbench measured mean vision rebuild40.25ms(max46.3ms), compared with cached check0.153ms. Rebuild tests fog block centres against the full host list; the cached path also scans every node for relays. Evidence: performance_results.json vision_rebuild/vision_cached.

**Reproduce/context:** Compare cached and invalidated _vision_list timings at1/50/150/400 nodes; profile a node-set mutation.

**Player impact:** Adding/removing/converting a host can briefly stall feedback in a larger network.

**Change:** Track visibility revision explicitly and update only affected blocks using spatial buckets or coverage counts. Ensure Undo/load invalidates the correct region.

**Done when:** Same fixture substantially reduces mutation-time spikes while visible cells and placement legality remain equivalent to the reference calculation.

**Source:** [source_latest/scripts/main.gd:807](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:807) · specialist key `PERF07`

<a id="rim-081"></a>
### RIM-081 · The sidebar recomputes mostly unchanged telemetry every frame

**P2 · improvement · verified_runtime · effort M** — Performance / UI updates

**Evidence:** Baseline v064 CPU microbench at400 synthetic nodes measured UI._process means1.92ms on Build and2.66ms on Stats per call. The UI walks network state and formats labels every frame while most simulation values change at10Hz or rate samples at1Hz. v065 adds compact-header measurement; quoted timings remain v064 measurements.

**Reproduce/context:** Run UI process microbench on unchanged fixtures and inspect label assignments/network loops during paused frames.

**Player impact:** Large networks pay formatting/counting costs on frames that cannot display new information.

**Change:** Refresh telemetry on simulation/rate revisions, inspector state on selection/mutations and layout on scale/size changes. Keep hover and warnings responsive.

**Done when:** Paused idle UI performs no unnecessary full-network telemetry pass; live values refresh at their data cadence and actions update immediately.

**Source:** [source_latest/scripts/ui.gd:826](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/ui.gd:826) · specialist key `PERF08`

<a id="rim-082"></a>
### RIM-082 · Paused frames still hash every node to detect visual changes

**P2 · improvement · verified_runtime · effort M** — Performance / invalidation

**Evidence:** CPU microbench measured _visual_sig mean0.986ms at400 nodes even without state changes. It hashes a full per-node representation on each main._process call. Evidence: performance_results.json visual_signature; the main script is unchanged in v065.

**Reproduce/context:** Profile stationary paused scenes at1/50/150/400 nodes and inspect _visual_sig.

**Player impact:** The existing repaint gate still spends proportional CPU time on an idle network.

**Change:** Increment a visual revision at every visible mutation and compare revisions; retain explicit camera/pointer/animation gates and audit all mutation paths.

**Done when:** Paused idle detection is constant-time while toggles, selection, settings, Undo, threat state and restores still repaint once.

**Source:** [source_latest/scripts/main.gd:256](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:256) · specialist key `PERF09`

<a id="rim-083"></a>
### RIM-083 · The Stats graph redraws every paused frame without new samples

**P2 · improvement · verified_runtime · effort S** — Performance / chart

**Evidence:** Rendered paused Stats test recorded80 graph draw notifications across80 frames while time/history sampling was stopped. graph._process checks its local visible flag and calls queue_redraw each frame. Evidence: render_results.json paused_stats.

**Reproduce/context:** Open Stats, pause, keep pointer/camera fixed and count graph draw notifications over80 frames.

**Player impact:** A static chart repeatedly regenerates identical drawing commands and may do work while an ancestor hides it.

**Change:** Redraw only on a history revision, size/theme/text-scale change or first becoming visible in the tree.

**Done when:** Paused unchanged Stats produces zero repeated graph redraws; each new sample and layout change repaints promptly.

**Source:** [source_latest/scripts/graph.gd:6](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/graph.gd:6) · specialist key `PERF10`

<a id="rim-084"></a>
### RIM-084 · Simulation catch-up has no per-frame work budget

**P2 · improvement · source_confirmed · effort M** — Performance / simulation scheduling

**Evidence:** main._process drains all accumulated0.1s ticks in an unbounded while loop. Separate400-node CPU fixtures measured roughly13ms per tick; a hitch can therefore demand several costly ticks before input/rendering resumes. No observed shipping-frame hitch or spiral is claimed.

**Reproduce/context:** Introduce controlled frame hitches in the isolated project and record catch-up work, elapsed simulation time and input latency.

**Player impact:** After a pause in execution, accumulated simulation work can extend the recovery stall.

**Change:** Set a documented per-frame catch-up/time budget and carry remaining debt across frames, with a clear policy for very long stalls. Preserve deterministic tick ordering.

**Done when:** Controlled250ms/1s hitches recover with bounded input latency and no silently skipped resource, threat or contract time under the chosen policy.

**Source:** [source_latest/scripts/main.gd:1607](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1607) · specialist key `PERF11`

<a id="rim-085"></a>
### RIM-085 · Long-route cursor previews need a bounded work cadence

**P2 · improvement · verified_runtime · effort M** — Performance / interactive routing

**Evidence:** Existing cached A* preview CPU probe on a generated100x100 city measured mean0.558ms for nearby target,5.88ms to(79,79),6.41ms to(99,99). The heap/search cap improvements are already present; this is remaining synchronous work on changed pointer cells. Evidence: performance_results.json route_preview.

**Reproduce/context:** Sweep the pointer through successive distant cells with a source armed; compare interactive latency with the recorded per-search microbench.

**Player impact:** Repeated long searches can make route placement feel sticky despite a working path cache.

**Change:** Debounce or budget preview work and cancel stale targets; render a pending state and validate the current endpoint synchronously on commit when needed.

**Done when:** Long-route hover remains responsive, stale results never appear on newer targets, and commit cost/validity uses the current topology.

**Source:** [source_latest/scripts/main.gd:742](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:742) · specialist key `PERF12`

<a id="rim-086"></a>
### RIM-086 · Account for route latency and supply rate in contract difficulty

**P2 · improvement · proposal · effort S** — Contracts / pacing

**Evidence:** The final snapshot filters stock offers by reachable output resources and allows Decline. Offer amount/deadline selection still does not budget for current production rate, input availability or end-to-end route latency. This is a balance proposal, not a recorded campaign deadline failure.

**Reproduce/context:** Source comparison: the same 50-Intel/90-second contract can be offered to a short sustained route and a distant starved route without changing difficulty or reward.

**Player impact:** The contract challenge can be dominated by seed geography and travel time rather than a deliberate player improvement.

**Change:** Use a few simple contract tiers keyed to achieved production, with a travel allowance and clear risk classification; keep acceptance optional.

**Done when:** Each tier has a feasible reference network, and the allowed time includes the first required packet round trip without relying on an unimplemented supply chain.

**Source:** [source_latest/scripts/main.gd:2009](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2009) · specialist key `D-CONTRACT-DEADLINE-BALANCE`

<a id="rim-087"></a>
### RIM-087 · Align coverage tuning with the actual radius-four grid ceiling

**P2 · improvement · source_confirmed · effort S** — Economy / production balance

**Evidence:** A radius-four integer disk intersects at most seven distinct 3x3 occupied blocks on a four-cell grid across all 16 centre phases. Thus current coverage/5 tops out at 1.4 before vacancies/farm narrowing, while the clamp/comment allow 2.5. Final source recheck: Radius, four-cell blocks, integer disk and coverage/5 are unchanged; the seven-building, 1.4 upper-bound proof still applies.

**Reproduce/context:** Read findings/coverage_geometry.json: exhaustive fully occupied-grid upper-bound calculation reproduces _coverage disk and block layout; no Godot playthrough is claimed.

**Player impact:** The advertised tuning range above 1.4 is unreachable in the current geometry, which distorts balance assumptions for advanced production and placement rewards.

**Change:** Choose an attainable density reference divisor or lower the documented/tuned upper range; avoid enlarging the radius solely to justify an old number.

**Done when:** The stated production multiplier range is reachable on a documented legal dense placement and verified by a small seed sample; sparse placements remain useful.

**Source:** [source_latest/scripts/main.gd:1632](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1632) · specialist key `D-COVERAGE-CEILING`

<a id="rim-088"></a>
### RIM-088 · Separate victory progress from the wallet spent on upgrades

**P2 · improvement · source_confirmed · effort S** — Economy / win condition

**Evidence:** The win check uses resources.credits >= 1000, while advanced facilities and tunnels deduct that same wallet. Every investment immediately reduces displayed goal progress even when it improves the network. Final source recheck: Victory still uses current credits >= 1000; facility and tunnel Cash purchases reduce that same wallet.

**Reproduce/context:** At a high Cash balance, buy a Cloud Cryptojacker, Mixer or HTTP tunnel; the victory balance falls by its cost.

**Player impact:** Near the finish, waiting with an adequate network can be more appealing than using the unlocked construction choices.

**Change:** Evaluate a cumulative earned-Cash milestone or a one-time final operation funded from Cash; keep Cash as the spendable currency.

**Done when:** A successful upgrade does not erase completed objective progress, and the goal clearly communicates whether earnings, retained balance or a final spend is required.

**Source:** [source_latest/scripts/main.gd:1754](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1754) · specialist key `D-GOAL-REINVESTMENT`

<a id="rim-089"></a>
### RIM-089 · Make compromised hosts look acquired rather than newly constructed

**P2 · improvement · proposal · effort M** — Hacker fantasy / map identity

**Evidence:** STRUCT supplies roof, windows, tiers and height for player nodes; _draw_building constructs architecture over the static city. The same physical-building metaphor dominates both unowned and owned map objects. Final source recheck: Player nodes still use tiered architecture, roof and window profiles. Canonical inspector operational-state labels do not change ownership rendering.

**Reproduce/context:** Source walkthrough: compare _paint_city background blocks with the tier/roof rendering of a deployed producer.

**Player impact:** Neon decoration does not clearly communicate the change from remote target to controlled host.

**Change:** Keep the city backdrop and footprint, but present acquired endpoints as marked hosts or executable modules with an unmistakable compromised state and resource glyph.

**Done when:** Before/after ownership can be identified at normal and far zoom without relying on colour; High Contrast and Reduced Motion preserve the cue.

**Source:** [source_latest/scripts/main.gd:2373](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:2373) · specialist key `D-HOST-OWNERSHIP`

<a id="rim-090"></a>
### RIM-090 · Permit a small set of producer upgrades that preserve the route

**P2 · improvement · source_confirmed · effort M** — Progression / network maintenance

**Evidence:** Higher-tier producers are separate placement tools. Replacing an existing footprint requires removal, and _remove_node detaches its incoming children and destroys their out-links. Final source recheck: Promote replacement: begin_reroute changes an existing edge, not producer type. Replacing a producer still requires removal, which detaches its children.

**Reproduce/context:** Source walkthrough: replace a routing producer with a stronger same-resource producer; removal detaches connected child links.

**Player impact:** Research offers more production choices, but adopting them can demand repeated rewiring instead of improving an established network.

**Change:** Support only obvious same-resource upgrades, charge the upgrade cost, and preserve footprint, parent route and incoming links when compatible.

**Done when:** An upgraded Cycles or Intel host retains valid network connections, recalculates load/output, and remains reversible through the existing undo model.

**Source:** [source_latest/scripts/main.gd:1534](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1534) · specialist key `D-INPLACE-UPGRADES`

<a id="rim-091"></a>
### RIM-091 · Make Onion Routing's long-reach promise measurable

**P2 · improvement · source_confirmed · effort S** — Progression / protocol choice

**Evidence:** All five TUNNEL_MAXLEN entries equal 255. Onion Routing is described as long-reach but currently differs through loss/upkeep/capacity rather than a larger routing budget. Final source recheck: Every TUNNEL_MAXLEN remains 255; long-route niche recommendation is still valid.

**Reproduce/context:** Compare _tool_maxlen for DNS, VPN, Reverse Shell, HTTP and Onion; all return the same maximum route length.

**Player impact:** The advanced unlock does not communicate a clearly distinct reach capability, so a costly Tool-based purchase can disappoint the stated expectation.

**Change:** Give Onion one clear distance niche, such as a larger route budget or strongly improved long-route economics, and describe that exact benefit.

**Done when:** A documented route comparison demonstrates a useful Onion advantage that another early protocol does not already provide at lower total cost.

**Source:** [source_latest/scripts/main.gd:60](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:60) · specialist key `D-ONION-NICHE`

<a id="rim-092"></a>
### RIM-092 · Make going quiet a meaningful answer to escalating pursuit

**P2 · improvement · source_confirmed · effort M** — Threat / strategic agency

**Evidence:** notoriety uses max(previous, wealth)+0.03 per second, never decays, and can independently charge sweeps above 45 even when Trace is zero. DDoS resets Trace and charge but not notoriety. Final source recheck: Notoriety still never decays and independently charges sweeps. New reroute affordance adds active evasion but does not make quieting prevent notoriety-driven pursuit.

**Reproduce/context:** Source walkthrough: once notoriety exceeds 45, use silent DNS/VPN links and zero Trace; _update_sweep still accumulates pursuit charge.

**Player impact:** Quiet protocol choices eventually stop preventing pursuit, while the game's guidance frames quieting as a defensive response.

**Change:** Either let sustained low exposure reduce pursuit pressure, or explicitly teach that permanent reputation requires active evasion rather than quieting.

**Done when:** A low-exposure strategy has a documented effect on future sweep frequency, or the independent reputation threat is clearly introduced before it becomes irreversible.

**Source:** [source_latest/scripts/main.gd:1754](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1754) · specialist key `D-QUIET-COUNTERPLAY`

<a id="rim-093"></a>
### RIM-093 · Stop optional Labs consuming inputs after the last useful unlock

**P2 · improvement · source_confirmed · effort S** — Economy / late-game automation

**Evidence:** TECH contains a finite seven-entry tree. _sim_tick continues Lab pulls and fuel spending after all technologies are researched; Research has no further spend in the current game. Final source recheck: Lab consumption still runs after the finite TECH set is fully unlocked; no auto-standby or repeatable Research use was added.

**Reproduce/context:** Source walkthrough: mark all TECH entries researched, retain an enabled linked Lab with Intel and Cycles, then evaluate processor pulls.

**Player impact:** A completed research system can keep diverting the resources needed for the remaining Cash objective without producing usable value.

**Change:** Put Labs in automatic standby when no current Research spend remains, with an explicit resume option for continued sandbox stockpiling.

**Done when:** After the last unlock, ordinary Lab automation stops consuming Intel/Cycles and clearly reports standby; manual override and saves preserve the intended state.

**Source:** [source_latest/scripts/main.gd:1754](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1754) · specialist key `D-RESEARCH-IDLE`

<a id="rim-094"></a>
### RIM-094 · Give the central Spire a simple end-of-run purpose

**P2 · improvement · source_confirmed · effort M** — Progression / endgame

**Evidence:** Generation always creates a Spire with ICE tier 3, but ZONE_RES gives it no output and victory checks only the Cash balance. It provides no unique operation or completion condition. Final source recheck: Spire remains an ICE-3 district with no unique completion operation; Cash is still the only win check.

**Reproduce/context:** Compare the Spire's generation/security entries with _placement_error, producer resource mappings and the win check.

**Player impact:** The visually prominent centre promises a destination that the economy does not require the player to reach.

**Change:** Add one optional or final Spire operation using existing Tools, routing and Cash rather than adding a separate progression currency.

**Done when:** The Spire has a stated actionable purpose and visible completion result; a player can understand its requirements before committing to the route.

**Source:** [source_latest/scripts/main.gd:334](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:334) · specialist key `D-SPIRE-PAYOFF`

<a id="rim-095"></a>
### RIM-095 · Validate an accessible starter route for each generated map

**P2 · improvement · proposal · effort M** — Map generation / opening fairness

**Evidence:** _place_hub selects the first residential coarse cell from the left. Generation does not validate reachable legal producer footprints, nearby Intel access, or the cost of the first useful reveal route. Final source recheck: Generation and first-residential hub placement remain unvalidated for a guaranteed affordable opening route.

**Reproduce/context:** Source review of generation and hub placement; inspect a fixed seed set for legal starter Cycles/Intel paths and required spend.

**Player impact:** Procedural variation can change the cost and clarity of the first lesson before the player understands routing; frequency needs a seed sweep, not a claimed played failure.

**Change:** Validate a small opening neighbourhood and reroll or adjust only invalid starts, preserving the rest of the random city.

**Done when:** A documented seed batch always offers a legal Cycles foothold and an affordable path toward Intel using starting resources and early income.

**Source:** [source_latest/scripts/main.gd:378](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:378) · specialist key `D-START-FAIRNESS`

<a id="rim-096"></a>
### RIM-096 · Market saturation immediately reverses when the player spends Cash

**P3 · improvement · proposal · effort M** — Market economy

**Evidence:** Measured controlled wallet fixture: at1000 Cash quote0.50; spending500 Cash raises quote0.75 without a change in sales volume. _market_price depends solely on present resources.credits. Evidence: simulation_results wallet_market_price. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Compare sale quote before and after buying Cash-costing infrastructure.

**Player impact:** The description says sales saturate demand, but buying upgrades restores demand instantly; the intended diversification incentive is weak and hard to understand.

**Change:** Choose wallet-sensitive pricing deliberately and explain it, or base saturation on cumulative/recent sales with an explicit recovery mechanism.

**Done when:** A spending-only action has the documented pricing effect; market-demand changes can be explained from visible inputs.

**Source:** [source_latest/scripts/main.gd:1278](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/main.gd:1278) · specialist key `SIM19`

<a id="rim-097"></a>
### RIM-097 · Startup menu has no initial keyboard focus

**P3 · improvement · proposal · effort S** — Startup keyboard navigation

**Evidence:** menu._ready creates buttons but never selects a focus target. The real-scene probe records initial_focus.path='null'. Keyboard Tab can initiate navigation; this proposal improves immediate discoverability rather than claiming keyboard navigation is impossible. Final source recheck: Replace resolved CONTROLS02 with this startup-focus proposal. _ready still never focuses a startup action; _open_settings focuses Reduced motion only after the new modal opens.

**Reproduce/context:** Launch using a keyboard and look for a focused default action before pressing Tab.

**Player impact:** There is no visible starting point or immediately actionable default for keyboard users.

**Change:** Focus Continue when a usable save is available, otherwise New Game, and retain a clear focus indicator.

**Done when:** The entry menu has one sensible initial focus target; Enter/Space activates it and all actions remain reachable with Tab/Shift+Tab.

**Source:** [source_latest/scripts/menu.gd:38](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/menu.gd:38) · specialist key `UI-CONTROLS-04`

<a id="rim-098"></a>
### RIM-098 · The Cash chart has no time or value scale

**P3 · improvement · proposal · effort S** — Stats chart

**Evidence:** Viewed screenshot10_stats.png and graph.gd: only 'Cash→1000 goal' is drawn; samples are arolling120-entry one-Hz buffer. No timestamps,x-axis range,value ticks or hover values are available. The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.

**Reproduce/context:** Open Stats after several minutes of play and interpret a rising/falling segment.

**Player impact:** The chart's meaning and measurement window cannot be read reliably, making economic comparisons guesswork.

**Change:** Label the rolling time window and currency scale; add current/peak values or simple hover readouts appropriate to a small sparkline. Use an adaptive early-game range with an explicit goal marker so small improvements remain visible; label the chosen range.

**Done when:** A player can determine the chart's period, approximate balance and timing of changes without reading code. Early Cash changes are discernible and the player can tell the displayed time span and value range.

**Source:** [source_latest/scripts/graph.gd:19](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/graph.gd:19) · specialist key `HUD07`

<a id="rim-099"></a>
### RIM-099 · Preserve map proportions in the minimap

**P3 · improvement · verified_runtime · effort S** — Minimap / spatial readability

**Evidence:** The actual 1280x720 startup layout reports a 284x148 minimap for a square 100x100 map. Its texture and coordinates scale independently on each axis, stretching horizontal relationships by about 1.92 relative to vertical ones; screenshots 02 and 20 show this wide projection. Final source recheck: Minimap draw/click transforms and 284x148 UI size are unchanged; aspect-distortion finding remains.

**Reproduce/context:** Compare a square district/camera footprint in the world with its displayed minimap proportions in 02_new_game.png.

**Player impact:** Distances and neighbourhood shapes on the overview do not match the spatial relationships used for routing.

**Change:** Letterbox a square map area inside the existing control and share its transform between drawing and click-to-pan.

**Done when:** Equal world distances appear equal on both minimap axes, and clicks map correctly through any letterbox margins.

**Source:** [source_latest/scripts/minimap.gd:64](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/minimap.gd:64) · specialist key `MAP08`

<a id="rim-100"></a>
### RIM-100 · Allow players to replay and share a map seed

**P3 · improvement · source_confirmed · effort S** — Replay / run setup

**Evidence:** The main menu assigns randi() for every New Game. Session.seed is already consumed by main and the current seed is available in Stats, but there is no seed-entry or restart-same-seed action. Final source recheck: Promote replacement: New Game still assigns randi(), with no seed field or restart-same-seed action. Menu Accessibility additions do not provide map replay.

**Reproduce/context:** Source walkthrough of New Game and Session.seed consumption; the current menu always selects a new random seed.

**Player impact:** Players cannot easily retry a difficult layout, compare routing solutions or reproduce an interesting city.

**Change:** Offer an optional seed field and a restart-this-map action; retain random New Game as the default.

**Done when:** Entering the same seed produces the same layout and start, and the chosen seed can be copied without accessing save files.

**Source:** [source_latest/scripts/menu.gd:171](C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source_latest/scripts/menu.gd:171) · specialist key `D-SEED-REPLAY`
