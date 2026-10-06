import collections
import copy
import csv
import difflib
import hashlib
import html
import json
import re
from pathlib import Path

AUDIT = Path(__file__).resolve().parents[1]
WORKSPACE = AUDIT.parents[1]
SNAPSHOT = 'source_latest'
VERSION = re.search(r'config/version="([^"]+)"', (AUDIT / SNAPSHOT / 'project.godot').read_text(encoding='utf-8')).group(1)
FILES = ['simulation.json', 'ui_controls.json', 'ui_panels.json', 'hud_stats_alerts.json', 'ui_map.json', 'performance_render.json', 'design.json']
EXCLUDED = {
    'D-OPERATOR-ACKNOWLEDGEMENT': 'Deferred accessible operations-history proposal; v065 already has an internal12-message history. Corrected observation retained in candidates.',
    'D-CONTRACT-ROTATION': 'Implemented in the final snapshot: contract Decline removes unwanted offers and advances refresh cooldown. Removed from the main count.',
    'D-CONTRACT-ELIGIBILITY': 'Implemented in the final snapshot: stock offers filter through connected enabled output resources. Remaining deadline/rate balance is retained separately.',
    'D-COVERAGE-AFFINITY': 'Deferred host-affinity balance change after the discovery prototype.',
    'D-MIXER-DIVERSIFICATION': 'Deferred optional economy balance experiment.',
    'D-OVERCLOCK-RETURN': 'Operating-cost context covered by UI-CONTROLS-14; charging unusable producers covered by SIM17.',
    'D-SWEEP-TARGETING': 'Deferred threat-selection experiment until threat feedback is legible.',
    'SIM03': 'Merged numeric invariants into SIM02.',
    'SIM04': 'Merged schema compatibility and researched IDs into SIM01.',
    'SIM18': 'Deferred Undo economic-policy decision; free temporary production may be intentional in a planning game.',
    'SIM20': 'Deferred policy clarification for in-flight inputs; do not call a currently unspecified rule a bug.',
    'HUD08': 'Merged adaptive chart scaling into HUD07.',
    'HUD14': 'Deferred separate DDoS discoverability proposal; retained SIM16 also includes its cost/access context as a follow-up.',
    'UI-CONTROLS-03': 'Deferred saved-run preview.',
    'UI-CONTROLS-02': 'Implemented in the final snapshot: Accessibility is available from the startup menu, with a live preview. Removed from the main count.',
    'UI-CONTROLS-10': 'Deferred empty-save affordance.',
    'UI-CONTROLS-11': 'Deferred settings explanatory copy.',
    'UI-CONTROLS-12': 'Deferred direct text-scale selector after layouts work at every existing scale.',
    'UI-CONTROLS-15': 'Deferred limit-button polish.',
    'UI-CONTROLS-18': 'Deferred separate contextual-action proposal; HUD11 includes upgrade/reroute affordances as follow-up work after selecting the diagnostic link.',
    'UI-PANELS-07': 'Deferred Proc abbreviation polish.',
    'UI-PANELS-08': 'Deferred armed-tool switching convenience.',
    'UI-PANELS-12': 'Merged locked-card cost visibility into UI-PANELS-13.',
    'UI-PANELS-14': 'Deferred research sorting polish.',
    'UI-PANELS-18': 'Merged sub-second deadline formatting into UI-PANELS-20.',
    'UI-PANELS-19': 'Merged deadline urgency into UI-PANELS-20.',
    'MAP15': 'Deferred cosmetic reverse-packet trail defect; movement itself is not claimed incorrect.',
}

all_items = []
for name in FILES:
    entries = json.loads((AUDIT / 'findings' / name).read_text(encoding='utf-8'))
    for item in entries:
        item = copy.deepcopy(item)
        item['specialist_file'] = 'findings/' + name
        item['category'] = {
            'simulation.json': 'Simulation and saves', 'ui_controls.json': 'Menus and inspector',
            'ui_panels.json': 'Build, research and jobs', 'hud_stats_alerts.json': 'HUD, Stats and alerts',
            'ui_map.json': 'Map and minimap', 'performance_render.json': 'Rendering and performance',
            'design.json': 'Game design',
        }[name]
        all_items.append(item)

by_key = {x['key']: x for x in all_items}
assert len(by_key) == len(all_items) == 127

