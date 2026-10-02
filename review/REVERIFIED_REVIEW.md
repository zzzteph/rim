# RIM v0.5.8 — reverified review and 100 improvements

Reviewed 2 October 2026, Europe/Berlin. This pass rechecks all **50 earlier findings**, adds **12 further findings**, and expands the **50 earlier improvement suggestions to 100**. The 62-item audit contains **55 defects and 7 unresolved rule mismatches**. It does not claim 100 confirmed bugs. The earlier report and its 120-row backlog remain preserved.

## Main assessment

The recent work targets rendering efficiency, but the core simulation, saving and interaction defects remain. None of the earlier 50 findings is closed by the inspected v0.5.8 changes. The most useful next release is a trustworthy, readable operation: guarantee Cycles recovery, preserve a run on Save/Continue, make traffic limits and OFF states consistent, restore meaningful sweep counterplay, and make all primary actions reachable at 720p and large text sizes.

The game already has contracts, ICE sweeps, alerts, tooltips and a Cash graph. Recommendations below extend those systems; older gap documents must not be used to claim they are absent. The primary progression problem remains: the same opening Intel-to-Market chain can satisfy the 1000-Cash victory check while research, Tools, Crypto and protected expansion remain optional. A supplied final operation and useful intermediate capabilities would create more decisions. Raising the Cash target alone would extend accumulation.

## What was reverified

Current production scripts, scenes and project configuration were hashed before probing. Three isolated current copies were imported with Godot 4.7.2. Only copied Session/Settings paths were redirected away from normal user saves; production gameplay code was not changed. Source comparison shows that the v0.5.8 main changes concern fog caching, redraw gating, frustum culling and rendering LOD; UI changes throttle alert scanning. Menu and minimap mechanics are unchanged.

**55 of 62 findings have fresh engine-fixture support**; the rest rely on current source or a communicated-rule mismatch. R = reproduced state/layout/geometry observation; C = inspected current code; D = intended-rule decision still required. Some R fixtures establish a bad state while the later error path is source-verified. Geometric culling fixtures establish an algorithm failure, not how often a naturally generated route exhibits it. Headless checks do not establish human readability, screen-reader support, controller usability, renderer frame rate or completed-run pacing.

The engine emitted a certificate-store diagnostic and editor-settings permission messages during isolated import. They are environment diagnostics and excluded from game defects. Completed final probes produced retained results; discarded exploratory parse failures are not passing evidence.

## Strongest current evidence

| Finding | Fresh observation | Implication |
|---|---|---|
| B01 | A legal three-Market/one-DNS opening remains at zero resources after fresh Continue and 100 simulated seconds. | MIN_FEED does not guarantee recovery without a source. |
| B03 / B04 | A rated 3/s DNS fixture models 11.54/s delivery from 115.4/s offered; a processor emits three input packets while offered load says zero. | Balance data cannot be trusted until capacity semantics and traffic accounting agree. |
| B13 / B14 | Cutting a swept tunnel still causes a four-second blackout and 25-Cash sting; the six-second warning already quarantines its target. | Advertised planning and counterplay do not match execution. |
| B16–B24 | A 0.5-Cash packet becomes 1; fresh Continue loses boosts, contracts, threat and cumulative metrics; stale undo refunds 5 Cycles. | Saving changes player-earned state and can exploit resource accounting. |
| B27–B29 / B47 | Build status starts at y742 in a 720px viewport; most nominal 200% text stays unchanged; warning and rates overlap. | Essential actions and information are inaccessible at supported settings. |
| B51 / B52 | A paused toggle changes state with no draw event; endpoint-box culling rejects an actually visible detour segment. | New optimization work needs visual invalidation and correct geometry bounds. |
| B55 / B57 / B58 | Lab/Forge rates round to 1/s, quarantine says no path, and 3% distance plus 20% Trace loss is labelled 22% distance. | Incorrect diagnosis encourages the wrong network changes. |

## Corrections to the earlier review

- B05: the disabled junction still has an edge record; the verified fault is unpaid forwarding upkeep/noise.
- B06: passing Intel sells while OFF. Finishing prepaid work after shutdown requires its own explicit policy and is not counted as a separate bug.
- B08, B03, B15 and B25 are retained as unresolved rule mismatches, rather than assuming a specific restriction, capacity or reward policy is unintended.
- B10 includes slums vacancy and Farm footprint disagreements under one geometry fix; B26 includes square/circle coverage and the erroneous six-tile Intel description.
- B39 cites the pause-planning implementation/design contradiction, not a demonstrated on-screen promise. B44 withdraws the unverified claim that all glyphs immediately update their palette.
- B53 distinguishes ordinary source selection, which rejects linked nodes, from the armed-source/Undo state transition that allows replacement. Reroute recommendations must not imply an existing atomic upgrade UI.
- The earlier ideal research calculation remains 115 RP / 0.5 RP/s = 230 seconds of supplied Lab processing. It is not a measured full-run duration. The previous 90–120-minute standard scenario target remains a playtest hypothesis, not a shipping requirement.

## Prioritized delivery order

Effort S/M/L describes relative implementation scope, not elapsed days. P0 blocks recovery; P1 should precede another broad playtest; P2 improves the next dependable version; P3 is an optional later experiment. Proposal priority does not make it a confirmed defect. Do not attempt all 100 suggestions at once.

| Batch | Work to complete | Check before proceeding |
|---|---|---|
| 1 — Recover and preserve | B01, B02, B16–B24; T40, T95, T99 | Legal exhausted openings recover; full-state fresh/in-place round trips match; bad or interrupted saves keep the last good run. |
| 2 — Make the network reliable | B03–B07, B09–B15, B26, B53–B54; T26–T34 | Settled capacity/OFF rules, directional processor traffic, valid packets after topology changes, live sweep traversal and conserved undo. |
| 3 — Make interaction readable | B27–B50, B55–B59; T13, T15–T17, T20, T80 | 720p and large text work; modals contain focus/input; inspection explains actual rates and loss causes. |
| 4 — Validate performance changes | B51–B52; T32, T97 | Paused actions repaint, on-screen detours remain visible, and performance is measured with representative traffic. |
| 5 — Teach and measure | T21, T23, T25, T42–T50, T51, T92 | Players build a sustainable opening; recurring jobs require new work; measurement separates operations, transactions and idle time. |
| 6 — Add depth selectively | T41, T54–T59, T62, T70–T75, T89 | Prototype one new capability and one supplied end objective; playtests demonstrate new decisions and multiple viable strategies. |

## Reverified findings: B01–B50 and additions B51–B62

Every earlier ID remains stable. Related extra symptoms are folded into their earlier finding; additional candidate lists from specialists are supporting notes, not extra counted findings. A rule mismatch can be resolved by changing the mechanic or its explanation, after choosing the intended rule.

### B01 — A legal opening can permanently stall the economy

**P0 · Defect · Open · R+C · effort M**. Source: [main.gd:1461](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1461).

Three Markets cost 75 Cycles; one DNS link spends the last 5. After Save → Continue, there are no producers, inputs, affordable replacements, or undo records. A 100-second probe remained at zero resources.

**Action:** Guarantee an emergency Cycles/reconnection path or sufficient salvage.

**Acceptance:** Recover the legal zero-resource opening after fresh Continue through guaranteed salvage or emergency supply; keep every reachable run recoverable.

### B02 — Infrastructure bypasses ICE affordability and can mint Tools

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:1149](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1149).

A Market placed in ICE with zero Tools succeeds and takes the balance to −1. After the tick clamps it to zero, undo refunds an unpaid Tool.

**Action:** Validate the complete cost, including ICE, before placement; refund only what was paid.

**Acceptance:** At zero Tools an ICE placement is refused with no charge or node; undo never refunds more than the verified payment.

### B03 — Advertised tunnel capacity is not a throughput ceiling

**P1 · Rule mismatch · Rule decision unresolved · R+C+D · effort M**. Source: [main.gd:1500](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1500).

The congestion floor leaves 10% of arbitrarily large input. A DNS fixture reported capacity 3/s, offered 115.4/s, and modeled delivery 11.54/s.

**Action:** Clarify whether capacity is a hard ceiling or an intentionally soft threshold; then align admission behavior, balance and telemetry.

**Acceptance:** Choose hard or soft capacity explicitly; offered 115.4/s on a rated 3/s edge obeys the chosen admission rule and matching telemetry.

### B04 — Converter requests and outputs do not count toward load

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1572](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1572).

A Market debited 3 Intel and emitted 3 input packets while its edge reported offered load 0/s. Shared trunks omit processor traffic too.

**Action:** Include input and return traffic in the capacity model.

**Acceptance:** Account for processor input and output on all traversed edges; three input requests cannot report zero offered load.

### B05 — Disabled junctions forward for free

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:1462](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1462).

An OFF Market and its child remain reachable and the OFF edge still has telemetry. Its outgoing forwarding incurs no upkeep or noise; the fixture charges only the enabled child's link.

**Action:** Define production-off versus network-off explicitly and charge forwarding consistently.

**Acceptance:** Define production-off versus routing-off; forwarded traffic pays its intended upkeep and noise even when local production is disabled.

### B06 — Disabled Markets still sell passing Intel

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:852](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:852).

Intel passing through an OFF Market still becomes Cash. A prepaid inbound request also completes after shutdown; define whether that existing work should finish, buffer or cancel separately from pass-through selling.

**Action:** Require an operational Market before conversion.

**Acceptance:** An OFF or otherwise non-operational Market cannot silently convert passing Intel; any permitted draining behavior is explicit.

### B07 — Rebuilt links leave packets on obsolete routes

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:837](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:837).

