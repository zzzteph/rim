# Earlier decisions relevant to the city redesign

These notes support the consolidated root [CLAUDE_BRIEF.md](../CLAUDE_BRIEF.md). They were checked against this project's earlier user messages, all 19 Claude Markdown memory files, all 20 original repository Markdown design/review notes, and the latest requests in this conversation. The two documentation files created earlier in this conversation were also rechecked. Historical instructions are evidence of earlier choices; the latest user request controls conflicting behavior.

## Latest clarification: two connected maps

The user explicitly clarified that this is a merge of ideas already coded. Reuse the earlier city, production chains, catalog, transport, and shared quality systems, then extend them with component maps, cards, and access degradation. A smaller replacement prototype does not fulfill that intent.

The user's latest explanation supersedes the earlier radius-based draft:

- City size is configurable from 10×10 to 100×100; the exact grid unit is not settled.
- SimCity/Constructor describe the physical city; Stellaris describes buildings as systems containing a second, local map.
- Scanning a building discovers external connections. Entering it shows one initial component; scanning local components progressively discovers connected components.
- Hack individual components using resource-funded technique cards. One captured component establishes a foothold for onward expansion, without requiring a program. Every actual component captured means full building control.
- Initial component kinds/slots: IoT 2, web server 4, file server 4, database 6, PC 6.
- Component specialties affect installed output: IoT favors CPU/Cycles, databases favor Intel. Other specialties and exact bonuses are unspecified.
- Installation slots differ from supported workload. A database with six slots and Intel capacity 3 can fit load 4 but then degrades over time and can lose access, requiring rehacking.
- Cards include password/brute-force techniques and zero-day variants, with distinct powers and effects against relevant component defenses.
- The user subsequently proposed research for more powerful cards, then identified three areas to develop: vulnerability research, credentials, and phishing. Reuse the earlier Lab/Research economy for technique progression. This replaces the assistant's earlier two-branch recommendation. Resource emphases, example card tiers, human-facing PC eligibility/direct capture for phishing, and supporting efficiency/reconnaissance/stability upgrades are recommendations, not previously settled tuning. Preserve the existing Phishing Intel-producing program separately from phishing attack cards.
- Programs generate value that genuinely flows to the hub. Discovered connections and resource-flow feedback are now part of the requested presentation.

## Earlier decisions still applicable

Preserve 2D/unseen-operator play; a continuous architectural city; one New Game/Continue experience; meaningful production chains and the six resource roles; installation inside existing systems; readable fixed left inspector; large text/accessibility; remove/disable/output/undo controls; accurate delivery and processor inputs; measured performance; atomic validated saves; bounded recovery; and the Windows export/fresh-launch workflow.

Earlier general requests for resource-funded hacking now apply through attack cards. Multiple programs now occupy slots on individual captured components rather than one building-wide pool. The latest configurable size replaces fixed100×100, while the earlier city generator remains useful.

## Earlier rules replaced by the latest explanation

| Earlier draft or prototype | Current direction |
|---|---|
| Required radius-only scans and spatial-only expansion | Discovered inter-building links plus progressive local component links |
| All connection/flow overlays hidden | Connections discovered by scanning; real flow on known operational links |
| One interior scan reveals all installable targets | Local schematic starts with one component and is explored progressively |
| Hack/capture the whole building as one action | Use technique cards to capture individual components |
| Installed content required before expansion | One captured component is enough, with no installed program required |
| Uniform whole-building slot pool | IoT/web/file/DB/PC component pools of 2/4/4/6/6 slots |
| Fixed100×100 map | Configurable10×10…100×100 |
| Building-wide affinity as the only bonus model | Component specialties/capacity; preserve earlier100%/50% intent while explicitly choosing its mapping to components |
| Slot availability guarantees safe production | Slots and supported workload differ; overload can degrade and lose access |

