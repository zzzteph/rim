# Implementation guidance for Claude

Use `BACKLOG_100.json` and `REVIEW.md` as the review brief. They contain 100 selected bugs/improvements with evidence, source anchors and completion checks. Treat them as versioned findings; check the current code before implementing because concurrent changes already addressed some earlier candidates.

Work in small reviewable tranches:

1. Protect the run: atomic save loading, full state/graph validation, checked backup rotation and correct world/minimap refresh after load.
2. Repair interaction: trap and restore modal keyboard focus; make palette, tabs, HUD, warning space and victory actions usable at every supported text scale from 100% to 200%.
3. Make feedback truthful: rerouted packets in both directions, actual contract-delivery accounting, active traffic/fuel behaviour, roof hit targets, route-preview validity/cost, and diagnostic alert navigation.
4. Improve performance against equivalent fixtures: batch/cull the city, cache host/route geometry, refresh UI/chart values only when their data changes, then improve visibility and packet lookups. Keep synthetic stress results separate from real campaign measurements.

For the game redesign, coordinate with the Netrun prototype that appeared after the audit cutoff. Check its current implementation, then establish only this base first:

- The city is visible, with connected hosts. A host's contents are unknown until scanned.
- Start with one host where the player already has persistence.
- Scan graph-adjacent hosts from a persistent host. Reveal type, security, organization and compatible payloads.
- Hack an eligible discovered host and gain persistence. Show acquired access clearly on the existing host.
- Install an existing producer/processor as a payload. Show its output, input requirements and upkeep before commitment.
- Persistence alone enables scanning farther; installing a payload is optional and separate.
- Several hosts belong to one organization. Start with 3–5 hosts and 1–2 organizations, and one working resource chain.

Keep controls direct: selecting a host opens its current state and relevant next action. Provide Scan, Hack, gain Persistence and install Payload steps as they become available. Use the same identity in the map, inspector, alerts and minimap. Keep critical actions visible before flavour text.

Verify the full starter sequence and supported text scales in the rendered game. Run the existing regression checks and any targeted check needed for the actual change. Report what changed, the evidence and limitations. Establish this playable base before expanding the progression systems.