A packet stores node IDs for A→B→C2. Reconnect A to D before arrival: its first edge now uses new geometry, but its stored next hop still references B.

**Action:** Version edges and invalidate replaced-edge traffic, or repath at junction arrivals.

**Acceptance:** Reparent A from B to D while a packet is in flight; it follows a valid live route or is cancelled under a stated policy.

### B08 — Advanced Cycles producers reject residential Cycles ground

**P2 · Rule mismatch · Rule decision unresolved · R+C+D · effort S**. Source: [main.gd:1181](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1181).

The GDD says Package and Cryptojacker can use any Cycles ground, while placement excludes The Sprawl because residential is absent from ZONE_RES. The restriction may be intentional; the communicated rule is inconsistent.

**Action:** Reconcile the intended district rule and its descriptions, using one authoritative mapping.

**Acceptance:** Choose whether residential is valid advanced Cycles ground; all previews, tool help and design documentation use that same mapping.

### B09 — Construction can obstruct an existing tunnel

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1149](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1149).

A footprint may include road cells if at least half its cells belong to a building. Placement checks other structures, but not existing tunnel cells.

**Action:** Reject conflicting footprints or preview and reroute affected links.

**Acceptance:** Reject a footprint over a tunnel or commit a reviewed reroute; no completed construction leaves traffic intersecting blocked geometry.

### B10 — Rendered buildings and simulated occupancy disagree

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:740](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:740).

At city seed 12345, a tile/block comparison finds 15 vacancy disagreements near slums boundaries and 53 Farm blocks whose narrow rendered footprint disagrees with wider collision. One authoritative geometry fix covers both.

**Action:** Generate one authoritative block descriptor for rendering, placement, coverage, and routing.

**Acceptance:** Rendering, placement, coverage and road routing consume one authoritative building geometry; verify slums boundaries and narrowed Farm blocks.

### B11 — Undo can leave a nonexistent pending tunnel source

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:2298](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2298).

Place a producer, arm a tunnel from it, then undo its placement. pending_child still references the erased node; the next preview accesses invalid routing state.

**Action:** Clear pending references and route caches when their node disappears.

**Acceptance:** Undo the armed source's placement; pending references and preview caches clear without invalid node access.

### B12 — Undo can leave an invalid selected tunnel

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:2313](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2313).

Select a newly built tunnel and undo construction. Its node survives with tunnel type '', but the inspector still looks up TUNNEL_DEFS using that empty key.

**Action:** Clear edge selection when its edge is removed; validate before inspection.

**Acceptance:** Undo a selected edge; selection clears or moves to a valid node and the inspector never indexes an empty tunnel definition.

### B13 — Cutting or rerouting a swept link does not break the trace

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1617](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1617).

Cutting the targeted tunnel still causes a four-second blackout and 25-Cash penalty. Traversal follows stored node IDs without validating live adjacency. The advertised 'go quiet' action affects future charge, not active traversal.

**Action:** Validate the traced connection at every step and cancel or repath it.

**Acceptance:** Sever and reparent an actively swept edge; sweep traversal validates live adjacency and countermeasure help states what quieting can actually do.

### B14 — The advance warning already quarantines the target

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:1628](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1628).

During the six-second warning, the target's quarantine is continuously refreshed. The attack has already impaired the network while the banner says impact is still ahead.

**Action:** Apply quarantine on arrival, or label the opening phase as an immediate lockdown.

**Acceptance:** During the advertised warning period, no quarantine applies before impact unless the warning explicitly labels an immediate lockdown.

### B15 — 'Run linked structures' accepts disabled operations

**P2 · Rule mismatch · Rule decision unresolved · R+C+D · effort S**. Source: [main.gd:1686](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1686).

The contract counts connected non-Proxy nodes without checking their enabled state. OFF infrastructure can satisfy an active-operation objective.

**Action:** Define eligible operating structures and require them to be enabled.

**Acceptance:** OFF nodes cannot satisfy an objective phrased as running linked operations; define and display its exact eligibility policy.

### B16 — Reload inflates fractional Cash packets

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:2414](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2414).

Saving an in-flight packet valued at 0.5 and loading it restores value 1.0. The value field is omitted, then defaults to one on delivery.

**Action:** Serialize and restore packet value.

**Acceptance:** A fractional 0.5-Cash packet retains 0.5 after Save, in-place Load and fresh Continue and banks exactly once.

### B17 — Continuing erases the threat subsystem

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:2394](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2394).

Saves omit sweeps, sweep charge, Notoriety, blackout and quarantine timers. A fresh Continue resets them; in-place loading can instead retain unrelated current state.

**Action:** Persist the complete threat subsystem and restore it as one transaction.

**Acceptance:** Sweep route, phase, charge, Notoriety, blackout and quarantine resume identically in fresh and in-place load.

### B18 — Continuing removes a paid Overclock

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:2407](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2407).

The payment is saved, but boost_t is not. Saving during the 20-second boost loses the remaining benefit on Continue.

**Action:** Persist the remaining boost duration.

**Acceptance:** A paid boost resumes with its saved remaining duration; payment and benefit cannot diverge across reload.

### B19 — Continuing discards accepted and completed contracts

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:2394](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2394).

The save contains no board, deadlines, completed rewards, next contract ID, or generation cooldown. Accepted work and unclaimed rewards disappear.

**Action:** Persist the contract lifecycle and its generation state.

**Acceptance:** Offers, acceptance, completion, unclaimed rewards, deadlines and generation state survive fresh and in-place load without duplicate rewards.

### B20 — Continuing resets cumulative run statistics

**P2 · Defect · Open · R+C · effort S**. Source: [main.gd:2398](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2398).

The saved time is the animation clock. Active-play duration, delivered packets, peak Trace and peak Cash rate are absent, so a resumed run's result excludes earlier activity.

**Action:** Persist cumulative metrics and a captured victory result.

**Acceptance:** Run duration, delivered count, peak metrics and captured victory result preserve their accumulated values after Continue.

### B21 — Load accepts invalid game schemas

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:2425](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2425).

A JSON object such as {} passes the top-level check, installs an empty node set, and returns success. Simulation then accesses a nonexistent Hub; node types and packet indices are also unchecked.

**Action:** Validate version, resources, node graph and packet fields in temporary state before replacing the session.

**Acceptance:** Reject empty, malformed or unsupported save schemas before touching the active run; validate hub, graph, routes and numeric ranges.

### B22 — The only save is truncated before replacement is secure

**P1 · Defect · Open · C · effort M**. Source: [main.gd:2415](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2415).

Opening the save in WRITE mode destroys the previous contents before the new write completes. An interrupted write can lose the usable save; final write errors are not checked.

**Action:** Write a checked temporary file, replace safely, and retain a backup.

**Acceptance:** An interrupted or failed write preserves the last valid save; return success only after a checked durable write and safe replacement.

### B23 — Load restarts simulation randomness

**P2 · Defect · Open · R+C · effort S**. Source: [main.gd:2439](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2439).

Only the world seed is restored. Regenerating the city restarts the RNG stream instead of restoring packet-loss and contract randomness to the saved point.

**Action:** Persist simulation RNG state separately from the map seed.

**Acceptance:** The next simulation random draw after reload equals the uninterrupted run; persist RNG state without losing integer precision.

### B24 — In-place Load retains undo records from the discarded timeline

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:2425](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2425).

In-place Load retains discarded undo history: the fixture refunds 5 unpaid Cycles, changing 1000 to 1005. It also retains selection, pan and rate/preview state from the other timeline; reset those as one load transaction.

**Action:** Clear undo and transient action state on load, or restore history belonging to that save.

**Acceptance:** Loading a prior state clears its discarded undo history and transient selections, drag state, preview and rate sampling; undo cannot mint resources.

### B25 — Repeatable stockpile rewards bypass the production economy

**P1 · Rule mismatch · Rule decision unresolved · R+C+D · effort S**. Source: [main.gd:1730](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1730).

The starting 80 Cycles satisfy 20–50-Cycle jobs. A probe claimed 50 Cash and 5 RP while retaining all 80 Cycles; the same stock can qualify again. Stockpile milestones can be intentional, but repeatable payouts undermine the stated supply-chain gate.

**Action:** Use incremental production or deliveries, or make possession milestones one-time rewards.

**Acceptance:** Repeatable work cannot pay again for the same unchanged starting stock; define possession rewards as one-time milestones or pay for new deliveries.

### B26 — Coverage calculation, shape and advertised range disagree

**P2 · Defect · Open · R+C · effort S**. Source: [main.gd:1397](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1397).

Production counts a radius-four square while displaying a radius-four circle. Of 225 fixture centers, 164 differ under disk counting. Phishing/Scraper inspector separately advertises six tiles although productive coverage uses four.

**Action:** Use the same geometry and center for calculation and visualization.

**Acceptance:** Coverage calculation, displayed shape, center and range text agree; the current square-radius-four and circle/radius-six descriptions cannot coexist.

### B27 — The sidebar overflows the supported 720-pixel viewport

**P1 · Defect · Open · R+C · effort M**. Source: [ui.gd:152](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:152).

At 1280x720, Build status begins at y742 and Tech at y765. Stats also reaches about y750, with status at y756. Reserve a visible feedback region and allow every long tab to scroll.

**Action:** Allocate remaining height responsively and reserve a visible status region.

**Acceptance:** Every Build, Tech and Stats action and status remains reachable in the supported 720p viewport at all supported text scales.

### B28 — The Jobs board has no scrolling

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:203](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:203).

Three ordinary contract cards extend from y199 to y765; the last action lies below the viewport, without a scroll container.

