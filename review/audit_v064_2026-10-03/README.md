# Audit artifacts

Open `AUDIT_VIEWER.html` locally for searchable/filterable100 findings and screenshots. `REVIEW.md` includes methods, performance limits and the complete review. `BACKLOG_100.csv` works in a spreadsheet; `BACKLOG_100.json` preserves structured evidence and acceptance checks. `ADDITIONAL_CANDIDATES.json` holds27 deferred/merged records outside the main count.

`source/` freezes the initial v0.6.4 production snapshot; `source_v065/` freezes the concurrent v0.6.5 update. `source_latest/` is the final authoritative snapshot declaring v0.6.7; its production hashes are in source_latest_manifest.json. Intermediate files named v066 label the capture stage, not a claim about the declared release version. Copies redirect save/settings paths into their own projects so probes cannot alter the user's real save. Manifests record production hashes before redirection. Sub-agent projects are also isolated. The audit did not edit production code.

Evidence:

- `playthrough.json`, `playthrough_engine.log`, `screenshots/01..20`: real rendered input-driven legal opening and settings/tabs. No full campaign claimed.
- `interface_states*.json`, `screenshots/25..29`, `screenshots_latest/25..29`: controlled UI/threat/victory fixtures. Latest files recheck the compact header and queue implementation.
- `probes/simulation_results.json`, `probes/corrupt_save_results.json`, `probes/corrupt_save.log`: new simulation/save probes.
- `probes/t99_v066_results.json`: prior regression suite50PASS/0FAIL; fixed old issues not recounted.
- `probes/hud_v066_results.json`: latest message FIFO, restore, repeated-message and layout checks.
- `panels_project/`: build/research/jobs and modal/inspector keyboard/geometry probes.
- `map_project/`: roof target, stale preview and Proxy upkeep probes.
- `performance_results.json`: headless CPU measurements; `render_results.json`: fixed-camera local renderer/UI observations with clearly labelled synthetic dense fixtures.
- `discarded_*`: harness development attempts, excluded from findings and metrics.

Reproduction on this Windows workspace uses Godot4.7.2 at `C:/Users/steph/Downloads/godot/Godot_v4.7.2-stable_win64_console.exe`. From the repository root, import the isolated project before scripts:

```powershell
$auditGodot = 'C:/Users/steph/Downloads/godot/Godot_v4.7.2-stable_win64_console.exe'
$auditProject = 'C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/source'
& $auditGodot --headless --path $auditProject --editor --import
& $auditGodot --headless --path $auditProject --script 'C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/probes/performance.gd'
& $auditGodot --path $auditProject --script 'C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/probes/playthrough.gd'
& $auditGodot --path $auditProject --script 'C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03/probes/render_benchmark.gd'
```

The rendered playthrough uses actual pointer position/input and needs an undisturbed cursor; synthetic render probes disable native game edge-pan to keep the camera stable. Playthrough generates an isolated save used by the subsequent UI-state probe. Running probes overwrites audit result files, never production save/settings files. Scripts contain this machine's absolute output paths. To rebuild the consolidated artifacts after reviewing candidate edits: `python review/audit_v064_2026-10-03/probes/build_report.py`.
