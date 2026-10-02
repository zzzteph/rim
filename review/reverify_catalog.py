"""Build the current review from explicit, independently checkable findings.

Run from the repository root. This changes review artifacts only.
"""
from pathlib import Path
import csv
import difflib
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "review"
OLD = list(csv.DictReader((REVIEW / "REVIEW_BACKLOG.csv").open(encoding="utf-8-sig")))

# ID | priority | effort | area | action | acceptance check | current code anchor
# Original T IDs remain stable. All entries are proposals, not implemented features.
TWEAKS = """
T01|P2|M|Interface|Offer compact, normal and readable interface density presets with separate spacing and type tokens.|Each preset keeps every action reachable at 1280x720 and 1920x1080, including 200% text.|scripts/ui.gd:89
T02|P2|M|Interface|Make the sidebar resizable and collapsible with a persistent minimum width and a restore shortcut.|Resizing reallocates map space without clipping buttons; collapse and restore preserve the active tab and selection.|scripts/ui.gd:119
T03|P1|S|Accessibility|Add a live settings preview containing HUD text, a district, packet shapes and a tunnel warning.|Changing palette, contrast, motion or type size updates the preview immediately and shows a readable example.|scripts/ui.gd:360
T04|P2|M|Controls|Replace hardcoded action keys with named input actions and a remapping screen that reports conflicts.|All gameplay actions can be rebound; duplicate bindings are explained and restored mappings survive restart.|scripts/main.gd:942
T05|P2|L|Controls|Provide a keyboard placement cursor, target cycling, link-source selection and confirm/cancel actions.|A player can create and inspect a producer-to-C2 chain using only a keyboard, with visible focus and no modal leakage.|scripts/main.gd:975
T06|P3|L|Controls|Add a controller navigation map and a world targeting cursor after keyboard actions are complete.|A controller can complete the same opening without a mouse; switching input method preserves focus and selection.|scripts/ui.gd:89
T07|P2|S|Camera|Expose edge-pan enablement, pan sensitivity, drag buttons and optional inverted scroll as preferences.|Edge-pan can be disabled; each preference persists and works during ordinary play and pause planning.|scripts/main.gd:1330
T08|P2|M|Camera|Anchor zoom to the cursor or keyboard-focused object rather than only the screen center.|Repeated zoom in and out keeps the anchor under the pointer to within a few screen pixels.|scripts/main.gd:1017
T09|P2|M|Accessibility|Offer larger click targets for tunnels and small map markers, measured in screen pixels.|A fixed screen-space target size remains usable across zoom levels, and overlapping targets can be cycled.|scripts/main.gd:681
T10|P2|M|Accessibility|Separate ambient motion, packet motion and urgent effects while keeping one master Reduced Motion switch.|The master setting stops decorative motion in every scene; urgent information remains visible as static text or symbols.|scripts/settings.gd:6
T11|P1|M|Accessibility|Use resource symbols or patterns on districts, producers, build chips, minimap and packets with one semantic palette.|A grayscale view still distinguishes all resources and valid placement; palette changes keep every resource cue consistent.|scripts/settings.gd:13
T12|P2|M|Accessibility|Give controls descriptive accessible names, announced states and a clear focus order; validate actual engine support.|Supported assistive navigation identifies selected tabs, toggles and actions; remaining platform limitations are documented from testing.|scripts/ui.gd:89
T13|P1|M|Interface|Lay out resources, rates and warnings as separate responsive HUD regions with a compact fallback.|A hot Trace warning and all six resources remain legible at 720p and 200% text with no overlap.|scripts/ui.gd:210
T14|P2|S|Information|Add stock tooltips showing production, consumption, reserved amounts and what each resource unlocks.|Hover or focus explains why a balance changes and identifies at least one current use of that resource.|scripts/ui.gd:680
T15|P1|M|Information|Use one operational vocabulary: producing, forwarding, disabled, unlinked, quarantined, input-starved and overloaded.|The inspector, map and alerts report the same state for fixtures covering each condition and combinations.|scripts/main.gd:1415
T16|P2|S|Interface|Keep the inspector summary short and put formulas, flavor and route detail in expandable sections.|The default inspector exposes output, operating state and actions without scrolling at 720p; detail remains accessible.|scripts/ui.gd:809
T17|P1|S|Feedback|Use a timed message queue with severity and an optional history instead of overwriting action results with guidance.|Save success, failed placement and a claimed reward each remain visible long enough to read and can be reviewed later.|scripts/ui.gd:797
T18|P2|M|Diagnostics|Rank alerts by estimated lost output or blocked progress, with the most severe recovery issue first.|A severed Cycles trunk outranks a harmless idle branch, and the displayed reason explains the ranking.|scripts/ui.gd:708
T19|P2|S|Diagnostics|Make repeated alert clicks cycle through every affected node and show its index in the group.|An alert affecting three nodes visits all three without conflicting selections and returns to the first on the fourth click.|scripts/ui.gd:662
T20|P2|S|Accessibility|Show the same contextual help on keyboard focus, hover and an explicit help action.|Focused build and research entries expose the same cost, purpose and restrictions as pointer hover.|scripts/ui.gd:589
T21|P1|M|Onboarding|Teach a sustainable Cycles route before selling Intel, and explain the reserve needed for recovery.|The opening guide checks a live path and net Cycles supply rather than merely checking that a producer exists.|scripts/main.gd:1110
T22|P2|S|Research|Explain the practical problem solved by each unlock, with a before/after throughput or resource example.|Every technology states its operating cost, new capability and a situation where it improves the current network.|scripts/main.gd:40
T23|P1|M|Economy|Separate operating income and consumption from purchases, refunds, contract payouts and blackout penalties in rate telemetry.|Buying or undoing a structure never changes the displayed operating production rate or inflates the peak-income record.|scripts/main.gd:1361
T24|P2|S|Information|Report end-to-end travel time in seconds and show starvation-adjusted ETA separately from packet count.|A known-length multi-hop route's displayed time agrees with a timed engine fixture under normal and starved operation.|scripts/main.gd:769
T25|P1|M|Construction|Preview total deployment cost, ICE cost, incremental tunnel upkeep and forecast net Cycles balance before confirming.|The preview includes every cost actually deducted and warns if the completed plan lacks a recovery reserve.|scripts/main.gd:909
T26|P1|M|Diagnostics|Display effective edge capacity after node limits, incoming-link penalties and Proxy bonuses alongside the protocol rating.|A many-input producer and a Proxy trunk show their actual limiting capacity, matching simulation admission rules.|scripts/main.gd:1486
T27|P1|M|Diagnostics|Split distance loss, overload drops and hot-Trace loss into separate counters and explanations.|A short under-capacity link at high Trace is labelled with the Trace penalty, and predicted losses reconcile with measurements.|scripts/main.gd:1497
T28|P2|M|Construction|Support atomic protocol upgrades with a preview of incremental cost, capacity, noise and packet handling.|An upgrade preserves endpoints and path; failure changes nothing, and undo restores the original protocol and paid balance.|scripts/main.gd:1265
T29|P1|M|Construction|Preview reroutes before committing, including orphaned branches, packet policy and active sweep effects.|Cancel leaves the network intact; commit changes one complete edge transaction and undo restores the old edge.|scripts/main.gd:1265
T30|P2|M|Routing|Make route choice deterministic and explain failures such as blocked road, occupied lane or unreachable endpoint.|Repeated previews of unchanged geometry choose the same path, and a failed connection gives a specific actionable cause.|scripts/main.gd:496
T31|P2|S|Construction|Preview Proxy conversion as a trade: lost production, added vision, upkeep change and aggregation benefit.|The preview names the donor's lost output and the resulting effective trunk capacity before payment.|scripts/main.gd:1248
T32|P1|M|Performance|Use explicit world, topology, settings and visual revisions to invalidate geometry, minimap, visibility and redraw caches.|Changes while paused and same-count load replacements refresh every dependent view; idle frames still avoid unnecessary work.|scripts/main.gd:1387
T33|P2|M|Automation|Add converter input priorities and reserves so Labs, Forges and Markets compete according to player intent.|With insufficient Intel, a chosen Forge reserve is honored regardless of node iteration order; all allocations are visible.|scripts/main.gd:1525
T34|P1|S|Information|Generate processor descriptions from recipe data, including input, output, fuel and gross/actual rates.|Forge shows 0.6 Tools/s and 1.8 Cycles/s at full operation; Lab and Mixer descriptions also match CONV.|scripts/main.gd:32
T35|P2|L|Economy|Experiment with shared local extraction capacity or diminishing overlap so identical nearby producers do not multiply the same targets indefinitely.|Two producers sharing a target set show the shared yield; spaced or upgraded alternatives remain worthwhile across sparse and dense starts.|scripts/main.gd:1397
T36|P2|M|Districts|Give district specializations small, explicit output or recipe bonuses instead of relying only on a common resource color.|A player can predict why a Registry Package differs from a Farm Package, with clear baseline and bonus values.|scripts/main.gd:148
T37|P2|M|Balance|Tune protocols against effective node capacity, distance, upkeep and threat so each has a distinct use.|A comparison over short, long and aggregated routes yields a viable niche for every protocol, including research-gated HTTP/2 Flood and Onion Route.|scripts/main.gd:58
T38|P2|M|Economy|Test Intel prices based on recent sold volume or district demand instead of the current spendable Cash balance.|Spending Cash does not instantly reset demand; price history and recovery are visible, and contracts use the same pricing policy.|scripts/main.gd:1105
T39|P2|M|Economy|Price the Crypto chain against its research, capital, protected access and round-trip losses, with a distinct laundering market.|Matched-investment fixtures show when Crypto is preferable to Intel; their price curves and payback assumptions are explicit.|scripts/main.gd:35
T40|P1|M|Recovery|Protect a bootstrap path through limited salvage, an emergency rebuild action or a ring-fenced construction reserve.|The three-Market/one-DNS zero-resource save can recover into real Cycles production without starting a new game or using contracts.|scripts/main.gd:1313
T41|P2|L|Research|Introduce research branches that require operating a new capability and provide alternative strategic routes.|Each tier changes a production problem; no branch is mandatory solely to lengthen play, and every purchased unlock has a useful operating period.|scripts/main.gd:40
T42|P1|M|Contracts|Generate jobs from reachable capabilities and let players decline unsuitable offers without permanently blocking the board.|A board containing three inaccessible jobs can recover; offers disclose any capability or location requirement before acceptance.|scripts/main.gd:1659
T43|P1|M|Contracts|Pay recurring contracts for new deliveries or sustained service; reserve possession rewards for one-time milestones.|The same unchanged 80-Cycle stock cannot repeatedly earn rewards; recorded job income corresponds to additional completed work.|scripts/main.gd:1686
T44|P2|S|Contracts|Show the full deadline before acceptance, distinguish offer expiry from active time, and explain pause behavior.|A player knows when a timer starts and what failure costs; pause, save and reload preserve the displayed remaining time.|scripts/ui.gd:602
T45|P1|M|Threat|Preview each countermeasure's effect on the active sweep and future launch charge before spending resources.|DDoS, rerouting, severing and quiet protocols show only effects the simulation actually implements, with remaining impact time.|scripts/main.gd:1608
T46|P2|M|Threat|Choose sweep targets from reachable, active and exposed branches, weighted by activity or noise rather than equal random choice.|Empty or disabled branches do not distract threats indefinitely; a quiet low-value branch is less likely to be selected than an exposed trunk.|scripts/main.gd:1589
T47|P2|M|Threat|Guarantee a visible recovery interval after an attack and avoid scheduling unavoidable repeated blackouts.|A recovering bootstrap network has time to restore supply before another sweep; cooldown rules remain visible and persist across reload.|scripts/main.gd:1608
T48|P2|M|Victory|Capture a permanent victory result at the winning tick, with active time, delivered value, reinvestment and threat recoveries.|Keep Playing cannot change the earned victory result; save/load preserves it and transaction spikes do not count as production records.|scripts/main.gd:1741
T49|P2|S|Replay|Expose seed entry, copy and paste in New Game and Stats while retaining random generation as the default.|The same seed and rules produce the same city; invalid input is handled clearly and seed sharing includes the rules version.|scripts/menu.gd:55
T50|P1|M|Validation|Run formative playtests across dense and sparse starts with new and experienced players, including accessibility settings.|Capture first stable supply, first sale, blocked actions, idle time and stage completion; use observations to choose balance targets.|review/PACING_REVIEW.md:1
T51|P1|M|Onboarding|Build a guided operation on a curated city with live checks for production, linking, selling, shortages and recovery.|The tutorial completes from legal actions, recognizes alternate valid layouts and can be replayed or skipped without changing Standard saves.|scripts/main.gd:1110
T52|P2|M|Modes|Add a Sandbox rules preset with configurable starting resources, research and threat pressure.|Changing Sandbox options affects a new session; sandbox results are identified and cannot overwrite Standard records accidentally.|scripts/session.gd:5
T53|P3|M|Modes|Create a small set of fixed-seed challenge scenarios using the same simulation and explicit objective rules.|At least one quiet extraction, one constrained supply and one Crypto scenario validate different strategies and show their rules before start.|scripts/main.gd:1567
T54|P2|L|Progression|Prototype a final Spire extraction requiring delivered supplies and a sustained route after several capability milestones.|A run must solve more than accumulating Cash; the final mission has clear success, failure and recovery rules, with alternate viable approaches.|scripts/main.gd:1567
T55|P2|L|Progression|Use client or C2 operation ranks that demand new capabilities and unlock choices as the network grows.|Each rank introduces one understandable operating requirement and payoff; shortages pause advancement without destroying the run.|scripts/main.gd:1110
T56|P3|L|Economy|Add recurring client service requests with simultaneous supply and reliability requirements.|Meeting one client can create a visible allocation choice for another; pausing and saving preserve service windows and partial progress.|scripts/main.gd:1659
T57|P3|L|Production|Pilot one two-input recipe, such as Intel plus Tools into an extraction kit, before expanding the resource roster.|Both inputs are actually reserved and consumed; partial supply cannot duplicate output, and the new product has a useful demand sink.|scripts/main.gd:32
T58|P2|L|Automation|Introduce small converter input/output buffers that store delivered goods and expose blocked or starved state.|Fuel is consumed at the defined processing step; delivered input remains recoverable after a pause or failed output route.|scripts/main.gd:1525
T59|P2|M|Contracts|Give the seven existing clients recognizable job preferences such as quiet extraction, bulk delivery or research service, shown before acceptance.|In a seeded sample, each client consistently offers its disclosed request/reward/risk style; a client never adds an unannounced penalty or eligibility rule.|scripts/main.gd:70
T60|P3|L|Automation|Experiment with finite packet queues and backpressure after settling the capacity rule.|A full edge slows upstream dispatch instead of exceeding capacity; queue length and waiting time are visible and saved consistently.|scripts/main.gd:1480
T61|P2|M|Diagnostics|Add a network overview listing per-node input, output, fuel, queue, loss and limiting edge, sortable by blocked value.|Selecting a row focuses the corresponding node; totals reconcile with resource balances over a measured interval.|scripts/main.gd:1507
T62|P2|M|Construction|Offer compatible producer upgrades in place, such as Phishing to Scraper, with a paid difference and a production preview.|The upgraded node keeps identity, valid links and packet policy; undo restores the donor and exact payment without duplicating output.|scripts/main.gd:1225
T63|P3|M|Automation|Add simple production conditions such as stop below a Cycles reserve or above an output-stock threshold.|Hysteresis prevents rapid toggling; the active condition and reason for stopping are visible and reload restores the rule.|scripts/main.gd:1415
T64|P3|L|Construction|Support blueprints for a selected cluster with relative positions, link topology and a complete cost preview.|Invalid placement identifies each conflicting footprint; successful placement is one undoable transaction with no partial hidden charges.|scripts/main.gd:1225
T65|P2|M|Construction|Let players copy and paste production caps, converter priority and tunnel configuration between compatible nodes.|Paste names exactly which settings change, preserves geometry and resource ownership, and can be undone.|scripts/main.gd:2349
T66|P2|M|Construction|Add group selection for bulk disable, output caps and inspection of combined upkeep.|A bulk action excludes C2 and incompatible nodes, reports affected count, and uses the same operating rules as individual actions.|scripts/main.gd:2342
T67|P3|L|Construction|Prototype delivered deployment supplies for advanced installations while keeping early construction immediate.|The ghost remains inspectable during delivery; cancellation returns only recoverable material, and blocked construction has a clear remedy.|scripts/main.gd:1225
T68|P3|L|Customization|Add a small set of mutually exclusive efficiency, throughput and stealth modules with operating tradeoffs.|Every module states its costs and effect; matched-network tests show a distinct use for each without one dominating all routes.|scripts/main.gd:1415
T69|P3|M|Exploration|Offer quiet and loud district scans with distinct costs, revealed information and threat consequences.|A scan shows what will be revealed and why; loud scans affect pressure under a stated rule and all scan state persists.|scripts/main.gd:705
T70|P2|M|Districts|Expose a district inspector with slots, ICE, useful targets, coverage and reachable approach routes.|Clicking or focusing a district explains its limits before spending Tools and identifies a viable next expansion action.|scripts/main.gd:1208
T71|P3|M|Districts|Add district operation objectives that reward actual sustained activity there, rather than construction counts alone.|A district reward requires delivered production or service from that district; inactive or converted donor nodes cannot satisfy it.|scripts/main.gd:1686
T72|P3|L|Simulation|Prototype one rival operator that competes for optional city opportunities and telegraphs its next move.|The rival creates a reversible choice about expansion or defense; losing a target never eliminates the bootstrap recovery path.|scripts/main.gd:300
T73|P3|L|Threat|Localize threat exposure by district so geography and loud routes influence where sweeps originate.|The map shows district heat and launch causes; equally productive quiet and loud layouts have different visible exposure.|scripts/main.gd:1545
T74|P2|M|Recovery|Offer explicit Proxy reversal after undo history expires, with the donor's restored production and upkeep shown before commitment.|A converted producer can return to its original role after Continue; links stay valid and reversible cost rules cannot mint resources.|scripts/main.gd:1248
T75|P2|M|Recovery|Offer a paid quarantine remediation action with a displayed time reduction and opportunity cost.|Repairing a selected node changes its actual remaining quarantine, and unavailable resources cannot trigger or partially pay the action.|scripts/main.gd:1438
T76|P2|S|Camera|Add return-to-C2, fit-network and a few saved camera bookmarks, with bounded minimap drag input.|One action recovers a useful view after panning beyond any map edge; saved bookmarks restore both position and zoom.|scripts/minimap.gd:24
T77|P2|S|Narrative|Add brief handler messages at real capability milestones and recovery events.|Messages are tied to accomplished actions, do not block play, can be reread and never describe an unimplemented mechanic.|scripts/main.gd:1110
T78|P2|M|Audio|Add restrained sounds for build, link, sale, resource delivery and critical operational events.|Each sound communicates an action or state; dense traffic is rate-limited and silence remains available without losing visual information.|scripts/main.gd:859
T79|P2|S|Audio|Expose master, UI, alerts, effects and music controls with persistent mute settings.|Every sound respects its bus and master mute; changing a slider previews a representative sound without resuming paused gameplay.|scripts/settings.gd:39
T80|P1|S|Accessibility|Expose accessibility Settings on the main menu before the first run, with a live example and initial keyboard focus.|A player can enable large text and Reduced Motion before New Game; the menu and next scene reflect the persisted choice immediately.|scripts/menu.gd:34
T81|P2|M|Feedback|Add a small resource counter pulse, route-power effect and distinct victory effect through the shared motion settings.|Repeated deliveries are coalesced, Reduced Motion uses a static cue, and effects never conceal prices or warnings.|scripts/main.gd:1441
T82|P2|M|Pacing|Extend the existing pause with 1x, 2x and 3x controls by applying one simulation-time multiplier to every gameplay system.|At each speed, resources, packets, contracts, boosts and threats advance consistently; paused planning remains available.|scripts/main.gd:1330
T83|P2|S|Accessibility|Offer optional auto-pause on new sweeps, major disconnection or starvation, with an explanation and quick resume.|Only new incidents pause the session, repeated conditions do not retrigger endlessly, and players can choose which events qualify.|scripts/ui.gd:708
T84|P2|M|Economy|Show separate Cash and RP sources: Intel sales, Crypto laundering, contracts and penalties over a chosen interval.|The breakdown sums to net change after spending and refunds; it reveals whether rewards bypass the intended production chain.|scripts/main.gd:1730
T85|P2|M|Diagnostics|Extend the Cash sparkline to production, consumption, stock and threat histories with explicit time axes.|Samples use active simulation time, pause creates no fake production and each graph preserves its meaning after speed changes and reload.|scripts/graph.gd:13
T86|P2|M|Balance|Show an estimated investment payback for advanced structures using current delivered output and operating costs.|The estimate lists assumptions, distinguishes gross output from net income and flags upgrades that cannot repay during the remaining scenario.|scripts/main.gd:73
T87|P2|M|Replay|Keep a local run archive with captured results, seed, rules and strategy-relevant metrics.|Finishing a second run preserves the first result; comparing records distinguishes Standard, Sandbox and challenge rules.|scripts/main.gd:1741
T88|P2|M|Validation|Record seed, rules and ordered player commands at simulation ticks to reproduce complete runs and reported failures.|Replaying an opening, reroute, defense and undo sequence twice produces identical state digests at recorded checkpoints on the same rules version.|scripts/main.gd:975
T89|P3|M|Replay|Offer city archetypes such as sparse, finance-heavy and fortified by varying existing district generation weights.|Each archetype changes a real opening decision; automated seed sweeps verify legal recoverable starts for all presets.|scripts/main.gd:300
T90|P2|S|Commands|Renew Overclock with a displayed top-up price or explicitly purchased additional duration, instead of charging a full boost to overwrite remaining time.|Renewing with 17 seconds remaining grants exactly the priced additional time; OFF or disconnected targets disclose whether the boost can provide useful production.|scripts/main.gd:2360
T91|P2|M|Information|Move player text into translation keys and a consistent glossary, then check layout with expanded pseudo-translations.|A 30% text-expansion pass retains every action, and default text consistently says Cycles, Intel, Cash and Research rather than legacy names.|scripts/main.gd:917
T92|P1|M|Balance|Run declarative legal opening and growth scenarios through the real simulator across a fixed set of city seeds.|A batch of at least 100 seeds exports first stable supply, first sale, useful research, stuck runs and objective time; every action obeys ordinary validators and payment.|scripts/main.gd:1435
T93|P2|M|Information|Add an in-game reference for resources, recipes, protocols, district rules and threat stages generated from authoritative data.|Reference values match previews and simulation; the player can open the relevant entry directly from an inspector or failed action.|scripts/main.gd:114
T94|P2|S|Settings|Add validated settings defaults, reset by category and a readable recovery path for unusable text or input settings.|Malformed values fall back safely; reset remains reachable when fonts or controls are changed to an inconvenient configuration.|scripts/settings.gd:47
T95|P1|M|Persistence|Add named save slots, a verified last-good backup and a lightweight preview of seed, time and progression.|Corrupting the latest slot does not destroy its previous valid backup; Continue selects a validated save and explains recovery.|scripts/main.gd:2394
T96|P2|M|Persistence|Add rotating autosaves at safe milestones with an explicit interval and status indicator.|Autosaves preserve complete simulation state, never replace a named manual slot unexpectedly and recover after an interrupted write.|scripts/main.gd:2394
T97|P1|M|Performance|Benchmark fixed small and large networks before and after optimizations, measuring simulation and drawing separately.|A reproducible benchmark reports frame-time distributions and draw work; paused, reduced-motion and moving-packet cases retain visual correctness.|scripts/main.gd:1383
T98|P2|M|Diagnostics|Provide an optional local diagnostic export containing version, seed, sanitized state and recent in-game events.|A reported failure can be reconstructed from the export without personal paths or unrelated user data; exporting leaves the active run unchanged.|scripts/main.gd:2394
T99|P1|M|Validation|Turn reproduced defects into intended-behavior assertions and run them against an isolated current snapshot.|The suite fails on each retained defect and passes only after its desired rule is implemented; it cannot modify normal user saves.|review/reverify_current_probe.gd:1
T100|P2|L|Architecture|Extract authoritative rules and simulation state from the monolithic controller so rendering and UI consume a shared model, with a validated definition table.|Headless and normal sessions produce equivalent state; new definitions are checked for costs, recipes, unlocks and glyph IDs before use.|scripts/main.gd:1
""".strip()

