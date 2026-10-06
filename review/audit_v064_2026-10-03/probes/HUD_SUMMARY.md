# HUD, Stats and alerts audit, latest v0.6.5

20 distinct findings: 10 bugs and 10 improvements. Findings are in `../findings/hud_stats_alerts.json`.

The original v0.6.4 run established baseline geometry and behavior. Production UI/project files changed concurrently during the audit. The latest parent-provided `source_v065` was therefore copied into an isolated `hud_latest_project`, imported, and probed again. Source references in the HUD findings point to v0.6.5. Main simulation was unchanged, so the simulation findings remain applicable. No production files were edited by this audit agent.

The new compact header and message queue were recognized as implemented. They are not reported as absent. At 200% text, the compact header still needs 1005 px in a 956 px region, the legend extends beyond the viewport, and Feed is omitted in compact mode. The new severity classification changes colors/durations but queue order is FIFO: a controlled ten-message routine backlog delays a BLACKOUT result at least 22 s. The pending queue grew to 110 while history stayed bounded at 12.

Current headless UI results are in `hud_v065_results.json`; the earlier baseline is in `hud_results.json`. The probe instantiates the actual main scene at 1280×720, waits for layout, disables automatic game/UI processing and drives controlled production UI updates. It measures real Control rectangles and font text widths rather than estimated screenshot coordinates. Message probes use explicit controlled result strings; they do not claim a natural 110-message player encounter.

Visual evidence was also reviewed from parent-generated gameplay screenshots, including new-game, selected producer, Stats at 100%/200%, and simultaneous alerts at 100%/200%. Fresh v0.6.5 images `../screenshots_v065/25_alerts_100.png` and `26_alerts_200.png` confirm the compact header behavior, legend overflow and warning/alert collision. The original `screenshots/26_alerts_200.png` is baseline v0.6.4. Gameplay and render capture are coordinated by the parent; this specialist pass does not claim an independent full playthrough.

Other reverified defects: rates overlap the legend; the sweep headline intersects alert buttons; Stats omits stored Research; overload navigation opens the node instead of the affected tunnel; intact quarantined hosts are called unlinked; identical repeated errors and same-frame earlier results never enter the new queue/history; planning pause loses visible indication; loading does not clear discarded-timeline UI messages.

Chart scale/axes, aggregate operating telemetry, alert cycling, contextual diagnostics/actions and compact passive guidance are explicitly marked improvements. Individual inspector telemetry, Build/Tech/Jobs, controls/modals, world rendering and graph redraw performance are owned by other audit passes.