# Independent review: observed behaviour alone does not establish a broken design contract.
by_key['UI-PANELS-02']['kind'] = 'improvement'
by_key['UI-PANELS-02']['title'] = 'Offer an immediate visible preview of palette tool details'
by_key['UI-PANELS-02']['evidence_level'] = 'source_confirmed'
by_key['UI-PANELS-02']['evidence'] += ' The existing delayed tooltip already exposes full help; this proposal improves presentation rather than claiming hover help is absent.'
by_key['UI-PANELS-02']['impact'] = 'A player must wait for the tooltip; the existing immediate inspector-preview assignment is invisible while the build palette is open.'
by_key['SIM17']['kind'] = 'improvement'
by_key['SIM17']['title'] = 'Prevent or explain Overclock spending on currently unavailable producers'
by_key['SIM17']['evidence'] += ' Spending on an unavailable target is verified, but requiring a live target or queuing a boost is a design choice, not an established forbidden operation.'
by_key['UI-CONTROLS-20']['evidence'] = by_key['UI-CONTROLS-20']['evidence'].replace('two legal same-type node fixtures', 'a controlled two-node same-type UI fixture')
by_key['UI-PANELS-16']['reproduction'] = 'Accept an Add N linked structures job, convert an unlinked producer to Proxy, then link it. Compare the visible connection with unchanged job progress; converting an already-counted producer alone is not the add-structure reproduction.'

def append(key, field, value):
    by_key[key][field] += ' ' + value

append('SIM01', 'evidence', by_key['SIM04']['evidence'])
append('SIM01', 'recommendation', 'Declare supported save-schema versions, migrate known older versions and validate researched IDs before committing a temporary restored state.')
append('SIM01', 'acceptance', 'Unsupported schemas and unknown researched IDs produce a clear error rather than a later lookup failure; supported legacy schemas migrate correctly.')
append('SIM02', 'evidence', by_key['SIM03']['evidence'])
append('SIM02', 'recommendation', 'Require finite bounded numeric values, a next_id above all existing IDs, valid camera zoom, footprint bounds and sizes, and valid output/timer/lane values.')
append('SIM02', 'acceptance', 'Reject colliding next_id, zero/invalid zoom and impossible numeric state before application; normal generated saves remain valid.')
by_key['SIM02']['title'] = 'Saved network topology, identities and numeric state are insufficiently validated'
append('HUD07', 'recommendation', 'Use an adaptive early-game range with an explicit goal marker so small improvements remain visible; label the chosen range.')
append('HUD07', 'acceptance', 'Early Cash changes are discernible and the player can tell the displayed time span and value range.')
append('SIM16', 'recommendation', 'Expose the recovery command beside quarantine/trace alerts, with cost, cooldown and affordability, rather than relying on discovery inside Stats.')
append('SIM16', 'acceptance', 'A quarantined player can find the command and predict its actual effect and cost before using it.')
append('HUD11', 'recommendation', 'Provide contextual upgrade/reroute actions and show the expected capacity/cost change from the selected diagnostic tunnel.')
append('UI-PANELS-13', 'recommendation', 'Show the Research price even when a prerequisite locks the card, alongside the named prerequisite and current balance.')
append('UI-PANELS-13', 'acceptance', 'Prerequisite-locked cards expose their price, and insufficient-balance cards expose the precise deficit.')
append('UI-PANELS-20', 'recommendation', 'Show a consistent positive countdown until expiry, then an explicit expired state; add labelled urgency for near deadlines without relying on colour alone.')
append('UI-PANELS-20', 'acceptance', 'Accepted jobs are easy to locate, never display expired-looking zero while still active, and clearly distinguish urgent, expired and claimable states.')