The earlier separated-plate presentation remains superseded by an adjoining city. Preventing plate overlap is a geometry correction, not a requirement for distant islands. Old statements that all graph-based scanning was discarded describe the earlier draft, not the newest hierarchical design.

## Implementation choices that are not settled agreements

Exact map units; global/local scan and attack frontiers; capacity units and per-resource/shared budgets; disabled-program load; degradation grace, rate, recovery and loss threshold; dormant versus removed programs after loss; deterministic versus probabilistic cards; bonus values; full-control rewards; and victory conditions all need explicit implementation choices.

The current brief offers labeled recoverable defaults: known-link expansion from a captured foothold, entry-component access followed by component progression, active programs contributing load, dormant installations after loss, and selectable deterministic cards for the first slice. These are recommendations, not claims about prior wording or final tuning.

## Review coverage and recovered lessons

The discussion review covered 111 user text records from the two Claude project logs, excluding tool results, task notifications, and local-command metadata. Short replies such as “A” or “continue” do not independently establish a mechanic; the design/memory chronology provides their context. Historical implementation claims and pass counts are not current verification.

Additional requirements recovered during the full review:

- Resource flow must represent real economy state, not an animation unrelated to delivered goods. Discovered-link flow preserves that rule.
- Retain remove/disable/output controls, actual converter inputs, exact paid-cost refunds, and access separate from production.
- Avoid the older long-path freeze. Intermediate storage was raised again as an open direction; a new storage subsystem is separate scope unless explicitly chosen.
- Keep early resource classes locally reachable instead of putting all useful Intel far away. Start on the Rim and expand toward richer targets.
- Keep research usable in a fitting tree/view rather than a clipped sidebar list.
- Use consistent rendering/hit geometry, circular checks for any retained production coverage, frontmost selection, immediate paused-state repaint, and discovery-aware minimap updates. This does not reintroduce radius-only exploration.
- Preserve modal focus/input isolation and recoverable pause state; verify rendered controls at large text sizes.
- Measure rendered FPS with comparable fixtures. Old figures and headless CPU timings do not establish new gameplay performance.
- Isolate probes from player saves/settings and preserve a live run after rejected loading.

## Inventory: repository design and review notes

All 20 original repository Markdown notes below were reviewed. Their classification describes their use in this redesign, not a claim that every historical finding remains reproducible.

| Source | Purpose and current use |
|---|---|
| `DESIGN.md` | Active description plus legacy changelog; recover useful work, replace obsolete scan/route rules |
| `GAME_DESIGN.md` | v0.5.2 snapshot; recover catalog/chains/city, verify exact numbers against current code |
| `GAP_ANALYSIS.md` | Genre proposal study; wider wishlist, not automatic scope |
| `review/README.md` | Review index and reproduction guidance; now points to the current root brief |
| `review/GAME_REVIEW.md` | v0.5.6 quality audit; historical evidence and preservation lessons |
| `review/REVERIFIED_REVIEW.md` | v0.5.8 recheck/proposals; old probes do not validate current Netrun |
| `review/PACING_REVIEW.md` | Progression/pacing hypotheses; no promised two-hour session or new objective |
| `review/REVERIFY_README.md` | Isolated-copy reproduction guidance and evidence limits |
| `review/reverify_design_findings.md` | Rule mismatches and candidates; distinguish chosen rules from proposals |
| `review/reverify_sim_findings.md` | Historical economy/state/recovery defects; preserve accounting and geometry |
| `review/reverify_ui_findings.md` | UI/input/accessibility findings; preserve focus, scaling, and click safety |
| `review/audit_v064_2026-10-03/README.md` | Audit methods and snapshots through declared v0.6.7; distinguishes evidence types |
| `review/audit_v064_2026-10-03/REVIEW.md` | Historical 100-item audit; not a mandate for the entire backlog |
| `review/audit_v064_2026-10-03/CLAUDE_BRIEF.md` | Earlier handoff; graph frontier, empty-host expansion, and small prototype superseded |
| `review/audit_v064_2026-10-03/findings/ui_panels_summary.md` | Panel overflow/focus evidence; relevant preservation checks |
| `review/audit_v064_2026-10-03/findings/ui_controls_summary.md` | Modal/menu/inspector focus and readable-action evidence |
| `review/audit_v064_2026-10-03/findings/quality_review.md` | Audit classification/evidence quality and synthetic limits |
| `review/audit_v064_2026-10-03/probes/V066_TRIAGE.md` | Concurrent-source recheck; historical pass counts rather than new verification |
| `review/audit_v064_2026-10-03/probes/SIMULATION_SUMMARY.md` | Save/restore, real economy, and recovery evidence |
| `review/audit_v064_2026-10-03/probes/HUD_SUMMARY.md` | Later HUD recheck; text clipping, warning timing, and load-message lessons |

