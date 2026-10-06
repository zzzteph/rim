import json
from pathlib import Path

AUDIT = Path(__file__).resolve().parents[1]
items = []

def add(key, title, kind, area, priority, level, evidence, source, reproduction, impact, recommendation, acceptance, effort):
    items.append(dict(key=key, title=title, kind=kind, area=area, priority=priority,
                      evidence_level=level, evidence=evidence, source=source,
                      reproduction=reproduction, impact=impact, recommendation=recommendation,
                      acceptance=acceptance, effort=effort, current_validation="present_v065"))

add("PERF01", "Loading another city seed leaves the old baked city visible", "bug", "World rendering / save restore", "P1", "verified_runtime",
    "Rendered load probe changed seed 1321476956 to 7654321; 302 of 400 district cells changed, but _city_layer emitted zero draw notifications. The minimap correctly changed seed. Screenshots21/22 show before/after;23 is a manual invalidation control. Evidence: render_results.json different_seed_load.",
    "scripts/main.gd:2867", "Run probes/render_benchmark.gd in the isolated copy, or load a valid save with a different seed while gameplay is already open.",
    "The visible city no longer represents terrain, legal placement and routing used by the restored simulation.",
    "Invalidate the baked city after generating the restored city; coordinate all terrain, fog and minimap caches through a world revision.",
    "Loading each of two different seeds refreshes the city layer once and visible terrain agrees with placement/routing descriptors.", "S")

add("PERF02", "Same-seed restores can leave minimap host markers at old positions", "bug", "Minimap / save restore", "P2", "verified_runtime",
    "Controlled rendered cache-invalidation probe restored a same-seed state with equal node count/camera but synthetically moved C2 to(18,18); minimap emitted zero draw notifications. C2 does not ordinarily move. Its key covers seed/count/relay count/camera, not node identity or positions. The legal analogous scenario is same-count saves with different producer positions; that exact legal roundtrip was not recorded. Evidence: render_results.json same_seed_node_move_load.",
    "scripts/minimap.gd:32", "Restore two same-seed states with equal node and relay counts but different positions, keeping camera and zoom unchanged.",
    "Players navigate toward markers belonging to the discarded run.",
    "Invalidate on restore and include a node-position/topology revision in minimap state tracking.",
    "Same-count replacement, Undo and save restore repaint markers immediately without needing a camera move.", "S")

add("PERF03", "A baked city still submits thousands of retained draw calls", "improvement", "Performance / static world", "P1", "verified_runtime",
    "At1280x720, the fixed opening view had2595 draw calls even when paused and the world emitted zero redraws. Median paused frame interval was11.99ms on this RTX3060 laptop. This is local renderer evidence, not shipping-build FPS; render_results.json paused_build.",
    "scripts/city_layer.gd:7", "Run the fixed-camera rendered benchmark; compare paused opening draw calls and frame intervals after chunking/batching.",
    "Redraw gating reduces CPU command regeneration but the renderer still submits the retained city commands on every frame.",
    "Partition the backdrop into cullable chunks and compare a texture/mesh batch for static roofs, windows and streets. Preserve crisp zoom and palette changes.",
    "The same paused view has substantially fewer draw calls and lower frame intervals, with seed/palette refresh and terrain fidelity intact.", "L")

add("PERF04", "Dense structures need cached geometry and detail levels", "improvement", "Performance / dynamic world", "P1", "verified_runtime",
    "Synthetic50/150/400-node fixed-camera scenes measured median running frame intervals30.89/86.15/119.89ms and3667/6682/8130 draw calls. At400, reduced motion measured35.97ms; pausing35.58ms. Fixtures are unlinked zero-output nodes and establish rendering scaling, not an attainable campaign benchmark.",
    "scripts/main.gd:2274", "Run the three dense rendered fixtures with identical camera, viewport and motion setting.",
    "Animated geometry and dense retained commands can make network expansion hard to interact with.",
    "Cache static host prisms/windows and animate a smaller overlay. Cull and reduce fine details at distance; prioritize selected/threatened hosts and keep silhouettes legible.",
    "Compare50/150/400 fixtures before/after with identical composition; reduce median/p95 cost while selected hosts, packets and threats stay readable.", "L")

add("PERF05", "Tunnel rendering repeatedly rebuilds stable route geometry", "improvement", "Performance / routes", "P2", "source_confirmed",
    "_draw queries _path_bounds for each tunnel; that function loops the route cells, and _edge_pts recreates route polylines. Packet movement has a _polyline cache, but bounds and drawing do not share it. This is a source-confirmed avoidable cost; no isolated savings estimate is claimed.",
    "scripts/main.gd:2030", "Inspect draw work with long street routes while endpoints/topology remain fixed.",
    "Stable routes perform repeated allocation and cell traversal whenever ambient animation redraws the map.",
    "Cache bounds, rendered polyline and segment lengths together per topology revision; invalidate on reroute, removal and restore.",
    "Repeated draws allocate no fresh stable-route geometry; topology changes update all caches before rendering or movement.", "M")

add("PERF06", "Packet movement repeatedly searches long polylines from their start", "improvement", "Performance / packets", "P2", "verified_runtime",
    "CPU microbench using a synthetic winding120-cell/62-point path measured mean movement0.236ms at100 packets,2.715ms at1000 and9.235ms at3000(p95 13.647ms). _point_at_dist linearly searches segments and per-packet lookup repeats work. These counts are stress fixtures. Evidence: performance_results.json.",
    "scripts/main.gd:1012", "Run the packet movement microbench at100/1000/3000 packets on the same winding path.",
    "Packet work competes with simulation and rendering as traffic grows.",
    "Cache cumulative segment distances and use a remembered segment index or binary search; reuse positions for drawing, with explicit reverse-direction handling.",
    "Movement is identical across bends and both directions, and the same packet fixture shows lower mean/p95 CPU time.", "M")