by_key['D-OPERATOR-ACKNOWLEDGEMENT']['evidence'] = 'v065 UI has an internal capped12-message _msg_history and a pending display queue. History is not exposed to players; same-frame/repeated-string events can be lost and urgent events can wait behind routine feedback (HUD15/16).'
by_key['D-OPERATOR-ACKNOWLEDGEMENT']['source'] = 'scripts/ui.gd:803'
by_key['D-OPERATOR-ACKNOWLEDGEMENT']['source_snapshot'] = 'v0.6.5'
by_key['D-HOST-DISCOVERY']['recommendation'] = ('Build the smallest accepted base: start on one persistent host in a visible city with unknown contents. Scan graph-adjacent hosts; reveal host type, security and compatible payloads. Hack one eligible host and gain persistence. Install an existing producer/processor as a payload on that host; its output supplies information/resources. Persistence, rather than installing a payload, enables the next adjacent scan. Group several hosts into one named organization. Prototype3-5 hosts and1-2 organizations before extending the economy.')
by_key['D-HOST-DISCOVERY']['acceptance'] = ('A fresh run completes scan -> reveal -> hack -> persistence -> optional payload -> scan further in five minutes. Unknown host interiors stay hidden; nonadjacent targets cannot be scanned; a newly persistent empty host can reveal its neighbours. Organization membership is legible, and acquisition/production have separate states.')
append('D-HOST-DISCOVERY', 'evidence', 'This observation concerns the existing main game mode in the frozen snapshot. A separate Netrun prototype appeared after the cutoff and was not inspected or played in this review; check that work before implementing the proposal.')

# Source rechecks account for the concurrent menu/contract/reroute/state additions.
current_anchors = {}
for file, groups in [('v066_ui_triage.json', ['selected_controls', 'selected_panels']), ('v066_design_map_triage.json', ['design', 'map'])]:
    triage = json.loads((AUDIT / 'findings' / file).read_text(encoding='utf-8'))
    for group in groups:
        for entry in triage.get(group, []):
            if entry.get('current_source'):
                current_anchors[entry['key']] = entry['current_source']
            if entry['key'] in by_key and entry.get('notes'):
                append(entry['key'], 'evidence', 'Final source recheck: ' + entry['notes'])
by_key['UI-CONTROLS-16']['title'] = 'The inspector lacks actual throughput and delivery rates'
by_key['UI-CONTROLS-16']['evidence'] = 'Baseline inspector reports nominal generation/processor recipe values rather than measured delivery. The final snapshot adds operational-state labels and effective tunnel admission capacity; those improvements are credited. Actual per-host throughput, deliveries and losses still require inference from packet motion and stock changes. Baseline UI evidence is controlled; current persistence is source-rechecked.'
by_key['D-CONTRACT-DEADLINE-BALANCE']['evidence'] = 'The final snapshot filters stock offers by reachable output resources and allows Decline. Offer amount/deadline selection still does not budget for current production rate, input availability or end-to-end route latency. This is a balance proposal, not a recorded campaign deadline failure.'
append('HUD03', 'evidence', 'Final HUD rerun measured expanded countermeasure headline988px at100% (previous325px); the overlap persists and is stronger. Evidence: probes/hud_v066_results.json and screenshots_latest/25_alerts_100.png.')
for x in all_items:
    if x['specialist_file'] in ['findings/simulation.json', 'findings/hud_stats_alerts.json']:
        append(x['key'], 'evidence', 'The retained behaviour was rechecked in the final code snapshot; stage-named results are probes/simulation_v066_results.json and probes/hud_v066_results.json.')

line_maps = {}
for base in ['source', 'source_v065']:
    line_maps[base] = {}
    for name in ['ui.gd', 'main.gd', 'minimap.gd', 'graph.gd', 'menu.gd', 'city_layer.gd']:
        old = (AUDIT / base / 'scripts' / name).read_text(encoding='utf-8').splitlines()
        new = (AUDIT / SNAPSHOT / 'scripts' / name).read_text(encoding='utf-8').splitlines()
        mapping = {}
        for op, a, b, c, d in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
            for i in range(a, b):
                mapping[i + 1] = (c + (i - a) + 1) if op == 'equal' else min(len(new), c + 1)
        line_maps[base][name] = mapping

for x in all_items:
    source = current_anchors.get(x['key'], x['source'])
    if x['key'] not in current_anchors:
        base = 'source_v065' if x['specialist_file'] in ['findings/hud_stats_alerts.json', 'findings/performance_render.json'] or x.get('source_snapshot') == 'v0.6.5' else 'source'
        m = re.fullmatch(r'scripts/(\w+\.gd):(\d+)', source)
        if m and m.group(1) in line_maps[base]:
            source = f"scripts/{m.group(1)}:{line_maps[base][m.group(1)].get(int(m.group(2)), int(m.group(2)))}"
    x['reviewed_source'] = SNAPSHOT + '/' + source
    x['current_validation'] = 'runtime_rechecked_latest' if x['specialist_file'] in ['findings/simulation.json', 'findings/hud_stats_alerts.json'] else 'source_rechecked_latest_with_labelled_baseline_runtime'