**Action:** Make the board scroll within the available sidebar height.

**Acceptance:** Three or more job cards scroll within the available sidebar; the last claim/accept action remains reachable at 720p.

### B29 — 200% text size leaves most interface text unchanged

**P1 · Defect · Open · R+C · effort M**. Source: [ui.gd:576](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:576).

HUD/body/status stay 18/16/14 pixels and tabs stay 16 pixels. Fixed per-control overrides bypass the scaled theme default.

**Action:** Scale centralized font tokens and allow layouts to reflow.

**Acceptance:** At 200% all ordinary HUD, body, status, tab, button and graph text scales under shared tokens and layouts reflow.

### B30 — Selection prevents tab navigation

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:721](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:721).

Selecting C2 then choosing Menu leaves the inspector visible and Menu hidden. Arming a tool can likewise retain tunnel selection and suppress Build content; treat navigation and inspection as explicit states.

**Action:** Decouple navigation state from inspection, or explicitly close inspection when switching tabs.

**Acceptance:** Switching tabs while inspecting a node or tunnel reveals the chosen tab or explicitly closes the inspector.

### B31 — Tool help and introductory instructions are hidden

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:722](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:722).

Armed-tool, hover and C2 Console text are computed inside sel_box, but that parent is visible only when an object is selected.

**Action:** Show contextual help in a region visible in those states.

**Acceptance:** Introductory, armed-tool and hover/focus help is visible even with no selected map object.

### B32 — Action feedback is replaced by generic guidance

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:801](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:801).

'Game saved' is replaced by next-step guidance; tool hints can mask failures and rewards. Smokescreen also replaces its sweep-cancel outcome internally before the UI can show it.

**Action:** Give action results a dedicated timed message channel.

**Acceptance:** Save success, failed placement, rewards and other action results persist visibly before generic guidance resumes.

### B33 — Offline alerts omit completely unlinked structures

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:705](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:705).

Newly placed nodes and children detached by dismantling have parent == −1 and are skipped by the offline alert counter.

**Action:** Count all intended operations without a live C2 route, with a separate disabled category.

**Acceptance:** Unlinked new producers and newly detached branches appear in offline diagnostics; intentionally disabled nodes have their own state.

### B34 — Alert navigation leaves conflicting selections active

**P2 · Defect · Open · R+C · effort S**. Source: [ui.gd:662](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:662).

After selecting a tunnel, clicking a Trace or Starved alert selects C2 but retains the tunnel selection. The inspector continues showing the old tunnel; an armed tool can also retain priority.

**Action:** Clear conflicting selection/tool state before selecting the alert target.

**Acceptance:** An alert jump establishes one coherent selection and the inspector describes the jumped-to object.

### B35 — Settings block interaction while the simulation continues

**P1 · Defect · Open · R+C · effort M**. Source: [ui.gd:438](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:438).

Opening blocking Settings leaves paused=false. Current processing therefore continues production, contracts and threat clocks. The fresh fixture verifies pause state; it does not claim a full countdown playthrough.

**Action:** Suspend the simulation while this modal is open and restore the prior pause state.

**Acceptance:** Opening blocking Settings freezes gameplay while preserving the previous pause state; closing restores that state.

### B36 — Escape acts behind Settings

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:942](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:942).

Repeated Escape presses toggle simulation pause/resume while Settings remains visible, instead of dismissing the frontmost screen.

**Action:** Route Escape to the frontmost modal first.

**Acceptance:** Escape closes or backs out of the topmost Settings/modal state before changing hidden gameplay pause or tool state.

### B37 — Gameplay shortcuts pass through blocking modals

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:954](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:954).

E disables a selected node behind Settings; Delete, undo, overclock and output keys share the unguarded dispatcher. Continuous raw arrow-key polling also pans the camera behind the modal.

**Action:** Gate gameplay shortcuts by modal context; explicitly allow only intended planning actions.

**Acceptance:** Blocking modals prevent Delete, output, disable, overclock, undo and map action shortcuts from changing the background run.

### B38 — Modal keyboard focus remains on background controls

**P1 · Defect · Open · R+C · effort M**. Source: [ui.gd:438](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:438).

Focus a build button, open Settings, press Enter: the background build tool activates. The modal neither claims initial focus nor bounds navigation.

**Action:** Set initial focus, trap it within the modal, and restore it on close.

**Acceptance:** Opening a modal transfers focus inside and prevents focus or activation of background controls until closing.

### B39 — The pause menu blocks the advertised mouse planning flow

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:542](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:542).

The full-screen pause dimmer consumes mouse input, so current pause-to-plan code comments/design intent do not provide usable mouse planning. The review no longer treats this as a demonstrated on-screen promise.

**Action:** Separate a planning pause from the modal pause menu.

**Acceptance:** Expose a non-modal planning pause; mouse selection, construction and linking work while simulation remains frozen.

### B40 — The victory scorecard extends beyond the viewport

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:553](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:553).

At 1280×720, an unwrapped result label expands the panel to 899 pixels at x460; its right edge reaches x1359.

**Action:** Wrap result text and center a panel sized against the viewport.

**Acceptance:** The victory panel wraps and remains wholly within 1280x720, including all supported type scales and a long result string.

### B41 — Reduced Motion is ignored in the main menu

**P2 · Defect · Open · R+C · effort S**. Source: [menu.gd:68](C:/Users/steph/Documents/GitHub/rim/scripts/menu.gd:68).

With Reduced Motion enabled, menu._process(1) still advances its animation time and drifting packet positions use that time. This is a current state/source check, not a rendered motion-comfort study.

**Action:** Apply the setting across menu and gameplay animation.

**Acceptance:** Persisted Reduced Motion gates menu time-driven packet drift and decorative animation as well as gameplay.

### B42 — Placement validity keeps red/green-only previews

**P1 · Defect · Open · C · effort S**. Source: [main.gd:1895](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1895).

The footprint preview uses hardcoded green/red even under the colour-blind setting, without a local symbol identifying validity.

**Action:** Use semantic palette colours plus an OK/blocked symbol and readable reason.

**Acceptance:** Valid and invalid placement have redundant local symbols/reasons and use semantic palette colors rather than red/green alone.

### B43 — Decision-critical map colours ignore the colour-blind palette

**P2 · Defect · Open · C · effort M**. Source: [minimap.gd:46](C:/Users/steph/Documents/GitHub/rim/scripts/minimap.gd:46).

Districts and minimap markers use ZONE_COLOR/COLORS, while resource packets use Settings colours. Resource-to-ground matching becomes inconsistent.

**Action:** Apply one semantic palette to ground, markers and resource cues, reinforced with patterns.

**Acceptance:** Ground, build chips, map structures, minimap and resource packets use consistent resource semantics when the alternate palette changes.

### B44 — Palette changes leave cached interface colors stale

**P2 · Defect · Open · R+C · effort S**. Source: [ui.gd:234](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:234).

Alternate-palette toggle leaves legend label colors unchanged and unequal to Settings.res_color. GlyphIcon also lacks settings-driven redraw invalidation; the earlier claim that every glyph updates immediately is withdrawn.

**Action:** Refresh cached UI colour overrides when settings change.

**Acceptance:** Changing the palette refreshes legend label colors immediately, alongside glyphs and packets.

### B45 — Slow drags become unintended clicks

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:1009](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1009).

With the viewport pointer explicitly outside the sidebar, twenty movements of 2 pixels total 40 pixels but never set the drag flag. Slow release can therefore place/select or cancel after panning.

**Action:** Measure total displacement from press and use one shared drag threshold.

**Acceptance:** Twenty 2-pixel movements after one press count as a drag; release cannot place or cancel after the full 40-pixel displacement.

### B46 — Middle-mouse panning can remain latched after a UI release

**P1 · Defect · Open · R+C · effort S**. Source: [main.gd:990](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:990).

A Control-consumed middle-button release can leave _panning latched. In the state fixture, subsequent motion with button_mask=0 still moves the camera; the ordinary release path is source-verified.

**Action:** Capture release globally and reconcile pan state with the actual button state.

**Acceptance:** A middle-button release over a Control always clears panning; pointer movement afterward cannot move the camera without a held button.

### B47 — Critical warnings overlap the net-rate text

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:242](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:242).

Warning rectangle (300,42,359,24) overlaps rate rectangle (312,42,361,22). A separate large-stock stress fixture also pushes the unwrapped resource/goal HUD beyond the right edge; use one responsive HUD layout.

**Action:** Reserve separate responsive HUD regions for warnings, legend and rates.

**Acceptance:** Overload or ICE warnings occupy a reserved HUD region separate from economic rates and other text at 720p.

### B48 — Visible tower rooftops do not match selection targets

**P2 · Defect · Open · R+C · effort M**. Source: [main.gd:382](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:382).

Hit-testing the projected C2 roof-center tile returns no node: the roof is drawn above/right of the ground footprint but _node_at tests ground cells. The fixture derives the projected target and checks it; it is not a rendered mouse-click playtest.

**Action:** Hit-test the visible silhouette or expose a clear selectable ground marker.

**Acceptance:** Clicks on the visible tower silhouette select the intended structure, or the selectable ground target is clearly shown and consistently used.

### B49 — Loading a different seed leaves the previous minimap districts

**P2 · Defect · Open · R+C · effort S**. Source: [minimap.gd:56](C:/Users/steph/Documents/GitHub/rim/scripts/minimap.gd:56).

The minimap retains its baked texture after seed 42 to 43 regeneration. Load calls that regeneration without invalidating the cache. The fixture checks regeneration and texture retention; the full UI Load click path is source-verified.

