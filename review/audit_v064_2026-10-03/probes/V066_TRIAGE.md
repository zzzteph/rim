# Concurrent v0.6.6 update triage

The parent requested a narrow check of simulation and HUD findings after concurrent main/UI/menu changes. Latest production files were read and copied only into existing isolated audit projects. Session/settings redirection was preserved; no production files were edited.

**None of this specialist's retained simulation/HUD findings was resolved.** The previous assertion suite again passed **50 checks, 0 failures**. Results: `t99_v066_results.json`.

The full existing simulation probe was rerun without expanding the hunt. Its results are unchanged: `simulation_v066_results.json`. Reachable-resource contract gating and Decline do not change the net-stock progress calculation or the demonstrated refund completion. The new operational-state helper does not change fuel checks, Overclock eligibility, emergency income detection or quarantine-clearing behavior.

The existing current HUD probe also ran successfully: `hud_v066_results.json`. Compact header clipping, rate/legend overlap, missing Research in Stats, identical/same-frame message loss, FIFO critical warning delay, old timeline messages after Load, hidden planning pause, overload navigation selection and aggregate quarantine labeling remain.

The sweep warning now includes countermeasure explanation text. This addition is recognized as implemented; contextual navigation is still absent. The measured headline text width increased from 325 to 988 px at 100% text, extending from x=300 toward x=1288 and still intersecting the alert buttons at x=924, y=70. This strengthens the existing warning-layout finding rather than creating another entry.

The new `_rerouting` transient was observed not being explicitly reset by `_apply_save`, but normal tool selection resets it. No player-facing exploit was established in this narrow triage, so it was not promoted to a finding.
