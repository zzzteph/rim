# Simulation audit, RIM v0.6.4, 3 October 2026

20 distinct findings: 16 bugs and 4 improvements. Findings are in `../findings/simulation.json`.

The prior v0.5.9 intended-behavior assertion suite was copied unchanged into the isolated current project and run headlessly: **50 passed, 0 failed**. These checks cover earlier recovery, roundtrip, live-run corruption refusal, backup fallback, upward stale routes, disabled forwarding/upkeep, and related fixes. Earlier fixed defects were not listed as current.

New probes use a frozen v0.6.4 copy under `simulation_project`, with save/settings paths redirected to files inside that copy. Production scripts, scenes, project settings and existing review files were not modified. Probe scripts instantiate the real production Main with a Camera2D and suppress per-frame processing; they drive production APIs and simulation ticks. These are targeted headless tests, not a visual game playthrough or real-world hacking.

The strongest current failure is a partially malformed JSON save: a path point `[1]` passes validation, then applying it clears live nodes and fails indexing the missing second coordinate. `load_game()` still returns true and says `Game loaded.`; the fixture leaves only C2. See `corrupt_save.log` and `corrupt_save_results.json`.

Another save test creates a valid backup, writes parseable invalid JSON to the current save, and saves the active run. The formerly valid backup becomes unusable because rotation verifies only JSON parsing.

Contract reproduction uses two **legally placed** Mirai from the normal seed12345 opening, then a controlled offer that matches an allowed generated Cycles20 contract. Accepting after placement and undoing both completes the job despite zero packets delivered. The offer was selected by the fixture rather than encountered randomly in a full playthrough.

All other geometry/economy fixtures are synthetic isolated arrangements. In particular, the ICE boundary test moves C2 to isolate reachability, the slot test uses an artificial two-slot district, and capacity/topology/fuel scenarios inject explicit nodes. Their results establish individual rules; they do not claim the fixture layout or parameters arose through legal uninterrupted play. The malformed-save probes deliberately modify only audit save files.

Selected results: stale downward packets survive a changed downstream parent; an unfuelled Forge injects modeled traffic1.2/s but emits no work; 0%-output Cycles production suppresses emergency reserve; active transit through a disabled TCP source has upkeep but no TCP noise; guarded-center/unguarded-origin footprint pays0 Tools; three Mirai fit a counted two-slot district; disabled/offline Overclock spends20 Cycles; equal-depth sweep target changes2→10 through JSON roundtrip ordering.

Soft-cap throughput, Undo grace periods, wallet-linked saturation and queued processor work are expressly labeled design improvements, not asserted defects of unconfirmed design intent.