add("PERF07", "Full fog recomputation becomes a noticeable placement spike", "improvement", "Performance / visibility", "P2", "verified_runtime",
    "Synthetic400-node CPU microbench measured mean vision rebuild40.25ms(max46.3ms), compared with cached check0.153ms. Rebuild tests fog block centres against the full host list; the cached path also scans every node for relays. Evidence: performance_results.json vision_rebuild/vision_cached.",
    "scripts/main.gd:806", "Compare cached and invalidated _vision_list timings at1/50/150/400 nodes; profile a node-set mutation.",
    "Adding/removing/converting a host can briefly stall feedback in a larger network.",
    "Track visibility revision explicitly and update only affected blocks using spatial buckets or coverage counts. Ensure Undo/load invalidates the correct region.",
    "Same fixture substantially reduces mutation-time spikes while visible cells and placement legality remain equivalent to the reference calculation.", "M")

add("PERF08", "The sidebar recomputes mostly unchanged telemetry every frame", "improvement", "Performance / UI updates", "P2", "verified_runtime",
    "Baseline v064 CPU microbench at400 synthetic nodes measured UI._process means1.92ms on Build and2.66ms on Stats per call. The UI walks network state and formats labels every frame while most simulation values change at10Hz or rate samples at1Hz. v065 adds compact-header measurement; quoted timings remain v064 measurements.",
    "scripts/ui.gd:803", "Run UI process microbench on unchanged fixtures and inspect label assignments/network loops during paused frames.",
    "Large networks pay formatting/counting costs on frames that cannot display new information.",
    "Refresh telemetry on simulation/rate revisions, inspector state on selection/mutations and layout on scale/size changes. Keep hover and warnings responsive.",
    "Paused idle UI performs no unnecessary full-network telemetry pass; live values refresh at their data cadence and actions update immediately.", "M")

add("PERF09", "Paused frames still hash every node to detect visual changes", "improvement", "Performance / invalidation", "P2", "verified_runtime",
    "CPU microbench measured _visual_sig mean0.986ms at400 nodes even without state changes. It hashes a full per-node representation on each main._process call. Evidence: performance_results.json visual_signature; the main script is unchanged in v065.",
    "scripts/main.gd:255", "Profile stationary paused scenes at1/50/150/400 nodes and inspect _visual_sig.",
    "The existing repaint gate still spends proportional CPU time on an idle network.",
    "Increment a visual revision at every visible mutation and compare revisions; retain explicit camera/pointer/animation gates and audit all mutation paths.",
    "Paused idle detection is constant-time while toggles, selection, settings, Undo, threat state and restores still repaint once.", "M")

add("PERF10", "The Stats graph redraws every paused frame without new samples", "improvement", "Performance / chart", "P2", "verified_runtime",
    "Rendered paused Stats test recorded80 graph draw notifications across80 frames while time/history sampling was stopped. graph._process checks its local visible flag and calls queue_redraw each frame. Evidence: render_results.json paused_stats.",
    "scripts/graph.gd:6", "Open Stats, pause, keep pointer/camera fixed and count graph draw notifications over80 frames.",
    "A static chart repeatedly regenerates identical drawing commands and may do work while an ancestor hides it.",
    "Redraw only on a history revision, size/theme/text-scale change or first becoming visible in the tree.",
    "Paused unchanged Stats produces zero repeated graph redraws; each new sample and layout change repaints promptly.", "S")

add("PERF11", "Simulation catch-up has no per-frame work budget", "improvement", "Performance / simulation scheduling", "P2", "source_confirmed",
    "main._process drains all accumulated0.1s ticks in an unbounded while loop. Separate400-node CPU fixtures measured roughly13ms per tick; a hitch can therefore demand several costly ticks before input/rendering resumes. No observed shipping-frame hitch or spiral is claimed.",
    "scripts/main.gd:1568", "Introduce controlled frame hitches in the isolated project and record catch-up work, elapsed simulation time and input latency.",
    "After a pause in execution, accumulated simulation work can extend the recovery stall.",
    "Set a documented per-frame catch-up/time budget and carry remaining debt across frames, with a clear policy for very long stalls. Preserve deterministic tick ordering.",
    "Controlled250ms/1s hitches recover with bounded input latency and no silently skipped resource, threat or contract time under the chosen policy.", "M")

add("PERF12", "Long-route cursor previews need a bounded work cadence", "improvement", "Performance / interactive routing", "P2", "verified_runtime",
    "Existing cached A* preview CPU probe on a generated100x100 city measured mean0.558ms for nearby target,5.88ms to(79,79),6.41ms to(99,99). The heap/search cap improvements are already present; this is remaining synchronous work on changed pointer cells. Evidence: performance_results.json route_preview.",
    "scripts/main.gd:741", "Sweep the pointer through successive distant cells with a source armed; compare interactive latency with the recorded per-search microbench.",
    "Repeated long searches can make route placement feel sticky despite a working path cache.",
    "Debounce or budget preview work and cancel stale targets; render a pending state and validate the current endpoint synchronously on commit when needed.",
    "Long-route hover remains responsive, stale results never appear on newer targets, and commit cost/validity uses the current topology.", "M")

(AUDIT / "findings/performance_render.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Wrote {len(items)} performance/render findings")