BUG_ACCEPTANCE = """
B01|Recover the legal zero-resource opening after fresh Continue through guaranteed salvage or emergency supply; keep every reachable run recoverable.
B02|At zero Tools an ICE placement is refused with no charge or node; undo never refunds more than the verified payment.
B03|Choose hard or soft capacity explicitly; offered 115.4/s on a rated 3/s edge obeys the chosen admission rule and matching telemetry.
B04|Account for processor input and output on all traversed edges; three input requests cannot report zero offered load.
B05|Define production-off versus routing-off; forwarded traffic pays its intended upkeep and noise even when local production is disabled.
B06|An OFF or otherwise non-operational Market cannot silently convert passing Intel; any permitted draining behavior is explicit.
B07|Reparent A from B to D while a packet is in flight; it follows a valid live route or is cancelled under a stated policy.
B08|Choose whether residential is valid advanced Cycles ground; all previews, tool help and design documentation use that same mapping.
B09|Reject a footprint over a tunnel or commit a reviewed reroute; no completed construction leaves traffic intersecting blocked geometry.
B10|Rendering, placement, coverage and road routing consume one authoritative building geometry; verify slums boundaries and narrowed Farm blocks.
B11|Undo the armed source's placement; pending references and preview caches clear without invalid node access.
B12|Undo a selected edge; selection clears or moves to a valid node and the inspector never indexes an empty tunnel definition.
B13|Sever and reparent an actively swept edge; sweep traversal validates live adjacency and countermeasure help states what quieting can actually do.
B14|During the advertised warning period, no quarantine applies before impact unless the warning explicitly labels an immediate lockdown.
B15|OFF nodes cannot satisfy an objective phrased as running linked operations; define and display its exact eligibility policy.
B16|A fractional 0.5-Cash packet retains 0.5 after Save, in-place Load and fresh Continue and banks exactly once.
B17|Sweep route, phase, charge, Notoriety, blackout and quarantine resume identically in fresh and in-place load.
B18|A paid boost resumes with its saved remaining duration; payment and benefit cannot diverge across reload.
B19|Offers, acceptance, completion, unclaimed rewards, deadlines and generation state survive fresh and in-place load without duplicate rewards.
B20|Run duration, delivered count, peak metrics and captured victory result preserve their accumulated values after Continue.
B21|Reject empty, malformed or unsupported save schemas before touching the active run; validate hub, graph, routes and numeric ranges.
B22|An interrupted or failed write preserves the last valid save; return success only after a checked durable write and safe replacement.
B23|The next simulation random draw after reload equals the uninterrupted run; persist RNG state without losing integer precision.
B24|Loading a prior state clears its discarded undo history and transient selections, drag state, preview and rate sampling; undo cannot mint resources.
B25|Repeatable work cannot pay again for the same unchanged starting stock; define possession rewards as one-time milestones or pay for new deliveries.
B26|Coverage calculation, displayed shape, center and range text agree; the current square-radius-four and circle/radius-six descriptions cannot coexist.
B27|Every Build, Tech and Stats action and status remains reachable in the supported 720p viewport at all supported text scales.
B28|Three or more job cards scroll within the available sidebar; the last claim/accept action remains reachable at 720p.
B29|At 200% all ordinary HUD, body, status, tab, button and graph text scales under shared tokens and layouts reflow.
B30|Switching tabs while inspecting a node or tunnel reveals the chosen tab or explicitly closes the inspector.
B31|Introductory, armed-tool and hover/focus help is visible even with no selected map object.
B32|Save success, failed placement, rewards and other action results persist visibly before generic guidance resumes.
B33|Unlinked new producers and newly detached branches appear in offline diagnostics; intentionally disabled nodes have their own state.
B34|An alert jump establishes one coherent selection and the inspector describes the jumped-to object.
B35|Opening blocking Settings freezes gameplay while preserving the previous pause state; closing restores that state.
B36|Escape closes or backs out of the topmost Settings/modal state before changing hidden gameplay pause or tool state.
B37|Blocking modals prevent Delete, output, disable, overclock, undo and map action shortcuts from changing the background run.
B38|Opening a modal transfers focus inside and prevents focus or activation of background controls until closing.
B39|Expose a non-modal planning pause; mouse selection, construction and linking work while simulation remains frozen.
B40|The victory panel wraps and remains wholly within 1280x720, including all supported type scales and a long result string.
B41|Persisted Reduced Motion gates menu time-driven packet drift and decorative animation as well as gameplay.
B42|Valid and invalid placement have redundant local symbols/reasons and use semantic palette colors rather than red/green alone.
B43|Ground, build chips, map structures, minimap and resource packets use consistent resource semantics when the alternate palette changes.
B44|Changing the palette refreshes legend label colors immediately, alongside glyphs and packets.
B45|Twenty 2-pixel movements after one press count as a drag; release cannot place or cancel after the full 40-pixel displacement.
B46|A middle-button release over a Control always clears panning; pointer movement afterward cannot move the camera without a held button.
B47|Overload or ICE warnings occupy a reserved HUD region separate from economic rates and other text at 720p.
B48|Clicks on the visible tower silhouette select the intended structure, or the selectable ground target is clearly shown and consistently used.
B49|Loading a different seed rebuilds minimap district texture and state even if node count and camera happen to match.
B50|A converted donor appears as a Proxy on the minimap immediately and after loading; effective identity participates in invalidation.
""".strip()