items = [x for x in all_items if x['key'] not in EXCLUDED]
assert len(items) == 100
assert set(EXCLUDED) <= set(by_key)
items.sort(key=lambda x: (int(x['priority'][1]), 0 if x['kind'] == 'bug' else 1, FILES.index(x['specialist_file'].split('/')[-1]), x['key']))
for number, x in enumerate(items, 1):
    x['id'] = f'RIM-{number:03d}'

required = ['key', 'title', 'kind', 'area', 'priority', 'evidence_level', 'evidence', 'source', 'reproduction', 'impact', 'recommendation', 'acceptance', 'effort']
for x in items:
    assert all(isinstance(x.get(k), str) and x[k] for k in required), x['key']
    assert x['kind'] in ['bug', 'improvement']
    assert x['evidence_level'] in ['verified_runtime', 'source_confirmed', 'proposal']
    m = re.fullmatch(r'(.+):(\d+)', x['reviewed_source'])
    assert m and (AUDIT / m.group(1)).is_file(), x['reviewed_source']
    assert int(m.group(2)) <= len((AUDIT / m.group(1)).read_text(encoding='utf-8').splitlines()), x['reviewed_source']

counts = {field: dict(collections.Counter(x[field] for x in items)) for field in ['kind', 'priority', 'evidence_level', 'category']}
metadata = dict(date='2026-10-03', reviewed_version='v' + VERSION, baseline_version='v0.6.4', total=len(items), counts=counts,
    scope='Read-only production review. Actual input-driven opening and UI playthrough on v064; source/UI and retained simulation findings rechecked in the final frozen snapshot. Controlled correctness and synthetic CPU/render fixtures are separately labelled.',
    production_edits_by_audit=False)
(AUDIT / 'BACKLOG_100.json').write_text(json.dumps(dict(metadata=metadata, findings=items), ensure_ascii=False, indent=2), encoding='utf-8')
with (AUDIT / 'BACKLOG_100.csv').open('w', newline='', encoding='utf-8-sig') as f:
    fields = ['id', 'key', 'priority', 'kind', 'category', 'area', 'title', 'evidence_level', 'effort', 'reviewed_source', 'evidence', 'reproduction', 'impact', 'recommendation', 'acceptance']
    writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(items)
additional = [dict(by_key[k], disposition=reason) for k, reason in EXCLUDED.items()]
(AUDIT / 'ADDITIONAL_CANDIDATES.json').write_text(json.dumps(additional, ensure_ascii=False, indent=2), encoding='utf-8')

def table(headers, rows):
    return '\n'.join(['| ' + ' | '.join(headers) + ' |', '| ' + ' | '.join(['---'] * len(headers)) + ' |'] + ['| ' + ' | '.join(map(str, r)) + ' |' for r in rows])

def item_link(key):
    x = by_key[key]
    return f"[{x['id']}: {x['title']}](#{x['id'].lower()})"

