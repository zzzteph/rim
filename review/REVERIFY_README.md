# Reproduce the v0.5.8 re-verification

The final deliverables are [REVERIFIED_REVIEW.md](REVERIFIED_REVIEW.md), [REVERIFIED_BACKLOG.csv](REVERIFIED_BACKLOG.csv), and [REVERIFY_100_IMPROVEMENTS.csv](REVERIFY_100_IMPROVEMENTS.csv). The report retains all 50 earlier finding IDs, adds 12 findings, and contains exactly 100 improvement proposals. Specialist candidate lists overlap and are not extra backlog entries.

The inspected production version is 0.5.8. `reverify_source_manifest.json` records source hashes; `reverify_summary.json` records counts. `reverify_catalog.py` regenerates the final Markdown, CSV and JSON artifacts and verifies that production source matches the recorded hashes. It changes review files only:

```powershell
python review/reverify_catalog.py
```

All engine probes use copies of the current scripts/scenes. Production saves and settings were not opened. Keep copied `Session.SAVE_PATH` and `Settings.PATH` redirected to `res://` files in these copies; do not point them to `user://`. The previous `review/snapshot` and prior probe output remain historical and were not used as current runtime evidence.

Use the local Godot executable below, or substitute its path on another machine. Import each isolated project before running scripts so the `Glyphs` global class is registered. Specify a log file inside the workspace. From the repository root:

```powershell
$reviewEngine = 'C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64.exe'
$reviewWorkspace = (Get-Location).Path

& $reviewEngine --headless --editor --path 'review/reverify_current' --import --quit --log-file "$reviewWorkspace/review/reverify_current_import.log"
& $reviewEngine --headless --path 'review/reverify_current' --script "$reviewWorkspace/review/reverify_current_probe.gd" --log-file "$reviewWorkspace/review/reverify_current_probe.log"

& $reviewEngine --headless --editor --path 'review/reverify_sim' --import --quit --log-file "$reviewWorkspace/review/reverify_sim_import.log"
& $reviewEngine --headless --path 'review/reverify_sim' --script "$reviewWorkspace/review/reverify_sim/simulation_probe.gd" --log-file "$reviewWorkspace/review/reverify_sim_base.log"
& $reviewEngine --headless --path 'review/reverify_sim' --script "$reviewWorkspace/review/reverify_sim/extra_probe.gd" --log-file "$reviewWorkspace/review/reverify_sim_extra.log"

& $reviewEngine --headless --editor --path 'review/reverify_ui/project' --import --quit --log-file "$reviewWorkspace/review/reverify_ui/import.log"
& $reviewEngine --headless --path 'review/reverify_ui/project' --script "$reviewWorkspace/review/reverify_ui/project/ui_reverify.gd" --log-file "$reviewWorkspace/review/reverify_ui/engine.log"
```

Results are retained in `reverify_current_results.json`, `reverify_sim_base_results.json`, `reverify_sim_extra_results.json`, and `reverify_ui/project/results.json`. The corresponding scripts and logs explain fixtures. Engine exit status alone is insufficient: inspect for script errors and confirm the expected result records were emitted.

These probes reproduce defects. They do not assert that present faulty behavior is correct. The report's acceptance criteria describe intended behavior to implement and turn into regression assertions later. UI checks inspect layout rectangles and dispatch/focus state; culling checks use constructed geometry. They do not establish human usability, rendered screenshot correctness, natural-route prevalence or GPU performance.

The sandbox's certificate-store diagnostic and attempted editor-settings writes are environmental. They are excluded from game findings. Final probe runs completed and wrote their expected output. Early exploratory failures are not used as supporting evidence.

To review a later source revision, create fresh isolated copies and a new manifest, re-run the relevant probes, and update classification and acceptance criteria. Do not label the retained v0.5.8 results as runtime evidence for a later build.