def mapped_source(source):
    file, sep, number = source.rpartition(":")
    if not sep or not number.isdigit():
        return source
    before = (REVIEW / "snapshot" / file).read_text(encoding="utf-8-sig").splitlines()
    after = (ROOT / file).read_text(encoding="utf-8-sig").splitlines()
    index = int(number) - 1
    for tag, a, b, c, d in difflib.SequenceMatcher(None, before, after, autojunk=False).get_opcodes():
        if a <= index < b:
            return f"{file}:{(c + index - a + 1) if tag == 'equal' else c + 1}"
    return source

def link(source):
    file, sep, line = source.rpartition(":")
    if not sep or not line.isdigit():
        file, line = source, None
    absolute = (ROOT / file).as_posix()
    label = f"{Path(file).name}:{line}" if line else Path(file).name
    return f"[{label}]({absolute}{':' + line if line else ''})"

DEPENDENCIES = """
01:B27 B29;02:B27 B29 B30;03:B29 B41 B43 B44;04:B36 B37 B38 B45 B46;05:B36 B37 B38 B45 B46;06:T04 T05;07:B37 B46;08:T07;09:B48;10:B41;11:B42 B43 B44;12:B38;13:B27 B29 B47;14:B31;15:B05 B57;16:B29 B30 B55 B56 B57;17:B32;18:B33 B58;19:B34;20:B31 B38;21:B01 B05;22:B55 B61 B62;23:B20;24:B05 B07;25:B02 B03 B04 B09 B26;26:B03 B04;27:B03 B04 B58 B61;28:B07 B12 B53;29:B07 B13 B53;30:B09 B10 B54;31:B05 B50 B56;32:B11 B12 B49 B50 B51 B52;33:B04 B19;34:B55;35:B10 B26;36:B08 B54;37:B03 B04 B61 B62;38:B16 B23 B25;39:B03 B04 B16 B60;40:B01;41:B19 B25;42:B19 B25;43:B15 B19 B25;44:B19 B35;45:B13 B14 B17 B59;46:B05 B13 B17;47:B17 T45;48:B20 T23;49:B23 T95;50:B01 B03 B04 B16 B17 B19;51:T21 B27 B30 B31 B32;52:B17 B19 B21;53:T48 T52;54:T41 T43 T58;55:T40 T41 T54;56:T33 T43 T58 T85;57:T58 T59;58:B04 B07 B17 B19 B21;59:T33;60:B03 B04 B07 B21;61:T23 T26 T27 T34;62:T28 B07 B53;63:T15 T23;64:B09 B10 B11 B12 B53 B54;65:T33;66:B05 B12;67:T58 T64;68:T26 T37 T41;69:B02 B17 T73;70:B08 B10 B26 B54;71:T43 T70;72:T40 T70;73:B13 B17 T46;74:B50 B56 T31;75:B17 B57 T15;76:B37 B46;77:B31 B32 T21;78:T15 T17 T79;79:Audio bus setup;80:B29 B41 B43 B44;81:B51 T10;82:B17 B19 T23;83:B33 B35 B36 T15 T45;84:T23 T43;85:B20 T23 T32;86:B03 B04 B16 B60 T23 T26 T27;87:B20 T48;88:B23 T99 T100;89:B01 B08 B10 B54 T92;90:T54 T87;91:B27 B29 B31 B55;92:B01 B02 B03 B04 B10 B54;93:B08 B26 B55 B56 B58 B60 B61 B62;94:B29 B41;95:B16 B17 B18 B19 B20 B21 B22 B23 B24;96:T95;97:B51 B52;98:T95 T99;99:Intended rule decisions for reproduced findings;100:T99
""".strip()