**Action:** Invalidate map-dependent minimap caches after loading.

**Acceptance:** Loading a different seed rebuilds minimap district texture and state even if node count and camera happen to match.

### B50 — Converted Proxies retain their original minimap identity

**P2 · Defect · Open · C · effort S**. Source: [minimap.gd:64](C:/Users/steph/Documents/GitHub/rim/scripts/minimap.gd:64).

Rendering uses n.type instead of the relay flag, and the redraw signature tracks node count rather than conversion state.

**Action:** Use the effective node type and include state revisions in minimap invalidation.

**Acceptance:** A converted donor appears as a Proxy on the minimap immediately and after loading; effective identity participates in invalidation.

### B51 — Paused actions can leave the map visually stale

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1387](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1387).

On a stationary paused view, toggling a selected node changes its enabled state but draw count remains 2. Explicit queue_redraw raises it to 3. Redraw gating checks motion/view/tool activity, not state mutations.

**Action:** Introduce visual dirty revisions and invalidate on state, selection, settings and final-animation transitions.

**Acceptance:** Toggle, dismantle, undo and change settings while paused without moving the pointer; the map updates once, then returns to idle redraw behavior.

### B52 — Culling bounds omit visible routes and selected overlays

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1767](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1767).

In a constructed orthogonal-detour fixture, a path point is inside the viewport while merged endpoint footprints fail culling; the tunnel and its packets are skipped. A selected-node vision ring can also cross the viewport while its footprint is culled. These are geometric fixtures, not measured natural-route prevalence.

**Action:** Cache actual path bounds and include visible overlay bounds; retain cheap culling after verifying geometry.

**Acceptance:** A detour segment and its packets remain visible when endpoints are offscreen; selected coverage/vision rings remain visible wherever they intersect the exposed view.

### B53 — Restored armed sources permit replacement Undo to lose the old link

**P1 · Defect · Open · R+C · effort M**. Source: [main.gd:1304](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1304).

A legal remove-link, arm-source, Undo-restores-link sequence leaves the source armed. Completing a different target replaces the old edge; the next Undo clears the edge rather than restoring the original connection. Directly selecting an already linked source is normally rejected.

**Action:** Validate the pending source at commit and preserve complete before/after edge state for any permitted replacement.

**Acceptance:** Remove, arm, restore with Undo, then commit a target: reject the stale action safely or permit one atomic replacement whose Undo restores the exact old link.

### B54 — Boundary placement can exceed a district's producer limit

**P2 · Defect · Open · R+C · effort S**. Source: [main.gd:1208](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1208).

For a 2x2 Phishing footprint crossing adjacent Intel regions, placement checks the origin region while occupancy counts its center region. The fixture admits a producer into a full center region and remaining slots change from 0 to -1.

**Action:** Choose one authoritative owning district or require a single-district footprint and use it for both validation and accounting.

**Acceptance:** A boundary build cannot exceed any declared slot limit, and its preview identifies the same owning district used after placement.

### B55 — Lab and Forge rates are rounded to incorrect whole numbers

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:858](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:858).

Converter text uses %.0f/s, displaying both Lab's actual 0.5/s and Forge's actual 0.6/s as 1/s. Players plan supply against substantially overstated rates.

**Action:** Format fractional rates with adequate precision and derive all input/output/fuel values from CONV.

**Acceptance:** The inspector shows Lab 0.5 Research/s and Forge 0.6 Tools/s with their actual fuel and input requirements.

### B56 — Proxy inspection still describes the donor's production

**P2 · Defect · Open · R+C · effort S**. Source: [ui.gd:838](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:838).

Converted Phishing correctly has a Proxy title but retains the producer homage and 'Sweeps Intel within 6 tiles'. Its production has actually stopped.

**Action:** Use effective relay identity for description, range, color and operational controls; keep donor provenance separate.

**Acceptance:** A converted producer's inspector explains forwarding, vision and upkeep and does not claim donor production; reversal restores the donor description.

### B57 — Quarantine is misdiagnosed as a missing physical path

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:868](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:868).

A node with a valid parent pointing to C2 and 4.9 seconds of quarantine shows 'OFFLINE - no path to C2'. This suggests rebuilding an intact connection rather than waiting or repairing quarantine.

**Action:** Report the operational cause and remaining quarantine separately from physical connectivity.

**Acceptance:** Quarantine on an intact branch displays remaining time and affected nodes; an actually severed branch still reports its missing connection.

### B58 — Hot-Trace loss is attributed to distance

**P1 · Defect · Open · R+C · effort S**. Source: [ui.gd:831](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:831).

A two-cell DNS at hot Trace shows 22% distance loss. The formula has 3% distance loss and a separate 20% ICE multiplier, for 77.6% survival. Shortening the link cannot remove the full reported loss.

**Action:** Store loss components and display actionable advice for each active cause.

**Acceptance:** The fixture reports 3% distance and 20% Trace effects with 77.6% combined survival, rather than calling all loss distance.

### B59 — Sweep remaining-hop count includes the destination node

**P2 · Defect · Open · R+C · effort S**. Source: [ui.gd:697](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:697).

A sweep path [node,C2] at step 0 reports 2 hops although only one edge remains. The current count uses node count minus step.

**Action:** Count remaining transitions, and preferably display an estimated arrival time as well.

**Acceptance:** One-edge and multi-edge paths report path.size - step - 1 transitions and reach zero at C2.

### B60 — Crypto laundering shares the saturation it supposedly diversifies away from

**P2 · Rule mismatch · Rule decision unresolved · C+D · effort M**. Source: [main.gd:865](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:865).

All credits-producing converters use _market_price(), so a Mixer also produces only 0.5 Cash per Crypto at 1000 banked Cash. The code and older design explanation imply diversification avoids Intel saturation; it currently does not.

**Action:** Choose and document a distinct Mixer exchange policy or remove the unsupported economic claim; evaluate full-chain investment returns.

**Acceptance:** Mixer payouts at 0, 500 and 1000 Cash match the displayed chosen rule and the documented reason to invest in Crypto.

### B61 — The described global hot-Trace throttle compounds per hop

**P2 · Rule mismatch · Rule decision unresolved · C+D · effort M**. Source: [main.gd:1505](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1505).

The source applies x0.8 survival to each edge and tests admission at each hop. Ignoring other losses, four hops retain 0.8^4 = 40.96%, whereas the older description calls it a whole-network x0.8 throttle. The formula is analytical source evidence, not a sampled four-hop run.

**Action:** Choose route-wide or per-edge security loss explicitly and show the end-to-end consequence in route diagnostics.

**Acceptance:** One-hop and four-hop fixtures match the chosen global or per-hop rule, and backbones are balanced against that actual rule.

### B62 — Onion advice promises additional reach despite the same route limit

**P2 · Rule mismatch · Rule decision unresolved · C+D · effort S**. Source: [main.gd:1289](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1289).

Every protocol has a 255-cell route limit. A failed route hint recommends Onion for over-length routes, but Onion cannot extend that limit; it only has lower distance loss.

**Action:** Explain Onion's actual lower-loss niche or implement a deliberately distinct reach rule; separate length failures from geometry failures.

**Acceptance:** An over-length route succeeds under an explicitly longer Onion limit, or the failure text no longer recommends an equally limited protocol as its remedy.

## 100 improved suggestions: T01–T100

T01–T50 strengthen the previous suggestions without changing their IDs. T51–T100 add new scope. Each entry has a concrete action, acceptance criterion, source anchor and dependency. These are proposals, not claims of implemented or tested features. Some specify how to address an audited defect; their proposal count does not mean there are 100 additional missing systems.

### T01 — Add interface-density presets

**P2 · effort M · Interface**. Source: [ui.gd:89](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:89). Dependencies: B27 B29.

Offer compact, normal and readable interface density presets with separate spacing and type tokens.

**Acceptance:** Each preset keeps every action reachable at 1280x720 and 1920x1080, including 200% text.

### T02 — Let the sidebar resize and collapse

**P2 · effort M · Interface**. Source: [ui.gd:119](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:119). Dependencies: B27 B29 B30.

Make the sidebar resizable and collapsible with a persistent minimum width and a restore shortcut.

**Acceptance:** Resizing reallocates map space without clipping buttons; collapse and restore preserve the active tab and selection.

### T03 — Preview readability settings immediately

**P1 · effort S · Accessibility**. Source: [ui.gd:360](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:360). Dependencies: B29 B41 B43 B44.

Add a live settings preview containing HUD text, a district, packet shapes and a tunnel warning.

**Acceptance:** Changing palette, contrast, motion or type size updates the preview immediately and shows a readable example.

### T04 — Make actions remappable

**P2 · effort M · Controls**. Source: [main.gd:942](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:942). Dependencies: B36 B37 B38 B45 B46.

Replace hardcoded action keys with named input actions and a remapping screen that reports conflicts.

**Acceptance:** All gameplay actions can be rebound; duplicate bindings are explained and restored mappings survive restart.

### T05 — Finish keyboard construction and inspection

**P2 · effort L · Controls**. Source: [main.gd:975](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:975). Dependencies: B36 B37 B38 B45 B46.

Provide a keyboard placement cursor, target cycling, link-source selection and confirm/cancel actions.

**Acceptance:** A player can create and inspect a producer-to-C2 chain using only a keyboard, with visible focus and no modal leakage.

### T06 — Make controller navigation consistent

**P3 · effort L · Controls**. Source: [ui.gd:89](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:89). Dependencies: T04 T05.

Add a controller navigation map and a world targeting cursor after keyboard actions are complete.

**Acceptance:** A controller can complete the same opening without a mouse; switching input method preserves focus and selection.

