# UI panels audit: frozen RIM v0.6.4

Scope: Build palette and subcategories, Tech/research, Jobs/contract board. No production code or old review artifacts were edited. Findings are in `ui_panels.json`: 20 distinct entries, comprising 6 bugs and 14 explicitly proposed improvements.

Rechecked against frozen `source_v065`: all 20 entries remain present and now carry `current_validation: present_v065`. Source pointers and probe artifacts remain baseline v0.6.4 evidence for root remapping; the v0.6.5 resource-bar/message-channel changes do not change these findings.

The strongest reproduced defects are palette overlap at 150–200% text, an invisible hover-detail inspector, clipping of the HTTP/2 prerequisite at default text size, and loss of keyboard focus whenever a contract change rebuilds all cards. Source-confirmed defects cover misleading linked-structure objective eligibility and the countdown flooring positive time to zero.

Runtime evidence: `../panels_project/panel_probe.gd` runs the real frozen scene headlessly using Godot 4.7.2 and emits `../panels_project/panel_probe_results.json`. This checks actual Control geometry, visibility, button text widths, and focus lifecycle; it does not implement alternative production behaviour. Rendered screenshots inspected: `08_tech.png`, `09_jobs.png`, `15_build_200.png`, `17_jobs_200.png`.

Important measurements: the 52px palette button contains 69px-high content at 150% and 90px at 200%; Poisoned Package content is 350px/440px wide against 284px/276px buttons. The default-size HTTP/2 locked text measures 345px within a 260px button, with no tooltip. The accepted contract's old card is freed and viewport focus becomes null.

Deduplication: net-stock vs delivered-resource contract wording/accounting is owned by the simulation agent and omitted here. Offer rotation, contract eligibility, and deadline balance belong to the cyberspace/design pass. Menu/settings/general navigation/HUD/inspector findings remain for subsequent UI passes. Explicitly reserve palette scaling and custom palette accessible names to this panel file; avoid adding them again as global accessibility findings.

Potential subsequent HUD finding observed but not included: at 200% the unbounded persistent next-step status paragraph consumes roughly 304px of the left panel, leaving about 134px for Jobs/Build. Screenshot `17_jobs_200.png` makes this visible.