report = [
    '# RIM game, UX and performance audit — 100 findings', '',
    'Reviewed on 3 October 2026. **44 bugs and 56 improvements** are prioritized below. Bug findings identify incorrect existing behaviour; improvements identify proposed design, usability or optimization changes. Runtime verification, source confirmation and proposals are marked separately. This is not a claim of 100 reproduced bugs.', '',
    'Specialist agents covered simulation, game design, HUD/Stats/alerts, map/minimap, build/research/jobs, menus/settings/modals and inspector. The root reviewer ran the rendered playthrough, rendering benchmarks and consolidation. A separate agent reviewed classification, duplicates and evidence limits before publication. No production code was edited by this audit.', '',
    f'The workspace began at v0.6.4 and advanced through v0.6.5 to declared **v{VERSION}** during concurrent work. The final reviewed snapshot is source_latest, with a production-hash manifest. New pre-game accessibility, contract Decline/resource filtering, rerouting, operational states and effective capacity are credited; implemented recommendations were removed. Simulation/HUD probes and the 50-check regression suite ran again, other UI/map/design claims were source-rechecked, and fresh threat/victory/menu screens were rendered. Stage filenames containing v066 refer to the final capture stage; its project declares v{VERSION}.', '',
    '## What was played and measured', '',
    'The actual rendered opening used input events and verified mouse position: New Game (seed 1321476956), choose/deploy a legal Mirai, connect DNS to C2, let packets arrive for 12 real seconds, select/disable/enable the producer, open every sidebar tab, save/load, change text size through the real Settings buttons and exercise pause/accessibility displays. That opening used starting resources and produced 11 delivered packets at the 12-second checkpoint. It did not complete a full campaign.', '',
    'A separate Netrun prototype and its menu entry appeared after the frozen source_latest cutoff. The100 selected findings cover the existing main game and shared interface represented by that snapshot. The prototype is not included in played evidence, and the discovery proposal should be coordinated with its ongoing implementation.', '',
    'Screenshots 01–20 are this legal opening/UI session. Screenshots 25–29 use explicitly controlled threat/victory/UI states; fresh final-version captures are in screenshots_latest. Corruption, packet-rerouting and economy probes use isolated fixtures. Dense network and 3000-packet tests are synthetic stress scenarios, not legal economic playthroughs.', '',
    'The previous regression suite passed **50 assertions with 0 failures** on the baseline and again on the final snapshot. Already-fixed older issues were not counted. New probes produced separate evidence; no shipping-build FPS claim is made.', '',
    'Measured environment: Godot 4.7.2, OpenGL Compatibility, 1280×720, AMD Ryzen 5 5600H, NVIDIA RTX 3060 Laptop GPU. Render probes use fixed camera, VSync off, main._process disabled to remove external mouse/edge-pan interference, with world clock/redraw and 10Hz simulation ticks driven by the harness; UI runs normally. Frame intervals are local rendering/UI measurements. Headless microbench timings are CPU work only. Each dense fixture has the same camera before/after. Reported frame medians use 60 or 80 observations; they are short local samples.', '',
    table(['Fixture', 'Result', 'Meaning'], [
        ['Opening, paused', '2595 draw calls;11.99ms median frame interval', 'Retained world commands still render when no world redraw is requested'],
        ['Synthetic50/150/400 nodes, motion on', '30.89/86.15/119.89ms median', 'Local dynamic-render scaling; not a campaign FPS estimate'],
        ['Synthetic400 nodes, reduced motion', '35.97ms median;8094 draw calls', 'Command regeneration drops; dense retained geometry remains costly'],
        ['Synthetic400-node simulation', '~13ms per0.1s tick', 'CPU tick budget and catch-up deserve attention'],
        ['Synthetic400-node fog rebuild', '40.25ms mean', 'Node-set changes can spike synchronous work'],
        ['Synthetic3000 packets, winding route', '9.235ms mean movement;13.647ms p95', 'Repeated segment lookup scales with traffic'],
        ['Distant A* route preview', '6.41ms mean per search', 'Remaining synchronous hover work after existing heap/cache improvements'],
    ]), '',
    'See [performance_results.json](performance_results.json), [render_results.json](render_results.json), [playthrough.json](playthrough.json), [final simulation results](probes/simulation_v066_results.json), [final HUD results](probes/hud_v066_results.json) and [final regression results](probes/t99_v066_results.json). Discarded harness attempts are named discarded_* and are excluded from conclusions.', '',
    '## What to fix first', '',
    '1. Protect saved runs: make restore atomic, validate graph/numeric/schema state, preserve the valid backup and refresh the restored world. Fix blocking modal focus so keyboard actions cannot run behind Settings/pause dialogs.',
    '2. Make every existing screen usable at 100–200%: flowing palette cards, readable full tab names, responsive HUD rows, separate threat/alert space, and victory actions reachable by keyboard and pointer.',
    '3. Correct the network feedback players depend on: both packet directions after rerouting, contract deliveries counted from actual events, traffic based on active production, consistent roof hit targets and fresh route previews.',
    '4. Profile one optimization at a time against the retained fixtures: batch/cull the static city, cache host and route geometry, reduce unchanged UI work, then address fog and packet lookup. Preserve visual readability and compare equivalent scenes.',
    '5. Establish the smallest discovery base once the existing loop is reliable, coordinating with the new Netrun prototype: scan -> reveal -> hack -> persistence -> optional payload -> scan further. Use 3–5 connected hosts grouped into 1–2 organizations. Persistence itself extends scanning; a payload is a separate production choice. Keep host interiors unknown until scanned.', '',
    'The most useful interface changes are a short sustainable-Cycles checklist; host/resource/operating-cost details before committing; costs and deficits on cards; inspector actions above flavour text; active/claimable jobs above offers; alerts that select the actual failing tunnel or threatened branch; and a minimap showing access, selection and network health.', '',
    '## Count and coverage', '',
    table(['Area', 'Findings'], sorted(counts['category'].items())), '',
    table(['Evidence class', 'Findings'], sorted(counts['evidence_level'].items())), '',
    'P1 means first tranche because it risks runs, blocks interaction, prevents readable critical feedback or addresses the dominant experience/performance issue. P2 improves correctness or normal play. P3 is polish or a balance experiment. Design P1s are proposals, not emergency defects. EffortS/M/L is relative implementation size, not an estimate in days.', '',
    'Each item includes reproduction/context, impact, a concrete change and a check for completion. Related candidates were merged; 27 lower-priority, implemented or merged records are retained in [ADDITIONAL_CANDIDATES.json](ADDITIONAL_CANDIDATES.json), outside the 100-item count. Frozen source links preserve exact evidence even if the working tree changes again.', '',
    '## The 100-item backlog', '',
]
for x in items:
    report.extend([
        f"<a id=\"{x['id'].lower()}\"></a>",
        f"### {x['id']} · {x['title']}", '',
        f"**{x['priority']} · {x['kind']} · {x['evidence_level']} · effort {x['effort']}** — {x['area']}", '',
        f"**Evidence:** {x['evidence']}", '',
        f"**Reproduce/context:** {x['reproduction']}", '',
        f"**Player impact:** {x['impact']}", '',
        f"**Change:** {x['recommendation']}", '',
        f"**Done when:** {x['acceptance']}", '',
        f"**Source:** [{x['reviewed_source']}]({AUDIT.as_posix()}/{x['reviewed_source']}) · specialist key `{x['key']}`", '',
    ])