### T07 — Expose camera interaction preferences

**P2 · effort S · Camera**. Source: [main.gd:1330](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1330). Dependencies: B37 B46.

Expose edge-pan enablement, pan sensitivity, drag buttons and optional inverted scroll as preferences.

**Acceptance:** Edge-pan can be disabled; each preference persists and works during ordinary play and pause planning.

### T08 — Zoom around the cursor or focused object

**P2 · effort M · Camera**. Source: [main.gd:1017](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1017). Dependencies: T07.

Anchor zoom to the cursor or keyboard-focused object rather than only the screen center.

**Acceptance:** Repeated zoom in and out keeps the anchor under the pointer to within a few screen pixels.

### T09 — Offer larger interaction targets

**P2 · effort M · Accessibility**. Source: [main.gd:681](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:681). Dependencies: B48.

Offer larger click targets for tunnels and small map markers, measured in screen pixels.

**Acceptance:** A fixed screen-space target size remains usable across zoom levels, and overlapping targets can be cycled.

### T10 — Separate motion controls

**P2 · effort M · Accessibility**. Source: [settings.gd:6](C:/Users/steph/Documents/GitHub/rim/scripts/settings.gd:6). Dependencies: B41.

Separate ambient motion, packet motion and urgent effects while keeping one master Reduced Motion switch.

**Acceptance:** The master setting stops decorative motion in every scene; urgent information remains visible as static text or symbols.

### T11 — Make resource identity redundant everywhere

**P1 · effort M · Accessibility**. Source: [settings.gd:13](C:/Users/steph/Documents/GitHub/rim/scripts/settings.gd:13). Dependencies: B42 B43 B44.

Use resource symbols or patterns on districts, producers, build chips, minimap and packets with one semantic palette.

**Acceptance:** A grayscale view still distinguishes all resources and valid placement; palette changes keep every resource cue consistent.

### T12 — Give existing controls accessible names and state

**P2 · effort M · Accessibility**. Source: [ui.gd:89](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:89). Dependencies: B38.

Give controls descriptive accessible names, announced states and a clear focus order; validate actual engine support.

**Acceptance:** Supported assistive navigation identifies selected tabs, toggles and actions; remaining platform limitations are documented from testing.

### T13 — Reflow the resource bar

**P1 · effort M · Interface**. Source: [ui.gd:210](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:210). Dependencies: B27 B29 B47.

Lay out resources, rates and warnings as separate responsive HUD regions with a compact fallback.

**Acceptance:** A hot Trace warning and all six resources remain legible at 720p and 200% text with no overlap.

### T14 — Explain resource stocks in tooltips

**P2 · effort S · Information**. Source: [ui.gd:680](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:680). Dependencies: B31.

Add stock tooltips showing production, consumption, reserved amounts and what each resource unlocks.

**Acceptance:** Hover or focus explains why a balance changes and identifies at least one current use of that resource.

### T15 — Use a consistent operational-state vocabulary

**P1 · effort M · Information**. Source: [main.gd:1415](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1415). Dependencies: B05 B57.

Use one operational vocabulary: producing, forwarding, disabled, unlinked, quarantined, input-starved and overloaded.

**Acceptance:** The inspector, map and alerts report the same state for fixtures covering each condition and combinations.

### T16 — Provide a compact summary with expandable details

**P2 · effort S · Interface**. Source: [ui.gd:809](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:809). Dependencies: B29 B30 B55 B56 B57.

Keep the inspector summary short and put formulas, flavor and route detail in expandable sections.

**Acceptance:** The default inspector exposes output, operating state and actions without scrolling at 720p; detail remains accessible.

### T17 — Queue important action messages

**P1 · effort S · Feedback**. Source: [ui.gd:797](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:797). Dependencies: B32.

Use a timed message queue with severity and an optional history instead of overwriting action results with guidance.

**Acceptance:** Save success, failed placement and a claimed reward each remain visible long enough to read and can be reviewed later.

### T18 — Sort problems by practical impact

**P2 · effort M · Diagnostics**. Source: [ui.gd:708](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:708). Dependencies: B33 B58.

Rank alerts by estimated lost output or blocked progress, with the most severe recovery issue first.

**Acceptance:** A severed Cycles trunk outranks a harmless idle branch, and the displayed reason explains the ranking.

### T19 — Cycle through all affected objects

**P2 · effort S · Diagnostics**. Source: [ui.gd:662](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:662). Dependencies: B34.

Make repeated alert clicks cycle through every affected node and show its index in the group.

**Acceptance:** An alert affecting three nodes visits all three without conflicting selections and returns to the first on the fourth click.

### T20 — Make help available through focus as well as hover

**P2 · effort S · Accessibility**. Source: [ui.gd:589](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:589). Dependencies: B31 B38.

Show the same contextual help on keyboard focus, hover and an explicit help action.

**Acceptance:** Focused build and research entries expose the same cost, purpose and restrictions as pointer hover.

### T21 — Teach the Cycles safety margin first

**P1 · effort M · Onboarding**. Source: [main.gd:1110](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1110). Dependencies: B01 B05.

Teach a sustainable Cycles route before selling Intel, and explain the reserve needed for recovery.

**Acceptance:** The opening guide checks a live path and net Cycles supply rather than merely checking that a producer exists.

### T22 — Explain the job each unlock solves

**P2 · effort S · Research**. Source: [main.gd:40](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:40). Dependencies: B55 B61 B62.

Explain the practical problem solved by each unlock, with a before/after throughput or resource example.

**Acceptance:** Every technology states its operating cost, new capability and a situation where it improves the current network.

### T23 — Separate operation rates from transactions

**P1 · effort M · Economy**. Source: [main.gd:1361](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1361). Dependencies: B20.

Separate operating income and consumption from purchases, refunds, contract payouts and blackout penalties in rate telemetry.

**Acceptance:** Buying or undoing a structure never changes the displayed operating production rate or inflates the peak-income record.

### T24 — Show travel time in seconds

**P2 · effort S · Information**. Source: [main.gd:769](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:769). Dependencies: B05 B07.

Report end-to-end travel time in seconds and show starvation-adjusted ETA separately from packet count.

**Acceptance:** A known-length multi-hop route's displayed time agrees with a timed engine fixture under normal and starved operation.

### T25 — Preview the complete running commitment

**P1 · effort M · Construction**. Source: [main.gd:909](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:909). Dependencies: B02 B03 B04 B09 B26.

Preview total deployment cost, ICE cost, incremental tunnel upkeep and forecast net Cycles balance before confirming.

**Acceptance:** The preview includes every cost actually deducted and warns if the completed plan lacks a recovery reserve.

### T26 — Display effective capacity

**P1 · effort M · Diagnostics**. Source: [main.gd:1486](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1486). Dependencies: B03 B04.

Display effective edge capacity after node limits, incoming-link penalties and Proxy bonuses alongside the protocol rating.

**Acceptance:** A many-input producer and a Proxy trunk show their actual limiting capacity, matching simulation admission rules.

### T27 — Separate causes of packet loss

**P1 · effort M · Diagnostics**. Source: [main.gd:1497](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1497). Dependencies: B03 B04 B58 B61.

Split distance loss, overload drops and hot-Trace loss into separate counters and explanations.

**Acceptance:** A short under-capacity link at high Trace is labelled with the Trace penalty, and predicted losses reconcile with measurements.

### T28 — Upgrade tunnels as an atomic operation

**P2 · effort M · Construction**. Source: [main.gd:1265](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1265). Dependencies: B07 B12 B53.

Support atomic protocol upgrades with a preview of incremental cost, capacity, noise and packet handling.

**Acceptance:** An upgrade preserves endpoints and path; failure changes nothing, and undo restores the original protocol and paid balance.

### T29 — Replace a parent with a reviewed reroute

**P1 · effort M · Construction**. Source: [main.gd:1265](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1265). Dependencies: B07 B13 B53.

Preview reroutes before committing, including orphaned branches, packet policy and active sweep effects.

**Acceptance:** Cancel leaves the network intact; commit changes one complete edge transaction and undo restores the old edge.

### T30 — Make routing quality predictable

**P2 · effort M · Routing**. Source: [main.gd:496](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:496). Dependencies: B09 B10 B54.

Make route choice deterministic and explain failures such as blocked road, occupied lane or unreachable endpoint.

**Acceptance:** Repeated previews of unchanged geometry choose the same path, and a failed connection gives a specific actionable cause.

### T31 — Preview Proxy conversion consequences

**P2 · effort S · Construction**. Source: [main.gd:1248](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1248). Dependencies: B05 B50 B56.

Preview Proxy conversion as a trade: lost production, added vision, upkeep change and aggregation benefit.

**Acceptance:** The preview names the donor's lost output and the resulting effective trunk capacity before payment.

### T32 — Cache authoritative spatial and network revisions

**P1 · effort M · Performance**. Source: [main.gd:1387](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1387). Dependencies: B11 B12 B49 B50 B51 B52.

Use explicit world, topology, settings and visual revisions to invalidate geometry, minimap, visibility and redraw caches.

**Acceptance:** Changes while paused and same-count load replacements refresh every dependent view; idle frames still avoid unnecessary work.

### T33 — Prioritize scarce converter inputs

**P2 · effort M · Automation**. Source: [main.gd:1525](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1525). Dependencies: B04 B19.

Add converter input priorities and reserves so Labs, Forges and Markets compete according to player intent.

**Acceptance:** With insufficient Intel, a chosen Forge reserve is honored regardless of node iteration order; all allocations are visible.

### T34 — Show exact converter rates and fuel demand