def parse_tweaks():
    dependencies = {f"T{int(k):02d}": v for k, v in (part.split(":", 1) for part in DEPENDENCIES.split(";"))}
    dependencies.update({"T57": "T33 T58", "T59": "T42 T43", "T90": "B18 T23 T25"})
    previous = {r["ID"]: r for r in OLD}
    result = []
    for row in TWEAKS.splitlines():
        parts = row.split("|")
        assert len(parts) == 7, row
        identifier, priority, effort, area, action, criterion, source = parts
        title = previous[identifier]["Title"] if identifier in previous else action.split(";", 1)[0].split(".", 1)[0]
        result.append(dict(ID=identifier, Type="Improvement proposal", Priority=priority,
                           Evidence="Proposal", Effort=effort, Area=area, Title=title,
                           Observation=action, Action=action, Acceptance=criterion, Source=source,
                           Status="Proposed", Prior_ID=identifier if int(identifier[1:]) <= 50 else "",
                           Dependency=dependencies[identifier]))
    assert len(result) == 100 and len({r["ID"] for r in result}) == 100
    return result

def parse_bugs():
    criteria = dict(row.split("|", 1) for row in BUG_ACCEPTANCE.splitlines())
    bugs = []
    runtime_ids = set(f"B{i:02d}" for i in range(1, 27)) - {"B22"}
    runtime_ids |= {f"B{i:02d}" for i in range(27, 51)} - {"B42", "B43", "B50"}
    rules = {"B03", "B08", "B15", "B25"}
    areas = {**{f"B{i:02d}": "Simulation" for i in range(1, 16)},
             **{f"B{i:02d}": "Persistence" for i in range(16, 25)},
             **{f"B{i:02d}": "Interface / accessibility" for i in range(27, 51)},
             "B25": "Contracts", "B26": "Geometry"}
    efforts = {"B01": "M", "B03": "M", "B04": "M", "B07": "M", "B09": "M", "B10": "M", "B13": "M", "B17": "M", "B19": "M", "B21": "M", "B22": "M", "B27": "M", "B29": "M", "B35": "M", "B37": "M", "B38": "M", "B43": "M", "B48": "M"}
    for old in OLD:
        identifier = old["ID"]
        if not identifier.startswith("B"):
            continue
        evidence = ("R+C" if identifier in runtime_ids else "C") + ("+D" if identifier in rules else "")
        source = mapped_source(old["Source"])
        if identifier == "B21": source = "scripts/main.gd:2425"
        bugs.append(dict(ID=identifier, Type="Rule mismatch" if identifier in rules else "Defect", Priority=old["Priority"],
                         Evidence=evidence, Effort=efforts.get(identifier, "S"), Area=areas[identifier], Title=old["Title"],
                         Observation=old["Observation or proposal"], Action=old["Recommended action or player value"],
                         Acceptance=criteria[identifier], Source=source, Status="Rule decision unresolved" if identifier in rules else "Open",
                         Prior_ID=identifier, Dependency="", Evidence_detail="Fresh current-copy observation and source" if identifier in runtime_ids else "Current source inspection"))
    by_id = {r["ID"]: r for r in bugs}
    updates = {
        "B05": {"Observation": "An OFF Market and its child remain reachable and the OFF edge still has telemetry. Its outgoing forwarding incurs no upkeep or noise; the fixture charges only the enabled child's link.", "Source": "scripts/main.gd:1462"},
        "B06": {"Observation": "Intel passing through an OFF Market still becomes Cash. A prepaid inbound request also completes after shutdown; define whether that existing work should finish, buffer or cancel separately from pass-through selling."},
        "B10": {"Observation": "At city seed 12345, a tile/block comparison finds 15 vacancy disagreements near slums boundaries and 53 Farm blocks whose narrow rendered footprint disagrees with wider collision. One authoritative geometry fix covers both."},
        "B13": {"Observation": "Cutting the targeted tunnel still causes a four-second blackout and 25-Cash penalty. Traversal follows stored node IDs without validating live adjacency. The advertised 'go quiet' action affects future charge, not active traversal."},
        "B24": {"Observation": "In-place Load retains discarded undo history: the fixture refunds 5 unpaid Cycles, changing 1000 to 1005. It also retains selection, pan and rate/preview state from the other timeline; reset those as one load transaction."},
        "B26": {"Title": "Coverage calculation, shape and advertised range disagree", "Observation": "Production counts a radius-four square while displaying a radius-four circle. Of 225 fixture centers, 164 differ under disk counting. Phishing/Scraper inspector separately advertises six tiles although productive coverage uses four."},
        "B27": {"Observation": "At 1280x720, Build status begins at y742 and Tech at y765. Stats also reaches about y750, with status at y756. Reserve a visible feedback region and allow every long tab to scroll."},
        "B30": {"Observation": "Selecting C2 then choosing Menu leaves the inspector visible and Menu hidden. Arming a tool can likewise retain tunnel selection and suppress Build content; treat navigation and inspection as explicit states."},
        "B32": {"Observation": "'Game saved' is replaced by next-step guidance; tool hints can mask failures and rewards. Smokescreen also replaces its sweep-cancel outcome internally before the UI can show it."},
        "B35": {"Observation": "Opening blocking Settings leaves paused=false. Current processing therefore continues production, contracts and threat clocks. The fresh fixture verifies pause state; it does not claim a full countdown playthrough."},
        "B37": {"Observation": "E disables a selected node behind Settings; Delete, undo, overclock and output keys share the unguarded dispatcher. Continuous raw arrow-key polling also pans the camera behind the modal."},
        "B39": {"Observation": "The full-screen pause dimmer consumes mouse input, so current pause-to-plan code comments/design intent do not provide usable mouse planning. The review no longer treats this as a demonstrated on-screen promise."},
        "B41": {"Observation": "With Reduced Motion enabled, menu._process(1) still advances its animation time and drifting packet positions use that time. This is a current state/source check, not a rendered motion-comfort study."},
        "B44": {"Title": "Palette changes leave cached interface colors stale", "Observation": "Alternate-palette toggle leaves legend label colors unchanged and unequal to Settings.res_color. GlyphIcon also lacks settings-driven redraw invalidation; the earlier claim that every glyph updates immediately is withdrawn."},
        "B45": {"Observation": "With the viewport pointer explicitly outside the sidebar, twenty movements of 2 pixels total 40 pixels but never set the drag flag. Slow release can therefore place/select or cancel after panning."},
        "B46": {"Observation": "A Control-consumed middle-button release can leave _panning latched. In the state fixture, subsequent motion with button_mask=0 still moves the camera; the ordinary release path is source-verified."},
        "B47": {"Observation": "Warning rectangle (300,42,359,24) overlaps rate rectangle (312,42,361,22). A separate large-stock stress fixture also pushes the unwrapped resource/goal HUD beyond the right edge; use one responsive HUD layout."},
        "B48": {"Observation": "Hit-testing the projected C2 roof-center tile returns no node: the roof is drawn above/right of the ground footprint but _node_at tests ground cells. The fixture derives the projected target and checks it; it is not a rendered mouse-click playtest."},
        "B49": {"Observation": "The minimap retains its baked texture after seed 42 to 43 regeneration. Load calls that regeneration without invalidating the cache. The fixture checks regeneration and texture retention; the full UI Load click path is source-verified."},
    }
    for identifier, update in updates.items():
        by_id[identifier].update(update)
    additional = [
        ("B51", "Defect", "P1", "R+C", "M", "Rendering", "Paused actions can leave the map visually stale",
         "On a stationary paused view, toggling a selected node changes its enabled state but draw count remains 2. Explicit queue_redraw raises it to 3. Redraw gating checks motion/view/tool activity, not state mutations.",
         "Introduce visual dirty revisions and invalidate on state, selection, settings and final-animation transitions.",
         "Toggle, dismantle, undo and change settings while paused without moving the pointer; the map updates once, then returns to idle redraw behavior.", "scripts/main.gd:1387"),
        ("B52", "Defect", "P1", "R+C", "M", "Rendering", "Culling bounds omit visible routes and selected overlays",
         "In a constructed orthogonal-detour fixture, a path point is inside the viewport while merged endpoint footprints fail culling; the tunnel and its packets are skipped. A selected-node vision ring can also cross the viewport while its footprint is culled. These are geometric fixtures, not measured natural-route prevalence.",
         "Cache actual path bounds and include visible overlay bounds; retain cheap culling after verifying geometry.",
         "A detour segment and its packets remain visible when endpoints are offscreen; selected coverage/vision rings remain visible wherever they intersect the exposed view.", "scripts/main.gd:1767"),
        ("B53", "Defect", "P1", "R+C", "M", "Undo", "Restored armed sources permit replacement Undo to lose the old link",
         "A legal remove-link, arm-source, Undo-restores-link sequence leaves the source armed. Completing a different target replaces the old edge; the next Undo clears the edge rather than restoring the original connection. Directly selecting an already linked source is normally rejected.",
         "Validate the pending source at commit and preserve complete before/after edge state for any permitted replacement.",
         "Remove, arm, restore with Undo, then commit a target: reject the stale action safely or permit one atomic replacement whose Undo restores the exact old link.", "scripts/main.gd:1304"),
        ("B54", "Defect", "P2", "R+C", "S", "Placement", "Boundary placement can exceed a district's producer limit",
         "For a 2x2 Phishing footprint crossing adjacent Intel regions, placement checks the origin region while occupancy counts its center region. The fixture admits a producer into a full center region and remaining slots change from 0 to -1.",
         "Choose one authoritative owning district or require a single-district footprint and use it for both validation and accounting.",
         "A boundary build cannot exceed any declared slot limit, and its preview identifies the same owning district used after placement.", "scripts/main.gd:1208"),
        ("B55", "Defect", "P1", "R+C", "S", "Information", "Lab and Forge rates are rounded to incorrect whole numbers",
         "Converter text uses %.0f/s, displaying both Lab's actual 0.5/s and Forge's actual 0.6/s as 1/s. Players plan supply against substantially overstated rates.",
         "Format fractional rates with adequate precision and derive all input/output/fuel values from CONV.",
         "The inspector shows Lab 0.5 Research/s and Forge 0.6 Tools/s with their actual fuel and input requirements.", "scripts/ui.gd:858"),
        ("B56", "Defect", "P2", "R+C", "S", "Information", "Proxy inspection still describes the donor's production",
         "Converted Phishing correctly has a Proxy title but retains the producer homage and 'Sweeps Intel within 6 tiles'. Its production has actually stopped.",
         "Use effective relay identity for description, range, color and operational controls; keep donor provenance separate.",
         "A converted producer's inspector explains forwarding, vision and upkeep and does not claim donor production; reversal restores the donor description.", "scripts/ui.gd:838"),
        ("B57", "Defect", "P1", "R+C", "S", "Information", "Quarantine is misdiagnosed as a missing physical path",
         "A node with a valid parent pointing to C2 and 4.9 seconds of quarantine shows 'OFFLINE - no path to C2'. This suggests rebuilding an intact connection rather than waiting or repairing quarantine.",
         "Report the operational cause and remaining quarantine separately from physical connectivity.",
         "Quarantine on an intact branch displays remaining time and affected nodes; an actually severed branch still reports its missing connection.", "scripts/ui.gd:868"),
        ("B58", "Defect", "P1", "R+C", "S", "Information", "Hot-Trace loss is attributed to distance",
         "A two-cell DNS at hot Trace shows 22% distance loss. The formula has 3% distance loss and a separate 20% ICE multiplier, for 77.6% survival. Shortening the link cannot remove the full reported loss.",
         "Store loss components and display actionable advice for each active cause.",
         "The fixture reports 3% distance and 20% Trace effects with 77.6% combined survival, rather than calling all loss distance.", "scripts/ui.gd:831"),
        ("B59", "Defect", "P2", "R+C", "S", "Threat UI", "Sweep remaining-hop count includes the destination node",
         "A sweep path [node,C2] at step 0 reports 2 hops although only one edge remains. The current count uses node count minus step.",
         "Count remaining transitions, and preferably display an estimated arrival time as well.",
         "One-edge and multi-edge paths report path.size - step - 1 transitions and reach zero at C2.", "scripts/ui.gd:697"),
        ("B60", "Rule mismatch", "P2", "C+D", "M", "Economy", "Crypto laundering shares the saturation it supposedly diversifies away from",
         "All credits-producing converters use _market_price(), so a Mixer also produces only 0.5 Cash per Crypto at 1000 banked Cash. The code and older design explanation imply diversification avoids Intel saturation; it currently does not.",
         "Choose and document a distinct Mixer exchange policy or remove the unsupported economic claim; evaluate full-chain investment returns.",
         "Mixer payouts at 0, 500 and 1000 Cash match the displayed chosen rule and the documented reason to invest in Crypto.", "scripts/main.gd:865"),
        ("B61", "Rule mismatch", "P2", "C+D", "M", "Threat", "The described global hot-Trace throttle compounds per hop",
         "The source applies x0.8 survival to each edge and tests admission at each hop. Ignoring other losses, four hops retain 0.8^4 = 40.96%, whereas the older description calls it a whole-network x0.8 throttle. The formula is analytical source evidence, not a sampled four-hop run.",
         "Choose route-wide or per-edge security loss explicitly and show the end-to-end consequence in route diagnostics.",
         "One-hop and four-hop fixtures match the chosen global or per-hop rule, and backbones are balanced against that actual rule.", "scripts/main.gd:1505"),
        ("B62", "Rule mismatch", "P2", "C+D", "S", "Routing", "Onion advice promises additional reach despite the same route limit",
         "Every protocol has a 255-cell route limit. A failed route hint recommends Onion for over-length routes, but Onion cannot extend that limit; it only has lower distance loss.",
         "Explain Onion's actual lower-loss niche or implement a deliberately distinct reach rule; separate length failures from geometry failures.",
         "An over-length route succeeds under an explicitly longer Onion limit, or the failure text no longer recommends an equally limited protocol as its remedy.", "scripts/main.gd:1289"),
    ]
    for identifier, kind, priority, evidence, effort, area, title, observation, action, acceptance, source in additional:
        bugs.append(dict(ID=identifier, Type=kind, Priority=priority, Evidence=evidence, Effort=effort, Area=area,
                         Title=title, Observation=observation, Action=action, Acceptance=acceptance, Source=source,
                         Status="Rule decision unresolved" if kind == "Rule mismatch" else "Open", Prior_ID="",
                         Dependency="", Evidence_detail="Fresh current-copy fixture and source" if "R" in evidence else "Current source / communicated-rule inspection"))
    assert len(bugs) == 62
    return bugs

