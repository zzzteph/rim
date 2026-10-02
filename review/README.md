**RIM review artifacts**

Latest: [v0.5.8 reverified review and 100 improvements](REVERIFIED_REVIEW.md), [162-row sortable backlog](REVERIFIED_BACKLOG.csv), [100 improvements](REVERIFY_100_IMPROVEMENTS.csv), and [reproduction instructions](REVERIFY_README.md). The earlier artifacts below are preserved as the v0.5.6 review.

Read [GAME_REVIEW.md](C:/Users/steph/Documents/GitHub/rim/review/GAME_REVIEW.md) for the full assessment and [REVIEW_BACKLOG.csv](C:/Users/steph/Documents/GitHub/rim/review/REVIEW_BACKLOG.csv) for its 120 sortable entries.

The probes use Godot 4.7.2 and the separate project in review/snapshot. Production scripts and scenes were copied without gameplay fixes. In that copy only, Session.SAVE_PATH and Settings.PATH point to res://review_save.json and res://review_settings.json. Do not redirect them back to user:// when running these probes.

The simulation probe creates controlled network fixtures, exercises serialization and in-place loading, and also builds a legal three-Market/one-DNS opening before a fresh Continue. Synthetic load fixtures verify formulas and state transitions rather than proving an end-to-end legal large-network build. UI probes inspect actual Control layouts and input/focus behavior; they do not provide rendered screenshots or human usability results.

From the repository root in PowerShell:

```powershell
& 'C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64.exe' --headless --editor --path 'review\snapshot' --import --quit --log-file 'C:\Users\steph\Documents\GitHub\rim\review\ui_import.log'
& 'C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64.exe' --headless --path 'review\snapshot' --script 'C:\Users\steph\Documents\GitHub\rim\review\probes\simulation_probe.gd' --log-file 'C:\Users\steph\Documents\GitHub\rim\review\simulation_probe.log'
& 'C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64.exe' --headless --path 'review\snapshot' --script 'C:\Users\steph\Documents\GitHub\rim\review\probes\ui_probe.gd' --log-file 'C:\Users\steph\Documents\GitHub\rim\review\ui_probe_final.log'
& 'C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64.exe' --headless --path 'review\snapshot' --script 'C:\Users\steph\Documents\GitHub\rim\review\probes\ui_interactions.gd' --log-file 'C:\Users\steph\Documents\GitHub\rim\review\ui_interactions.log'
```

Import first if rebuilding the snapshot, so the Glyphs global class is registered. Use a corresponding local Godot path on another machine and change only the artifact paths.

These are defect reproduction probes. Their printed results record current faulty behavior rather than treating that behavior as a passing regression assertion. After fixes, convert the relevant observations into assertions for the intended rules.

simulation_results.json contains the compact simulation observations. The UI logs include viewport/control rectangles, effective fonts, selection, focus, modal and drag results. source_hashes.json identifies the inspected production scripts; source_manifest.json records snapshot parity. The source project version is 0.5.6 at review completion.

The runner's certificate-store warning is environmental. It did not prevent completed probes and is not part of the bug count. An initial exploratory UI run failed before class registration and was discarded; the final retained UI probes completed successfully.