**P1 · effort S · Information**. Source: [main.gd:32](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:32). Dependencies: B55.

Generate processor descriptions from recipe data, including input, output, fuel and gross/actual rates.

**Acceptance:** Forge shows 0.6 Tools/s and 1.8 Cycles/s at full operation; Lab and Mixer descriptions also match CONV.

### T35 — Limit repeated exploitation of identical targets

**P2 · effort L · Economy**. Source: [main.gd:1397](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1397). Dependencies: B10 B26.

Experiment with shared local extraction capacity or diminishing overlap so identical nearby producers do not multiply the same targets indefinitely.

**Acceptance:** Two producers sharing a target set show the shared yield; spaced or upgraded alternatives remain worthwhile across sparse and dense starts.

### T36 — Reward relevant district targets

**P2 · effort M · Districts**. Source: [main.gd:148](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:148). Dependencies: B08 B54.

Give district specializations small, explicit output or recipe bonuses instead of relying only on a common resource color.

**Acceptance:** A player can predict why a Registry Package differs from a Farm Package, with clear baseline and bonus values.

### T37 — Give every protocol an explicit niche

**P2 · effort M · Balance**. Source: [main.gd:58](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:58). Dependencies: B03 B04 B61 B62.

Tune protocols against effective node capacity, distance, upkeep and threat so each has a distinct use.

**Acceptance:** A comparison over short, long and aggregated routes yields a viable niche for every protocol, including research-gated HTTP/2 Flood and Onion Route.

### T38 — Tie Intel saturation to sales activity

**P2 · effort M · Economy**. Source: [main.gd:1105](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1105). Dependencies: B16 B23 B25.

Test Intel prices based on recent sold volume or district demand instead of the current spendable Cash balance.

**Acceptance:** Spending Cash does not instantly reset demand; price history and recovery are visible, and contracts use the same pricing policy.

### T39 — Price Crypto against its investment

**P2 · effort M · Economy**. Source: [main.gd:35](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:35). Dependencies: B03 B04 B16 B60.

Price the Crypto chain against its research, capital, protected access and round-trip losses, with a distinct laundering market.

**Acceptance:** Matched-investment fixtures show when Crypto is preferable to Intel; their price curves and payback assumptions are explicit.

### T40 — Protect a recoverable starting budget

**P1 · effort M · Recovery**. Source: [main.gd:1313](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1313). Dependencies: B01.

Protect a bootstrap path through limited salvage, an emergency rebuild action or a ring-fenced construction reserve.

**Acceptance:** The three-Market/one-DNS zero-resource save can recover into real Cycles production without starting a new game or using contracts.

### T41 — Shape research around consequential choices

**P2 · effort L · Research**. Source: [main.gd:40](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:40). Dependencies: B19 B25.

Introduce research branches that require operating a new capability and provide alternative strategic routes.

**Acceptance:** Each tier changes a production problem; no branch is mandatory solely to lengthen play, and every purchased unlock has a useful operating period.

### T42 — Generate reachable jobs and let players decline

**P1 · effort M · Contracts**. Source: [main.gd:1659](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1659). Dependencies: B19 B25.

Generate jobs from reachable capabilities and let players decline unsuitable offers without permanently blocking the board.

**Acceptance:** A board containing three inaccessible jobs can recover; offers disclose any capability or location requirement before acceptance.

### T43 — Balance payouts against delivered economic value

**P1 · effort M · Contracts**. Source: [main.gd:1686](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1686). Dependencies: B15 B19 B25.

Pay recurring contracts for new deliveries or sustained service; reserve possession rewards for one-time milestones.

**Acceptance:** The same unchanged 80-Cycle stock cannot repeatedly earn rewards; recorded job income corresponds to additional completed work.

### T44 — Clarify deadlines before accepting

**P2 · effort S · Contracts**. Source: [ui.gd:602](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:602). Dependencies: B19 B35.

Show the full deadline before acceptance, distinguish offer expiry from active time, and explain pause behavior.

**Acceptance:** A player knows when a timer starts and what failure costs; pause, save and reload preserve the displayed remaining time.

### T45 — Show the effect of each countermeasure

**P1 · effort M · Threat**. Source: [main.gd:1608](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1608). Dependencies: B13 B14 B17 B59.

Preview each countermeasure's effect on the active sweep and future launch charge before spending resources.

**Acceptance:** DDoS, rerouting, severing and quiet protocols show only effects the simulation actually implements, with remaining impact time.

### T46 — Target useful and noisy branches

**P2 · effort M · Threat**. Source: [main.gd:1589](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1589). Dependencies: B05 B13 B17.

Choose sweep targets from reachable, active and exposed branches, weighted by activity or noise rather than equal random choice.

**Acceptance:** Empty or disabled branches do not distract threats indefinitely; a quiet low-value branch is less likely to be selected than an exposed trunk.

### T47 — Create recovery intervals

**P2 · effort M · Threat**. Source: [main.gd:1608](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1608). Dependencies: B17 T45.

Guarantee a visible recovery interval after an attack and avoid scheduling unavoidable repeated blackouts.

**Acceptance:** A recovering bootstrap network has time to restore supply before another sweep; cooldown rules remain visible and persist across reload.

### T48 — Capture the earned victory result

**P2 · effort M · Victory**. Source: [main.gd:1741](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1741). Dependencies: B20 T23.

Capture a permanent victory result at the winning tick, with active time, delivered value, reinvestment and threat recoveries.

**Acceptance:** Keep Playing cannot change the earned victory result; save/load preserves it and transaction spikes do not count as production records.

### T49 — Expose the existing seed system

**P2 · effort S · Replay**. Source: [menu.gd:55](C:/Users/steph/Documents/GitHub/rim/scripts/menu.gd:55). Dependencies: B23 T95.

Expose seed entry, copy and paste in New Game and Stats while retaining random generation as the default.

**Acceptance:** The same seed and rules produce the same city; invalid input is handled clearly and seed sharing includes the rules version.

### T50 — Measure sessions and accessibility with players

**P1 · effort M · Validation**. Source: [PACING_REVIEW.md:1](C:/Users/steph/Documents/GitHub/rim/review/PACING_REVIEW.md:1). Dependencies: B01 B03 B04 B16 B17 B19.

Run formative playtests across dense and sparse starts with new and experienced players, including accessibility settings.

**Acceptance:** Capture first stable supply, first sale, blocked actions, idle time and stage completion; use observations to choose balance targets.

### T51 — Build a guided operation on a curated city with live checks for production, linking, selling, shortages and recovery

**P1 · effort M · Onboarding**. Source: [main.gd:1110](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1110). Dependencies: T21 B27 B30 B31 B32.

Build a guided operation on a curated city with live checks for production, linking, selling, shortages and recovery.

**Acceptance:** The tutorial completes from legal actions, recognizes alternate valid layouts and can be replayed or skipped without changing Standard saves.

### T52 — Add a Sandbox rules preset with configurable starting resources, research and threat pressure

**P2 · effort M · Modes**. Source: [session.gd:5](C:/Users/steph/Documents/GitHub/rim/scripts/session.gd:5). Dependencies: B17 B19 B21.

Add a Sandbox rules preset with configurable starting resources, research and threat pressure.

**Acceptance:** Changing Sandbox options affects a new session; sandbox results are identified and cannot overwrite Standard records accidentally.

### T53 — Create a small set of fixed-seed challenge scenarios using the same simulation and explicit objective rules

**P3 · effort M · Modes**. Source: [main.gd:1567](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1567). Dependencies: T48 T52.

Create a small set of fixed-seed challenge scenarios using the same simulation and explicit objective rules.

**Acceptance:** At least one quiet extraction, one constrained supply and one Crypto scenario validate different strategies and show their rules before start.

### T54 — Prototype a final Spire extraction requiring delivered supplies and a sustained route after several capability milestones

**P2 · effort L · Progression**. Source: [main.gd:1567](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1567). Dependencies: T41 T43 T58.

Prototype a final Spire extraction requiring delivered supplies and a sustained route after several capability milestones.

**Acceptance:** A run must solve more than accumulating Cash; the final mission has clear success, failure and recovery rules, with alternate viable approaches.

### T55 — Use client or C2 operation ranks that demand new capabilities and unlock choices as the network grows

**P2 · effort L · Progression**. Source: [main.gd:1110](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1110). Dependencies: T40 T41 T54.

Use client or C2 operation ranks that demand new capabilities and unlock choices as the network grows.

**Acceptance:** Each rank introduces one understandable operating requirement and payoff; shortages pause advancement without destroying the run.

### T56 — Add recurring client service requests with simultaneous supply and reliability requirements

**P3 · effort L · Economy**. Source: [main.gd:1659](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1659). Dependencies: T33 T43 T58 T85.

Add recurring client service requests with simultaneous supply and reliability requirements.

**Acceptance:** Meeting one client can create a visible allocation choice for another; pausing and saving preserve service windows and partial progress.

### T57 — Pilot one two-input recipe, such as Intel plus Tools into an extraction kit, before expanding the resource roster

**P3 · effort L · Production**. Source: [main.gd:32](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:32). Dependencies: T33 T58.

Pilot one two-input recipe, such as Intel plus Tools into an extraction kit, before expanding the resource roster.

**Acceptance:** Both inputs are actually reserved and consumed; partial supply cannot duplicate output, and the new product has a useful demand sink.

### T58 — Introduce small converter input/output buffers that store delivered goods and expose blocked or starved state

**P2 · effort L · Automation**. Source: [main.gd:1525](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1525). Dependencies: B04 B07 B17 B19 B21.

Introduce small converter input/output buffers that store delivered goods and expose blocked or starved state.

