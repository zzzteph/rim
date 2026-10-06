# UI controls audit

20 distinct findings in `ui_controls.json`: 6 bugs and 14 proposed improvements. Scope: startup/Continue, Menu/Pause/Victory, Settings/accessibility, structure/tunnel inspector and action controls. All files created or changed by this pass are inside the audit directory.

Real-scene headless probe: `../panels_project/controls_probe.gd`, output `../panels_project/controls_probe_results.json`. Screenshots inspected: startup, selected producer, in-game Menu, Settings at 100/200%, Menu at 200%, and Pause (`01`, `06`, `11`–`14`, `19`).

Strong reproduced findings:

- Settings keyboard traversal escapes to background Build/Tech/Stats. Actual Enter press/release activates Stats while Settings is still visibly open.
- Closing Settings over Pause leaves keyboard focus null rather than returning to its opener.
- A 200% victory scorecard pushes its panel to y891 and Main Menu to y822–883 in a 720px logical viewport. Settings and Pause fit; no separate false smaller-resolution failures were filed.
- Main menu ignores the persisted 200% text setting and keeps buttons at 16px.
- Same-type endpoints read `Links Mirai Dropper → Mirai Dropper`, with no distinguishing identity.
- Main tab labels clip to `Bu/Te/St/Jo/Me` at 200%, as visible in the rendered screenshots.

Viewport checks: 1280×720; 1024×600 stretches to a logical 1280×750; 1366×768 stretches to a logical 1280×720. Geometry was assessed against logical dimensions, so physical/logical pixel differences do not become spurious overflow findings.

The frozen v0.6.5 UI was compared against the original v0.6.4 copy. New code changes the resource bar and message queue/history; affected controls, palette, modal and inspector logic are unchanged. Every panels/controls entry now has `current_validation: present_v065`. `source` pointers and runtime artifacts intentionally refer to the frozen baseline v0.6.4 evidence, for root aggregation/remapping to current v0.6.5 lines.

Deduplication: status guidance height, same-message timers, message history and planning-pause indication belong to the HUD agent. Save corruption/backup handling, DDoS quarantine mismatch, and disabled/offline overclock guards belong to the simulation agent. This pass owns Overclock pre-action cost/duration and remaining-boost UI only. The design agent confirmed discovered-host identity is separate from this pass's ambiguous owned-node endpoint labels.