(AUDIT / 'REVIEW.md').write_text('\n'.join(report), encoding='utf-8')

payload = json.dumps(dict(metadata=metadata, findings=items), ensure_ascii=False).replace('</', '<\\/')
viewer = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RIM audit —100 findings</title><style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0b1017;color:#e8edf5;font:16px/1.5 system-ui,sans-serif}main{max-width:1160px;margin:auto;padding:24px}h1{font-size:clamp(26px,4vw,40px);line-height:1.15}a{color:#80c7ff}p{max-width:950px}.muted{color:#aebed0}.filters{display:flex;flex-wrap:wrap;gap:10px;margin:24px 0;position:sticky;top:0;padding:12px 0;background:#0b1017;z-index:2}input,select{font:inherit;border:1px solid#596c81;background:#152130;color:inherit;border-radius:6px;padding:10px}input{flex:1;min-width:200px}details{background:#121d29;border:1px solid#334a60;border-radius:8px;margin:12px 0}summary{padding:16px;cursor:pointer;display:list-item;margin-left:16px;font-weight:650}summary small{display:block;color:#b7c8da;font-weight:400;margin-top:5px}.detail{padding:0 22px 18px}.detail p{white-space:pre-wrap}.pill{background:#294d6a;padding:2px 7px;border-radius:4px;font-size:13px;margin-right:7px}.P1{background:#764032}.shots{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}figure{margin:0}img{width:100%;height:auto;border:1px solid#42566c}figcaption{font-size:14px;color:#bbccdd}button{font:inherit;padding:9px;background:#294d6a;color:white;border:1px solid#7895af;border-radius:6px}h2{margin-top:30px}table{border-collapse:collapse}td,th{padding:10px;border-bottom:1px solid#40546a;text-align:left}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto}}
</style><main><h1>RIM: 100 bugs and improvements</h1><p><strong>44 bugs · 56 improvements</strong> across game design, simulation, every major interface area and performance. Reviewed 3 October 2026, with v0.6.5 UI rechecks. Production code was not edited.</p><p class="muted">Evidence separates actual input-driven opening play, controlled correctness/UI fixtures, source inspection and design proposals. Dense-network benchmarks are synthetic stress tests, not full-campaign FPS. <a href="REVIEW.md">Full report and methods</a> · <a href="BACKLOG_100.csv">CSV backlog</a> · <a href="BACKLOG_100.json">JSON backlog</a></p><p>Start with atomic/validated saves, safe backup rotation, modal keyboard focus and 100–200% layouts. Then fix misleading network feedback and reduce rendering costs. The proposed discovery base is scan → reveal → hack → persistence → optional payload → scan further.</p><details><summary>Performance context and limits</summary><div class="detail"><p>Godot 4.7.2 / OpenGL Compatibility / 1280×720 / RTX 3060 Laptop / Ryzen 5 5600H. Fixed camera, VSync disabled. Rendering harness drives redraw/time and 10Hz ticks; UI runs normally. Headless timings are CPU work only.</p><table><tr><th>Fixture</th><th>Measured result</th></tr><tr><td>Paused opening</td><td>2595 draw calls; 11.99ms median interval</td></tr><tr><td>Synthetic 50 / 150 / 400 nodes, motion on</td><td>30.89 / 86.15 / 119.89ms median interval</td></tr><tr><td>Synthetic 400 nodes, reduced motion</td><td>35.97ms median interval</td></tr><tr><td>Synthetic 400-node fog rebuild</td><td>40.25ms mean CPU</td></tr><tr><td>Synthetic 3000 packets</td><td>9.235ms mean movement CPU</td></tr></table></div></details><details><summary>Rendered interface evidence</summary><div class="detail shots">
<figure><a href="screenshots/06_selected_producer.png"><img loading="lazy" src="screenshots/06_selected_producer.png" alt="Legal opening with a selected producer and inspector"></a><figcaption>Actual legal opening / inspector, baseline v064</figcaption></figure>
<figure><a href="screenshots/15_build_200.png"><img loading="lazy" src="screenshots/15_build_200.png" alt="Build cards overlap at200 percent text size"></a><figcaption>Actual Settings200% / palette, baseline; rechecked in v065</figcaption></figure>
<figure><a href="screenshots_v065/26_alerts_200.png"><img loading="lazy" src="screenshots_v065/26_alerts_200.png" alt="Latest compact header and threat alerts clip or overlap"></a><figcaption>Controlled alerts200%, fresh v065 render</figcaption></figure>
<figure><a href="screenshots_v065/28_victory_200.png"><img loading="lazy" src="screenshots_v065/28_victory_200.png" alt="Victory actions are below the viewport at200 percent text"></a><figcaption>Controlled victory200%, fresh v065 render</figcaption></figure>
</div></details><div class="filters"><input id="q" type="search" placeholder="Search issue, fix or evidence" aria-label="Search audit"><select id="kind" aria-label="Finding type"><option value="">All types</option><option>bug</option><option>improvement</option></select><select id="priority" aria-label="Priority"><option value="">All priorities</option><option>P1</option><option>P2</option><option>P3</option></select><select id="category" aria-label="Interface or system area"><option value="">All areas</option></select><select id="evidence" aria-label="Evidence type"><option value="">All evidence</option><option>verified_runtime</option><option>source_confirmed</option><option>proposal</option></select><button id="reset" type="button">Reset</button></div><p id="count" role="status"></p><div id="results"></div></main>
<script type="application/json" id="data">PAYLOAD</script><script>
const data=JSON.parse(document.getElementById('data').textContent);const ids=['q','kind','priority','category','evidence'];const controls=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)]));const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));[...new Set(data.findings.map(x=>x.category))].sort().forEach(c=>{const o=document.createElement('option');o.textContent=c;controls.category.appendChild(o)});function render(){const q=controls.q.value.toLowerCase();const rows=data.findings.filter(x=>(!q||JSON.stringify(x).toLowerCase().includes(q))&&(!controls.kind.value||x.kind===controls.kind.value)&&(!controls.priority.value||x.priority===controls.priority.value)&&(!controls.category.value||x.category===controls.category.value)&&(!controls.evidence.value||x.evidence_level===controls.evidence.value));document.getElementById('count').textContent=rows.length+' of100 findings';document.getElementById('results').innerHTML=rows.map(x=>`<details id="${x.id}"><summary><span class="pill ${x.priority}">${x.priority}</span>${x.id} · ${esc(x.title)}<small>${esc(x.kind)} · ${esc(x.category)} · ${esc(x.evidence_level)} · effort${x.effort}</small></summary><div class="detail">${[['Evidence','evidence'],['Reproduce / context','reproduction'],['Player impact','impact'],['Suggested change','recommendation'],['Done when','acceptance']].map(([label,key])=>`<p><strong>${label}:</strong> ${esc(x[key])}</p>`).join('')}<p><strong>Frozen source:</strong> <a href="${esc(x.reviewed_source.replace(/:\d+$/,''))}">${esc(x.reviewed_source)}</a> · ${esc(x.key)}</p></div></details>`).join('')};ids.forEach(id=>controls[id].addEventListener('input',render));document.getElementById('reset').addEventListener('click',()=>{ids.forEach(id=>controls[id].value='');render()});render();
</script></html>'''
viewer = viewer.replace('with v0.6.5 UI rechecks', f'with v{VERSION} rechecks').replace('screenshots_v065/', 'screenshots_latest/').replace('fresh v065 render', 'fresh final-snapshot render').replace('rechecked in v065', 'source-rechecked in final snapshot')
viewer = viewer.replace('PAYLOAD', payload)
viewer = viewer.replace('<p>Start with', '<p class="muted">This snapshot covers the main game. The Netrun prototype added after the cutoff is outside the played evidence.</p><p>Start with')
(AUDIT / 'AUDIT_VIEWER.html').write_text(viewer, encoding='utf-8')

readme = '''# Audit artifacts