## Inventory: Claude project memory notes

All 19 Markdown files in the memory directory were reviewed. They are historical project notes rather than higher-priority instructions.

| File | Preserve, adapt, or defer |
|---|---|
| `MEMORY.md` | Index; interpret historical “locked” labels against newer user decisions |
| `game-concept.md` | 2D/unseen operator, generated city, Rim start, resource cost ladder; older restrictions superseded |
| `game-first-priority.md` | Fun, direct controls, and recoverability |
| `resource-set.md` | Six resource roles/chains; extra commands/topology remain later work |
| `netrun-prototype.md` | Host/access/install separation and real economy; single-level scans, single payloads, small separate mode superseded |
| `netrun-city-hosts.md` | Architecture/multiple programs remain useful; whole-building capture and separated plates must become component-based play |
| `ui-readability.md` | Large defaults and maximized window; latest city references control styling |
| `ui-panel-fixed-width.md` | Stable left inspector, wrapped content, clickable actions, map-input protection |
| `accessibility-phase1.md` | Low-vision settings, non-color cues, pause-to-plan, undo; roadmap is context |
| `gameplay-rules-v061.md` | Applicable honest costs/inputs, enabled-state rules, geometry, palette/focus, state transitions |
| `persistence-recovery.md` | Validated atomic saves/backups and bounded recovery; adapt reserve |
| `performance-levers.md` | Culling, detail levels, cache/redraw controls, equivalent benchmarks |
| `render-to-png-for-inspection.md` | Visual inspection; adapt legacy harness/scene to active game |
| `always-build-and-run.md` | Clean checks, Windows export, and fresh launch after implementation |
| `godot-install-path.md` | Recorded engine location; verify availability |
| `versioning-scheme.md` | Single-digit carry; read current version before bumping |
| `agent-fleet-roadmap.md` | Recover implemented UI/performance work; remaining proposals are not automatic scope |
| `gap-analysis-roadmap.md` | Proposal/status history; later notes supersede stale missing-feature claims |
| `improvements-backlog.md` | Applicable later quality work; old assertion totals are historical |

## Source locations

- Project Claude discussions: `C:/Users/steph/.claude/projects/C--Users-steph-Documents-GitHub-rim/3485bf28-a4ff-4fcc-aae4-b8e827a9570e.jsonl` and the shorter `2e316d21-8aed-4610-84ae-22a3d62808f0.jsonl`. Only user text was used as discussion evidence; tool outputs and task notifications were excluded.
- Project Claude memory directory: `C:/Users/steph/.claude/projects/C--Users-steph-Documents-GitHub-rim/memory/`. Relevant files include `game-concept.md`, `netrun-city-hosts.md`, `resource-set.md`, `ui-panel-fixed-width.md`, `ui-readability.md`, `persistence-recovery.md`, `always-build-and-run.md`, and `versioning-scheme.md`.
- Repository: `DESIGN.md`, `GAME_DESIGN.md`, and `review/audit_v064_2026-10-03/CLAUDE_BRIEF.md`. These have different ages; verify mechanics against current code instead of treating old success reports as current test results.