**Acceptance:** Fuel is consumed at the defined processing step; delivered input remains recoverable after a pause or failed output route.

### T59 — Give the seven existing clients recognizable job preferences such as quiet extraction, bulk delivery or research service, shown before acceptance

**P2 · effort M · Contracts**. Source: [main.gd:70](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:70). Dependencies: T42 T43.

Give the seven existing clients recognizable job preferences such as quiet extraction, bulk delivery or research service, shown before acceptance.

**Acceptance:** In a seeded sample, each client consistently offers its disclosed request/reward/risk style; a client never adds an unannounced penalty or eligibility rule.

### T60 — Experiment with finite packet queues and backpressure after settling the capacity rule

**P3 · effort L · Automation**. Source: [main.gd:1480](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1480). Dependencies: B03 B04 B07 B21.

Experiment with finite packet queues and backpressure after settling the capacity rule.

**Acceptance:** A full edge slows upstream dispatch instead of exceeding capacity; queue length and waiting time are visible and saved consistently.

### T61 — Add a network overview listing per-node input, output, fuel, queue, loss and limiting edge, sortable by blocked value

**P2 · effort M · Diagnostics**. Source: [main.gd:1507](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1507). Dependencies: T23 T26 T27 T34.

Add a network overview listing per-node input, output, fuel, queue, loss and limiting edge, sortable by blocked value.

**Acceptance:** Selecting a row focuses the corresponding node; totals reconcile with resource balances over a measured interval.

### T62 — Offer compatible producer upgrades in place, such as Phishing to Scraper, with a paid difference and a production preview

**P2 · effort M · Construction**. Source: [main.gd:1225](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1225). Dependencies: T28 B07 B53.

Offer compatible producer upgrades in place, such as Phishing to Scraper, with a paid difference and a production preview.

**Acceptance:** The upgraded node keeps identity, valid links and packet policy; undo restores the donor and exact payment without duplicating output.

### T63 — Add simple production conditions such as stop below a Cycles reserve or above an output-stock threshold

**P3 · effort M · Automation**. Source: [main.gd:1415](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1415). Dependencies: T15 T23.

Add simple production conditions such as stop below a Cycles reserve or above an output-stock threshold.

**Acceptance:** Hysteresis prevents rapid toggling; the active condition and reason for stopping are visible and reload restores the rule.

### T64 — Support blueprints for a selected cluster with relative positions, link topology and a complete cost preview

**P3 · effort L · Construction**. Source: [main.gd:1225](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1225). Dependencies: B09 B10 B11 B12 B53 B54.

Support blueprints for a selected cluster with relative positions, link topology and a complete cost preview.

**Acceptance:** Invalid placement identifies each conflicting footprint; successful placement is one undoable transaction with no partial hidden charges.

### T65 — Let players copy and paste production caps, converter priority and tunnel configuration between compatible nodes

**P2 · effort M · Construction**. Source: [main.gd:2349](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2349). Dependencies: T33.

Let players copy and paste production caps, converter priority and tunnel configuration between compatible nodes.

**Acceptance:** Paste names exactly which settings change, preserves geometry and resource ownership, and can be undone.

### T66 — Add group selection for bulk disable, output caps and inspection of combined upkeep

**P2 · effort M · Construction**. Source: [main.gd:2342](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2342). Dependencies: B05 B12.

Add group selection for bulk disable, output caps and inspection of combined upkeep.

**Acceptance:** A bulk action excludes C2 and incompatible nodes, reports affected count, and uses the same operating rules as individual actions.

### T67 — Prototype delivered deployment supplies for advanced installations while keeping early construction immediate

**P3 · effort L · Construction**. Source: [main.gd:1225](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1225). Dependencies: T58 T64.

Prototype delivered deployment supplies for advanced installations while keeping early construction immediate.

**Acceptance:** The ghost remains inspectable during delivery; cancellation returns only recoverable material, and blocked construction has a clear remedy.

### T68 — Add a small set of mutually exclusive efficiency, throughput and stealth modules with operating tradeoffs

**P3 · effort L · Customization**. Source: [main.gd:1415](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1415). Dependencies: T26 T37 T41.

Add a small set of mutually exclusive efficiency, throughput and stealth modules with operating tradeoffs.

**Acceptance:** Every module states its costs and effect; matched-network tests show a distinct use for each without one dominating all routes.

### T69 — Offer quiet and loud district scans with distinct costs, revealed information and threat consequences

**P3 · effort M · Exploration**. Source: [main.gd:705](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:705). Dependencies: B02 B17 T73.

Offer quiet and loud district scans with distinct costs, revealed information and threat consequences.

**Acceptance:** A scan shows what will be revealed and why; loud scans affect pressure under a stated rule and all scan state persists.

### T70 — Expose a district inspector with slots, ICE, useful targets, coverage and reachable approach routes

**P2 · effort M · Districts**. Source: [main.gd:1208](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1208). Dependencies: B08 B10 B26 B54.

Expose a district inspector with slots, ICE, useful targets, coverage and reachable approach routes.

**Acceptance:** Clicking or focusing a district explains its limits before spending Tools and identifies a viable next expansion action.

### T71 — Add district operation objectives that reward actual sustained activity there, rather than construction counts alone

**P3 · effort M · Districts**. Source: [main.gd:1686](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1686). Dependencies: T43 T70.

Add district operation objectives that reward actual sustained activity there, rather than construction counts alone.

**Acceptance:** A district reward requires delivered production or service from that district; inactive or converted donor nodes cannot satisfy it.

### T72 — Prototype one rival operator that competes for optional city opportunities and telegraphs its next move

**P3 · effort L · Simulation**. Source: [main.gd:300](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:300). Dependencies: T40 T70.

Prototype one rival operator that competes for optional city opportunities and telegraphs its next move.

**Acceptance:** The rival creates a reversible choice about expansion or defense; losing a target never eliminates the bootstrap recovery path.

### T73 — Localize threat exposure by district so geography and loud routes influence where sweeps originate

**P3 · effort L · Threat**. Source: [main.gd:1545](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1545). Dependencies: B13 B17 T46.

Localize threat exposure by district so geography and loud routes influence where sweeps originate.

**Acceptance:** The map shows district heat and launch causes; equally productive quiet and loud layouts have different visible exposure.

### T74 — Offer explicit Proxy reversal after undo history expires, with the donor's restored production and upkeep shown before commitment

**P2 · effort M · Recovery**. Source: [main.gd:1248](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1248). Dependencies: B50 B56 T31.

Offer explicit Proxy reversal after undo history expires, with the donor's restored production and upkeep shown before commitment.

**Acceptance:** A converted producer can return to its original role after Continue; links stay valid and reversible cost rules cannot mint resources.

### T75 — Offer a paid quarantine remediation action with a displayed time reduction and opportunity cost

**P2 · effort M · Recovery**. Source: [main.gd:1438](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1438). Dependencies: B17 B57 T15.

Offer a paid quarantine remediation action with a displayed time reduction and opportunity cost.

**Acceptance:** Repairing a selected node changes its actual remaining quarantine, and unavailable resources cannot trigger or partially pay the action.

### T76 — Add return-to-C2, fit-network and a few saved camera bookmarks, with bounded minimap drag input

**P2 · effort S · Camera**. Source: [minimap.gd:24](C:/Users/steph/Documents/GitHub/rim/scripts/minimap.gd:24). Dependencies: B37 B46.

Add return-to-C2, fit-network and a few saved camera bookmarks, with bounded minimap drag input.

**Acceptance:** One action recovers a useful view after panning beyond any map edge; saved bookmarks restore both position and zoom.

### T77 — Add brief handler messages at real capability milestones and recovery events

**P2 · effort S · Narrative**. Source: [main.gd:1110](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1110). Dependencies: B31 B32 T21.

Add brief handler messages at real capability milestones and recovery events.

**Acceptance:** Messages are tied to accomplished actions, do not block play, can be reread and never describe an unimplemented mechanic.

### T78 — Add restrained sounds for build, link, sale, resource delivery and critical operational events

**P2 · effort M · Audio**. Source: [main.gd:859](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:859). Dependencies: T15 T17 T79.

Add restrained sounds for build, link, sale, resource delivery and critical operational events.

**Acceptance:** Each sound communicates an action or state; dense traffic is rate-limited and silence remains available without losing visual information.

### T79 — Expose master, UI, alerts, effects and music controls with persistent mute settings

**P2 · effort S · Audio**. Source: [settings.gd:39](C:/Users/steph/Documents/GitHub/rim/scripts/settings.gd:39). Dependencies: Audio bus setup.

Expose master, UI, alerts, effects and music controls with persistent mute settings.

**Acceptance:** Every sound respects its bus and master mute; changing a slider previews a representative sound without resuming paused gameplay.

### T80 — Expose accessibility Settings on the main menu before the first run, with a live example and initial keyboard focus

**P1 · effort S · Accessibility**. Source: [menu.gd:34](C:/Users/steph/Documents/GitHub/rim/scripts/menu.gd:34). Dependencies: B29 B41 B43 B44.

Expose accessibility Settings on the main menu before the first run, with a live example and initial keyboard focus.

**Acceptance:** A player can enable large text and Reduced Motion before New Game; the menu and next scene reflect the persisted choice immediately.

### T81 — Add a small resource counter pulse, route-power effect and distinct victory effect through the shared motion settings

**P2 · effort M · Feedback**. Source: [main.gd:1441](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1441). Dependencies: B51 T10.

Add a small resource counter pulse, route-power effect and distinct victory effect through the shared motion settings.