Open `AUDIT_VIEWER.html` locally for searchable/filterable100 findings and screenshots. `REVIEW.md` includes methods, performance limits and the complete review. `BACKLOG_100.csv` works in a spreadsheet; `BACKLOG_100.json` preserves structured evidence and acceptance checks. `ADDITIONAL_CANDIDATES.json` holds27 deferred/merged records outside the main count.

`source/` freezes the initial v0.6.4 production snapshot; `source_v065/` freezes the concurrent v0.6.5 update. Copies redirect save/settings paths into their own projects so probes cannot alter the user's real save. Manifests record production hashes before redirection. Sub-agent projects are also isolated. The audit did not edit production code.

Evidence:

- `playthrough.json`, `playthrough_engine.log`, `screenshots/01..20`: real rendered input-driven legal opening and settings/tabs. No full campaign claimed.
- `interface_states*.json`, `screenshots/25..29`, `screenshots_v065/25..29`: controlled UI/threat/victory fixtures. v065 files recheck the compact header and queue implementation.
- `probes/simulation_results.json`, `probes/corrupt_save_results.json`, `probes/corrupt_save.log`: new simulation/save probes.
- `probes/t99_current_results.json`: prior regression suite50PASS/0FAIL; fixed old issues not recounted.
- `probes/hud_v065_results.json`: latest message FIFO, restore, repeated-message and layout checks.
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
'''
readme = readme.replace('`source_v065/` freezes the concurrent v0.6.5 update.', f'`source_v065/` freezes the concurrent v0.6.5 update. `source_latest/` is the final authoritative snapshot declaring v{VERSION}; its production hashes are in source_latest_manifest.json. Intermediate files named v066 label the capture stage, not a claim about the declared release version.')
readme = readme.replace('`screenshots_v065/25..29`', '`screenshots_latest/25..29`').replace('v065 files recheck', 'Latest files recheck').replace('`probes/hud_v065_results.json`', '`probes/hud_v066_results.json`').replace('`probes/t99_current_results.json`', '`probes/t99_v066_results.json`')
(AUDIT / 'README.md').write_text(readme, encoding='utf-8')

# Check current production against the latest reviewed manifest without touching it.
manifest = json.loads((AUDIT / 'source_latest_manifest.json').read_text(encoding='utf-8-sig'))
drift = []
for entry in manifest:
    p = WORKSPACE / entry['path']
    actual = hashlib.sha256(p.read_bytes()).hexdigest().upper() if p.exists() else 'MISSING'
    if actual != entry['sha256'].upper():
        drift.append(dict(path=entry['path'], reviewed=entry['sha256'], current=actual))
validation = dict(total=100, unique_keys=len({x['key'] for x in items}), unique_ids=len({x['id'] for x in items}),
                  reviewed_version='v' + VERSION, counts=counts, excluded_count=len(EXCLUDED), source_links_valid=True, production_drift_after_latest=drift)
(AUDIT / 'REPORT_VALIDATION.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(validation, ensure_ascii=False, indent=2))