def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

def validate(rows):
    assert len({r["ID"] for r in rows}) == len(rows)
    ids = {r["ID"] for r in rows}
    for row in rows:
        file, _, line = row["Source"].rpartition(":")
        assert (ROOT / file).is_file(), row["Source"]
        assert 1 <= int(line) <= len((ROOT / file).read_text(encoding="utf-8-sig").splitlines()), row["Source"]
        assert row["Acceptance"] and row["Action"] and row["Priority"]
        for dependency in re.findall(r"\b[BT]\d{2,3}\b", row["Dependency"]):
            assert dependency in ids, (row["ID"], dependency)

def main():
    bugs, tweaks = parse_bugs(), parse_tweaks()
    # Match the CSV field set when combining defects and proposals.
    for row in tweaks: row["Evidence_detail"] = "Acceptance criterion is proposed; not a passing implementation test."
    rows = bugs + tweaks
    validate(rows)
    manifest = json.loads((REVIEW / "reverify_source_manifest.json").read_text(encoding="utf-8-sig"))
    for file in manifest["files"]:
        assert hashlib.sha256((ROOT / file["path"]).read_bytes()).hexdigest() == file["sha256"], f"Production changed: {file['path']}"
    assert hashlib.sha256((ROOT / "project.godot").read_bytes()).hexdigest() == manifest["project_sha256"]
    (REVIEW / "reverify_improvements.json").write_text(json.dumps(tweaks, indent=2, ensure_ascii=False), encoding="utf-8")
    (REVIEW / "reverify_findings.json").write_text(json.dumps(bugs, indent=2, ensure_ascii=False), encoding="utf-8")
    write_csv(REVIEW / "REVERIFIED_BACKLOG.csv", rows)
    write_csv(REVIEW / "REVERIFY_100_IMPROVEMENTS.csv", tweaks)
    bug_count = sum(r["Type"] == "Defect" for r in bugs)
    runtime_count = sum("R" in r["Evidence"] for r in bugs)
    lines = [
        "# RIM v0.5.8 — reverified review and 100 improvements", "",
        "Reviewed 2 October 2026, Europe/Berlin. This pass rechecks all **50 earlier findings**, adds **12 further findings**, and expands the **50 earlier improvement suggestions to 100**. The 62-item audit contains **55 defects and 7 unresolved rule mismatches**. It does not claim 100 confirmed bugs. The earlier report and its 120-row backlog remain preserved.", "",
        "## Main assessment", "",
        "The recent work targets rendering efficiency, but the core simulation, saving and interaction defects remain. None of the earlier 50 findings is closed by the inspected v0.5.8 changes. The most useful next release is a trustworthy, readable operation: guarantee Cycles recovery, preserve a run on Save/Continue, make traffic limits and OFF states consistent, restore meaningful sweep counterplay, and make all primary actions reachable at 720p and large text sizes.", "",
        "The game already has contracts, ICE sweeps, alerts, tooltips and a Cash graph. Recommendations below extend those systems; older gap documents must not be used to claim they are absent. The primary progression problem remains: the same opening Intel-to-Market chain can satisfy the 1000-Cash victory check while research, Tools, Crypto and protected expansion remain optional. A supplied final operation and useful intermediate capabilities would create more decisions. Raising the Cash target alone would extend accumulation.", "",
        "## What was reverified", "",
        "Current production scripts, scenes and project configuration were hashed before probing. Three isolated current copies were imported with Godot 4.7.2. Only copied Session/Settings paths were redirected away from normal user saves; production gameplay code was not changed. Source comparison shows that the v0.5.8 main changes concern fog caching, redraw gating, frustum culling and rendering LOD; UI changes throttle alert scanning. Menu and minimap mechanics are unchanged.", "",
        f"**{runtime_count} of 62 findings have fresh engine-fixture support**; the rest rely on current source or a communicated-rule mismatch. R = reproduced state/layout/geometry observation; C = inspected current code; D = intended-rule decision still required. Some R fixtures establish a bad state while the later error path is source-verified. Geometric culling fixtures establish an algorithm failure, not how often a naturally generated route exhibits it. Headless checks do not establish human readability, screen-reader support, controller usability, renderer frame rate or completed-run pacing.", "",
        "The engine emitted a certificate-store diagnostic and editor-settings permission messages during isolated import. They are environment diagnostics and excluded from game defects. Completed final probes produced retained results; discarded exploratory parse failures are not passing evidence.", "",
        "## Strongest current evidence", "",
        "| Finding | Fresh observation | Implication |",
        "|---|---|---|",
        "| B01 | A legal three-Market/one-DNS opening remains at zero resources after fresh Continue and 100 simulated seconds. | MIN_FEED does not guarantee recovery without a source. |",
        "| B03 / B04 | A rated 3/s DNS fixture models 11.54/s delivery from 115.4/s offered; a processor emits three input packets while offered load says zero. | Balance data cannot be trusted until capacity semantics and traffic accounting agree. |",
        "| B13 / B14 | Cutting a swept tunnel still causes a four-second blackout and 25-Cash sting; the six-second warning already quarantines its target. | Advertised planning and counterplay do not match execution. |",
        "| B16–B24 | A 0.5-Cash packet becomes 1; fresh Continue loses boosts, contracts, threat and cumulative metrics; stale undo refunds 5 Cycles. | Saving changes player-earned state and can exploit resource accounting. |",
        "| B27–B29 / B47 | Build status starts at y742 in a 720px viewport; most nominal 200% text stays unchanged; warning and rates overlap. | Essential actions and information are inaccessible at supported settings. |",
        "| B51 / B52 | A paused toggle changes state with no draw event; endpoint-box culling rejects an actually visible detour segment. | New optimization work needs visual invalidation and correct geometry bounds. |",
        "| B55 / B57 / B58 | Lab/Forge rates round to 1/s, quarantine says no path, and 3% distance plus 20% Trace loss is labelled 22% distance. | Incorrect diagnosis encourages the wrong network changes. |", "",
        "## Corrections to the earlier review", "",
        "- B05: the disabled junction still has an edge record; the verified fault is unpaid forwarding upkeep/noise.",
        "- B06: passing Intel sells while OFF. Finishing prepaid work after shutdown requires its own explicit policy and is not counted as a separate bug.",
        "- B08, B03, B15 and B25 are retained as unresolved rule mismatches, rather than assuming a specific restriction, capacity or reward policy is unintended.",
        "- B10 includes slums vacancy and Farm footprint disagreements under one geometry fix; B26 includes square/circle coverage and the erroneous six-tile Intel description.",
        "- B39 cites the pause-planning implementation/design contradiction, not a demonstrated on-screen promise. B44 withdraws the unverified claim that all glyphs immediately update their palette.",
        "- B53 distinguishes ordinary source selection, which rejects linked nodes, from the armed-source/Undo state transition that allows replacement. Reroute recommendations must not imply an existing atomic upgrade UI.",
        "- The earlier ideal research calculation remains 115 RP / 0.5 RP/s = 230 seconds of supplied Lab processing. It is not a measured full-run duration. The previous 90–120-minute standard scenario target remains a playtest hypothesis, not a shipping requirement.", "",
        "## Prioritized delivery order", "",
        "Effort S/M/L describes relative implementation scope, not elapsed days. P0 blocks recovery; P1 should precede another broad playtest; P2 improves the next dependable version; P3 is an optional later experiment. Proposal priority does not make it a confirmed defect. Do not attempt all 100 suggestions at once.", "",
        "| Batch | Work to complete | Check before proceeding |",
        "|---|---|---|",
        "| 1 — Recover and preserve | B01, B02, B16–B24; T40, T95, T99 | Legal exhausted openings recover; full-state fresh/in-place round trips match; bad or interrupted saves keep the last good run. |",
        "| 2 — Make the network reliable | B03–B07, B09–B15, B26, B53–B54; T26–T34 | Settled capacity/OFF rules, directional processor traffic, valid packets after topology changes, live sweep traversal and conserved undo. |",
        "| 3 — Make interaction readable | B27–B50, B55–B59; T13, T15–T17, T20, T80 | 720p and large text work; modals contain focus/input; inspection explains actual rates and loss causes. |",
        "| 4 — Validate performance changes | B51–B52; T32, T97 | Paused actions repaint, on-screen detours remain visible, and performance is measured with representative traffic. |",
        "| 5 — Teach and measure | T21, T23, T25, T42–T50, T51, T92 | Players build a sustainable opening; recurring jobs require new work; measurement separates operations, transactions and idle time. |",
        "| 6 — Add depth selectively | T41, T54–T59, T62, T70–T75, T89 | Prototype one new capability and one supplied end objective; playtests demonstrate new decisions and multiple viable strategies. |", "",
        "## Reverified findings: B01–B50 and additions B51–B62", "",
        "Every earlier ID remains stable. Related extra symptoms are folded into their earlier finding; additional candidate lists from specialists are supporting notes, not extra counted findings. A rule mismatch can be resolved by changing the mechanic or its explanation, after choosing the intended rule.", "",
    ]
    for row in bugs:
        lines += [f"### {row['ID']} — {row['Title']}", "",
                  f"**{row['Priority']} · {row['Type']} · {row['Status']} · {row['Evidence']} · effort {row['Effort']}**. Source: {link(row['Source'])}.", "",
                  row["Observation"], "", f"**Action:** {row['Action']}", "", f"**Acceptance:** {row['Acceptance']}", ""]
    lines += ["## 100 improved suggestions: T01–T100", "",
              "T01–T50 strengthen the previous suggestions without changing their IDs. T51–T100 add new scope. Each entry has a concrete action, acceptance criterion, source anchor and dependency. These are proposals, not claims of implemented or tested features. Some specify how to address an audited defect; their proposal count does not mean there are 100 additional missing systems.", ""]
    for row in tweaks:
        lines += [f"### {row['ID']} — {row['Title']}", "",
                  f"**{row['Priority']} · effort {row['Effort']} · {row['Area']}**. Source: {link(row['Source'])}. Dependencies: {row['Dependency']}.", "",
                  row["Action"], "", f"**Acceptance:** {row['Acceptance']}", ""]
    lines += ["## Deliverables and reproduction", "",
              "- [Complete sortable audit and proposal backlog](REVERIFIED_BACKLOG.csv): 162 unique rows.",
              "- [Exactly 100 improvement proposals](REVERIFY_100_IMPROVEMENTS.csv).",
              "- [Current source manifest](reverify_source_manifest.json), [persistence/redraw/geometry results](reverify_current_results.json), [simulation baseline](reverify_sim_base_results.json), [simulation extras](reverify_sim_extra_results.json), [UI results](reverify_ui/project/results.json).",
              "- [Simulation specialist evidence](reverify_sim_findings.md), [UI specialist evidence](reverify_ui_findings.md), [design specialist notes](reverify_design_findings.md). These candidate notes overlap the final backlog and must not be added to its count.",
              "- [Probe instructions](REVERIFY_README.md). Probes record faulty behavior; future acceptance checks become regression assertions after implementation.", ""]
    assert bug_count == 55 and len(tweaks) == 100
    (REVIEW / "REVERIFIED_REVIEW.md").write_text("\n".join(lines), encoding="utf-8")
    summary = dict(version="0.5.8", previous_findings=50, previous_closed=0, further_findings=12,
                   audit_findings=len(bugs), defects=bug_count, rule_mismatches=len(bugs)-bug_count,
                   engine_backed_findings=runtime_count, improvement_proposals=len(tweaks), total_rows=len(rows),
                   production_hashes_unchanged=True)
    (REVIEW / "reverify_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))

if __name__ == "__main__": main()