**Acceptance:** Repeated deliveries are coalesced, Reduced Motion uses a static cue, and effects never conceal prices or warnings.

### T82 — Extend the existing pause with 1x, 2x and 3x controls by applying one simulation-time multiplier to every gameplay system

**P2 · effort M · Pacing**. Source: [main.gd:1330](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1330). Dependencies: B17 B19 T23.

Extend the existing pause with 1x, 2x and 3x controls by applying one simulation-time multiplier to every gameplay system.

**Acceptance:** At each speed, resources, packets, contracts, boosts and threats advance consistently; paused planning remains available.

### T83 — Offer optional auto-pause on new sweeps, major disconnection or starvation, with an explanation and quick resume

**P2 · effort S · Accessibility**. Source: [ui.gd:708](C:/Users/steph/Documents/GitHub/rim/scripts/ui.gd:708). Dependencies: B33 B35 B36 T15 T45.

Offer optional auto-pause on new sweeps, major disconnection or starvation, with an explanation and quick resume.

**Acceptance:** Only new incidents pause the session, repeated conditions do not retrigger endlessly, and players can choose which events qualify.

### T84 — Show separate Cash and RP sources: Intel sales, Crypto laundering, contracts and penalties over a chosen interval

**P2 · effort M · Economy**. Source: [main.gd:1730](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1730). Dependencies: T23 T43.

Show separate Cash and RP sources: Intel sales, Crypto laundering, contracts and penalties over a chosen interval.

**Acceptance:** The breakdown sums to net change after spending and refunds; it reveals whether rewards bypass the intended production chain.

### T85 — Extend the Cash sparkline to production, consumption, stock and threat histories with explicit time axes

**P2 · effort M · Diagnostics**. Source: [graph.gd:13](C:/Users/steph/Documents/GitHub/rim/scripts/graph.gd:13). Dependencies: B20 T23 T32.

Extend the Cash sparkline to production, consumption, stock and threat histories with explicit time axes.

**Acceptance:** Samples use active simulation time, pause creates no fake production and each graph preserves its meaning after speed changes and reload.

### T86 — Show an estimated investment payback for advanced structures using current delivered output and operating costs

**P2 · effort M · Balance**. Source: [main.gd:73](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:73). Dependencies: B03 B04 B16 B60 T23 T26 T27.

Show an estimated investment payback for advanced structures using current delivered output and operating costs.

**Acceptance:** The estimate lists assumptions, distinguishes gross output from net income and flags upgrades that cannot repay during the remaining scenario.

### T87 — Keep a local run archive with captured results, seed, rules and strategy-relevant metrics

**P2 · effort M · Replay**. Source: [main.gd:1741](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1741). Dependencies: B20 T48.

Keep a local run archive with captured results, seed, rules and strategy-relevant metrics.

**Acceptance:** Finishing a second run preserves the first result; comparing records distinguishes Standard, Sandbox and challenge rules.

### T88 — Record seed, rules and ordered player commands at simulation ticks to reproduce complete runs and reported failures

**P2 · effort M · Validation**. Source: [main.gd:975](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:975). Dependencies: B23 T99 T100.

Record seed, rules and ordered player commands at simulation ticks to reproduce complete runs and reported failures.

**Acceptance:** Replaying an opening, reroute, defense and undo sequence twice produces identical state digests at recorded checkpoints on the same rules version.

### T89 — Offer city archetypes such as sparse, finance-heavy and fortified by varying existing district generation weights

**P3 · effort M · Replay**. Source: [main.gd:300](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:300). Dependencies: B01 B08 B10 B54 T92.

Offer city archetypes such as sparse, finance-heavy and fortified by varying existing district generation weights.

**Acceptance:** Each archetype changes a real opening decision; automated seed sweeps verify legal recoverable starts for all presets.

### T90 — Renew Overclock with a displayed top-up price or explicitly purchased additional duration, instead of charging a full boost to overwrite remaining time

**P2 · effort S · Commands**. Source: [main.gd:2360](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2360). Dependencies: B18 T23 T25.

Renew Overclock with a displayed top-up price or explicitly purchased additional duration, instead of charging a full boost to overwrite remaining time.

**Acceptance:** Renewing with 17 seconds remaining grants exactly the priced additional time; OFF or disconnected targets disclose whether the boost can provide useful production.

### T91 — Move player text into translation keys and a consistent glossary, then check layout with expanded pseudo-translations

**P2 · effort M · Information**. Source: [main.gd:917](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:917). Dependencies: B27 B29 B31 B55.

Move player text into translation keys and a consistent glossary, then check layout with expanded pseudo-translations.

**Acceptance:** A 30% text-expansion pass retains every action, and default text consistently says Cycles, Intel, Cash and Research rather than legacy names.

### T92 — Run declarative legal opening and growth scenarios through the real simulator across a fixed set of city seeds

**P1 · effort M · Balance**. Source: [main.gd:1435](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1435). Dependencies: B01 B02 B03 B04 B10 B54.

Run declarative legal opening and growth scenarios through the real simulator across a fixed set of city seeds.

**Acceptance:** A batch of at least 100 seeds exports first stable supply, first sale, useful research, stuck runs and objective time; every action obeys ordinary validators and payment.

### T93 — Add an in-game reference for resources, recipes, protocols, district rules and threat stages generated from authoritative data

**P2 · effort M · Information**. Source: [main.gd:114](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:114). Dependencies: B08 B26 B55 B56 B58 B60 B61 B62.

Add an in-game reference for resources, recipes, protocols, district rules and threat stages generated from authoritative data.

**Acceptance:** Reference values match previews and simulation; the player can open the relevant entry directly from an inspector or failed action.

### T94 — Add validated settings defaults, reset by category and a readable recovery path for unusable text or input settings

**P2 · effort S · Settings**. Source: [settings.gd:47](C:/Users/steph/Documents/GitHub/rim/scripts/settings.gd:47). Dependencies: B29 B41.

Add validated settings defaults, reset by category and a readable recovery path for unusable text or input settings.

**Acceptance:** Malformed values fall back safely; reset remains reachable when fonts or controls are changed to an inconvenient configuration.

### T95 — Add named save slots, a verified last-good backup and a lightweight preview of seed, time and progression

**P1 · effort M · Persistence**. Source: [main.gd:2394](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2394). Dependencies: B16 B17 B18 B19 B20 B21 B22 B23 B24.

Add named save slots, a verified last-good backup and a lightweight preview of seed, time and progression.

**Acceptance:** Corrupting the latest slot does not destroy its previous valid backup; Continue selects a validated save and explains recovery.

### T96 — Add rotating autosaves at safe milestones with an explicit interval and status indicator

**P2 · effort M · Persistence**. Source: [main.gd:2394](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2394). Dependencies: T95.

Add rotating autosaves at safe milestones with an explicit interval and status indicator.

**Acceptance:** Autosaves preserve complete simulation state, never replace a named manual slot unexpectedly and recover after an interrupted write.

### T97 — Benchmark fixed small and large networks before and after optimizations, measuring simulation and drawing separately

**P1 · effort M · Performance**. Source: [main.gd:1383](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1383). Dependencies: B51 B52.

Benchmark fixed small and large networks before and after optimizations, measuring simulation and drawing separately.

**Acceptance:** A reproducible benchmark reports frame-time distributions and draw work; paused, reduced-motion and moving-packet cases retain visual correctness.

### T98 — Provide an optional local diagnostic export containing version, seed, sanitized state and recent in-game events

**P2 · effort M · Diagnostics**. Source: [main.gd:2394](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:2394). Dependencies: T95 T99.

Provide an optional local diagnostic export containing version, seed, sanitized state and recent in-game events.

**Acceptance:** A reported failure can be reconstructed from the export without personal paths or unrelated user data; exporting leaves the active run unchanged.

### T99 — Turn reproduced defects into intended-behavior assertions and run them against an isolated current snapshot

**P1 · effort M · Validation**. Source: [reverify_current_probe.gd:1](C:/Users/steph/Documents/GitHub/rim/review/reverify_current_probe.gd:1). Dependencies: Intended rule decisions for reproduced findings.

Turn reproduced defects into intended-behavior assertions and run them against an isolated current snapshot.

**Acceptance:** The suite fails on each retained defect and passes only after its desired rule is implemented; it cannot modify normal user saves.

### T100 — Extract authoritative rules and simulation state from the monolithic controller so rendering and UI consume a shared model, with a validated definition table

**P2 · effort L · Architecture**. Source: [main.gd:1](C:/Users/steph/Documents/GitHub/rim/scripts/main.gd:1). Dependencies: T99.

Extract authoritative rules and simulation state from the monolithic controller so rendering and UI consume a shared model, with a validated definition table.

**Acceptance:** Headless and normal sessions produce equivalent state; new definitions are checked for costs, recipes, unlocks and glyph IDs before use.

## Deliverables and reproduction

- [Complete sortable audit and proposal backlog](REVERIFIED_BACKLOG.csv): 162 unique rows.
- [Exactly 100 improvement proposals](REVERIFY_100_IMPROVEMENTS.csv).
- [Current source manifest](reverify_source_manifest.json), [persistence/redraw/geometry results](reverify_current_results.json), [simulation baseline](reverify_sim_base_results.json), [simulation extras](reverify_sim_extra_results.json), [UI results](reverify_ui/project/results.json).
- [Simulation specialist evidence](reverify_sim_findings.md), [UI specialist evidence](reverify_ui_findings.md), [design specialist notes](reverify_design_findings.md). These candidate notes overlap the final backlog and must not be added to its count.
- [Probe instructions](REVERIFY_README.md). Probes record faulty behavior; future acceptance checks become regression assertions after implementation.
